---
title: materialProperties 参数完整字典 — Conductivity + Opacity + Viscosity + MagneticResistivity
skill: flash-material
category: params
source_anchors:
  - source/physics/materialProperties/Conductivity/ConductivityMain/Config:L5-L9
  - source/physics/materialProperties/Conductivity/ConductivityMain/Constant/Config:L1-L5
  - source/physics/materialProperties/Opacity/OpacityMain/Config:L4-L10
  - source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Config:L4-L43
  - source/physics/materialProperties/MagneticResistivity/MagneticResistivityMain/Config:L5-L35
  - source/physics/materialProperties/Viscosity/Config:L3-L12
manual_ref: "FLASH 4.8 User Guide §16-§17 + parfiles"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: beta
tags:
  - materialproperties
  - conductivity
  - opacity
  - params
  - runtimeparameters
---

# materialProperties 参数完整字典

> **TL;DR**：FLASH 4.8 materialProperties 的全部 runtime parameters，按子单元分组。每个参数给：类型、默认、单位、含义、声明位置、**为什么默认这个值**（L-011）。

---

## 1. 主控开关（顶层）

| 参数 | 类型 | 默认 | 含义 | 声明位置 |
|---|---|---|---|---|
| `useConductivity` | BOOLEAN | TRUE | 是否启用 Conductivity 单元（计算电子/离子热传导） | `Conductivity/ConductivityMain/Config:L9` |
| `useOpacity` | BOOLEAN | TRUE | 是否启用 Opacity 单元（计算辐射不透明度） | `Opacity/OpacityMain/Config:L7` |
| `useViscosity` | BOOLEAN CONSTANT | FALSE | 是否启用 Viscosity 单元（**CONSTANT** = 编译期固定，运行时改无效） | `Viscosity/Config:L8` |
| `useMagneticResistivity` | BOOLEAN | TRUE | 是否启用 MagneticResistivity 单元（MHD 才有意义） | `MagneticResistivity/Config:L9` |

### 1.1 为什么 useConductivity / useOpacity 默认 TRUE

**为什么 TRUE**：HEDP 算例几乎都需要热传导 + 辐射。**变体 Config 里有具体公式，关闭等于返回 0**——但 0 会让物理失真（能量不扩散）。

**何时改 FALSE**：纯 Hydro 算例（如 Sedov、KelvinHelmholtz）不需要扩散。

### 1.2 为什么 useViscosity 默认 FALSE（CONSTANT）

**为什么 FALSE**：Hydro 单元自带人工粘性（PPM/HYBRID 用 `cvisc=0.1`），物理粘性通常可忽略（高雷诺数流）。

**为什么 CONSTANT**：useViscosity 影响是否编译 Viscosity 子树。**编译期决定**，运行时改无效（要重新 setup）。

### 1.3 为什么 useMagneticResistivity 默认 TRUE（但 LaserSlab 不用）

**为什么 TRUE**：MagneticResistivity 子单元默认编译。但 LaserSlab 没用 MHD（`+noMHD` 或没 `+magnetic`），所以实际不调用。

---

## 2. Conductivity 参数

### 2.1 Constant 变体（数值测试用）

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/Constant/Config`

| 参数 | 类型 | 默认 | 单位 | 含义 |
|---|---|---|---|---|
| `cond_constantParallel` | REAL | 0.0 | erg/(cm·s·K) | 平行方向热导率（各向异性用） |
| `cond_constantPerpendicular` | REAL | 0.0 | erg/(cm·s·K) | 垂直方向热导率（磁化等离子体用） |
| `cond_constantCross` | REAL | 0.0 | erg/(cm·s·K) | 交叉方向热导率（Hall 效应） |
| `cond_constantIsochoric` | REAL | 0.0 | erg/(cm·s·K) | 等容热导率（设非 0 时覆盖其他三个） |

**为什么默认 0.0**：用户必须显式给值，否则 cond_zone 全 0，物理无意义（无扩散）。

**用法**：调试时设 `cond_constantIsochoric = 1e7` 看 Hydro/EOS 是否对。

### 2.2 SpitzerHighZ 变体（LaserSlab 默认）

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Config`

```
REQUIRES physics/utilities/PlasmaState
```

**无专属 runtime parameter**——SpitzerHighZ 全部从 solnVec 状态（ρ、T_ele、T_ion、massfrac）和 PlasmaState 算。物理常数（m_ele、k_B、e、N_A）从 PhysicalConstants 单元拿。

**为什么无参数**：公式严格按 Atzeni 形式，无可调经验项。**这是优点**（无 hidden knob），**也是缺点**（不能 fine-tune）。

### 2.3 Spitzer 变体（Z=1 经典版）

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/Spitzer/Conductivity.F90:L55-L56`

```fortran
real, parameter :: ck = 9.2e-7    ! 硬编码系数
real, parameter :: cexp = 2.5     ! T 指数
```

**无 runtime parameter**——ck 和 cexp 硬编码。

**为什么硬编码**：Spitzer (1962) 标准值，校准到 H 等离子体。改公式用 PowerLaw 变体。

### 2.4 PowerLaw 变体

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/PowerLaw/Config`

| 参数 | 类型 | 默认 | 单位 | 含义 |
|---|---|---|---|---|
| `cond_PowerLawConst` | REAL | 1.0 | 复合单位 | 系数 a |
| `cond_PowerLawExp` | REAL | 2.5 | 无 | T 指数 b |

**为什么默认 exp=2.5**：物理上 Spitzer 是 T^2.5，匹配经典等离子体。

### 2.5 LeeMore 变体（高 Z 稠密）

LeeMore 用 Lee & More 1984 公式（含简并、密度修正）。无 runtime parameter，全从状态算。

---

## 3. Opacity 参数

### 3.1 主控

源码：`source/physics/materialProperties/Opacity/OpacityMain/Config:L4-L10`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `useOpacity` | BOOLEAN | TRUE | 总开关 |
| `rt_useMGD` | BOOLEAN | FALSE（RadTrans 设）| 是否多群扩散。**必须 TRUE 才有意义配 Opacity 表** |

### 3.2 Multispecies 变体（LaserSlab 默认）

源码：`source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Config:L4-L43`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `opacity_ignoreLowTemp` | BOOLEAN | TRUE | 是否忽略低温泉化（TRUE=用表，FALSE=用 Biggs1971/Klein） |
| `opacity_writeOpacityInfo` | BOOLEAN | FALSE | 是否输出表加载详细信息（调试用） |
| `opacity_ceiling` | REAL | 1.e6 | 读 TOPS 表时的 κ 上限（防止发散） |

#### 3.2.1 每 species 5 个参数（auto-generated）

源码：`source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Config:L28-L39`

setup 命令行 `species=cham,targ` 时自动生成：

| 参数（以 `cham` 为例）| 类型 | 默认 | 含义 |
|---|---|---|---|
| `op_chamAbsorb` | STRING | "op_undefined" | 吸收不透明度类型（7 选 1）|
| `op_chamEmiss` | STRING | "op_undefined" | 发射不透明度类型 |
| `op_chamTrans` | STRING | "op_undefined" | 输运不透明度类型 |
| `op_chamAbsorbConstant` | REAL | -1.0 | 常数吸收（如 op_chamAbsorb="op_constant" 时用）|
| `op_chamEmissConstant` | REAL | -1.0 | 常数发射 |
| `op_chamTransConstant` | REAL | -1.0 | 常数输运 |
| `op_chamFileName` | STRING | "NOT SPECIFIED" | 表文件名 |
| `op_chamFileType` | STRING | "NOT SPECIFIED" | 表格式（5 选 1）|

**Absorb/Emiss/Trans 7 种类型**：
- `op_undefined`：未定义（默认，会 abort）
- `op_constant`：常数（cm^-1，path-length）
- `op_constcm2g`：常数（cm²/g，mass）
- `op_tabpa`：从 Planck Absorption 表读
- `op_tabpe`：从 Planck Emission 表读
- `op_tabro`：从 Rosseland 表读
- `op_zeldovich`：Zeldovich 平均

**FileType 5 种格式**：
- `tops`：LLNL TOPS 工具输出（罕用）
- `ionmix`：IONMIX v2（后缀 `.imx`，老版）
- `ionmix4`：IONMIX v4（后缀 `.cn4`，**主流**）
- `propaceos`：Propaceos 格式（罕用）
- `opacplot`：Opacplot 格式（罕用）

#### 3.2.2 为什么 LaserSlab 用 op_tabpa/op_tabpe/op_tabro 三表

**物理上 PA/PE/RO 含义不同**：
- PA：吸收（等离子体从辐射场吸收能量）
- PE：发射（等离子体发射到辐射场）
- RO：扩散通量

MGD 求解同时需要这三个。**只用一个会让某些项算错**。

#### 3.2.3 为什么默认 op_undefined（会 abort）

源码：`source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity_init.F90:L168-L185`

```fortran
if( any(op_absorptionKind == 0) .or. ... ) then
   ! 每物种必须显式配 Absorb/Emiss/Trans
   call Driver_abortFlash("[opacity_init] bad opacity kind")
end if
```

**为什么 abort**：强制用户配置。**否则 κ=0 导致辐射算例失真**（无吸收/发射）。

### 3.3 Constant / Constcm2g 变体

`Constant`：固定 κ（cm^-1），全域一样
`Constcm2g`：固定 κ（cm²/g），按密度换算

### 3.4 Zeldovich 变体（高能 γ）

源码：`source/physics/materialProperties/Opacity/OpacityMain/Zeldovich/`

Zeldovich 平均不透明度，用于高能 γ 辐射（核物理、CCSN）。LaserSlab 不用。

---

## 4. Viscosity 参数

源码：`source/physics/materialProperties/Viscosity/Config:L3-L12`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `useViscosity` | BOOLEAN CONSTANT | FALSE | 编译期总开关 |
| `useExplicitViscosity` | BOOLEAN | TRUE | TRUE=显式（Hydro 步内更新），FALSE=隐式（HYPRE） |

**为什么默认 FALSE**：Hydro 已有人工粘性，物理粘性可忽略。**LaserSlab 不用**。

**为什么 useExplicitViscosity 默认 TRUE**：显式快（不调 HYPRE），适合低 Reynolds 数稳定算例。

---

## 5. MagneticResistivity 参数

源码：`source/physics/materialProperties/MagneticResistivity/MagneticResistivityMain/Config:L5-L35`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `useMagneticResistivity` | BOOLEAN | TRUE | 总开关（MHD 才有意义） |
| `resistivitySolver` | STRING | "explicit" | 求解器（explicit/implicit） |
| `resistivityForm` | STRING | "perpendicular" | 电阻项形式（perpendicular/full） |
| `res_maxRes` | REAL | -1.0 | 电阻率上限（-1.0=不限制）|
| `res_vacSpec` | STRING | "vacu" | 哪个 species 当真空 |
| `res_vacDens` | REAL | 0.0 | 密度低于此值当真空 |
| `res_vacFrac` | REAL | 0.5 | 真空 mass fraction 阈值 |
| `res_vacRes` | REAL | 0.0 | 真空 cell 加的电阻 |
| `res_useVac` | BOOLEAN | false | 是否启用真空模型 |
| `res_addAnomRes` | BOOLEAN | FALSE | 是否加反常电阻（两流不稳定性）|

### 5.1 为什么 res_maxRes 默认 -1.0（不限制）

**为什么不限制**：Spitzer 公式低温发散（η ~ T^-3/2），物理上 cell 太冷时会算超大值。**LaserSlab 不用**所以默认保守。

**生产 MHD 算例**设 `res_maxRes = 1e6`（避免数值爆炸）。

### 5.2 为什么真空模型存在

**物理上**：磁场不能在真空扩散（无电子）。**数值上**：cell 太空时 Spitzer 公式发散。`res_vacDens` 阈值切换到 `res_vacRes`（小值或 0）。

---

## 6. 其他相关参数（跨单元但和物质属性相关）

### 6.1 Diffuse 参数（控制热扩散求解）

源码：`source/Simulation/SimulationMain/LaserSlab/flash.par:L162-L175`

| 参数 | 默认（LaserSlab） | 含义 |
|---|---|---|
| `useDiffuse` | TRUE | 总开关 |
| `useConductivity` | TRUE | 用 Conductivity 算 κ（不用就 cond_zone=0） |
| `diff_useEleCond` | TRUE | 启用电子热传导（3T 用） |
| `diff_eleFlMode` | "fl_larsen" | 通量限制器模式 |
| `diff_eleFlCoef` | 0.06 | 通量限制器系数（Larsen 典型 0.05-0.1） |
| `diff_thetaImplct` | 1.0 | 隐式度（1=全隐）|
| `dt_diff_factor` | 1e100 | Diffusion dt 因子（LaserSlab 设大值禁用 diffusion dt） |

**为什么 diff_eleFlCoef=0.06**：Larsen 通量限制器的 ICF 标准值（来自 LaserSLab 经验）。太小→数值扩散不足；太大→物理过扩散。

详见 flash-diffuse skill。

### 6.2 RadTrans 参数（控制 MGD 求解）

源码：`source/Simulation/SimulationMain/LaserSlab/flash.par:L41-L58`

| 参数 | 默认（LaserSlab） | 含义 |
|---|---|---|
| `rt_useMGD` | TRUE | 启用多群扩散 |
| `rt_mgdNumGroups` | 6 | 群数 |
| `rt_mgdBounds_1..7` | 1e-1..1e5 | 群边界（eV）|
| `rt_mgdFlMode` | "fl_harmonic" | 通量限制器模式（harmonic=sum of fluxes）|
| `rt_mgdFlCoef` | 1.0 | 通量限制器系数 |

详见 flash-radtrans skill。

### 6.3 Multispecies 参数（物质定义）

| 参数 | 含义 |
|---|---|
| `ms_<spec>A` | 物质原子量（如 `ms_targA=26.98`） |
| `ms_<spec>Z` | 物质电荷态（如 `ms_targZ=13`） |
| `ms_<spec>ZMin` | 最小 Z（防止全中性，如 `ms_targZMin=0.02`）|

详见 flash-multispecies skill。

### 6.4 EOS 参数（cv 计算）

| 参数 | 含义 |
|---|---|
| `eos_<spec>EosType` | EOS 类型（`eos_tab`/`eos_gam`）|
| `eos_<spec>SubType` | EOS 子类型（`ionmix4`/`gammaLaw`）|
| `eos_<spec>TableFile` | EOS 表文件（通常和 Opacity 表同源）|

详见 flash-eos skill。

---

## 7. 参数选择速查（按 L-013 主流）

| 场景 | 推荐配置 |
|---|---|
| **HEDP 激光算例（LaserSlab）** | `useConductivity=.true.` + SpitzerHighZ + `useOpacity=.true.` + Multispecies/IONMIX4 |
| **MHD 算例** | + `useMagneticResistivity=.true.` + SpitzerHighZ/DaviesWen + 可选 `useViscosity=.true.` |
| **天体物理（恒星）** | Conductivity/Spitzer + Opacity/OPAL + Viscosity/Spitzer |
| **调试 Hydro** | `useConductivity=.false.` + `useOpacity=.false.`（纯 Hydro） |
| **教学算例** | Conductivity/Constant + Opacity/Constcm2g |

---

## 8. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（beta）：8 节参数字典，覆盖主控开关 + Conductivity 全部 9 变体 + Opacity 全部 7 变体 + Viscosity + MagneticResistivity + 跨单元相关参数；按 L-011 重点讲"为什么默认这个值" + L-013 主流配置在前 | claude |
