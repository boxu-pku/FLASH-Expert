---
title: materialProperties 典型配置 — SpitzerHighZ + IONMIX4 + 9 变体选择 + parfile
skill: flash-material
category: recipes
source_anchors:
  - source/Simulation/SimulationMain/LaserSlab/Config:L11
  - source/Simulation/SimulationMain/LaserSlab/flash.par:L41-L74
  - source/Simulation/SimulationMain/LaserSlab/flash.par:L162-L175
  - source/physics/materialProperties/Conductivity/ConductivityMain/Config:L5-L9
  - source/physics/materialProperties/Opacity/OpacityMain/Config:L4-L10
manual_ref: "FLASH 4.8 User Guide §16-§17 + LaserSlab example"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: beta
tags:
  - materialproperties
  - recipes
  - parfile
  - spitzerhighz
  - ionmix4
  - laserslab
---

# materialProperties 典型配置（可复制粘贴）

> **TL;DR**：可执行配置片段。按"教学顺序"组织（L-004）：(1) 最小可运行配置；(2) LaserSlab 典型配置；(3) 简化调试配置；(4) 变体选择决策树。

---

## 1. 最小可运行配置（教学起步）

适用场景：纯 Hydro 算例（如 Sedov、KelvinHelmholtz），**不需要**物质属性扩散。

### 1.1 setup 命令

```bash
./setup Sedov -2d +cylindrical -auto -objdir=cases/Sedov
```

**不需要 REQUESTS 任何 materialProperties 子单元**——Sedov Config 不 REQUESTS Conductivity/Opacity。

### 1.2 parfile 物质属性相关参数（全关）

```fortran
# Sedov parfile 默认就是关的，无需显式写
# useConductivity = .false.  (默认值)
# useOpacity      = .false.  (默认值)
```

### 1.3 为什么这是最小配置

HEDP 物理扩散是后期加进来的"附加物理"。纯 Hydro 算例不需要。**Config 不 REQUESTS** 时这些单元根本不编译。

---

## 2. LaserSlab HEDP 标准配置（主流路径）

适用场景：HEDP 激光打靶，含热传导 + 辐射扩散 + 激光沉积 + 电子-离子平衡。

### 2.1 setup 命令

源码：参考 `cases/LaserSlab/setup_call` 或 CLAUDE.md 中的 LaserSlab setup 命令

```bash
./setup LaserSlab -2d -auto +cylindrical \
    -nxb=16 -nyb=16 \
    +hdf5typeio \
    species=cham,targ \
    +mtmmmt +laser +uhd3t +mgd \
    mgd_meshgroups=6 \
    -objdir=cases/LaserSlab \
    -parfile=example.par
```

**为什么这些 setup 变量**：
- `species=cham,targ`：物质名（cham=chamber gas He, targ=target Al）。**Multispecies/Opacity 自动生成 op_cham*/op_targ* 参数**
- `+mtmmmt`：multi-temp EOS（3T 必需，Conductivity/SpitzerHighZ REQUIRES 3T）
- `+laser`：EnergyDeposition 激光单元
- `+uhd3t`：unsplit hydro + 3T（启用 TELE_VAR/TION_VAR/TRAD_VAR）
- `+mgd`：Multigroup Diffusion（启用 RadTrans/MGD）
- `mgd_meshgroups=6`：6 个能群（影响 Opacity 查询频次）

### 2.2 Simulation Config（REQUESTS）

源码：`source/Simulation/SimulationMain/LaserSlab/Config:L7-L12`

```
USESETUPVARS ThreeT

IF ThreeT
   REQUESTS physics/Diffuse/DiffuseMain/Unsplit

   REQUESTS physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer
   REQUESTS physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ
ENDIF
```

**为什么 REQUESTS SpitzerHighZ**：HEDP 主流。**SpitzerHighZ 自动 REQUIRES PlasmaState**（用于 ln Λ）。

### 2.3 parfile 完整物质属性段

源码：`source/Simulation/SimulationMain/LaserSlab/flash.par:L41-L74, L162-L175`

```fortran
############################
# RADIATION/OPACITY PARAMETERS
############################
rt_useMGD       = .true.
rt_mgdNumGroups = 6
rt_mgdBounds_1  = 1.0e-01      # eV，群 1 下边界
rt_mgdBounds_2  = 1.0e+00
rt_mgdBounds_3  = 1.0e+01
rt_mgdBounds_4  = 1.0e+02
rt_mgdBounds_5  = 1.0e+03
rt_mgdBounds_6  = 1.0e+04
rt_mgdBounds_7  = 1.0e+05      # eV，群 6 上边界（N+1 个边界）

rt_mgdFlMode    = "fl_harmonic"   # 通量限制器
rt_mgdFlCoef    = 1.0

# 边界条件（辐射）
rt_mgdXlBoundaryType = "reflecting"
rt_mgdXrBoundaryType = "vacuum"
rt_mgdYlBoundaryType = "vacuum"
rt_mgdYrBoundaryType = "reflecting"
rt_mgdZlBoundaryType = "reflecting"
rt_mgdZrBoundaryType = "reflecting"

useOpacity     = .true.

### SET CHAMBER (HELIUM) OPACITY OPTIONS ###
op_chamAbsorb   = "op_tabpa"           # 用 Planck Absorption 表
op_chamEmiss    = "op_tabpe"           # 用 Planck Emission 表
op_chamTrans    = "op_tabro"           # 用 Rosseland 表
op_chamFileType = "ionmix4"            # IONMIX4 格式（主流）
op_chamFileName = "he-imx-005.cn4"     # 数据文件

### SET TARGET (ALUMINUM) OPACITY OPTIONS ###
op_targAbsorb   = "op_tabpa"
op_targEmiss    = "op_tabpe"
op_targTrans    = "op_tabro"
op_targFileType = "ionmix4"
op_targFileName = "al-imx-003.cn4"

############################
# CONDUCTION PARAMETERS
############################
useDiffuse      = .true.
useConductivity = .true.
diff_useEleCond = .true.               # 启用电子热传导（3T 必需）
diff_eleFlMode  = "fl_larsen"          # 电子通量限制器（Larsen）
diff_eleFlCoef  = 0.06                 # 系数（ICF 标准值）
diff_thetaImplct = 1.0                 # 全隐式（HYPRE）

# 电子热传导边界条件
diff_eleXlBoundaryType = "neumann"
diff_eleXrBoundaryType = "neumann"
diff_eleYlBoundaryType = "vacuum"
diff_eleYrBoundaryType = "neumann"
diff_eleZlBoundaryType = "neumann"
diff_eleZrBoundaryType = "neumann"
```

### 2.4 数据文件

源码：`source/Simulation/SimulationMain/LaserSlab/Config:L25-L29`

```
DATAFILES al-imx-002.cn4
DATAFILES al-imx-003.cn4
DATAFILES he-imx-005.cn4
DATAFILES al-imx-003.ses
DATAFILES he-imx-005.ses
```

**为什么这些文件**：
- `al-imx-003.cn4`：Al 的 IONMIX4 不透明度表（targ 用）
- `he-imx-005.cn4`：He 的 IONMIX4 不透明度表（cham 用）
- `al-imx-003.ses`：Al 的 SESAME EOS 表（EOS 用，本 skill 不展开）
- `he-imx-005.ses`：He 的 SESAME EOS 表

**注意**：opacity 表（`.cn4`）和 EOS 表（`.ses`）通常**同源**（同一物质两份表）。LaserSlab 这里 al-imx-003 是配套 al-imx-003.ses 的不透明度版本。

### 2.5 物质定义（Multispecies）

源码：`source/Simulation/SimulationMain/LaserSlab/flash.par:L238-L254`

```fortran
# Target (Aluminum):
ms_targA = 26.9815386          # 原子量
ms_targZ = 13.0                # 原子序数
ms_targZMin = 0.02             # 最小电离度（防全中性）
eos_targEosType = "eos_tab"
eos_targSubType = "ionmix4"
eos_targTableFile = "al-imx-003.cn4"

# Chamber (Helium):
ms_chamA = 4.002602
ms_chamZ = 2.0
eos_chamEosType = "eos_tab"
eos_chamSubType = "ionmix4"
eos_chamTableFile = "he-imx-005.cn4"
```

详见 flash-multispecies 和 flash-eos skill。

### 2.6 完整物质属性决策树

```
是否 HEDP 算例（含激光 + 辐射）？
├── 是 → LaserSlab 路径：
│   ├── Conductivity = SpitzerHighZ（REQUIRES PlasmaState）
│   ├── Opacity = Multispecies
│   ├── 每 species 配 op_<spec>Absorb/Emiss/Trans + FileName + FileType
│   ├── FileType 用 ionmix4
│   ├── DATAFILES 把 .cn4 文件加到 setup
│   ├── 用 rt_mgdBounds_* 定义群边界
│   └── 用 diff_useEleCond + fl_larsen 配热扩散
│
└── 否 → 简化路径：
    ├── 纯 Hydro（Sedov）：不 REQUESTS 任何 materialProperties
    ├── 调试：Conductivity=Constant + Opacity=Constcm2g
    └── 教学：Conductivity=PowerLaw（κ = a·T^b）
```

---

## 3. 简化调试配置

### 3.1 调试 Conductivity（用 Constant）

```fortran
# parfile
useConductivity = .true.
useDiffuse      = .true.
diff_useEleCond = .true.

# 用 Constant 变体（需 setup REQUESTS Constant）
cond_constantIsochoric = 1.0e7    # erg/(cm·s·K)，固定电导率
```

setup：
```bash
./setup MyProblem -2d +cylindrical -auto \
    REQUESTS=physics/materialProperties/Conductivity/ConductivityMain/Constant \
    -objdir=cases/MyProblem
```

**为什么调试用 Constant**：
- 公式简单（无 ln Λ 依赖）
- 数值稳定（固定 κ）
- 物理可预测（D = κ/(ρ·cv) 直接算）

### 3.2 调试 Opacity（用 Constcm2g）

```fortran
# parfile
useOpacity = .true.
rt_useMGD  = .true.
rt_mgdNumGroups = 4
rt_mgdBounds_1 = 1.0
rt_mgdBounds_2 = 10.0
rt_mgdBounds_3 = 100.0
rt_mgdBounds_4 = 1000.0
rt_mgdBounds_5 = 10000.0

# 用 Constcm2g 变体（需 setup REQUESTS Constcm2g）
op_chamAbsorb = "op_constcm2g"
op_chamAbsorbConstant = 100.0     # cm²/g
op_chamEmiss  = "op_constcm2g"
op_chamEmissConstant  = 100.0
op_chamTrans  = "op_constcm2g"
op_chamTransConstant  = 100.0
```

setup：
```bash
./setup MyProblem -2d -auto \
    REQUESTS=physics/materialProperties/Opacity/OpacityMain/Constcm2g \
    species=cham \
    -objdir=cases/MyProblem
```

**为什么调试用 Constcm2g**：无需外部表文件，常数 κ 直接给。**适合单元测试和教学**。

---

## 4. Conductivity 9 变体选择决策树（按 L-011）

### 4.1 决策表

| 你的场景 | 推荐变体 | 理由 |
|---|---|---|
| **HEDP 激光算例（多元素靶，Z>1）** | **SpitzerHighZ** ⭐ | Atzeni 公式含 Z 修正，ICF 社区标准。LaserSlab 默认 |
| **HEDP 高 Z 物质（Au, W, CH foam）** | **LeeMore** | 含稠密/简并修正，T < 100 eV 准确度更高 |
| **天体物理（恒星、H/He 等离子体）** | **Spitzer** | 纯 H/He 适用，Z=1，无 Z 修正 |
| **磁化等离子体（MHD）** | **EppHain** / **JiHeld** | 各向异性 κ，磁场约束电子运动 |
| **灰体近似（教学/测试）** | **PowerLaw-gray** | 经验关系 `κ = a·T^b` |
| **教学（理想 T^2.5）** | **PowerLaw** | 自定义 a, b |
| **数值调试** | **Constant** | 固定 κ，无物理依赖 |
| **直接控制扩散系数 D** | **Constant-diff** | 跳过 κ，直接给 D |
| **恒星内部** | **Stellar** | 含恒星修正 |

### 4.2 SpitzerHighZ vs LeeMore 详细对比

| 维度 | SpitzerHighZ | LeeMore |
|---|---|---|
| **公式来源** | Atzeni 2004《Physics of Inertial Fusion》 | Lee & More 1984 (Phys. Fluids 27, 1273) |
| **物理假设** | 经典弱耦合（Γ << 1） | 含稠密/简并修正 |
| **T 范围** | T > 50 eV 准确 | T > 1 eV 都可 |
| **Z 范围** | 任意（含 Z+3.3 项） | 任意 |
| **简并处理** | 不处理 | 处理（Fermi 能） |
| **依赖** | PlasmaState（ln Λ） | PlasmaState + Multispecies |
| **运行成本** | 低（简单公式） | 中（多次查简并能） |
| **典型用途** | Al, CH, plastic 靶 | Au, W hohlraum 壁 |

### 4.3 SpitzerHighZ vs Spitzer 详细对比

| 维度 | SpitzerHighZ | Spitzer |
|---|---|---|
| **公式** | `κ = (8/π)^1.5 k_B^3.5 T^2.5 / (sqrt(m_e) e^4 lnΛ (Z+3.3))` | `κ = 9.2e-7 * T^2.5` |
| **ln Λ** | 自动算（PlasmaState） | 不算 |
| **Z 修正** | `(Z+3.3)` 项 | 无（系数 9.2e-7 已含 Z=1 校准） |
| **适用 Z** | 任意 | Z=1（H）或近 1（He） |
| **依赖** | PlasmaState | 无 |
| **编译要求** | 必须 3T | 1T 或 3T 都可 |

---

## 5. Opacity 7 变体选择决策树

| 你的场景 | 推荐变体 | 理由 |
|---|---|---|
| **多物质混合（HEDP 标准）** | **Multispecies** ⭐ | 每 species 独立配表，按 ion number density 混合。LaserSlab 默认 |
| **常数不透明度（cm^-1，path-length）** | **Constant** | 直接给 κ（不依赖密度）|
| **常数不透明度（cm²/g，mass）** | **Constcm2g** | 物理单位，按密度换算 |
| **每群不同常数** | **ConstPerGroup** | 灰体近似测试 |
| **解析公式（全电离）** | **BremsstrahlungAndThomson** | 韧致辐射 + 汤姆逊散射 |
| **恒星内部** | **OPAL** | OPAL 表格式 |
| **高能 γ 辐射** | **Zeldovich** | Zeldovich 平均 |

### 5.1 Multispecies 内部 7 种 op_<spec>Absorb 选择

```
op_<spec>Absorb 选哪个？
├── 用表（推荐）：
│   ├── "op_tabpa"  → 用 Planck Absorption 表（等离子体吸收辐射）
│   ├── "op_tabpe"  → 用 Planck Emission 表（等离子体发射）
│   └── "op_tabro"  → 用 Rosseland 表（群间扩散通量）
│
├── 常数：
│   ├── "op_constant"    → 给 cm^-1（path-length）
│   ├── "op_constcm2g"  → 给 cm²/g（mass，按密度换算）
│
├── 解析：
│   └── "op_zeldovich"  → Zeldovich 平均公式
│
└── "op_undefined" → 默认，会 abort！必须显式配
```

### 5.2 FileType 选择

```
op_<spec>FileType 选哪个？
├── "ionmix4"   ⭐ 主流（后缀 .cn4）
├── "ionmix"    老版（后缀 .imx），已被 ionmix4 取代
├── "tops"      LLNL TOPS 工具输出（罕用）
├── "propaceos" Propaceos 格式（罕用）
└── "opacplot"  Opacplot 格式（罕用）
```

---

## 6. 自定义物质（添加新 species）

适用场景：算例需要新的物质（如 CH 塑料、Au 金）。

### 6.1 准备数据文件

需要两个文件：
- `<name>-imx-NNN.cn4`：IONMIX4 不透明度表
- `<name>-imx-NNN.ses` 或同 `.cn4`（ionmix4 EOS）：EOS 表

**来源**：
- IAPCM（中国 ICF 联合中心）：通过学术合作获取
- SESAME（LANL）：商业授权
- FEOS（德国）：自己的工具生成 IONMIX4 格式
- 自算（用 TOPS、OpacPlot2 等工具）

### 6.2 修改 Simulation Config

源码：参考 `source/Simulation/SimulationMain/Sunliang_laser_CH/Config`

```
DATAFILES ch-imx-001.cn4
DATAFILES ch-imx-001.ses
# ... 其他文件
```

### 6.3 setup 命令加 species

```bash
./setup MyProblem -2d -auto \
    species=cham,targ1,targ2,targ3 \
    +mtmmmt +laser +mgd +uhd3t \
    mgd_meshgroups=6 \
    -objdir=cases/MyProblem
```

### 6.4 parfile 加物质定义

```fortran
# 物质 1：CH 塑料（targ1）
ms_targ1A = 12.011                  # C 原子量（CH 平均）
ms_targ1Z = 6.0
ms_targ1ZMin = 0.02
eos_targ1EosType = "eos_tab"
eos_targ1SubType = "ionmix4"
eos_targ1TableFile = "ch-imx-001.cn4"

op_targ1Absorb   = "op_tabpa"
op_targ1Emiss    = "op_tabpe"
op_targ1Trans    = "op_tabro"
op_targ1FileType = "ionmix4"
op_targ1FileName = "ch-imx-001.cn4"

# 物质 2、3 类似...
```

详见 `source/Simulation/SimulationMain/Sunliang_laser_CH/`（用户自定义 CH 靶算例）。

---

## 7. 群边界设置（rt_mgdBounds_*）

### 7.1 LaserSlab 默认 6 群

```fortran
rt_mgdNumGroups = 6
rt_mgdBounds_1  = 1.0e-01     # eV
rt_mgdBounds_2  = 1.0e+00
rt_mgdBounds_3  = 1.0e+01
rt_mgdBounds_4  = 1.0e+02
rt_mgdBounds_5  = 1.0e+03
rt_mgdBounds_6  = 1.0e+04
rt_mgdBounds_7  = 1.0e+05     # 共 N+1 个边界
```

**为什么对数分布**：HEDP 辐射谱是宽频 Bremsstrahlung，对数群分布让每群覆盖等量能量范围。

### 7.2 群边界和 IONMIX4 表对齐

**重要**：rt_mgdBounds 必须和 .cn4 文件的群边界**完全一致**（容差 1e-8 eV）。

**为什么**：Opacity 启动时检查对齐。不对齐会 abort。

**如何检查**：
```bash
# 读 .cn4 文件开头看群边界
head -30 cases/LaserSlab/al-imx-003.cn4
```

---

## 8. MagneticResistivity 配置（MHD 算例）

适用场景：MHD 算例（如 Z-pinch、磁化 ICF）。

### 8.1 setup

```bash
./setup MyMHDProblem -2d -auto +cylindrical +magnetic \
    REQUESTS=physics/materialProperties/MagneticResistivity/MagneticResistivityMain/SpitzerHighZ \
    -objdir=cases/MyMHDProblem
```

### 8.2 parfile

```fortran
useMagneticResistivity = .true.
resistivitySolver     = "explicit"      # 或 "implicit"
resistivityForm       = "perpendicular" # 或 "full"
res_maxRes            = 1.0e6           # 电阻率上限（防 T→0 发散）

# 真空模型（腔体气体区）
res_useVac   = .true.
res_vacSpec  = "cham"                   # cham 当真空
res_vacDens  = 1.0e-6                   # g/cm^3，低于此值当真空
res_vacRes   = 1.0e-10                  # 真空电阻率
```

---

## 9. Viscosity 配置（罕用）

适用场景：高雷诺数剪切流（如天体物理湍流）。

### 9.1 setup

```
# Simulation Config
REQUESTS physics/materialProperties/Viscosity/ViscosityMain/Spitzer
```

### 9.2 parfile

```fortran
useViscosity         = .true.    # 编译期决定！必须 setup 时打开
useExplicitViscosity = .true.
```

**注意**：useViscosity 是 **CONSTANT** 参数，**setup 时设**（不能运行时改）。

---

## 10. 延伸阅读

- **参数完整字典**：`knowledge/params.md`
- **内部实现**：`knowledge/internals.md`
- **常见错误**：`knowledge/pitfalls.md`
- **物理原理 + 设计**：`knowledge/overview.md`
- **LaserSlab example.par**：`source/Simulation/SimulationMain/LaserSlab/flash.par`
- **Sunliang_laser_CH 自定义多物质**：`source/Simulation/SimulationMain/Sunliang_laser_CH/`
- **手册**：FLASH 4.8 User Guide §16-§17

---

## 11. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（beta）：10 节典型配置，覆盖最小可运行 + LaserSlab HEDP 标准 + 简化调试 + 9 变体选择决策树 + 自定义物质 + 群边界 + MHD + Viscosity；按 L-004 教学顺序（最小→典型→特殊→进阶）+ L-011 每个配置讲为什么 + L-013 主流 LaserSlab 在前 | claude |
