---
title: materialProperties 内部实现 — Conductivity/SpitzerHighZ + Opacity/Multispecies per-group 查询
skill: flash-material
category: internals
source_anchors:
  - source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Conductivity.F90:L36-L148
  - source/physics/materialProperties/Conductivity/ConductivityMain/cond_getCv.F90:L54-L170
  - source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity.F90:L28-L222
  - source/physics/materialProperties/Opacity/OpacityMain/Multispecies/method/Tabulated/op_getSpeciesTabulatedOpacities.F90:L34-L140
  - source/physics/materialProperties/Opacity/OpacityMain/Multispecies/op_computeMultispeciesOpacities.F90:L25-L80
manual_ref: "FLASH 4.8 User Guide §16-§17"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: beta
tags:
  - materialproperties
  - internals
  - conductivity
  - opacity
  - per-group
  - ionmix4
---

# materialProperties 内部实现（API + 调用图 + per-group 查询）

> **TL;DR**：本文讲清楚 (1) Conductivity/SpitzerHighZ 主流程——状态→ln Λ→公式→diffCoeff；(2) Opacity/Multispecies per-group 查询机制——cell state→per-species 表插值→混合；(3) cond_getCv 通过 EOS 拿 cv 的细节；(4) PlasmaState_logLambda 共享机制。

---

## 1. Conductivity 公共 API

源码：`source/physics/materialProperties/Conductivity/Conductivity_interface.F90:L17-L46`

```fortran
module Conductivity_interface
  interface
     subroutine Conductivity_init()        ! 启动时调一次
     end subroutine Conductivity_init
  end interface

  interface
     subroutine Conductivity_finalize()    ! 结束时调一次
     end subroutine Conductivity_finalize
  end interface

  interface
     subroutine Conductivity(solnVec, isochoricCond, diffCoeff, component)
       real,    target,   intent(IN) :: solnVec(NUNK_VARS)
       real,    OPTIONAL, intent(OUT)  :: diffCoeff(3)
       real,    OPTIONAL, intent(OUT)  :: isochoricCond(3)
       integer, OPTIONAL, intent(IN) :: component    ! 1=ion, 2=ele, 3=rad
     end subroutine Conductivity
  end interface

  interface
     subroutine Cond_unitTest(fileUnit, perfect)   ! 单元测试
     end subroutine Cond_unitTest
  end interface
end module Conductivity_interface
```

### 1.1 为什么传 solnVec 而非 (ρ, T, X)

**为什么**：物质属性依赖完整状态（ρ、T_ele、T_ion、massfractions、EOSderived abar/zbar）。传 solnVec 让 subroutine 内部按需取，**接口稳定**（变体不同时取的变量不同）。

### 1.2 为什么 isochoricCond / diffCoeff 是 OPTIONAL

**为什么**：调用方有时只要 κ（Diffuse 求 dt），有时只要 D（diff_advanceTherm 求解），有时都要（输出诊断）。**OPTIONAL 避免冗余计算**。

### 1.3 为什么 component 默认 0（综合）

**为什么**：1T（无 3T）模式下只有 T 综合温度，component=0 用 TEMP_VAR。**3T 模式必须显式给 component=1 或 2**。

### 1.4 为什么 isochoricCond(3) 三元素

3 元素代表 (parallel, perpendicular, cross)，**用于磁化等离子体各向异性**。无磁场时三值相同（ isotropic 实现，如 SpitzerHighZ 把所有设为 condLoc）。

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Conductivity.F90:L145-L146`

```fortran
! This is an isotropic implementation, so all components are equal
if(present(isochoricCond)) isochoricCond(:) = isochoricCondLoc
```

---

## 2. Conductivity/SpitzerHighZ 主流程

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Conductivity.F90:L36-L148`

### 2.1 流程图

```
Conductivity(solnVec, isochoricCond, diffCoeff, component)
│
├── 1. 检查 FLASH_3T 编译宏
│       否 → Driver_abortFlash("only works in 3T")
│
├── 2. 解析 component → tempToUse
│       component=1 → TION_VAR
│       component=2 → TELE_VAR
│       component=3 → Driver_abortFlash("does not work with radiation")
│
├── 3. 检查 cond_useConductivity（runtime 参数）
│       FALSE → 返回 isochoricCondLoc=0
│
├── 4. 算 abar/zbar：
│       call Eos_getAbarZbar(solnVec, abar, zbar)
│       nele = zbar * xden * cond_navo / abar
│       mion = abar / cond_navo
│
├── 5. 分支（电子 vs 离子）
│
│   ├── 电子（useTele）:
│   │   call PlasmaState_logLambda(ELE_ION, tele, tion, nele, mion, zbar, ll, .true.)
│   │   isochoricCondLoc = (8/π)^1.5 * k_B^3.5 / (sqrt(m_ele) * e^4)
│   │                      * T_ele^2.5 / (ll * (zbar + 3.3))
│   │
│   └── 离子（useTion）:
│       call PlasmaState_logLambda(ION_ION, tele, tion, nele, mion, zbar, ll, .true.)
│       isochoricCondLoc = 0.164 * 20 * (8/π)^1.5 * k_B^3.5
│                        * T_ion^2.5 / (sqrt(m_ion) * e^4 * zbar^4 * ll)
│
├── 6. 算 diffCoeff（如请求）:
│       diffCoeffLoc = isochoricCondLoc / (xden * cond_getCv(component, solnVec))
│
└── 7. 填充输出数组（三元素同值）
        isochoricCond(:) = isochoricCondLoc
        diffCoeff(:) = diffCoeffLoc
```

### 2.2 关键代码段

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Conductivity.F90:L67-L69`

```fortran
#ifndef FLASH_3T
  call Driver_abortFlash("[Conductivity] SpitzerHighZ conductivity only works in 3T")
#endif
```

**为什么必须 3T**：SpitzerHighZ 区分 TION_VAR 和 TELE_VAR，1T 模式只有 TEMP_VAR。**用 Spitzer（无 Z 修正）变体兼容 1T**。

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Conductivity.F90:L110-L123`

```fortran
if (cond_useConductivity) then

   call Eos_getAbarZbar(solnVec=solnVec, abar=abar, zbar=zbar)
   xden = solnVec(DENS_VAR)
   nele = zbar * xden * cond_navo / abar          ! 电子数密度 [cm^-3]
   mion = abar / cond_navo                          ! 离子质量 [g]

   if(useTele .or. tempToUse == TEMP_VAR) then

      !! call the logLambda routine with Spitzer switch on
      call PlasmaState_logLambda(ELE_ION, solnVec(teleVar), solnVec(tionVar), &
                                  nele, mion, zbar, ll, .true.)

      ! Spitzer-Härm 形式 + Atzeni Z 修正
      isochoricCondLoc = (8.0/PI)**1.5*cond_boltz**3.5 / (sqrt(cond_mele)*cond_qele**4) * &
           solnVec(teleVar)**cexp / (ll * (zbar + 3.3))

   elseif(useTion) then
      ! 离子热导率（公式不同，硬编码系数 0.164*20）
      call PlasmaState_logLambda(ION_ION, solnVec(teleVar), solnVec(tionVar), &
                                  nele, mion, zbar, ll, .true.)
      isochoricCondLoc = &
           0.164 * 20.0 * (8.0/PI)**1.5*cond_boltz**3.5 * solnVec(tionVar)**2.5 / &
           (sqrt(mion) * cond_qele**4 * zbar**4 * ll)
   end if

   if (present(diffCoeff)) then
      diffCoeffLoc = isochoricCondLoc/(xden * cond_getCv(component=component, solnVec=solnVec))
   end if

end if
```

### 2.3 为什么 PlasmaState_logLambda 传 .true.（Spitzer 模式）

源码：`source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_logLambda.F90:L52`

```fortran
logical, optional, intent(in) :: spitzer  ! does simpler Spitzer calculation
```

**为什么 Spitzer 模式**：默认 PlasmaState 算更复杂 ln Λ（含 Debye 长度 + 量子修正）。**SpitzerHighZ 公式假设经典**，所以传 `.true.` 用简化版（更快，且和公式匹配）。

---

## 3. cond_getCv（cv 计算工具）

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/cond_getCv.F90:L54-L170`

### 3.1 作用

返回当前 cell 的比热 cv（用于 diffCoeff = κ/(ρcv)）。

### 3.2 流程

```
cond_getCv(component, solnVec)
│
├── 1. 选择 whichCv
│       component=1 → EOS_CVION（离子 cv）
│       component=2 → EOS_CVELE（电子 cv）
│       未给      → EOS_CV（综合 cv）
│
├── 2. 准备 eos_arr
│       call Eos_getAbarZbar(solnVec, abar, zbar)
│       eos_arr(EOS_DENS) = solnVec(DENS_VAR)
│       call Eos_getTempData(solnVec, eos_arr, MODE_DENS_TEMP_GATHER)
│
├── 3. 调 EOS 算 cv
│       call Eos(MODE_DENS_TEMP_GATHER, 1, eos_arr, massfractions, mask)
│       ! mask 含 EOS_CV + EOS_DET
│
├── 4. 3T 修正（关键）
│       若 EOS 只返回 EOS_CV（综合），按 zbar 拆分：
│         cv_ion = cv / (1 + zbar)
│         cv_ele = cv * zbar / (1 + zbar)
│
└── 5. 返回 cvOut
```

### 3.3 为什么按 zbar 拆分

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/cond_getCv.F90:L152-L166`

```fortran
#ifdef TELE_VAR
  if (present(component)) then
     select case (component)
     case(1)
        if (whichCv == EOS_CV) then
           cvOut = cvOut / (1.0+zbar)        ! 离子份额
        end if
     case(2)
        if (whichCv == EOS_CV) then
           if (zbar .NE. 0.0) &
                cvOut = cvOut * zbar / (1.0+zbar)   ! 电子份额
        end if
     end select
  end if
#endif
```

**为什么 zbar 拆分**：理想气体 cv = (自由度/2) · k_B / m_particle。
- 离子 cv ∝ 1/m_ion = 1/abar
- 电子 cv ∝ zbar/m_ion = zbar/abar（每个离子贡献 zbar 个电子）
- **cv_ele / cv_ion = zbar**
- 总 cv = cv_ion · (1 + zbar)，所以 cv_ion = cv / (1+zbar)、cv_ele = cv · zbar/(1+zbar)

**注意**：仅当 EOS 实现不区分 CVION/CVELE 时才走这个 fallback。**multiTemp EOS 直接返回 EOS_CVION 和 EOS_CVELE**，不走拆分。

---

## 4. Opacity per-group 查询机制

源码：`source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity.F90:L28-L222`

### 4.1 调用接口

```fortran
subroutine Opacity(soln, ngrp, opacityAbsorption, opacityEmission, opacityTransport)
  integer, intent(in)  :: ngrp                              ! 群号 g
  real,    intent(out) :: opacityAbsorption                 ! κ_abs [cm^-1]
  real,    intent(out) :: opacityEmission                   ! κ_emi [cm^-1]
  real,    intent(out) :: opacityTransport                  ! κ_trans [cm^-1]
  real,    intent(in), dimension(:) :: soln                 ! solnVec
end subroutine Opacity
```

**关键**：**每次调用返回一个群的 κ**。MGD 求解器循环 `g=1..Ngrp`，每群调一次。

### 4.2 主流程

```
Opacity(soln, ngrp, opacityAbsorption, opacityEmission, opacityTransport)
│
├── 1. 检查 useOpacity
│       FALSE → return（保持 0）
│
├── 2. 检查群号合法
│       ngrp < 1 或 > op_nEnergyGroups → Driver_abortFlash("no corresponding energy group")
│
├── 3. 从 soln 拿 cell 状态
│       op_cellMassDensity = soln(DENS_VAR)
│       op_cellTemperature = soln(TELE_VAR)         ! 用电子温度查表
│       op_cellSpeciesMassFractions(s) = soln(SPECIES_BEGIN-1+s)
│
├── 4. 算 ion number density per species
│       call op_computeIonNumberDensities()
│       → op_ionNumberDensity(s) = rho * Na / A * massfrac(s)
│
├── 5. 循环每 species（op_totalSpecies）
│   │
│   ├── 5a. 确定需要查哪种表（按 op_absorptionKind(s)/op_emissionKind(s)/op_transportKind(s)）
│   │        needConstant / needConstcm2g / needPATable / needPETable / needROTable / needZeldovich
│   │
│   ├── 5b. op_constant → call op_getSpeciesConstantOpacities(s, dens)
│   │        op_speciesOpacities(ABSORPTION,s) = op_absorptionConstant(s) / dens
│   │
│   ├── 5c. op_tabpa/pe/ro → 检查低温泉值
│   │        if T_cell < op_speciesMinTempPATable(s) → call op_getSpeciesLowTempOpacities(s)
│   │        否则 → call op_getSpeciesTabulatedOpacities(s, T, n_ion, g, ...)
│   │
│   └── 5d. op_zeldovich → call op_getSpeciesZeldovichOpacities(s, soln)
│
├── 6. 按离子数密度加权混合
│       call op_computeMultispeciesOpacities(κ_abs, κ_emi, κ_trans)
│       → κ_abs = rho * Σ_s [n_ion(s) · op_speciesOpacities(ABS,s)] / n_ion_total
│
└── 7. 返回三个 κ（[cm^-1]，path-length 单位）
```

### 4.3 关键代码段（per-group 主循环）

源码：`source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity.F90:L129-L207`

```fortran
do species = 1, op_totalSpecies

   ! 5a. 判断需要查哪种表
   needPATable  = (op_absorptionKind(species) == OP_TABULAR_PA) .or. ...
   needPETable  = (op_absorptionKind(species) == OP_TABULAR_PE) .or. ...
   needROTable  = (op_absorptionKind(species) == OP_TABULAR_RO) .or. ...
   needTable    = needPATable .or. needPETable .or. needROTable

   if (needTable) then

      speciesTemperature = op_cellTemperature

      if (.not.op_ignoreLowTemp) then
         ! 检查 T 是否低于表的最低值
         speciesLowTempCutoff  = op_speciesLowTempCutoff(species)
         speciesMinTempPATable = op_speciesMinTempPATable(species)

         needPALowTemp = needPATable .and. (speciesTemperature < speciesMinTempPATable)
         ! ...

         if (needLowTemp) then
             call op_getSpeciesLowTempOpacities(species, speciesTemperature, ngrp)
             CYCLE                          ! ★ 跳过表查询，用低温泉化值
         end if
      end if

      speciesDensity = op_ionNumberDensity(species)

      ! 5c. 从表查 PA/PE/RO
      call op_getSpeciesTabulatedOpacities(species, speciesTemperature, &
                                            speciesDensity, ngrp, &
                                            needPATable, needPETable, needROTable)
   end if

end do
```

### 4.4 表插值（op_getSpeciesTabulatedOpacities）

源码：`source/physics/materialProperties/Opacity/OpacityMain/Multispecies/method/Tabulated/op_getSpeciesTabulatedOpacities.F90:L34-L140`

```
op_getSpeciesTabulatedOpacities(species, T, n_ion, g, needPA, needPE, needRO)
│
├── if needPA: call op_getSpeciesPATableOpacity(species, T, n_ion, g, opacityPA)
│              → 在 op_PlanckAbsorptionTables(T, n, g, indexPA) 三线性插值
│
├── if needPE: call op_getSpeciesPETableOpacity(species, T, n_ion, g, opacityPE)
│              → 在 op_PlanckEmissionTables(T, n, g, indexPE) 三线性插值
│
├── if needRO: call op_getSpeciesROTableOpacity(species, T, n_ion, g, opacityRO)
│              → 在 op_RosselandTables(T, n, g, indexRO) 三线性插值
│
└── 按 op_absorptionKind/emissionKind/transportKind 选填充哪个
    op_speciesOpacities(ABSORPTION, species) = opacityPA 或 opacityPE 或 opacityRO
    op_speciesOpacities(EMISSION,   species) = ...
    op_speciesOpacities(TRANSPORT,  species) = ...
```

### 4.5 混合规则（op_computeMultispeciesOpacities）

源码：`source/physics/materialProperties/Opacity/OpacityMain/Multispecies/op_computeMultispeciesOpacities.F90:L25-L80`

```fortran
sumAbsorption = 0
sumEmission   = 0
sumTransport  = 0

do species = 1, op_totalSpecies
   ionNumberDensity = op_ionNumberDensity(species)

   sumAbsorption = sumAbsorption + ionNumberDensity * op_speciesOpacities(ABSORPTION, species)
   sumEmission   = sumEmission   + ionNumberDensity * op_speciesOpacities(EMISSION,   species)
   sumTransport  = sumTransport  + ionNumberDensity * op_speciesOpacities(TRANSPORT,  species)
end do

! 加权 + 换算到 path-length（cm^-1）
opacityAbsorption = op_cellMassDensity * (sumAbsorption / op_totalIonNumberDensity)
opacityEmission   = op_cellMassDensity * (sumEmission   / op_totalIonNumberDensity)
opacityTransport  = op_cellMassDensity * (sumTransport  / op_totalIonNumberDensity)
```

**为什么离子数密度加权**：

物理上不透明度（[cm²/g]，mass opacity）按 **每离子贡献** 加权。等价于：
- 物质 1（cham, He）质量分数 mf_1 + 物质 2（targ, Al）质量分数 mf_2
- 每 cm³ 内：物质 1 离子数 n_1 = ρ·mf_1·N_A/A_1，物质 2 离子数 n_2 = ρ·mf_2·N_A/A_2
- 总 κ（[cm^-1]）= ρ · Σ_s [mf_s · κ_s_mass] = ρ · Σ_s [n_s/n_total · κ_s_mass]

**公式等价**：`κ_total = ρ · <κ>_mass`，其中 `<κ>_mass = Σ_s (n_s · κ_s) / n_total`（按离子数加权，因为每离子贡献相同截面）。

---

## 5. IONMIX4 表加载机制

源码：`source/physics/materialProperties/Opacity/OpacityMain/Multispecies/method/Tabulated/op_readIonmix4Tables.F90`

### 5.1 启动时读表

```
Driver_initFlash
└── Opacity_init
    └── op_initTabulated
        ├── 遍历每 species：
        │   ├── 读 op_<spec>FileName（如 "al-imx-003.cn4"）
        │   ├── 读 op_<spec>FileType（如 "ionmix4"）
        │   ├── 按 FileType 分发：
        │   │   ├── "ionmix4" → call op_readIonmix4Tables(...)
        │   │   ├── "ionmix"  → call op_readIonmixTables(...)
        │   │   ├── "tops"    → call op_readTopsTables(...)
        │   │   └── ...
        │   └── 填充 op_PlanckAbsorptionTables(T, n, g, indexPA) 等
        │
        └── op_writeTables（可选，调试用）
```

### 5.2 IONMIX4 文件结构（.cn4）

ASCII 文本格式，结构：
```
# Header
IONMINX4版本号
物质名 (e.g., "Al")
原子量 A，原子序数 Z

# 网格
N_T温度点数
T_1 T_2 ... T_NT (eV)
N_n密度点数
n_1 n_2 ... n_Nn (cm^-3)
N_g群数
g_1 g_2 ... g_(N_g+1) (eV，群边界)

# 表（3 个：PA, PE, RO）
# Planck Absorption 表 [N_T × N_n × N_g]
PA[T=1, n=1, g=1..N_g]
PA[T=1, n=2, g=1..N_g]
...

# Planck Emission 表 [N_T × N_n × N_g]
PE[...]

# Rosseland 表 [N_T × N_n × N_g]
RO[...]
```

**单位**：温度 eV（FLASH 读时转 K），数密度 #/cm³，κ 是 cm²/g（FLASH 读时按物质密度换算到 cm^-1）。

### 5.3 为什么 .cn4 文件路径要在 parfile 给

源码：`source/Simulation/SimulationMain/LaserSlab/Config:L25-L29`

```
DATAFILES al-imx-002.cn4
DATAFILES al-imx-003.cn4
DATAFILES he-imx-005.cn4
DATAFILES al-imx-003.ses
DATAFILES he-imx-005.ses
```

**DATAFILES** 让 setup 把表文件复制到 objdir。**否则 Opacity_init 找不到文件 abort**。

### 5.4 群边界对齐检查

源码：`source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity_data.F90:L48`

```fortran
real, parameter :: op_energyDifferenceTolerance = 1.E-8
```

**启动时**检查 .cn4 表的群边界和 parfile 的 `rt_mgdBounds_*` 是否一致（容差 1e-8 eV）。**不一致 abort**。

**为什么严格**：每群插值假设边界对齐。不对齐会查错表，物理失真。

---

## 6. PlasmaState_logLambda 共享

源码：`source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_logLambda.F90`

### 6.1 接口

```fortran
subroutine PlasmaState_logLambda(comp, tele, tion, nele, mion, zbar, ll, spitzer)
  integer, intent(in) :: comp       ! ELE_ELE / ELE_ION / ION_ION
  real,    intent(in) :: tele       ! 电子温度 [K]
  real,    intent(in) :: tion       ! 离子温度 [K]
  real,    intent(in) :: nele       ! 电子数密度 [cm^-3]
  real,    intent(in) :: mion       ! 离子质量 [g]
  real,    intent(in) :: zbar       ! 平均电荷态
  real,    intent(out):: ll         ! ln Λ
  logical, optional, intent(in) :: spitzer  ! 用简化版
end subroutine
```

### 6.2 共享调用方

| 调用方 | comp | 用途 |
|---|---|---|
| Conductivity/SpitzerHighZ | ELE_ION | 电子热导率 |
| Conductivity/SpitzerHighZ | ION_ION | 离子热导率 |
| Conductivity/LeeMore | ELE_ION | Lee-More 电导率 |
| Conductivity/JiHeld | ELE_ELE + ELE_ION | Ji-Held 磁化电导率 |
| Heatexchange/Spitzer | ELE_ION | 电子-离子平衡时间 |
| MagneticResistivity/SpitzerHighZ | ELE_ION | 磁阻 |
| MagneticResistivity/DaviesWen | ELE_ELE + ELE_ION | 磁化磁阻 |

### 6.3 为什么 PlasmaState 是单独单元

**避免代码重复**：6+ 个调用方用同样的 ln Λ 公式。**统一在 PlasmaState 实现**保证一致性。

**实现差异**（spitzer=true vs false）：
- 默认（false）：用完整经典公式 + Debye 长度 + 量子修正
- Spitzer 模式（true）：用简化形式（适合匹配 Spitzer 公式假设）

---

## 7. 调用关系总图（按 L-002 文字+缩进）

```
Driver_evolveFlash (主循环)
│
├── Driver_initFlash (启动)
│   ├── Conductivity_init
│   │   └── cond_commonInit → PhysicalConstants_get → 拿 m_ele/k_B/e/N_A
│   ├── Opacity_init
│   │   ├── op_initTabulated
│   │   │   ├── 遍历 species
│   │   │   │   ├── op_readIonmix4Tables (主流)
│   │   │   │   ├── op_readIonmixTables (老版)
│   │   │   │   └── op_readTopsTables (罕用)
│   │   │   └── 填充 op_PlanckAbsorptionTables / op_PlanckEmissionTables / op_RosselandTables
│   │   ├── op_setEnergyGroupBoundaries (从 rt_mgdBounds 读)
│   │   ├── op_setLowTemperatureBoundaries
│   │   └── op_initLowTemp (Biggs1971 / Klein 数据)
│   └── Viscosity_init / MagneticResistivity_init (如启用)
│
├── Driver_evolveFlash 主循环（每步）
│   ├── Hydro
│   ├── Driver_sourceTerms
│   │   └── Heatexchange (调用 PlasmaState_logLambda —— 同 Conductivity 共享)
│   │
│   ├── Diffuse (热扩散求解，HYPRE)
│   │   ├── Diffuse_computeDt
│   │   │   └── call Conductivity(solnData, diffCoeff, component=2)  ★ 算 dt
│   │   └── diff_advanceTherm
│   │       └── call Conductivity(solnVec, cond_zone, component=EOSCOMP_ELE)
│   │           └── cond_getCv → Eos(MODE_DENS_TEMP_GATHER, mask=[EOS_CVELE])
│   │       └── Diffuse_solveScalar (HYPRE 隐式解 ∂T/∂t = ∇·(D∇T))
│   │
│   ├── RadTrans (MGD 多群辐射扩散求解)
│   │   ├── RadTrans_computeFluxLimiter
│   │   │   └── per cell, per group:
│   │   │       call Opacity(solnData, g, κ_abs, κ_emi, κ_trans)  ★
│   │   └── RadTrans.F90
│   │       └── do g = 1, op_nEnergyGroups
│   │           └── do cell
│   │               └── call Opacity(blkPtr(:,i,j,k), g, ...)
│   │                   └── op_computeIonNumberDensities (per species)
│   │                   └── per species:
│   │                       └── op_getSpeciesTabulatedOpacities
│   │                           └── op_getSpeciesPATableOpacity (T,n,g 三线性插值)
│   │                   └── op_computeMultispeciesOpacities (按 n_ion 加权混合)
│   │
│   └── IO_output
│
└── Driver_finalizeFlash
    ├── Conductivity_finalize
    └── Opacity_finalize
```

---

## 8. 与其他单元协作的细节

### 8.1 与 EOS 协作（拿 cv、abar、zbar）

| 调用 | 触发位置 | 目的 |
|---|---|---|
| `Eos_getAbarZbar(solnVec, abar, zbar)` | Conductivity/SpitzerHighZ | 拿当前 cell 平均原子量/电荷态 |
| `Eos_getTempData(solnVec, eos_arr, mode)` | cond_getCv | 从 solnVec 拿温度（包括 3T 的 TION/TELE/TRAD）|
| `Eos(MODE_DENS_TEMP_GATHER, mask=[EOS_CV, EOS_DET])` | cond_getCv | 算 cv 和 det（温度对内能导数）|

详见 flash-eos skill。

### 8.2 与 Diffuse 协作（diff_advanceTherm）

**Conductivity 只算 cond_zone**，Diffuse 内部用：
```
1. cond_zone = Conductivity(solnVec, component=EOSCOMP_ELE)
2. cv = cond_getCv(component=2, solnVec)
3. D = cond_zone / (rho * cv)
4. 应用 flux limiter（fl_larsen 等）
5. HYPRE 隐式解 ∂T_ele/∂t = ∇·(D∇T_ele)
```

详见 flash-diffuse skill。

### 8.3 与 RadTrans 协作（MGD per-group）

**Opacity 只返回每群 κ**，RadTrans 内部用：
```
1. do g = 1, op_nEnergyGroups
2.   call Opacity(soln, g, κ_abs, κ_emi, κ_trans)
3.   ! 用 κ_abs 算电子-辐射能量交换（plasma 吸收）
4.   change = urad * C * absorb_opac
5.   ! 用 κ_trans 算群间扩散通量
6.   F = -c/(3*κ_trans) ∇urad
7.   ! 用 κ_emi 算发射源项
8.   source = κ_emi * 4σT_ele^4
```

详见 flash-radtrans skill。

### 8.4 与 Heatexchange 协作（PlasmaState 共享）

Heatexchange 和 Conductivity **都调 PlasmaState_logLambda**，但：
- Heatexchange 用算 **eqtime**（电子-离子平衡时间，Braginskii 公式）
- Conductivity 用算 **ln Λ**（库仑对数，SpitzerHighZ 公式系数）

两者不直接调用对方，但 ln Λ 数值上一致（同 cell 同状态算）。

详见 flash-sourceterms skill。

---

## 9. 延伸阅读

- **参数完整字典**：`knowledge/params.md`
- **典型配置**：`knowledge/recipes.md`
- **常见错误**：`knowledge/pitfalls.md`
- **物理原理 + 设计**：`knowledge/overview.md`
- **Diffuse HYPRE 求解**：`flash-diffuse` skill
- **RadTrans MGD 求解**：`flash-radtrans` skill
- **Heatexchange PlasmaState 共享**：`flash-sourceterms` skill
- **手册**：FLASH 4.8 User Guide §16-§17

---

## 10. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（beta）：10 节内部实现，覆盖 Conductivity 公共 API + SpitzerHighZ 主流程 + cond_getCv + Opacity per-group 查询 + IONMIX4 表加载 + PlasmaState 共享 + 调用关系总图 + 跨单元协作细节；按 L-002 用文字+缩进不用 mermaid + L-008 贴源码相关代码 + L-012 公式 ASCII | claude |
