---
title: Multispecies 典型配置 — LaserSlab 双物质 / 多层靶 / 多元素物质 / parfile
skill: flash-multispecies
category: recipes
source_anchors:
  - source/Simulation/SimulationMain/LaserSlab/Config:L14-L22
  - source/Simulation/SimulationMain/LaserSlab/example.par:L63-L74
  - source/Simulation/SimulationMain/LaserSlab/example.par:L221-L237
  - source/Simulation/SimulationMain/LaserSlab/Simulation_initBlock.F90:L100-L153
  - source/Simulation/SimulationMain/Sunliang_laser_CH/example_xubo.par:L248-L277
manual_ref: "FLASH 4.8 User Guide §17 Multispecies + LaserSlab README"
created: 2026-07-31
last_verified: 2026-07-31
verifier: claude
status: beta
tags:
  - multispecies
  - recipes
  - setup
  - parfile
  - las erslab
  - multi-layer
  - multi-element
---

# Multispecies 典型配置 recipes

> **TL;DR**：按教学顺序（L-004）——(1) 最小双物质配置（LaserSlab cham+targ）；(2) 多层靶配置（Sunliang_laser_CH 4 种物质）；(3) 多元素物质（CH 塑料 NumElems+ZElems/AElems/Fractions）；(4) 核合成场景简要。所有 recipe 含 setup 命令 + parfile 片段 + 为什么这么配（L-011）。

---

## 1. Recipe 1：LaserSlab 双物质（最小 HEDP 配置）

### 1.1 场景

HEDP 标准算例：激光打到 Al 靶表面，靶在 He 真空腔里。需要追踪两种物质（cham=He 气体、targ=Al 靶），各自用 ionmix4 EOS 表 + Opacity 表。

### 1.2 setup 命令

```bash
./setup LaserSlab -2d -auto +cylindrical -nxb=16 -nyb=16 \
  +hdf5typeio species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 -objdir=cases/LaserSlab -parfile=example.par
```

关键 setup 变量：

| 选项 | 作用 |
|---|---|
| `species=cham,targ` | **核心**：定义 2 个 species，触发 Multispecies/Config Python 段 |
| `+mtmmmt` | multiTemp EOS（3T） |
| `+laser` | EnergyDeposition（激光沉积） |
| `+uhd3t` | Unsplit Hydrodynamics 3T |
| `+mgd` | MultiGroup Diffusion（辐射） |
| `mgd_meshgroups=6` | MGD 6 群 |

### 1.3 parfile 物种段（最小可运行）

```fortran
# ─── cham 物质：He 真空腔气体 ───
ms_chamA          = 4.002602         ! He 原子质量数
ms_chamZ          = 2.0              ! He 原子序数
ms_chamZMin       = 0.02             ! 离子化下限（防除零）

eos_chamEosType   = "eos_tab"        ! 用表 EOS
eos_chamSubType   = "ionmix4"        ! IONMIX4 格式
eos_chamTableFile = "he-imx-005.cn4" ! EOS 表文件

op_chamAbsorb     = "op_tabpa"       ! 吸收不透明度（Planck）
op_chamEmiss      = "op_tabpe"       ! 发射不透明度（Planck）
op_chamTrans      = "op_tabro"       ! 传输不透明度（Rosseland）
op_chamFileType   = "ionmix4"
op_chamFileName   = "he-imx-005.cn4"

# ─── targ 物质：Al 靶 ───
ms_targA          = 26.9815386       ! Al 原子质量数
ms_targZ          = 13.0             ! Al 原子序数
ms_targZMin       = 0.02

eos_targEosType   = "eos_tab"
eos_targSubType   = "ionmix4"
eos_targTableFile = "al-imx-003.cn4"

op_targAbsorb     = "op_tabpa"
op_targEmiss      = "op_tabpe"
op_targTrans      = "op_tabro"
op_targFileType   = "ionmix4"
op_targFileName   = "al-imx-003.cn4"
```

### 1.4 为什么这么配（L-011）

- **`ms_chamA=4.002`**：He 的精确原子质量数（4.002602 g/mol）。EOS 表查询和 Abar 计算用。
- **`ms_chamZ=2.0`**：He 的原子序数。Zbar 计算和 Coulomb 修正用。
- **`ms_chamZMin=0.02`**：典型 HEDP 值，避免 Z*=0 时电导率公式除零（Coulomb 对数 ln Λ 需要 Z*）。
- **`eos_chamEosType="eos_tab"`**：HEDP 物质用表（ionmix4 / sesame），不用理想气体（eos_gam）。
- **`eos_chamSubType="ionmix4"`**：L-013 主流格式，LaserSlab 自带的 .cn4 文件都是 ionmix4。
- **`op_chamAbsorb="op_tabpa"`**：用表查询 Planck 平均吸收不透明度（其他选项："op_const"、"op_electron" 等）。
- **EOS 表和 Opacity 表是同一个 .cn4 文件**：ionmix4 格式同时含 EOS + 不透明度，所以 `op_chamFileName = eos_chamTableFile`。

### 1.5 Simulation_initBlock 怎么初始化质量分数

源码：`source/Simulation/SimulationMain/LaserSlab/Simulation_initBlock.F90:L100-L153`

```fortran
species = CHAM_SPEC                       ! 默认 cham
if (sim_initGeom == "slab") then
   ! 2D/3D 几何判断：在靶区域内 → targ
   if (xcent(i) <= sim_targetRadius .and. &
       ycent(j) <= sim_targetHeight + sim_vacuumHeight .and. &
       ycent(j) >= sim_vacuumHeight) then
      species = TARG_SPEC
   end if
end if

! 根据位置设密度 / 温度
if (species == TARG_SPEC) then
   rho = sim_rhoTarg; tele = sim_teleTarg; tion = sim_tionTarg; trad = sim_tradTarg
else
   rho = sim_rhoCham; tele = sim_teleCham; tion = sim_tionCham; trad = sim_tradCham
end if

! ★ 核心：循环 SPECIES_BEGIN..SPECIES_END 填质量分数
if (NSPECIES > 0) then
   do n = SPECIES_BEGIN, SPECIES_END
      if (n == species) then
         call Grid_putPointData(blockID, CENTER, n, EXTERIOR, axis, &
                                1.0e0 - (NSPECIES-1)*sim_smallX)
      else
         call Grid_putPointData(blockID, CENTER, n, EXTERIOR, axis, sim_smallX)
      end if
   enddo
end if
```

**范式**：被选中的 species 设 `1 - (NSPECIES-1)*smallX`（接近 1），其余设 `smallX`（典型 1e-10）。这样保证 ΣX=1，且 EOS 不会因 X=0 除零。

---

## 2. Recipe 2：Sunliang_laser_CH 4 层靶（多层物质）

### 2.1 场景

ICF 多层靶：CH 塑料外壳 + CHBr 掺杂层 + CH 内壳，激光打到外层。需要 4 种物质（cham He 气体 + targ1/targ2/targ3 三层靶）。

### 2.2 setup 命令

```bash
./setup Sunliang_laser_CH -2d -auto +pm4dev -geometry=cylindrical \
  -nxb=16 -nyb=16 +mtmmmt +laser +mgd +uhd3t \
  species=cham,targ1,targ2,targ3 mgd_meshgroups=6 \
  -parfile=example_xubo.par -objdir=cases/Sunliang_laser_CH
```

### 2.3 parfile 物种段（4 套）

```fortran
# ─── cham: He 真空腔（同 LaserSlab）───
ms_chamA          = 4.002602
ms_chamZ          = 2.0
ms_chamZMin       = 0.02
eos_chamEosType   = "eos_tab"
eos_chamSubType   = "ionmix4"
eos_chamTableFile = "he-imx-005.cn4"

# ─── targ1: CH 塑料（外层）───
ms_tar1A          = 13                ! CH 塑料等效 A（≈ C×0.857 + H×0.143 ≈ 10，但用户设 13）
ms_tar1Z          = 6                 ! CH 等效 Z
ms_tar1ZMin       = 0.02
eos_tar1EosType   = "eos_tab"
eos_tar1SubType   = "ionmix4"
eos_tar1TableFile = "polystyrene-imx-008.cn4"

# ─── targ2: CHBr 掺杂层（中层）───
ms_tar2A          = 13
ms_tar2Z          = 6
ms_tar2ZMin       = 0.02
eos_tar2EosType   = "eos_tab"
eos_tar2SubType   = "ionmix4"
eos_tar2TableFile = "chBr-hyades.cn4"

# ─── targ3: CH 塑料（内层）───
ms_tar3A          = 13
ms_tar3Z          = 6
ms_tar3ZMin       = 0.02
eos_tar3EosType   = "eos_tab"
eos_tar3SubType   = "ionmix4"
eos_tar3TableFile = "polystyrene-imx-008.cn4"
```

### 2.4 为什么 targ1 和 targ3 用同一表（L-011）

虽然 targ1（外层）和 targ3（内层）都是 CH 塑料，**用同一 EOS 表**（`polystyrene-imx-008.cn4`）。原因：
- 物理上是同一种材料（聚苯乙烯）
- 但被分离为两个 species 以便在 Simulation_initBlock 里**按位置区分质量分数初始化**
- 这样 IO 输出里能分别看到 targ1 / targ3 的质量分数演化（即使 EOS 相同）

如果合并成一个 species，无法区分物理上不同位置的同一材料。

### 2.5 ms_tar1A=13 为什么不是 ~10（L-011）

CH 塑料的精确质量加权 A：
```
A = 0.857×12 + 0.143×1 = 10.4
```

但用户设 13（接近 C 的 12）——这是 **EOS 表内部约定**。ionmix4 表生成时按某个 A/Z 归一化（如按单体 C 算），用户在 parfile 里填的 A/Z 要和**表生成时的约定一致**，否则 EOS 表查询错位。具体值看 .cn4 表的元数据。

**实践建议**：从同款算例（如 Sunliang_laser_CH）拷 parfile，不要自己改 A/Z——除非知道 EOS 表生成细节。

---

## 3. Recipe 3：多元素物质（CH 塑料的元素构成）

### 3.1 场景

某些高级算例需要按**元素构成**（C+H）描述 CH 塑料，让 Opacity 单元按 per-element 查表（高保真）。用 NumElems + ZElems + AElems + Fractions 三件套。

### 3.2 parfile 物种段（多元素路径）

```fortran
# ─── ch: CH 塑料（多元素描述） ───
ms_chA             = 10.4              ! 可选：自动算 dot_product(Frac·AElem)
ms_chZ             = 5.43              ! 可选：自动算 dot_product(Frac·ZElem)
ms_chZMin          = 0.02

ms_chNumElems      = 2                 ! 2 种元素
ms_chZElems_1      = 6                 ! 元素 1: C (Z=6)
ms_chAElems_1      = 12                ! 元素 1: A=12
ms_chFractions_1   = 0.857             ! C 质量占比 85.7%
ms_chZElems_2      = 1                 ! 元素 2: H (Z=1)
ms_chAElems_2      = 1                 ! 元素 2: A=1
ms_chFractions_2   = 0.143             ! H 质量占比 14.3%

eos_chEosType      = "eos_tab"
eos_chSubType      = "ionmix4"
eos_chTableFile    = "polystyrene-imx-008.cn4"
```

### 3.3 为什么这么配（L-011）

- **`ms_chNumElems=2`**：CH 含 2 种元素（C、H）。
- **`ms_chZElems_1=6`**：碳的原子序数（6 个质子）。
- **`ms_chAElems_1=12`**：C-12 同位素（6 质子+6 中子）。
- **`ms_chFractions_1=0.857`**：C 在 CH 塑料里的质量分数。化学式 (C₈H₈)ₙ 中 C 的质量分数 `12×8/(12×8+1×8) = 96/104 = 0.923`，但实际聚苯乙烯含其他添加剂，按 0.857 经验值。
- **`ms_chA` 可省略**：如果留 -999.（默认），Multispecies_init 自动算 `dot_product(Frac, AElem) = 0.857×12 + 0.143×1 = 10.4`。
- **`ms_chFractions_*` 不必 Σ=1**：Multispecies_init 检查 sum，不等于 1 自动归一化（`frac_i = frac_i / sum`）。

### 3.4 检查方法

跑算例后看日志，Multispecies_list 会打印：

```
Species Constituents
ch      2 constituents
#  Z    A       Frac
  6   12  8.57E-01
  1    1  1.43E-01
```

确认元素构成正确。

---

## 4. Recipe 4：不用 species setup 变量（手写 SPECIES 行）

### 4.1 场景

特殊命名需求（如自定义 species 名空间），不想用 setup 自动建参数族。在 `Simulation/<problem>/Config` 手写 SPECIES 行，在 Simulation_initSpecies 里 setProperty。

### 4.2 Config 文件

```
# source/Simulation/SimulationMain/MyProblem/Config
REQUIRES Multispecies

SPECIES MY_SPEC1
SPECIES MY_SPEC2
```

### 4.3 Simulation_initSpecies.F90

```fortran
subroutine Simulation_initSpecies()
   use Multispecies_interface, ONLY : Multispecies_setProperty, Multispecies_setIntegerProperty
   use Multispecies_data, ONLY : ms_Array
#include "Multispecies.h"
#include "Flash.h"

   ! MY_SPEC1 物质属性
   call Multispecies_setProperty(MY_SPEC1, A, 26.98)
   call Multispecies_setProperty(MY_SPEC1, Z, 13.0)
   call Multispecies_setProperty(MY_SPEC1, MS_ZMIN, 0.02)
   call Multispecies_setIntegerProperty(MY_SPEC1, MS_EOSTYPE, EOS_TAB)
   ! ...

   ! MY_SPEC2 物质属性
   call Multispecies_setProperty(MY_SPEC2, A, 4.002)
   ! ...
end subroutine Simulation_initSpecies
```

### 4.4 为什么通常不用这条路径（L-011）

- **繁琐**：每个属性都要 setProperty 一行（10+ 行）
- **不可在 parfile 调整**：硬编码在 F90 文件，改 A 要重新 setup + make
- **易错**：忘记设某属性，运行时静默错误
- **不直观**：parfile 是配置文件的事实标准，setProperty 是程序代码

**推荐**：除非特殊原因（自定义命名 / 编译期常量），都用 `species=` setup 变量路径。

---

## 5. Recipe 5：核合成场景（简要，L-013 非 HEDP）

### 5.1 场景

天体物理（Type Ia 超新星核合成）追踪 Ni56 → Co → Fe 衰变链。

### 5.2 setup 命令

```bash
./setup Nova -3d -auto species=ni56,co61,fe51 +burn ...
```

### 5.3 关键点

- species 名用核素（ni56、co61、fe51）
- A/Z/N/EB 都要精确填（核物理数据）
- Burn 网络演化 species 质量分数
- HEDP 算例不用，简要

---

## 6. 通用建议（L-011 + L-013）

### 6.1 species 命名原则

| 命名 | 适用 | 例子 |
|---|---|---|
| 物理位置 | HEDP 标配 | cham（chamber）、targ（target） |
| 元素符号 | 单物质 | he、al、au |
| 多层编号 | 多层靶 | targ1、targ2、targ3 |
| 核素 | 核合成 | ni56、co61 |

### 6.2 parfile 物种段顺序

推荐顺序（便于阅读）：
1. ms_<spec>A / Z / ZMin（必填属性）
2. ms_<spec>NumElems + ZElems/AElems/Fractions（多元素时）
3. eos_<spec>EosType / SubType / TableFile（EOS 表）
4. op_<spec>Absorb/Emiss/Trans/FileName（Opacity 表）

### 6.3 物质属性获取

- A/Z：化学手册或 Wikipedia
- ionmix4 / sesame 表：从 IAPCM / 学术合作 / FEOS 工作流获取（详见 `flash-material`）
- 不要凭空猜——查表生成时的约定

### 6.4 IO 输出验证

跑算例后查看 plotfile 里的 `cham` / `targ` 变量，确认质量分数在合理范围（0~1，靶区 targ≈1，腔区 cham≈1）。如果看到 NaN 或负值，查 Simulation_initBlock 的初始化逻辑。

---

## 7. 完整 LaserSlab setup + parfile 物种段（参考）

### 7.1 setup（最终版）

```bash
./setup LaserSlab -2d -auto +cylindrical -nxb=16 -nyb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd mgd_meshgroups=6 \
  -objdir=cases/LaserSlab -parfile=example.par
```

### 7.2 parfile 物种段（最终版）

```fortran
# ─── Multispecies / cham (He) ───
ms_chamA          = 4.002602
ms_chamZ          = 2.0
ms_chamZMin       = 0.02
eos_chamEosType   = "eos_tab"
eos_chamSubType   = "ionmix4"
eos_chamTableFile = "he-imx-005.cn4"
op_chamAbsorb     = "op_tabpa"
op_chamEmiss      = "op_tabpe"
op_chamTrans      = "op_tabro"
op_chamFileType   = "ionmix4"
op_chamFileName   = "he-imx-005.cn4"

# ─── Multispecies / targ (Al) ───
ms_targA          = 26.9815386
ms_targZ          = 13.0
ms_targZMin       = 0.02
eos_targEosType   = "eos_tab"
eos_targSubType   = "ionmix4"
eos_targTableFile = "al-imx-003.cn4"
op_targAbsorb     = "op_tabpa"
op_targEmiss      = "op_tabpe"
op_targTrans      = "op_tabro"
op_targFileType   = "ionmix4"
op_targFileName   = "al-imx-003.cn4"

# ─── 初始条件（Simulation_initBlock 读）───
sim_rhoCham       = 1.0e-6            ! cham 初始密度（g/cc）
sim_rhoTarg       = 2.7               ! targ 初始密度（Al 实际密度）
sim_teleCham      = 50.0              ! cham 电子温度（K）
sim_teleTarg      = 50.0
# ... 其他 sim_* 参数
```

---

## 8. 延伸阅读

- 相关条目：`knowledge/overview.md`（机制 + 物理原理）、`knowledge/params.md`（参数族）、`knowledge/internals.md`（API + 数据结构）、`knowledge/pitfalls.md`（错误排查）
- examples：
  - `examples/setup-species-basics.sh` — LaserSlab + Sunliang_laser_CH setup 命令
  - `examples/parfile-multispecies.txt` — 完整物种段 parfile
- 跨 skill：
  - `flash-eos` — EOS 模式系统
  - `flash-material` — 表格式 + 不透明度
  - `flash-setup-builder` — 自动 setup 命令生成（Phase 3）

---

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-31 | 初始创建（5 recipes：双物质 + 多层靶 + 多元素 + 手写 SPECIES + 核合成 + 通用建议）| claude |
