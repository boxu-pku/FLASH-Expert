---
title: RadTrans 单元总览 — MGD 数学模型 + flux limiter + 物质耦合 + 变体对比
skill: flash-radtrans
category: overview
source_anchors:
  - source/physics/RadTrans/RadTransMain/Config:L2
  - source/physics/RadTrans/RadTransMain/MGD/Config
  - source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90:L31
  - source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90:L340-L356
  - source/physics/RadTrans/RadTransMain/MGD/rt_init.F90:L37-L131
manual_ref: "FLASH 4.8 User Guide §25"
created: 2026-07-19
last_verified: 2026-07-19
verifier: claude
status: draft
tags:
  - radtrans
  - mgd
  - overview
  - flux-limiter
  - implicit
  - hypre
---

# RadTrans 单元总览（MGD 聚焦）

> **TL;DR**：RadTrans 解**辐射输运方程**。FLASH 提供多个变体，但按 L-013 聚焦主流——**MGD（多群扩散）**是 HEDP/ICF/激光算例（如 LaserSlab）的唯一选择。MGD 把光子能量分 N 群（典型 6 群），每群解扩散方程，通过 `Diffuse_solveScalar` 调用 HYPRE 隐式求解。Flux limiter（LaserSlab 用 `fl_harmonic`）处理光学薄区的自由流极限。

---

## 1. RadTrans 在 HEDP 算例里扮演什么角色

### 1.1 一句话定位

RadTrans 单元 = **辐射能量在等离子体里的传输**。激光沉积能量到电子（`EELE_VAR`）后，电子通过韧致辐射把能量传给辐射场（`ERAD_VAR`），辐射场再扩散把能量带到等离子体其他区域。RadTrans 解这个扩散过程。

### 1.2 为什么 HEDP 需要 RadTrans

HEDP 算例里：
- **激光直接加热电子**（fs 时间尺度，flash-laser 处理）
- **电子通过韧致辐射发射光子**（ns 时间尺度，RadTrans + EOS 处理）
- **光子在等离子体扩散**（光速 c，但被不透明度 κ 限制实际速度 c·κ·Δx）
- **光子被其他区域电子吸收**（加热远区）

**没有 RadTrans**：辐射场假设瞬间平衡（gray + 立即耦合），物理严重失真——辐射无法将能量从激光沉积区传到靶背面。

### 1.3 与其他单元的耦合（LaserSlab 视角）

```
┌────────────────────────────────────────────────┐
│ Driver_evolveFlash 主循环                      │
│                                                │
│   ├── Hydro（更新 ENER_VAR）                   │
│   ├── Eos_wrapped（让 PRES/TEMP 自洽）         │
│   ├── Driver_sourceTerms:                      │
│   │   ├── EnergyDeposition（激光沉积到 EELE）  │  ← flash-laser
│   │   ├── Heatexchange（电子-离子平衡）        │
│   │   └── RadTrans（辐射扩散） ★ 本 skill     │
│   │       ├── 查 Opacity（per-group）          │  ← flash-material
│   │       ├── 算 flux limiter                  │
│   │       ├── 调 Diffuse_solveScalar（HYPRE）  │  ← flash-diffuse
│   │       ├── 更新 MGDRi_VAR（每群辐射能量）   │
│   │       └── 反馈到 EELE_VAR（电子内能）      │  ← flash-eos
│   └── Grid_updateRefinement                    │
└────────────────────────────────────────────────┘
```

---

## 2. 变体一览（按 L-013 主讲 MGD）

源码：`source/physics/RadTrans/RadTransMain/Config:L2`

```
DEFAULT MGD
```

| 变体 | 路径 | 描述 | 何时用 |
|---|---|---|---|
| **MGD**（默认） | `RadTransMain/MGD/` | 多群扩散，operator-split per-group HYPRE | **HEDP/ICF/激光默认** |
| MGD/Unified | `RadTransMain/MGD/Unified/` | electrons + 所有群耦合 HYPRE（一次解） | **实验性**（README 明示），不推荐生产 |
| MGD/ExpRelax | `RadTransMain/MGD/ExpRelax/` | RAGE-style 外迭代 | 罕用 |
| NeutrinoLeakage | `RadTransMain/NeutrinoLeakage/` | 核心坍缩超新星中子输运 | **非 HEDP**（中子星合并、CCSN） |

**本 skill 只详讲 MGD operator-split**（默认 + LaserSlab 用的）。其他变体简要带过——按 L-013 聚焦主流路径。

### 2.1 为什么 MGD 是默认

HEDP 算例需要：
1. **隐式时间步**（辐射扩散信号速度 = c，显式 CFL 会强迫 `dt < Δx/c`，需要 10⁶ 子步）
2. **多群结构**（HEDP 不透明度跨能段变化几个数量级，gray 模型失真）
3. **AMR 兼容**（HYPRE 提供分布式 block-structured AMR 求解）
4. **物质能量交换**（辐射↔电子通过韧致辐射耦合）

MGD operator-split 满足以上所有需求，且简单稳定。Unified 虽然更精确但实验性，NeutrinoLeakage 物理完全不同（中子）。

---

## 3. MGD 数学模型

### 3.1 辐射扩散方程（每群）

每群 g 解：

```
∂E_g/∂t - ∇·(D_g ∇E_g) = κ_a,g · c · (aT⁴·ΔP_g - E_g)
```

变量含义：
- `E_g`：第 g 群辐射能量密度（UNK 变量 `MGDRg_VAR`）
- `D_g`：扩散系数 = `c / (3 · κ_t,g)`（κ_t 是传输不透明度），flux limiter 修正后变成 `λ(R) · c / (3 · κ_t,g)`
- `κ_a,g`：吸收不透明度
- `aT⁴·ΔP_g`：Planck 发射项（黑体辐射的第 g 群份额，`ΔP_g` 来自 Planck 积分）
- `c`：光速

### 3.2 Flux limiter（处理光学薄区）

**问题**：纯扩散通量 `F = -D∇E` 在 `|∇E|` 大时会超过物理上限 `cE`（自由流极限）。

**解决**：引入 limiter `λ(R)`，让 `F = -λ(R) · D · ∇E`，其中 `R = |∇E| / (κ · E)`。

源码：`source/physics/RadTrans/RadTransMain/MGD/Config:L26`

| `rt_mgdFlMode` 取值 | λ(R) 公式特点 | 何时选 |
|---|---|---|
| `fl_none` | λ=1（不限流） | **危险**！只在测试纯扩散极限时用 |
| **`fl_harmonic`**（LaserSlab 用） | 调和平均，平滑过渡厚-薄区 | **HEDP 推荐** |
| `fl_larsen` | Larsen 七阶多项式 | 备选 |
| `fl_minmax` | min/max 组合 | 备选（有不连续性） |
| `fl_levermorepomraning1981` | Levermore-Pomraning 1981 | 理论精确，实现复杂 |

**注意**：源码**没有** `fl_geometric` 和 `fl_arithmetic`——这两个名字不存在（其他文档可能误列）。

### 3.3 为什么需要 flux limiter（详细解释）

**物理极限**：辐射通量上限是自由流（光子直线传播不带散射）：

```
F_free_stream = c · E
```

**纯扩散**给出：

```
F_diffusion = -(c / (3κ)) · ∇E
```

**问题**：当 `|∇E| / (κE) → ∞`（光学薄区，κ→0），`F_diffusion` 也 → ∞，违反物理极限。

**Flux limiter** 把有效扩散系数降到 `D_eff = λ(R) · D`，让 `F = λ(R) · c · |∇E| / (3κ) ≤ c · E`。`λ(R)` 在 R→0（光学厚）时 → 1（纯扩散），R→∞（光学薄）时 → 3κE/|∇E|（自由流）。

### 3.4 物质耦合（辐射↔电子）

源码：`MGD/RadTrans.F90:L528-L546`

每步 RadTrans 后：
1. 把每群辐射能量变化累加到 `MGDC_VAR`
2. **反馈到电子内能**：`EELE_VAR += MGDC_VAR · dt / ρ`
3. 调 `Eos_wrapped(MODE_DENS_EI_GATHER, ...)` 重算温度

**注意**：MGD 假设**电子温度**（`TELE_VAR`）做不透明度查询——不直接用辐射温度 `TRAD_VAR`。3T 效应需要 `rt_tightIonCoupling` 或 Unified 变体。

---

## 4. MGD 内部变体（同 MGD 但求解策略不同）

### 4.1 operator-split（默认 + LaserSlab 用的）

源码：`source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90`

**算法**：每群独立 HYPRE 求解：

```
for g = 1 to rt_mgdNumGroups:
    1. 查 Opacity(ρ, TELE, g) → κ_a, κ_t
    2. 算 COND_VAR = c³ / max(κ_t, ε·c³)
    3. 算 ABSR_VAR = c · κ_a
    4. 算 EMIS_VAR = κ_e · c · a · TELE⁴ · ΔP_g  (Planck 发射)
    5. 应用 flux limiter
    6. call Diffuse_solveScalar(g, COND_VAR, DFCF_VAR, ..., θ=1.0, ABSR_VAR, EMIS_VAR)
       └── HYPRE 解 7 点扩散方程 → 更新 MGDRg_VAR
    7. 累加 MGDC_VAR += (MGDRg_VAR_new - MGDRg_VAR_old) / dt
end for
8. 更新 EELE_VAR += MGDC_VAR · dt / ρ
9. Eos_wrapped 让温度自洽
```

**优点**：简单、稳定、支持 mesh replication（多 mesh copy 各解不同群）

### 4.2 Unified（实验性）

源码：`source/physics/RadTrans/RadTransMain/MGD/Unified/RadTrans.F90`

**算法**：把电子能量 + 所有群辐射能量**作为一个耦合 HYPRE 矩阵**一次解（block 结构）。

**优点**：无 operator-split 误差（更精确）

**缺点**：
- README 明示 "EXPERIMENTAL, VERY LIMITED TESTING"
- 不支持 mesh replication
- 群数受 HYPRE block 矩阵规模限制
- 时间步控制更复杂（θ_C, θ_D 分别控制吸收/发射耦合）

**结论**：**新算例不要用 Unified**，除非研究 MGD 算法本身。

### 4.3 ExpRelax（罕用）

源码：`source/physics/RadTrans/RadTransMain/MGD/ExpRelax/`

RAGE-style 外迭代：每步外迭代解 T_e ↔ E_r 平衡（解四次多项式根）。

**用途**：模拟 RAGE 代码的算法（用于代码对比验证）。HEDP 生产算例罕用。

---

## 5. 能群结构（mgd_meshgroups）

### 5.1 群数选择

LaserSlab 默认 **6 群**（5-decade 对数分布：0.1 eV 到 100 keV）：

```fortran
rt_mgdNumGroups = 6
rt_mgdBounds_1 = 1.e-1    # eV
rt_mgdBounds_2 = 1.e0
rt_mgdBounds_3 = 1.e1
rt_mgdBounds_4 = 1.e2
rt_mgdBounds_5 = 1.e3
rt_mgdBounds_6 = 1.e4
rt_mgdBounds_7 = 1.e5     # N+1 个边界（N 群需要 N+1 个边界）
```

### 5.2 群边界单位（重要）

源码：`rt_init.F90:L37, L131`

**`rt_mgdBounds_*` 单位是 eV**（不是 erg）！FLASH 内部用 `EV_TO_ERGS = 1.60217653e-12` 转换：

```fortran
group_bound_erg = group_bound_eV * EV_TO_ERGS
```

**常见错误**：用户误以为是 erg，写成 `1.6e-13`（实际应该是 `1.e-1` 表示 0.1 eV）。

### 5.3 mgd_meshgroups vs rt_mgdNumGroups

| 参数 | 类型 | 何时设 | 含义 |
|---|---|---|---|
| `mgd_meshgroups` | **setup 期变量** | setup 命令 | 编译期最大群数（分配 UNK 槽位） |
| `rt_mgdNumGroups` | runtime parameter | parfile | 实际使用的群数（≤ mgd_meshgroups） |

**例**：setup 用 `mgd_meshgroups=6` → 编译期有 6 个 `MGDR1_VAR`..`MGDR6_VAR` 槽；parfile 设 `rt_mgdNumGroups=6` → 全用。

### 5.4 IONMIX 表同步（重要陷阱）

**MGD 不自动同步** IONMIX 不透明度表的群结构！

用户责任：
- IONMIX 表有自己的群边界（如 100 群）
- MGD 的 `rt_mgdBounds_*` 必须和 IONMIX 表的群边界**手动对齐**
- 不对齐 → 物理静默错误（不 abort，但结果错）

---

## 6. 隐式时间步

### 6.1 为什么必须隐式

辐射扩散信号速度 = c（光速）。显式 CFL：

```
dt_explicit < Δx² / (D · Δx) = Δx / c
```

HEDP 典型 `Δx = 1e-4 cm`，`c = 3e10 cm/s` → `dt_explicit < 3e-15 s`。
Hydro 时间步 `dt_hydro ~ 1e-12 s` → 显式 RadTrans 需要 **1000 子步**每 hydro 步。

**全隐式（θ=1）**无条件稳定，1 个 HYPRE 求解即可。

### 6.2 rt_mgdthetaImplct

| 值 | 含义 | 稳定性 |
|---|---|---|
| 1.0（默认，LaserSlab 用） | 全后向 Euler | 无条件稳定 |
| 0.5 | Crank-Nicolson | 2 阶时间精度，但 `dt·c·κ > 2` 时震荡 |
| 0.0 | 全显式 | 不稳定，禁止用 |

### 6.3 rt_dtFactor

```fortran
rt_dtFactor = 0.02   # LaserSlab 用
```

**注意**：这只在 `rt_computeDt = .true.` 时生效。LaserSlab 不开 `rt_computeDt`，所以 `rt_dtFactor` 实际没用——隐式 HYPRE 求解无条件稳定，不需要辐射 dt 限制。

---

## 7. 边界条件

源码：`MGD/RadTrans.F90:L266-L274`

### 7.1 边界类型

| BC 类型 | 含义 | 何时选 |
|---|---|---|
| `reflecting` | 镜像（Neumann 零梯度） | 对称面 |
| `vacuum` | 自由流出口（黑体辐射出射） | 靶背面、开放边界 |
| `dirichlet` | 固定辐射温度（用 `rt_mgdXlBoundaryTemp`） | 外部辐射源 |
| `periodic` | 周期 | 全周期算例 |
| `outflow` | 流出 | 类似 vacuum |
| `outstream` | 入流 | 罕见 |

### 7.2 LaserSlab 边界（典型 HEDP）

```fortran
rt_mgdXlBoundaryType = "reflecting"   # 激光入射侧（对称）
rt_mgdXrBoundaryType = "vacuum"        # 靶背（辐射自由流出）
rt_mgdYlBoundaryType = "vacuum"        # 靶侧（开放）
rt_mgdYrBoundaryType = "reflecting"    # 对称
```

**为什么 X 方向 asymmetric（左 reflecting，右 vacuum）**：
- 左是激光入射方向，假设轴对称（reflecting）
- 右是靶背，辐射会向外逃逸（vacuum）

---

## 8. 与其他单元的耦合（详）

### 8.1 Diffuse（HYPRE 接口）

MGD **不直接调 HYPRE**，而是通过 `Diffuse_solveScalar`：

```fortran
! source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90:L415
call Diffuse_solveScalar(gvar, COND_VAR, DFCF_VAR,
                         bcTypes, bcValues, dt, 1.0, 1.0, mgdTheta,
                         pass, nblk, blklst, ABSR_VAR, EMIS_VAR)
```

Diffuse 内部建 HYPRE 矩阵、求解、返回结果。详见 `flash-diffuse`（Phase 2 后）。

### 8.2 EOS（电子温度耦合）

MGD 在两处调 EOS：
- **guard cell 填充后**（行 220-222）：`Eos_guardCells(MODE_DENS_EI_ELE, ...)` → 让 `TELE_VAR` 在 guard cell 自洽
- **所有群解完后**（行 528-546）：`Eos_wrapped(MODE_DENS_EI_GATHER, ...)` → 从更新后的 `EELE_VAR` 重算温度

### 8.3 Opacity（per-group 查询）

每群每 cell 查一次：

```fortran
! source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90:L301, L486
call Opacity(blkPtr(:,i,j,k), g, absorb_opac, emit_opac, trans_opac)
```

返回 3 个不透明度：
- `absorb_opac` → ABSR_VAR = `c · κ_a`
- `emit_opac` → EMIS_VAR = `κ_e · c · a · T⁴ · ΔP_g`
- `trans_opac` → COND_VAR = `c³ / max(κ_t, ε·c³)`

**查询温度**：用 `TELE_VAR`（电子温度）—— 不是 TRAD_VAR。

### 8.4 Hydro（能量反馈）

MGD 改 `EELE_VAR`，然后通过 EOS 让总能量 `ENER_VAR` 自洽。Hydro 下一步用更新后的 `ENER_VAR`。

**注意**：辐射压力 `PRAD_VAR` **不被** operator-split MGD 应用到 Hydro！这是已知局限。

---

## 9. 延伸阅读

- **参数完整字典**：`knowledge/params.md`
- **MGD 主流程**：`knowledge/internals.md`
- **典型配置**：`knowledge/recipes.md`
- **常见错误**：`knowledge/pitfalls.md`
- **Hydro 单元**：`flash-hydro` skill
- **EOS 单元（TELE/EELE 耦合）**：`flash-eos` skill
- **Diffuse 单元（HYPRE 接口）**：`flash-diffuse`（Phase 2 后）
- **手册**：FLASH 4.8 User Guide §25（opencode 已转，含互补内容）

---

## 10. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft）：10 段总览 + MGD 数学模型 + flux limiter 物理意义（5 种 + 解释为什么需要）+ 物质耦合 + 4 变体对比（按 L-013 主讲 MGD）+ 能群结构 + 隐式求解 + 边界 + 与 Diffuse/EOS/Opacity/Hydro 耦合；按 L-011 重点讲"为什么" + L-013 聚焦 MGD 主流路径 + L-012 公式 ASCII | claude |
