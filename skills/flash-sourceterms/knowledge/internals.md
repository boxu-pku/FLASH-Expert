---
title: sourceTerms 内部实现 — Heatexchange.F90 + Spitzer 算法 + PlasmaState 耦合
skill: flash-sourceterms
category: internals
source_anchors:
  - source/Driver/DriverMain/Driver_sourceTerms.F90:L55-L73
  - source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange.F90:L124-L307
  - source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange.F90:L198-L212
  - source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange_computeDt.F90
  - source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_ieEquilTime.F90:L36-L62
manual_ref: "FLASH 4.8 User Guide §18"
created: 2026-07-20
last_verified: 2026-07-20
verifier: claude
status: draft
tags:
  - sourceterms
  - internals
  - heatexchange
  - spitzer
  - call-graph
---

# sourceTerms 内部实现（Heatexchange 聚焦）

> **TL;DR**：Heatexchange 公共 API 只 4 个（Heatexchange / init / finalize / computeDt）。核心是 `Heatexchange(blockCount, blockList, dt)`——每 hydro 步调一次，循环每 cell 算 Spitzer eqtime + 解析 ODE 解 + 更新 EION/EELE。本文件讲：① 4 公共 API；② Heatexchange.F90 主流程；③ Spitzer 算法细节；④ PlasmaState 耦合；⑤ Driver_sourceTerms 调用顺序；⑥ 能量守恒机制。

### 术语速查（按 L-014，先解释再讲机制）

- **cv（比热）**：单位质量物质升高单位温度所需能量。Heatexchange 用 `cvion`（离子比热）和 `cvele`（电子比热）算能量变化。EOS 提供。
- **eqtime（平衡时间）**：电子-离子通过库仑碰撞达到热平衡的特征时间。Spitzer-Härm 公式：`eqtime ~ T_ele^(3/2) / (Z² · n_ion · ln Λ)`。HEDP 典型 1-100 皮秒。
- **ln Λ（库仑对数）**：库仑散射累积效应的标度。PlasmaState 工具按 T、n、Z 算。HEDP 典型 1-10。
- **解析 ODE 解**：解析（公式）解 vs 数值积分。Heatexchange 用解析解保证能量严格守恒（不是数值近似）。
- **operator-split**：sourceTerm 在 Hydro 主循环每步之间独立应用（不和 Hydro 隐式耦合）。
- **PlasmaState**：FLASH 的等离子体状态工具单元（`physics/utilities/PlasmaState/`），算 ln Λ、碰撞时间等共享量。多个单元（Heatexchange、Conductivity、Opacity）共用。

---

## 1. 公共 API 总览

源码：`source/physics/sourceTerms/Heatexchange/Heatexchange_interface.F90`

### 1.1 API 分类（4 函数）

| 函数 | 签名 | 用途 |
|---|---|---|
| `Heatexchange(blockCount, blockList, dt)` | `(IN int, IN int(:), IN real)` | 应用 HX 算子（每步调） |
| `Heatexchange_init(restart)` | `(IN logical)` | 读参数 + 设物理常量 |
| `Heatexchange_finalize()` | `()` | 清理（空 stub） |
| `Heatexchange_computeDt(blockID, blkLimits, blkLimitsGC, solnData, dt_heatXchg, dt_minloc)` | `(IN, IN, IN, IN, INOUT, INOUT)` | 时间步限制 |

**没有 `sourceTerms_interface.F90`**——每个 sourceTerm 有自己的接口文件（Heatexchange_interface.F90、Burn_interface.F90 等）。

### 1.2 关键 API 详解

#### `Heatexchange`（主入口）

源码：`source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange.F90:L124-L307`（327 行）

Driver_sourceTerms 每 hydro 步调一次。

#### `Heatexchange_init`

源码：`source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange_init.F90:L39-L48`

读参数 + 设物理常量：

```
- useHeatexchange / hx_logLevel / smalle
- hx_ieTimeCoef / hx_dtFactor / hx_relTol
- 物理常量（via PhysicalConstants_get）：
  electron mass / Boltzmann / electron charge / Planck / Avogadro
```

#### `Heatexchange_computeDt`

源码：`source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange_computeDt.F90`

dt 限制（行 24-44）：

```
dt_heatXchg = hx_dtFactor × (eint / |qdot|)
            = hx_dtFactor × (eint × eqtime / (cv × |T_ion - T_ele|))
```

约束：`|qdot × dt| < hx_dtFactor × eint`（每步能量交换不超内能比例）。

---

## 2. Heatexchange.F90 主流程（Spitzer 变体）

源码：`source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange.F90`（327 行）

### 2.1 11 步流程（文字 + 缩进）

```
Heatexchange(blockCount, blockList, dt)
│
├── Step 1: 前置检查
│   └── if (.not. useHeatexchange) return
│
├── Step 2: 对每 block:
│   └── Grid_getBlkPtr(blockID, solnData, CENTER)
│
├── Step 3: 通知 Grid 数据更新（行 101）
│   └── Grid_notifySolnDataUpdate([EION_VAR, EELE_VAR], ...)
│       └── 标记 guard cell 待重填
│
├── Step 4: 主循环——逐 cell 处理（行 124-307）
│   for each cell (i, j, k) in block:
│   │
│   ├── Step 4a: 读 ρ, T_ion, T_ele（行 129-131）
│   │   └── rho = solnData(DENS_VAR, i, j, k)
│   │       tion = solnData(TION_VAR, i, j, k)
│   │       tele = solnData(TELE_VAR, i, j, k)
│   │
│   ├── Step 4b: 算 Abar, Zbar（行 134）
│   │   └── call Eos_getAbarZbar(solnData(:,i,j,k), abar, zbar, ...)
│   │
│   ├── Step 4c: 算 cvion, cvele（行 144-152）
│   │   └── call Eos(MODE_DENS_TEMP_GATHER, vecLen, eosData, mask=[CVELE, CVION, DET])
│   │       └── 从 EOS 拿比热
│   │
│   ├── Step 4d: 算离子数密度 + 质量（行 190-191）
│   │   └── nion = rho × N_A / abar
│   │       mion = abar / N_A
│   │
│   ├── Step 4e: 算库仑对数 ln Λ（行 193）
│   │   └── call PlasmaState_logLambda(ELE_ION, tele, tion, zbar×nion, mion, zbar, ll, .true.)
│   │       └── PlasmaState 按 Spitzer-Härm 算
│   │
│   ├── Step 4f: 算平衡时间 eqtime（行 194）
│   │   └── call PlasmaState_ieEquilTime(eqtime, tele, tion, ll, zbar, ...)
│   │       └── eqtime ~ T_ele^(3/2) / (Z²·n·ln Λ)
│   │
│   ├── Step 4g: 缩放 eqtime（行 196）
│   │   └── eqtime = eqtime × hx_ieTimeCoef
│   │
│   ├── Step 4h: 解析 ODE 解（行 198-207）★ 核心
│   │   cvratio = cvele / cvion
│   │   A = (tion + cvratio × tele) / (1 + cvratio)
│   │   B = (tele - tion) / (1 + cvratio)
│   │   decay = exp(-(1+cvratio) × dt / eqtime)
│   │   tele_new = A + B × decay
│   │   tion_new = A - cvratio × B × decay
│   │
│   ├── Step 4i: 更新 EION/EELE（行 211-212）
│   │   solnData(EION_VAR, i, j, k) += cvion × (tion_new - tion)
│   │   solnData(EELE_VAR, i, j, k) += cvele × (tele_new - tele)
│   │   └── 严格守恒（ΔE_ion + ΔE_ele = 0）
│   │
│   └── Step 4j: 负能量回退（行 214-302）
│       └── if (EION 或 EELE 变负)：
│           ├── 用新温度重算 EION/EELE（via Eos）
│           └── 按总能比例缩放，保证守恒
│
├── Step 5: 释放指针
│   └── Grid_releaseBlkPtr(blockID, solnData, CENTER)
│
└── Step 6: EOS 调和（行 320）
    └── call Eos_wrapped(MODE_DENS_EI_GATHER, blkLimits, blockID)
        └── 让温度从更新后的能量重算（自洽）
```

### 2.2 为什么是这个流程

| 步骤 | 为什么在这位置 |
|---|---|
| Step 3 notifySolnDataUpdate | 提前告诉 Grid 即将改 EELE/EION，让其他单元知道 guard cell 脏了 |
| Step 4c 算 cv | 用 EOS 算的 cv（不是常数），随 T 变化 |
| Step 4e-f 算 ln Λ 和 eqtime | Spitzer 公式核心；通过 PlasmaState 共享 |
| Step 4h 解析解 | 保证能量守恒（数值积分做不到） |
| Step 4j 负能量回退 | EOS cv 跳变时解析解可能给负能量，回退机制保证物理合理 |
| Step 6 EOS 调和 | 让 PRES / TEMP 从更新后的能量重算 |

---

## 3. Spitzer 算法详解

### 3.1 ODE 形式

电子-离子能量交换 ODE（Braginskii 形式）：

```
cvele · dT_ele/dt = -qdot
cvion · dT_ion/dt = +qdot

qdot = cv · (T_ele - T_ion) / eqtime
```

其中 cv 是某个加权平均（解析解用 cvratio = cvele/cvion）。

### 3.2 解析解（行 198-207）

设 α = 1 + cvratio（cvratio = cvele/cvion），从 ODE：

```
dT_ele/dt = -(T_ele - T_ion) · α / eqtime
```

解析解：

```
A = (T_ion + cvratio · T_ele) / (1 + cvratio)    # 最终平衡 T
B = (T_ele - T_ion) / (1 + cvratio)               # 振幅

T_ele_new = A + B · exp(-α · dt / eqtime)
T_ion_new = A - cvratio · B · exp(-α · dt / eqtime)
```

**能量守恒验证**：

```
ΔE_ion = cvion · (T_ion_new - T_ion)
       = cvion · (-cvratio · B · (decay - 1))
       = -cvion · cvratio · B · (decay - 1)
       = -cvele · B · (decay - 1)    [因为 cvratio = cvele/cvion]

ΔE_ele = cvele · (T_ele_new - T_ele)
       = cvele · B · (decay - 1)

ΔE_ion + ΔE_ele = 0  ✓
```

严格为 0（解析解性质），不是数值近似。

### 3.3 为什么用解析解（不用数值积分）

1. **严格守恒**：ΔE_ion + ΔE_ele = 0（数值积分有舍入误差）
2. **无条件稳定**：任意 dt 都不发散（数值 Euler 在 dt > eqtime/2 震荡）
3. **快**：每 cell 几次乘除，不需要迭代

### 3.4 负能量回退（行 214-302）

**触发**：EOS 的 cv 随 T 跳变（如相变），解析解算出的 T_ion_new 或 T_ele_new 让能量变负。

**机制**：
1. 用新温度重算 EION/EELE（via Eos）
2. 按总能比例缩放（保证 ΔE_ion + ΔE_ele = 0）

这是**安全网**，正常算例不触发。

---

## 4. PlasmaState 工具（共享计算）

源码：`source/physics/utilities/PlasmaState/PlasmaStateMain/`

Heatexchange/Spitzer 调用 3 个 PlasmaState 函数：

### 4.1 PlasmaState_logLambda

源码：`source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_logLambda.F90`

```fortran
call PlasmaState_logLambda(ELE_ION, tele, tion, zbar*nion, mion, zbar, ll, .true.)
```

参数：
- `ELE_ION`：碰撞类型（电子-离子）
- `tele, tion`：温度
- `zbar*nion`：电子数密度
- `mion`：离子质量
- `zbar`：平均电荷
- `ll`：返回的 ln Λ 值
- `.true.`：Spitzer 经典模式开关

**返回**：库仑对数 ln Λ（HEDP 典型 1-10）。

### 4.2 PlasmaState_ieEquilTime

源码：`source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_ieEquilTime.F90:L36-L62`

```fortran
call PlasmaState_ieEquilTime(eqtime, tele, tion, ll, zbar, ...)
```

**返回**：电子-离子平衡时间 eqtime（秒）。HEDP 典型 1-100 ps。

**公式**（Spitzer-Härm）：

```
eqtime = (3 · sqrt(m_ele) · (k_B · T_ele)^(3/2)) /
         (4 · sqrt(2π) · ln Λ · q_e^4 · Z^2 · n_ion)
```

### 4.3 PlasmaState_tau

源码：`source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_tau.F90:L38`

算电子-离子碰撞时间 τ（Braginskii 形式），ieEquilTime 内部调它。

### 4.4 为什么共享

Conductivity（SpitzerHighZ）、Opacity、Heatexchange 都需要 ln Λ。共享 PlasmaState 避免每个单元重复实现。

---

## 5. Driver_sourceTerms 调用顺序

源码：`source/Driver/DriverMain/Driver_sourceTerms.F90:L55-L73`

### 5.1 默认顺序（行 55-71）

```
#ifdef DRIVER_EDEARLY        # 宏定义时激光最先
  call EnergyDeposition      # 激光提前
#endif
  call Polytrope             # 1
  call Stir                  # 2
  call Turb_calc             # 3
  call Flame_step            # 4
  call Burn                  # 5
  call Heat                  # 6
  call Heatexchange          # 7 ★ LaserSlab 用
  call Cool                  # 8
  call Ionize                # 9
#ifndef DRIVER_EDEARLY       # 默认激光最后
  call EnergyDeposition      # 10 ★ 激光默认第 10 位
#endif
  call Deleptonize           # 11
```

### 5.2 调用顺序的物理考虑

| 顺序 | sourceTerm | 为什么 |
|---|---|---|
| 1-6 | Polytrope / Stir / Turb / Flame / Burn / Heat | 这些是 "前期" 源项（变化较慢） |
| 7 | **Heatexchange** | 在激光前算电子-离子平衡，让激光沉积时 TELE 已合理 |
| 8-9 | Cool / Ionize | 辐射冷却 + 电离演化 |
| 10 | **EnergyDeposition**（激光） | 默认最后；等所有热损失和能量交换算完再加激光，避免同一步迭代不稳定 |
| 11 | Deleptonize | 最后算轻子数损失 |

### 5.3 DRIVER_EDEARLY 宏（让激光提前）

```bash
./setup LaserSlab ... +edearly ...
```

效果：EnergyDeposition 调到位置 0（最先）。

**何时用**：某些算例需要激光先沉积（如激光驱动的初始压力建立）。

### 5.4 怎么改调用顺序

1. **DRIVER_EDEARLY 宏**（激光提前）
2. **直接改 Driver_sourceTerms.F90**（重排 call 顺序）—— 不推荐
3. **替换 Driver 变体**（+with-unit=...）—— 高级

---

## 6. Driver_computeDt 集成

源码：`source/Driver/DriverMain/Driver_computeDt.F90:L79, L393-L394`

```fortran
use Heatexchange_interface, ONLY: Heatexchange_computeDt, ...
...
do i = 1, blockCount
    call Heatexchange_computeDt(blockList(i), blkLimits, blkLimitsGC, &
                                 solnData, dt_hx, dt_minloc)
    dt = min(dt, dt_hx)
end do
```

**dt_hx 公式**（Spitzer）：

```
dt_hx = hx_dtFactor × (eint × eqtime) / (cv × |T_ion - T_ele|)
```

**LaserSlab 禁用**（hx_dtFactor = 1e100）。

---

## 7. 完整调用关系（文字 + 缩进）

```
Driver_evolveFlash
│
├── (初始化) Driver_initFlash
│   └── Heatexchange_init ★
│       ├── 读 useHeatexchange / hx_dtFactor / hx_ieTimeCoef 等
│       └── 设物理常量（electron mass / Boltzmann / 等）
│
├── (主循环每步)
│   ├── Grid_fillGuardCells
│   ├── Hydro（更新 ENER_VAR）
│   ├── Eos_wrapped
│   ├── Driver_sourceTerms:
│   │   ├── Polytrope（罕用）
│   │   ├── Stir / Turb / Flame / Burn / Heat（非 HEDP）
│   │   ├── Heatexchange(blockCount, blockList, dt) ★ 本 skill 主角
│   │   │   ├── for each block:
│   │   │   │   ├── Grid_getBlkPtr
│   │   │   │   ├── Grid_notifySolnDataUpdate([EION, EELE])
│   │   │   │   ├── for each cell:
│   │   │   │   │   ├── 读 ρ, T_ion, T_ele
│   │   │   │   │   ├── Eos_getAbarZbar → Abar, Zbar
│   │   │   │   │   ├── Eos(MODE_DENS_TEMP_GATHER) → cvion, cvele
│   │   │   │   │   ├── PlasmaState_logLambda → ln Λ
│   │   │   │   │   ├── PlasmaState_ieEquilTime → eqtime
│   │   │   │   │   ├── 解析 ODE 解 → T_ion_new, T_ele_new
│   │   │   │   │   ├── 更新 EION_VAR, EELE_VAR（守恒）
│   │   │   │   │   └── 负能量回退（如需）
│   │   │   │   ├── Grid_releaseBlkPtr
│   │   │   │   └── Eos_wrapped(MODE_DENS_EI_GATHER)
│   │   ├── Cool / Ionize
│   │   ├── EnergyDeposition（激光，第 10 位；DRIVER_EDEARLY 可前移）
│   │   └── Deleptonize
│   ├── Diffuse（HYPRE）
│   ├── RadTrans（MGD）
│   └── Grid_updateRefinement
│
└── (收尾) Driver_finalizeFlash
    └── Heatexchange_finalize（空 stub）
```

---

## 8. 延伸阅读

- **sourceTerms 总览**：`knowledge/overview.md`
- **参数字典**：`knowledge/params.md`
- **典型配置**：`knowledge/recipes.md`
- **常见错误**：`knowledge/pitfalls.md`
- **EnergyDeposition（激光）**：`flash-laser` skill
- **EOS（3T）**：`flash-eos` skill
- **Driver 主循环**：`flash-driver` skill
- **手册**：FLASH 4.8 User Guide §18（opencode 部分转写）

---

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-20 | 初始创建（draft）：9 段 internals + 术语速查（L-014）；4 公共 API；Heatexchange.F90 11 步流程含行号；Spitzer 解析 ODE 解 + 能量守恒推导；PlasmaState 工具（logLambda/ieEquilTime/tau）；Driver_sourceTerms 调用顺序（11 位 + DRIVER_EDEARLY）；完整文字调用图（按 L-002 不用 mermaid） | claude |
