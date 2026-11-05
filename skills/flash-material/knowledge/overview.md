---
title: materialProperties 总览 — Conductivity/SpitzerHighZ + Opacity/Multispecies 主流 + 术语速查
skill: flash-material
category: overview
source_anchors:
  - source/physics/materialProperties/Conductivity/ConductivityMain/Config:L5-L7
  - source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Conductivity.F90:L122-L131
  - source/physics/materialProperties/Opacity/OpacityMain/Config:L1-L10
  - source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity.F90:L28-L222
  - source/Simulation/SimulationMain/LaserSlab/Config:L11
manual_ref: "FLASH 4.8 User Guide §16-§17"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: beta
tags:
  - materialproperties
  - conductivity
  - opacity
  - overview
  - spitzerhighz
  - ionmix4
  - hedp
---

# materialProperties 单元总览（Conductivity + Opacity 聚焦）

> **TL;DR**：materialProperties 是 FLASH 所有"物质属性查询"的集合。按 L-013 聚焦主流——**Conductivity/SpitzerHighZ**（HEDP 电子热传导，LaserSlab 用）+ **Opacity/Multispecies**（HEDP 多群辐射不透明度，LaserSlab 用 IONMIX4 表）。其他子单元（Viscosity / MagneticResistivity / Thermoelectric / MassDiffusivity / NSE）简要带过。

---

## 0. 术语速查（按 L-014，先解释再讲机制）

| 术语 | 解释 |
|---|---|
| **物质属性（material property）** | 等离子体在每个 cell 的"传导 / 阻挡 / 粘滞"等宏观输运系数。**不是状态量**（状态由 EOS 给出，如 T、ρ、P、E），而是描述能量/动量如何在 cell 间流动。**物质属性是状态量的函数**——给定 (ρ, T, X) 后查询 |
| **Conductivity（电导率/热导率）** | 物质传导热能的能力。HEDP 关注**电子热导率**（W/(cm·K) 或 erg/(cm·s·K)）。**越大**热扩散越快、温度梯度越平 |
| **isochoricCond** | "等容热导率"——直接从 Spitzer 公式得到的电导率 κ。**等容**指 cv 在不变密度下取值 |
| **diffCoeff** | "扩散系数"——`D = κ / (ρ · cv)`，单位 cm²/s。Diffuse 求解 `∂T/∂t = ∇·(D∇T)` 时直接用 D |
| **Spitzer-Härm 电导率** | 经典弱耦合等离子体的电子热导率公式（Spitzer & Härm 1953，Spitzer 1962）：`κ ~ T^(5/2) / (Z · ln Λ)`。HEDP 标准 |
| **SpitzerHighZ** | Spitzer 公式的 Atzeni 修正版（来自《Physics of Inertial Fusion》），含 `(Z + 3.3)` 经验项处理 Z>1 物质。LaserSlab 默认 |
| **Lee-More** | Lee & More (1984)，稠密/简并等离子体的电导率模型。处理电子简并（金属低温）。高 Z 物质（Au、CH foam）适用 |
| **Coulomb logarithm（ln Λ）** | 库仑散射最大/最小碰撞参数比的对数。编码小角散射累积效应。HEDP 典型值 1-10。**PlasmaState_logLambda** 共享计算 |
| **Opacity（不透明度）** | 物质阻挡/吸收辐射的能力。单位 1/cm（path length inverse）或 cm²/g（mass opacity）。**越大**辐射越难穿透 |
| **Rosseland 平均（κ_R）** | Rosseland & Meßmer 平均不透明度——**谐波权重**积分（`1/κ_R = ∫(dB/dT)dν / ∫(1/κ)(dB/dT)dν`）。**扩散近似**用，适合光学厚区 |
| **Planck 平均（κ_P）** | Planck 平均——**线性权重**积分（`κ_P = ∫κ(dB/dT)dν / ∫(dB/dT)dν`）。**发射/吸收**用，适合光学薄区或不透明区 |
| **Planck Absorption (PA)** | 吸收 Planck 不透明度——用于等离子体从辐射场吸收能量 |
| **Planck Emission (PE)** | 发射 Planck 不透明度——用于物质自身发射到辐射场 |
| **Rosseland (RO)** | Rosseland 平均——用于群间辐射扩散通量 |
| **IONMIX4** | FLASH 主流不透明度表格式（后缀 `.cn4`）。ASCII 文本，含 T × n × group 三维 PA/PE/RO 表。**LaserSlab 用此格式** |
| **IONMIX（老版）** | IONMIX v2 格式（后缀 `.imx`），早期版本，已被 IONMIX4 取代 |
| **TOPS** | 另一种表格式（LLNL 工具输出），FLASH 也支持但罕用 |
| **3T component** | 三温模型下，1=离子、2=电子、3=辐射。Conductivity 在 3T 下可分别查 ion/ele 的 κ |
| **EOSCOMP_ELE / EOSCOMP_ION / EOSCOMP_RAD** | FLASH 内部常量，对应 2/1/3 |
| **diff_advanceTherm** | Diffuse 单元的"热扩散推进" subroutine，**每步调用 Conductivity** 拿 κ 后传给 HYPRE 求解 |
| **flux limiter（通量限制器）** | 防止 Spitzer 公式在自由流区超光速，限制最大通量。LaserSlab 用 `fl_larsen`（系数 0.06） |
| **HEDP** | High-Energy-Density Physics（高能量密度物理）——压强 > 1 Mbar 的等离子体 |
| **operator-split** | Hydro 主循环每步之间顺序应用物质属性效应（不隐式耦合到 Hydro） |

---

## 1. materialProperties 在 HEDP 算例里扮演什么角色

### 1.1 一句话定位

materialProperties = **每个 cell 的物质属性查询服务**。其他单元（Diffuse/RadTrans/Hydro）需要 κ、χ、η 等系数时调用本单元，本单元**只查询不求解**。

### 1.2 HEDP 视角（LaserSlab）

LaserSlab 实际用的子单元：

| 子单元 | 用途 | HEDP 必需？ | LaserSlab 变体 |
|---|---|---|---|
| **Conductivity** | 电子热传导（diff_advanceTherm 调用） | ✓ 必需 | **SpitzerHighZ** |
| **Opacity** | 多群辐射不透明度（RadTrans/MGD 调用） | ✓ 辐射算例必需 | **Multispecies**（IONMIX4 表） |

**其他子单元（Viscosity/MagneticResistivity/Thermoelectric/MassDiffusivity/NSE）LaserSlab 不用**——Viscosity 是 Hydro 粘性（PPM/HYBRID 用人工粘性）、MagneticResistivity 是 MHD 磁扩散、Thermoelectric 是 Nernst 效应、MassDiffusivity 是组分扩散、NSE 是核统计平衡——都不是 LaserSlab 的 HEDP 物理需求。

### 1.3 与其他单元的耦合

```
┌────────────────────────────────────────────────┐
│ Driver_evolveFlash 主循环                      │
│                                                │
│   ├── Hydro（更新 ENER_VAR）                   │
│   ├── Eos_wrapped（让 PRES/TEMP 自洽）         │
│   ├── Driver_sourceTerms:                      │
│   │   ├── Heatexchange（Spitzer，PlasmaState） │
│   │   └── EnergyDeposition（激光）             │
│   ├── Diffuse（隐式扩散，HYPRE） ★ 调用 Conductivity│
│   │   └── diff_advanceTherm:                   │
│   │       └── call Conductivity(solnVec, cond_zone,│
│   │                              component=EOSCOMP_ELE)│
│   ├── RadTrans（MGD 辐射扩散） ★ 调用 Opacity  │
│   │   └── RadTrans.F90 do g=1,op_nEnergyGroups │
│   │       └── call Opacity(solnVec, g, κ_abs, κ_emi, κ_trans)│
│   └── Grid_updateRefinement                    │
└────────────────────────────────────────────────┘

materialProperties 是**被调用方**——只在 Diffuse/RadTrans/Heatexchange
需要时返回当前 cell 的物质属性值。
```

### 1.4 与 PlasmaState 共享

Conductivity/SpitzerHighZ 和 Heatexchange/Spitzer 都用 **PlasmaState_logLambda** 算 ln Λ。这是为了避免重复计算（同一 cell 同时算 Heatexchange 和 Conductivity 时，ln Λ 是同一个）。

| 共享工具 | 用途 |
|---|---|
| `PlasmaState_logLambda(ELE_ION, tele, tion, nele, mion, zbar, ll)` | 算电子-离子库仑对数（默认模式 + Spitzer 简化模式） |
| `PlasmaState_logLambda(ELE_ELE, ...)` | 算电子-电子库仑对数 |
| `PlasmaState_logLambda(ION_ION, ...)` | 算离子-离子库仑对数 |
| `PlasmaState_tau(...)` | 算电子-离子碰撞时间 τ |
| `PlasmaState_ieEquilTime(...)` | 算电子-离子平衡时间 eqtime（Heatexchange 用） |

详见 flash-sourceterms skill（Heatexchange 详讲）和 flash-driver（PlasmaState 工具集）。

---

## 2. 子单元列表（按 L-013 主流在前）

| 子单元 | 描述 | HEDP 必需？ | 详见 |
|---|---|---|---|
| **Conductivity** ⭐ | 电子/离子热传导 | ✓ 必需（LaserSlab 用 SpitzerHighZ） | 本 skill §3 详讲 |
| **Opacity** ⭐ | 多群辐射不透明度 | ✓ 辐射算例必需（LaserSlab 用 Multispecies/IONMIX4） | 本 skill §5 详讲 |
| Viscosity | 流体粘性（动量扩散） | ✗ LaserSlab 用人工粘性 | §7 简要 |
| MagneticResistivity | 磁场扩散电阻率 | ✗ MHD 算例才用 | §7 简要 |
| Thermoelectric | 热电效应（Nernst 等） | ✗ 高级 MHD | §7 简要 |
| MassDiffusivity | 组分扩散 | ✗ 多流体/混合 | §7 简要 |
| NSE | 核统计平衡 | ✗ 天体物理 | §7 简要 |

**本 skill 只详讲 Conductivity 和 Opacity**（按 L-013）。其他子单元各 1-2 句话简要，详见手册。

---

## 3. Conductivity 9 变体（核心内容）

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/Config:L5-L7`

```
DEFAULT Constant
EXCLUSIVE Constant Constant-diff Spitzer Stellar PowerLaw PowerLaw-gray SpitzerHighZ LeeMore EppHain JiHeld
```

| 变体 | 物理公式 | 何时选 | LaserSlab? |
|---|---|---|---|
| **Constant** | 用户给固定 κ（cond_constantParallel/Perpendicular/Cross） | 数值测试、调试、简单算例 | ✗ |
| **Constant-diff** | 直接给扩散系数 D（不通过 κ/ρcv） | 调试 | ✗ |
| **Spitzer** | `κ = ck · T^2.5`（ck = 9.2e-7） | 纯 H/He 等离子体（Z=1） | ✗ |
| **Stellar** | 恒星内部修正版 Spitzer | 天体物理 | ✗ |
| **PowerLaw** | `κ = a · T^b`（用户给 a, b） | 经验关系拟合 | ✗ |
| **PowerLaw-gray** | 灰体辐射+物质热传导（MHD 用） | MHD | ✗ |
| **SpitzerHighZ** ⭐ | Atzeni 修正：`κ ~ T^2.5 / (ln Λ · (Z+3.3))` | **HEDP 标准**（多元素 Z>1） | ✓ |
| **LeeMore** | Lee & More 1984，含稠密/简并修正 | 高 Z（Au、W、CH foam） | ✗ |
| **EppHain** | Epperlein-Hain（含磁场各向异性） | MHD 磁化等离子体 | ✗ |
| **JiHeld** | Ji-Held 2013，Epperlein-Hain 改进版 | MHD 强磁场 | ✗ |

### 3.1 LaserSlab 用 SpitzerHighZ

源码：`source/Simulation/SimulationMain/LaserSlab/Config:L11`

```
REQUESTS physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ
```

**为什么 SpitzerHighZ 是 HEDP 默认**（按 L-011 讲为什么）：

1. **多元素等离子体**：HEDP 靶材通常是 Al、CH、Au 等 Z>1 物质。Spitzer（无 Z 修正）低估 Z>1 物质电导率，**SpitzerHighZ 加 `(Z+3.3)` 经验项**处理 e-e 碰撞对 e-i 输运的修正
2. **Atzeni 公式可靠**：取自《Physics of Inertial Fusion》标准教材，ICF 社区广泛验证
3. **自动算 ln Λ**：通过 PlasmaState_logLambda，每 cell 算物理正确的库仑对数
4. **适用范围**：T > 10 eV、弱耦合（Γ << 1）。**HEDP 典型条件**

### 3.2 什么时候换 LeeMore

- **高 Z + 低温**：T < 50 eV 的 Au、W、CH foam。**SpitzerHighZ 低估**因为没考虑电子简并
- **稠密 / 简并等离子体**：Γ ~ 1（强耦合）或电子简并能 > kT（金属冷靶）

Lee & More (1984) 用密度和简并修正的 ln Λ，对 warm dense matter 实验数据符合更好。

### 3.3 什么时候用 Spitzer（无 Z 修正）

- **纯 H/He 等离子体**（Z=1）：`Z + 3.3 ≈ 4.3`，Spitzer（`ck · T^2.5`）系数已校准到 H
- **天体物理**（恒星大气、星际介质）
- **简化教学算例**：不需要 PlasmaState 依赖

### 3.4 什么时候用 Constant / PowerLaw

- **调试**：怀疑 SpitzerHighZ 公式有 bug，先用 Constant 看物理机制是否对
- **快速验证**：跑极短时间步看 Hydro/EOS 是否对
- **教学**：用 PowerLaw（`κ = T^2.5`）展示扩散行为

**生产算例不要用**：物理失真。

---

## 4. Conductivity 公式（SpitzerHighZ 详细）

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Conductivity.F90:L122-L131`

### 4.1 电子热导率公式（Atzeni 形式）

```
! 电子热导率
isochoricCondLoc = (8/π)^1.5 * k_B^3.5 / (sqrt(m_ele) * e^4)
                 * T_ele^2.5 / (ln Λ * (Z + 3.3))

! 离子热导率（数值远小于电子，通常忽略）
isochoricCondLoc_ion = 0.164 * 20 * (8/π)^1.5 * k_B^3.5 * T_ion^2.5
                     / (sqrt(m_ion) * e^4 * Z^4 * ln Λ)
```

**典型 HEDP 值**（Al, T=100 eV, ρ=2.7 g/cm³）：
- ln Λ ≈ 5
- Z ≈ 13（Al 全电离）
- κ_ele ≈ 10^7 erg/(cm·s·K) ≈ 10^5 W/(cm·K)

### 4.2 扩散系数

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Conductivity.F90:L135-L138`

```fortran
if (present(diffCoeff)) then
   diffCoeffLoc = isochoricCondLoc/(xden * cond_getCv(component=component,solnVec=solnVec))
end if
```

公式：

```
D = κ / (ρ · cv)
```

其中 cv 由 cond_getCv 通过 EOS 算（3T 下区分 cvion/cvele）。**Diffuse 求解** `∂T/∂t = ∇·(D∇T)` 时直接用 D，无需再除 ρcv。

### 4.3 为什么用 isochoricCond 而不是 isobaricCond

- **等容**（iso-choric）：密度不变下测的 cv。**Hydro 显式离散下，cell 内密度一步内不变**，所以等容近似合适
- **等压**（iso-baric）：会引入额外动量耦合，不适合 cell-based 显式 Hydro
- HEDP 物理上也合理：电子声速 << 流体速度，cell 内可视为等容

---

## 5. Opacity 7 变体

源码：`source/physics/materialProperties/Opacity/OpacityMain/Config:L10`

```
EXCLUSIVE Multispecies Constant Constcm2g ConstPerGroup BremsstrahlungAndThomson OPAL Zeldovich
```

| 变体 | 描述 | 何时选 | LaserSlab? |
|---|---|---|---|
| **Multispecies** ⭐ | 多物种混合，每物种独立配表（PA/PE/RO）| **HEDP 标准** | ✓ |
| **Constant** | 全域常数 κ（吸收=发射=输运） | 调试 | ✗ |
| **Constcm2g** | 常数 κ（cm²/g 单位） | 简化模型 | ✗ |
| **ConstPerGroup** | 每群一个常数 κ | 灰体近似测试 | ✗ |
| **BremsstrahlungAndThomson** | 韧致辐射+汤姆逊散射解析 | 全电离等离子体简化 | ✗ |
| **OPAL** | OPAL 表格式（恒星内部） | 天体物理 | ✗ |
| **Zeldovich** | Zeldovich 平均 | 高能 γ 辐射 | ✗ |

### 5.1 LaserSlab 用 Multispecies/IONMIX4

源码：`source/Simulation/SimulationMain/LaserSlab/flash.par:L60-L74`

```
useOpacity     = .true.

# Chamber (He):
op_chamAbsorb   = "op_tabpa"      # 用 PA 表
op_chamEmiss    = "op_tabpe"      # 用 PE 表
op_chamTrans    = "op_tabro"      # 用 RO 表
op_chamFileType = "ionmix4"       # 表格式
op_chamFileName = "he-imx-005.cn4"

# Target (Al):
op_targAbsorb   = "op_tabpa"
op_targEmiss    = "op_tabpe"
op_targTrans    = "op_tabro"
op_targFileType = "ionmix4"
op_targFileName = "al-imx-003.cn4"
```

### 5.2 为什么 Multispecies 是 HEDP 默认（按 L-011）

1. **多物质支持**：HEDP 算例通常 cham（腔体气体）+ targ（靶材）两种物质，每种 EOS/Opacity 表不同。Multispecies 让每 species 独立配
2. **per-group 查询**：MGD 每群（g=1..Ngrp）有独立 κ，Multispecies 内置 group loop
3. **多表共存**：吸收/发射/输运三种不透明度用不同表（PA/PE/RO），各自物理含义不同
4. **混合规则**：自动按 ion number density 加权混合（详见 `knowledge/internals.md §4.3`）

### 5.3 为什么三种表都要（PA + PE + RO）

**物理意义不同**（按 L-014）：

- **PA (Planck Absorption)**：等离子体从辐射场吸收能量时的等效不透明度。**用于能量交换项** `dE_rad/dt = -κ_PA · c · E_rad + κ_PE · 4σT^4`
- **PE (Planck Emission)**：等离子体自身发射到辐射场的不透明度。**用于发射源项**
- **RO (Rosseland)**：扩散通量平均。**用于群间扩散** `F = -c/(3κ_RO) ∇E_rad`

**HEDP 通常 PA ≠ PE ≠ RO**（特别是非灰体）。LaserSlab 三表都配。

### 5.4 Constcm2g vs Constant 区别

源码：`source/physics/materialProperties/Opacity/OpacityMain/Multispecies/method/Constant/op_getSpeciesConstantOpacities.F90:L45-L55`

```fortran
! op_constant: 表是 [length^-1] = [cm^-1]，直接给
! op_constcm2g: 表是 [cm^2/g]，需除密度 → [cm^-1]
op_speciesOpacities (ABSORPTION,species) = op_absorptionConstant (species) / dens
```

**为什么两种**：物理上 mass opacity（cm²/g）更基本（物质属性），但 FLASH 内部用 path-length opacity（cm^-1）。Constcm2g 让用户用物理单位给。

---

## 6. Viscosity / MagneticResistivity 简要

### 6.1 Viscosity（粘性）

源码：`source/physics/materialProperties/Viscosity/Config`

```
DEFAULT ViscosityMain
PARAMETER useViscosity BOOLEAN CONSTANT FALSE   # 默认关
PARAMETER useExplicitViscosity BOOLEAN TRUE      # 默认显式
```

LaserSlab **不用**（`useViscosity = .false.`），用 Hydro 的人工粘性（`use_avisc = .true.`, `cvisc = 0.1`）。

变体（在 `Viscosity/ViscosityMain/`）：
- **Constant**：固定 η（动力学粘度）
- **Spitzer**：经典等离子体公式，仅 3T 离子用

**何时用 Viscosity/Spitzer**：天体物理（高雷诺数剪切流），MHD 算例。

### 6.2 MagneticResistivity（磁阻）

源码：`source/physics/materialProperties/MagneticResistivity/MagneticResistivityMain/Config:L7-L10`

```
DEFAULT Constant
CHILDORDER Constant DaviesWen SpitzerHighZ Multitype
PARAMETER useMagneticResistivity BOOLEAN TRUE
```

LaserSlab **不用**（无 MHD）。MHD 算例（如 `magnetoHD` 问题）才用。

变体：
- **Constant**：固定电阻率
- **SpitzerHighZ**：Spitzer 公式（NRL 形式）：`η ~ Z · ln Λ / T^(3/2)`（[s]）
- **DaviesWen**：磁化等离子体修正
- **Multitype**：多物质混合

**何时用 MagneticResistivity**：MHD 算例（如 Z-pinch、磁化 ICF）。

### 6.3 Thermoelectric / MassDiffusivity / NSE

- **Thermoelectric**：热电效应（Nernst、Ettingshausen），高级 MHD。LaserSlab 不用
- **MassDiffusivity**：组分扩散（多流体混合）。LaserSlab 不用
- **NSE**：核统计平衡（天体物理 CCSN）。LaserSlab 不用

详见手册对应章节。

---

## 7. 与其他单元的耦合

### 7.1 EOS（拿 cv、abar、zbar）

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/cond_getCv.F90:L97-L121`

Conductivity/SpitzerHighZ 内部调 EOS：
- `Eos_getAbarZbar(solnVec, abar, zbar)` → 算平均原子量和电荷态
- `Eos(MODE_DENS_TEMP_GATHER, mask=[EOS_CV, EOS_DET])` → 算 cv（3T 下区分 cvion/cvele）
- 在 `cond_getCv` 内根据 `component` 选 EOS_CVION（1）/EOS_CVELE（2）

**为什么调 EOS 而不是常量**：cv 依赖 T、ρ、电离态。**multiTemp EOS** 模式下 cv_ele ≠ cv_ion（电子简并、电离能等影响）。物理正确性需要。

### 7.2 Diffuse（diff_advanceTherm 调用 Conductivity）

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/diff_advanceTherm.F90:L237`

```fortran
call Conductivity(solnVec(:,i,j,k), cond_zone, component=EOSCOMP_ELE)
```

每步：
1. **Diffuse 求 dt**：调 Conductivity 算 cond_zone → 算 D = κ/(ρcv) → 算 diffusion dt
2. **Diffuse 推进**：用 HYPRE 隐式解 `∂T/∂t = ∇·(D∇T)`，得 T_new
3. **Flux limiter**：限制 D 防止超光速（`diff_eleFlMode = "fl_larsen"`, `diff_eleFlCoef = 0.06`）

详见 flash-diffuse skill。

### 7.3 RadTrans（MGD per-group 调用 Opacity）

源码：`source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90:L486`

```fortran
do g = 1, op_nEnergyGroups
   do k, j, i:  ! 遍历 cell
      call Opacity(blkPtr(:,i,j,k), g, absorb_opac, emit_opac, trans_opac)
      ! 用 absorb_opac 算电子-辐射能量交换
      ! 用 trans_opac 算群间辐射扩散通量
   end do
end do
```

**注意**：每 cell 每群都调用一次 Opacity。**100 群 × 10⁶ cell × Nstep = 10⁹+ 次查询**。性能关键。

详见 flash-radtrans skill。

### 7.4 Heatexchange（共享 PlasmaState_logLambda）

Heatexchange/Spitzer 和 Conductivity/SpitzerHighZ 都用 `PlasmaState_logLambda(ELE_ION, ...)`。**互不调用**，但 ln Λ 计算共享。

详见 flash-sourceterms skill。

### 7.5 Multispecies（拿 species 名/A/Z）

源码：`source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Config:L23-L43`

Multispecies/Opacity 在 setup 阶段生成 `op_<spec>Absorb/Emiss/Trans/FileName/FileType` 参数，species 名来自 setup 命令行 `species=cham,targ`。

详见 flash-multispecies skill。

---

## 8. 延伸阅读

- **Conductivity 参数完整字典**：`knowledge/params.md`
- **Conductivity/SpitzerHighZ 主流程**：`knowledge/internals.md`
- **典型配置**：`knowledge/recipes.md`
- **常见错误**：`knowledge/pitfalls.md`
- **Heatexchange（电子-离子平衡）**：`flash-sourceterms` skill（共用 PlasmaState）
- **Diffuse（HYPRE 隐式扩散）**：`flash-diffuse` skill
- **RadTrans（MGD 求解）**：`flash-radtrans` skill
- **EOS（cv 计算）**：`flash-eos` skill
- **Multispecies（species 定义）**：`flash-multispecies` skill
- **手册**：FLASH 4.8 User Guide §16（Conductivity）、§17（Opacity）

---

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（beta）：9 段总览 + 术语速查（L-014）+ Conductivity 9 变体对比 + Opacity 7 变体对比 + per-group 设计 + SpitzerHighZ 公式 + Multispecies 混合规则 + 与 EOS/Diffuse/RadTrans/Heatexchange 协作；按 L-011 重点讲"为什么" + L-013 聚焦 Conductivity+Opacity 主流 + L-014 解释专业术语 + L-012 公式 ASCII | claude |
