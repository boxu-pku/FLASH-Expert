---
title: sourceTerms 总览 — Heatexchange 主流 + operator-split + 非 HEDP 简要
skill: flash-sourceterms
category: overview
source_anchors:
  - source/Driver/DriverMain/Driver_sourceTerms.F90:L55-L73
  - source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Config:L15-L19
  - source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange.F90:L124-L307
  - source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_ieEquilTime.F90:L36-L62
  - source/Simulation/SimulationMain/LaserSlab/Config:L10
manual_ref: "FLASH 4.8 User Guide §18"
created: 2026-07-20
last_verified: 2026-07-20
verifier: claude
status: draft
tags:
  - sourceterms
  - heatexchange
  - overview
  - spitzer
  - 3t
---

# sourceTerms 单元总览（Heatexchange 聚焦）

> **TL;DR**：sourceTerms 是 FLASH 所有"非 Hydro 源项"的集合。按 L-013 聚焦主流——**Heatexchange**（HEDP 3T 算例的电子-离子能量平衡，LaserSlab 用 Spitzer 变体）。其他 sourceTerms（Burn/Cool/Heat/Stir/Ionize/Flame/Polytrope）多用于天体物理，简要带过。EnergyDeposition（激光）归 flash-laser skill。

---

## 0. 术语速查（按 L-014，先解释再讲机制）

| 术语 | 解释 |
|---|---|
| **sourceTerm** | 在 Hydro 主循环每步之间应用的"非 Hydro 源项"。例：热交换、核燃烧、辐射冷却、激光沉积。和 Hydro 是 operator-split（分开算，不隐式耦合） |
| **3T (three-temperature)** | 三温模型——离子、电子、辐射各有独立温度（`TEION_VAR`/`TELE_VAR`/`TERAD_VAR`）和内能（`EION_VAR`/`EELE_VAR`/`ERAD_VAR`）。HEDP 必需，因为激光先加热电子，再慢慢传给离子 |
| **电子-离子平衡（coupling）** | 电子和离子通过库仑碰撞交换能量。HEDP 中时间尺度 ~皮秒（ps），比激光沉积（飞秒 fs）慢但比 Hydro（纳秒 ns）快 |
| **Spitzer-Härm** | 经典弱耦合等离子体输运理论（Spitzer & Härm 1953）。给出标准电子-离子平衡时间公式 `eqtime ~ T_ele^(3/2) / (Z² · n_ion · ln Λ)` |
| **Coulomb 对数（ln Λ）** | 库仑散射最大/最小碰撞参数之比的对数。编码小角散射累积效应。HEDP 典型值 1-10 |
| **Lee-More** | Lee & More (1984)，Spitzer 的扩展，处理稠密/部分简并等离子体。用于高 Z 物质（Au、CH foam） |
| **operator splitting** | 数值技术——一个时间步内不同物理过程按顺序应用，不隐式耦合。FLASH sourceTerms 都是 operator-split 自 Hydro |
| **HEDP** | High-Energy-Density Physics（高能量密度物理）——压强 > 1 Mbar 的等离子体（激光驱动 ICF、实验室天体） |
| **EOS `MODE_DENS_EI_MAT_EQUI`** | 强制所有物质 component（ion/ele）到同一温度的 EOS 模式。Heatexchange/Immediate 用它一步强制平衡 |

---

## 1. sourceTerms 在 HEDP 算例里扮演什么角色

### 1.1 一句话定位

sourceTerms = **Hydro 主循环每步之间加的"非 Hydro 源项"**。处理那些不能被 Hydro（流体方程）自然描述的物理过程：

- **能量在 component 间转移**（Heatexchange：电子 ↔ 离子）
- **能量从外部源注入**（EnergyDeposition 激光、Heat 中子沉积）
- **化学反应 / 核反应**（Burn 核燃烧、Flame 火焰）
- **辐射损失**（Cool 辐射冷却）
- **物质状态变化**（Ionize 电离演化）

### 1.2 HEDP 视角（LaserSlab）

LaserSlab 实际用的 sourceTerms（按 setup_call + Config）：

| sourceTerm | 用途 | HEDP 必需？ |
|---|---|---|
| **Heatexchange**（Spitzer 变体） | 电子-离子能量平衡 | ✓ 3T 必需 |
| **EnergyDeposition**（Laser） | 激光沉积到电子 | ✓ 激光算例必需（flash-laser 详讲） |

**其他 sourceTerms（Burn/Cool/Heat/Stir/Ionize/Flame/Polytrope）LaserSlab 不用**——它们是天体物理专用。

### 1.3 与其他单元的耦合

```
┌────────────────────────────────────────────────┐
│ Driver_evolveFlash 主循环                      │
│                                                │
│   ├── Hydro（更新 ENER_VAR）                   │
│   ├── Eos_wrapped（让 PRES/TEMP 自洽）         │
│   ├── Driver_sourceTerms:                      │
│   │   ├── Polytrope（多方修正，罕用）           │
│   │   ├── Stir（湍流驱动，非 HEDP）             │
│   │   ├── Flame（火焰，非 HEDP）                │
│   │   ├── Burn（核燃烧，非 HEDP）               │
│   │   ├── Heat（外热，非 HEDP）                 │
│   │   ├── Heatexchange ★ 本 skill 主角         │
│   │   │   └── 平衡 TEION ↔ TELE                │
│   │   ├── Cool（辐射冷却，非 HEDP）             │
│   │   ├── Ionize（电离演化，非 HEDP）           │
│   │   └── EnergyDeposition（激光） ★ flash-laser│
│   ├── Diffuse（隐式扩散，HYPRE）                │
│   ├── RadTrans（MGD 辐射扩散）                  │
│   └── Grid_updateRefinement                    │
└────────────────────────────────────────────────┘
```

---

## 2. sourceTerms 列表（按 L-013 主流在前）

| sourceTerm | 描述 | HEDP 必需？ | 详见 |
|---|---|---|---|
| **Heatexchange** ⭐ | 电子-离子能量平衡 | ✓ 3T 必需 | 本 skill 详讲 |
| **EnergyDeposition** | 激光沉积 | ✓ 激光算例必需 | flash-laser skill |
| Burn | 核燃烧（α链、NSE） | ✗ 天体物理 | 简要 |
| Cool | 辐射冷却（Λ(T) 表） | ✗ 天体物理 | 简要 |
| Heat | 外部加热（中子沉积） | ✗ CCSN | 简要 |
| Stir | 湍流驱动（OU 过程） | ✗ 天体物理 | 简要 |
| Turb | 湍流统计 | ✗ 天体物理 | 简要 |
| Ionize | 电离演化（H/He） | ✗ 天体物理 | 简要 |
| Flame | 亚网格火焰 | ✗ Type Ia SN | 简要 |
| Polytrope | 多方 EOS 修正 | ✗ 天体物理 | 简要 |
| Deleptonize | 轻子数损失 | ✗ CCSN | 简要 |
| PrimordialChemistry | 大爆炸化学网络 | ✗ 天体物理 | 简要 |
| Circuit | 外部电路耦合 | 边缘 HEDP（z-pinch）| 简要 |

**本 skill 只详讲 Heatexchange**（按 L-013）。其他 sourceTerms 各 1-2 句话简要，详见 `flash-sourceterms/knowledge/pitfalls.md §D` 或手册对应章节。

---

## 3. Heatexchange 5 个变体（核心内容）

源码：`source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Config:L15-L19`

```
EXCLUSIVE Constant ConstCoulomb Spitzer Immediate
DEFAULT Constant                          # Config 默认（LaserSlab 不用）
```

注：LeeMore 是单独子目录，不在 EXCLUSIVE 列表里但仍可选。

| 变体 | 物理 | 公式特点 | 何时选 |
|---|---|---|---|
| **Constant** | 用户给固定耦合系数 `hx_c12/hx_c13/hx_c23` | 不算 ln Λ | 快速测试、调试、简单算例 |
| **ConstCoulomb** | Spitzer 公式 + **固定** `hx_coulombLog` | 简化 Spitzer（不算 ln Λ） | 单物质中等耦合 |
| **Spitzer** ⭐ | Spitzer-Härm 公式 + PlasmaState 算 ln Λ | 完整经典 | **LaserSlab / HEDP 默认** |
| **LeeMore** | Lee-More 稠密等离子体修正 | 处理简并/强耦合 | 高 Z（Au、CH foam）HEDP |
| **Immediate** | 一步强制平衡 `Eos_wrapped(MODE_DENS_EI_MAT_EQUI)` | 不算时间尺度 | 调试、强制初始平衡 |

### 3.1 LaserSlab 用 Spitzer

源码：`source/Simulation/SimulationMain/LaserSlab/Config:L10`

```
REQUESTS physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer
```

**为什么 Spitzer 是 HEDP 默认**：

1. **经典等离子体适用**：HEDP 典型 T~100 eV、n~10²² cm⁻³，弱耦合（Γ << 1），Spitzer-Härm 准确度 ~10-20%
2. **自动算 ln Λ**：通过 PlasmaState 工具，每 cell 算物理正确的库仑对数
3. **能量守恒**：用解析 ODE 解（指数衰减），严格保证 `ΔE_ion + ΔE_ele = 0`

### 3.2 什么时候换 LeeMore

- **高 Z 物质**（Au hohlraum 壁、CH foam、W 靶）：T < 100 eV 时 Spitzer 低估电导率
- **稠密 / 简并等离子体**：Γ ~ 1（强耦合）或电子简并能 > kT

Lee & More (1984) 用密度和简并修正的 ln Λ，对 warm dense matter 实验数据符合更好。

### 3.3 Immediate 变体的用途

源码：`source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Immediate/`

```
call Eos_wrapped(MODE_DENS_EI_MAT_EQUI, blkLimits, blockID)
```

**一步强制 T_ion = T_ele**（按 cv 加权平均）。

**用途**：
- **调试**：怀疑 Spitzer 不收敛，用 Immediate 强制平衡看是否物理合理
- **初始化**：Simulation_initBlock 后强制 T_ion = T_ele 起步

**不要生产用**：忽略 ps 时间尺度，物理失真。

---

## 4. operator-split 设计（重要概念）

### 4.1 什么是 operator-split

源码：`source/Driver/DriverMain/Driver_sourceTerms.F90`

每 hydro 步内：

```
1. Hydro 推进（更新 ENER_VAR）
2. Eos_wrapped（让 PRES/TEMP 自洽）
3. Driver_sourceTerms（按顺序调各 sourceTerm）
   ├── Heatexchange（改 EION/EELE）
   ├── EnergyDeposition（改 EELE）
   └── ...
4. Eos_wrapped（让变量再次自洽）
5. 下一步
```

**为什么 operator-split**（不隐式耦合）：
1. **刚性**：核燃烧、辐射冷却时间尺度远短于 Hydro CFL，隐式耦合太贵
2. **模块化**：FLASH 设计哲学——即插即用单元
3. **守恒**：每个 sourceTerm 守恒自己的量

**代价**：dt 一阶误差。但 dt 足够小，可接受。

### 4.2 Driver_sourceTerms 默认调用顺序

源码：`source/Driver/DriverMain/Driver_sourceTerms.F90:L55-L73`

```
#ifdef DRIVER_EDEARLY        # 宏定义时激光最先
  call EnergyDeposition      # (激光提前)
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

### 4.3 为什么激光默认第 10 位（按 L-011）

**数值稳定性考虑**：等所有热损失（Cool）、能量交换（Heatexchange）、燃烧（Burn）算完再加激光，避免同一步内多次迭代的不稳定。

**何时改顺序**：用 `DRIVER_EDEARLY` 宏让激光最先（某些算例需要激光先沉积再算其他）。

setup 加 `+edearly`（或 Config 加 PPDEFINE）：

```bash
./setup LaserSlab ... +edearly ...
```

---

## 5. Spitzer-Härm 物理公式

### 5.1 电子-离子平衡时间 eqtime

源码：`source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_ieEquilTime.F90:L36-L62`

**Spitzer-Härm 公式**（Braginskii 形式）：

```
eqtime = (3 · sqrt(m_ele) · (k_B · T_ele)^(3/2)) /
         (4 · sqrt(2π) · ln Λ · q_e^4 · Z^2 · n_ion)
```

简化：

```
eqtime ~ T_ele^(3/2) / (Z² · n_ion · ln Λ)
```

**HEDP 典型值**：T~100 eV, n~10²² cm⁻³, Z~5, ln Λ~5 → eqtime ~ 1-100 ps。

### 5.2 解析 ODE 解（严格能量守恒）

源码：`source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange.F90:L198-L207`

设 cvratio = cvele / cvion，从 ODE：

```
dT_ele/dt = -(T_ele - T_ion) · (1 + cvratio) / eqtime
```

解析解：

```
A = (T_ion + cvratio · T_ele) / (1 + cvratio)    # 最终平衡 T
B = (T_ele - T_ion) / (1 + cvratio)               # 振幅

T_ele_new = A + B · exp(-(1+cvratio)·dt/eqtime)
T_ion_new = A - cvratio · B · exp(-(1+cvratio)·dt/eqtime)
```

**能量守恒**：

```
cvion · (T_ion_new - T_ion) + cvele · (T_ele_new - T_ele) = 0
```

严格为 0（解析解性质），不是数值近似。

### 5.3 为什么用解析解（不用数值积分）

1. **严格守恒**：解析解保证 ΔE_ion + ΔE_ele = 0
2. **无条件稳定**：任意 dt 都不发散（数值积分可能震荡）
3. **快**：每 cell 几次乘除，不需要迭代

---

## 6. PlasmaState 工具（共享计算）

源码：`source/physics/utilities/PlasmaState/PlasmaStateMain/`

Heatexchange/Spitzer 调用 PlasmaState 算 ln Λ 和 eqtime：

| 函数 | 用途 |
|---|---|
| `PlasmaState_logLambda` | 算库仑对数 ln Λ（支持 Spitzer/LeeMore 不同模式） |
| `PlasmaState_ieEquilTime` | 算电子-离子平衡时间 eqtime |
| `PlasmaState_tau` | 算电子-离子碰撞时间 τ（Braginskii 形式） |

**为什么共享**：Conductivity（SpitzerHighZ）、Opacity 等其他单元也用 ln Λ，避免重复计算。

---

## 7. 与其他单元的耦合

### 7.1 EOS（multiTemp 必需）

源码：`HeatexchangeMain/Config:L17`

```
REQUIRES physics/Eos/EosMain/multiTemp
```

**为什么**：单温度模式（1T）下 T_ion = T_ele 永远成立，qdot = 0，Heatexchange 没意义。3T 才有平衡需求。

Heatexchange 内部调 EOS：
- `Eos_getAbarZbar` → 算 Abar/Zbar（用物质质量分数）
- `Eos(MODE_DENS_TEMP_GATHER, mask=[CVELE, CVION, DET])` → 算比热 cv
- `Eos_wrapped(MODE_DENS_EI_GATHER)` → 最后让变量自洽

### 7.2 Driver（computeDt 注册）

`Heatexchange_computeDt` 注册为 Driver_computeDt 的一个 dt 限制器。

### 7.3 EnergyDeposition（激光，flash-laser）

激光沉积到 EELE 后，Heatexchange 让电子能量部分转移到离子。

### 7.4 RadTrans（辐射扩散）

Heatexchange/Spitzer **不直接耦合**辐射（TRAD_VAR）。辐射-电子平衡由 RadTrans 处理。

### 7.5 Conductivity（Diffuse，SpitzerHighZ）

Heatexchange 和 Conductivity 都用 PlasmaState 算 ln Λ，但**互不调用**。

---

## 8. 延伸阅读

- **Heatexchange 参数完整字典**：`knowledge/params.md`
- **Heatexchange.F90 主流程**：`knowledge/internals.md`
- **典型配置**：`knowledge/recipes.md`
- **常见错误**：`knowledge/pitfalls.md`
- **EnergyDeposition（激光）**：`flash-laser` skill
- **EOS（3T 耦合）**：`flash-eos` skill
- **Driver 主循环**：`flash-driver` skill
- **手册**：FLASH 4.8 User Guide §18（opencode 部分转写）

---

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-20 | 初始创建（draft）：9 段总览 + 术语速查（L-014）+ Heatexchange 5 变体对比 + operator-split 设计 + Spitzer-Härm 公式 + Driver_sourceTerms 调用顺序 + PlasmaState 工具；按 L-011 重点讲"为什么" + L-013 聚焦 Heatexchange 主流 + L-014 解释专业术语 + L-012 公式 ASCII | claude |
