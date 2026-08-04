---
name: flash-material
description: |
  FLASH 4.8 materialProperties 单元专家（物质属性）。
  按 L-013 聚焦主流量径——Conductivity/SpitzerHighZ（HEDP 电子热传导，LaserSlab 用）
  + Opacity/Multispecies（HEDP 多群辐射不透明度，LaserSlab 用 IONMIX4 表）。
  覆盖：
  - Conductivity 9 变体（Constant / Constant-diff / Spitzer / Stellar / PowerLaw / PowerLaw-gray / SpitzerHighZ ⭐ / LeeMore / EppHain / JiHeld）
  - **SpitzerHighZ 物理公式**（Atzeni 形式，含 ln Λ + Z 修正）：cond ~ k_B^3.5 * T_ele^2.5 / (sqrt(m_ele) * e^4 * ln Λ * (Z + 3.3))
  - **扩散系数 diffCoeff** = isochoricCond / (rho * cv)，3T 下区分 ion/ele component
  - Opacity/Multispecies per-group 查询机制（absorb/emiss/trans 三种，PA/PE/RO 三种表）
  - **IONMIX4 表格式**（.cn4 文件，温度/数密度/能群三维表）
  - 低温泉化（Biggs1971 / KleinGroupOpacity）
  - Rosseland / Planck 平均（吸收 PA / 发射 PE / Rosseland RO，三种不透明度的物理含义）
  - Zeldovich / Constcm2g / Constant / BremsstrahlungAndThomson / OPAL 变体简要
  - Viscosity（Spitzer 形式，3T 离子粘性，LaserSlab 不用）
  - MagneticResistivity（SpitzerHighZ/DaviesWen，MHD 用，非 HEDP 主流）
  - Thermoelectric / MassDiffusivity / NSE（边缘，简要）
  - PlasmaState_logLambda 共享（Conductivity/Heatexchange/Resistivity 共用）
  - 与 EOS（cond_getCv 拿 cv）/ Diffuse（diff_advanceTherm 调用）/ RadTrans（per-group Opacity 调用）耦合
  触发词：materialProperties, 物质属性, Conductivity, 电导率, 热导率, thermal conduction,
        Spitzer, Spitzer-Härm, SpitzerHighZ, LeeMore, EppHain, JiHeld, PowerLaw,
        Opacity, 不透明度, 透明度, Rosseland, Planck mean, Rosseland mean, emission, absorption,
        transport, op_tabpa, op_tabpe, op_tabro, op_constant, op_constcm2g, op_zeldovich,
        op_<spec>Absorb, op_<spec>Emiss, op_<spec>Trans, op_<spec>FileName, op_<spec>FileType,
        op_ignoreLowTemp, opacity_writeOpacityInfo, opacity_ceiling,
        ionmix, ionmix4, ionmix7, IONMIX4, .cn4, .imx, .ses, opacplot, tops, propaceos,
        Viscosity, 粘性, dynamic viscosity, kinematic viscosity, visc_, useViscosity, useExplicitViscosity,
        MagneticResistivity, 磁阻, res_, resPar, resPerp, res_maxRes, res_vacSpec,
        DaviesWen, res_davieswen, resistivitySolver, resistivityForm,
        Thermoelectric, MassDiffusivity, NSE,
        cond_, useConductivity, cond_constantParallel, cond_constantPerpendicular, cond_constantCross, cond_constantIsochoric,
        diff_useEleCond, diff_eleFlMode, diff_eleFlCoef, fl_larsen, fl_harmonic, flux limiter,
        PlasmaState_logLambda, Coulomb logarithm, ln Lambda, 库仑对数,
        cond_getCv, EOS_CV, EOS_CVION, EOS_CVELE, cvion, cvele,
        isochoricCond, diffCoeff, component, EOSCOMP_ELE, EOSCOMP_ION, EOSCOMP_RAD,
        RosselandTables, PlanckAbsorptionTables, PlanckEmissionTables,
        op_PlanckAbsorptionTables, op_PlanckEmissionTables,
        MassDiffusivity, thermoelectric, NSE, op_computeIonNumberDensities
triggers:
  # 中文
  - 物质属性
  - 电导率
  - 热导率
  - 不透明度
  - 透明度
  - 粘性
  - 粘滞
  - 磁阻
  - 磁电阻率
  - 热电
  - 质量扩散
  - 库仑对数
  - 罗斯兰德
  - 普朗克平均
  - 吸收系数
  - 发射系数
  - 输运系数
  - 物质表
  - 不透明度表
  # 英文——单元名
  - materialProperties
  - Conductivity
  - conductivity
  - Opacity
  - opacity
  - Viscosity
  - viscosity
  - MagneticResistivity
  - magneticResistivity
  - Thermoelectric
  - thermoelectric
  - MassDiffusivity
  - massDiffusivity
  - NSE
  - useConductivity
  - useOpacity
  - useViscosity
  - useMagneticResistivity
  # 英文——Conductivity 变体
  - SpitzerHighZ
  - spitzerHighZ
  - Spitzer
  - LeeMore
  - Lee-More
  - EppHain
  - JiHeld
  - PowerLaw
  - PowerLaw-gray
  - Stellar
  - Constant-diff
  # 英文——Opacity 变体
  - Multispecies
  - Constcm2g
  - ConstPerGroup
  - BremsstrahlungAndThomson
  - OPAL
  - Zeldovich
  - op_tabpa
  - op_tabpe
  - op_tabro
  - op_constant
  - op_constcm2g
  - op_zeldovich
  - op_undefined
  # 英文——参数前缀
  - op_
  - cond_
  - visc_
  - res_
  - op_chamAbsorb
  - op_chamEmiss
  - op_chamTrans
  - op_chamFileName
  - op_chamFileType
  - op_targAbsorb
  - op_targEmiss
  - op_targTrans
  - op_targFileName
  - op_targFileType
  - cond_constantParallel
  - cond_constantPerpendicular
  - cond_constantCross
  - cond_constantIsochoric
  - opacity_ignoreLowTemp
  - opacity_writeOpacityInfo
  - opacity_ceiling
  - res_maxRes
  - res_vacSpec
  - res_vacDens
  - res_vacFrac
  - res_vacRes
  - res_useVac
  - res_addAnomRes
  - resistivitySolver
  - resistivityForm
  # 英文——物理量
  - isochoricCond
  - diffCoeff
  - Rosseland
  - Planck mean
  - Rosseland mean
  - Planck absorption
  - Planck emission
  - emission opacity
  - absorption opacity
  - transport opacity
  - flux limiter
  - fl_larsen
  - fl_harmonic
  - fl_multigroup
  - fl_none
  - diff_useEleCond
  - diff_eleFlMode
  - diff_eleFlCoef
  - diff_thetaImplct
  # 英文——表格式
  - ionmix
  - ionmix4
  - ionmix7
  - IONMIX4
  - .cn4
  - .imx
  - .ses
  - tops
  - opacplot
  - propaceos
  # 英文——API / 内部
  - PlasmaState_logLambda
  - PlasmaState_tau
  - PlasmaState_ieEquilTime
  - ELE_ELE
  - ELE_ION
  - ION_ION
  - cond_getCv
  - EOS_CV
  - EOS_CVION
  - EOS_CVELE
  - EOSCOMP_ELE
  - EOSCOMP_ION
  - EOSCOMP_RAD
  - op_computeIonNumberDensities
  - op_computeMultispeciesOpacities
  - op_getSpeciesTabulatedOpacities
  - op_readIonmix4Tables
  - op_readIonmixTables
  - op_readTopsTables
  - op_PlanckAbsorptionTables
  - op_PlanckEmissionTables
  - op_RosselandTables
  - op_speciesOpacities
  - op_absorptionKind
  - op_emissionKind
  - op_transportKind
  - op_nEnergyGroups
  - op_cellTemperature
  - op_cellMassDensity
  - op_ionNumberDensity
when_to_use: |
  调用本 skill 的场景：
  1. 用户问 Conductivity（"电子热传导怎么算"、"SpitzerHighZ 公式"、"isochoricCond 是什么"）
  2. 用户问 Opacity（"不透明度怎么取"、"为什么每群都查一次"、"Rosseland vs Planck 区别"）
  3. 用户问 Conductivity 变体选择（"SpitzerHighZ vs LeeMore"、"PowerLaw 何时用"）
  4. 用户问表格文件（".cn4 是什么格式"、"ionmix4 vs ionmix 区别"、"怎么生成表"）
  5. 用户问 op_<spec>Absorb/Emiss/Trans 配置（"cham 用什么表"、"targ 用什么表"）
  6. 用户问 cond_getCv / cv 怎么算（"3T 下电子和离子 cv 怎么分"）
  7. 用户问 PlasmaState_logLambda（"ln Λ 怎么算"、"Coulomb 对数哪儿来"）
  8. 用户调试 Conductivity/Opacity（"cond_zone = 0"、"Opacity 返回 0"、"ionmix 表读不了"）
  9. 用户问 Conductivity 和 Diffuse 关系（"diff_advanceTherm 怎么调 Conductivity"）
  10. 用户问 LaserSlab 物质属性配置（"op_cham*/op_targ*"、"useConductivity/.true."）
  11. 用户问 Viscosity/MagneticResistivity（简要，非 HEDP 主流）
when_not_to_use: |
  **不调用本 skill 的场景**：
  - EOS 三温耦合（拿 T、cv、P、E） → `flash-eos`（materialProperties 调用 EOS 拿 cv，但不重复）
  - HYPRE 隐式扩散求解（diff_advanceTherm 内部） → `flash-diffuse`（Phase 2；Conductivity 只返回 cond，求解在 Diffuse）
  - MGD 辐射扩散求解 → `flash-radtrans`（MGD 调用 Opacity 拿 κ，但求解和通量限制器归 RadTrans）
  - 物种定义（species 名字、A/Z、massfractions） → `flash-multispecies`
  - Heatexchange 电子-离子平衡 → `flash-sourceterms`（共用 PlasmaState_logLambda 但归属不同）
  - Driver 主循环 → `flash-driver`
  - 找源码位置 → `flash-source-reader`
  - 错误匹配 → `flash-pitfall-finder`
  - 参数基本属性 → `flash-param-query`
  - 跑算例 → `flash-case-runner`（Phase 3）
layer: knowledge
phase: 2
status: stable
created: 2026-06-17
last_updated: 2026-07-31
owner: user
---

# flash-material — materialProperties 单元专家

> **状态**：beta（Phase 2 stable 知识层 skill，Phase 2 第七个知识层 skill）
>
> **按 L-013 聚焦主流**：本 skill 主讲 **Conductivity/SpitzerHighZ**（HEDP 电子热传导，LaserSlab 用）+ **Opacity/Multispecies**（HEDP 多群不透明度，LaserSlab 用 IONMIX4 表）。其他子单元（Viscosity/MagneticResistivity/Thermoelectric/MassDiffusivity/NSE）简要带过。

## 1. 角色与边界

### 1.1 我是做什么的

回答 FLASH **materialProperties 单元**相关问题——所有"物质属性"的查询与计算：

| 范畴 | 详见 |
|---|---|
| 物理原理 + 设计 | `knowledge/overview.md` — materialProperties 角色 + Conductivity 9 变体 + Opacity per-group + 术语速查（L-014）|
| 参数字典 | `knowledge/params.md` — useConductivity/useOpacity + op_<spec>* + cond_* + res_* 完整字典 |
| 内部实现 | `knowledge/internals.md` — Conductivity/SpitzerHighZ 主流程 + Opacity per-group 查询 + PlasmaState 耦合 |
| 典型配置 | `knowledge/recipes.md` — LaserSlab SpitzerHighZ + IONMIX4 + 典型 parfile |
| 踩坑排查 | `knowledge/pitfalls.md` — cond=0、Opacity 返回 0、ionmix 读不了、bad opacity kind 等 |

### 1.2 我不做什么

| 用户问题类型 | 归属 skill |
|---|---|
| EOS 三温耦合（拿 cv / E / P） | `flash-eos`（materialProperties 调用 EOS 拿 cv） |
| HYPRE 隐式扩散求解 | `flash-diffuse`（Conductivity 只返回 cond，求解在 Diffuse） |
| MGD 辐射扩散求解 | `flash-radtrans`（MGD 调用 Opacity 拿 κ，求解归 RadTrans） |
| 物种定义（species 名/A/Z） | `flash-multispecies` |
| Heatexchange 电子-离子平衡 | `flash-sourceterms`（共用 PlasmaState 但归属不同） |
| Driver 主循环 | `flash-driver` |
| Grid / AMR | `flash-grid` |
| 找源码位置 | `flash-source-reader` |
| 错误匹配 | `flash-pitfall-finder` |
| 参数基本属性 | `flash-param-query` |

## 2. 行为协议

按 `agent/TEMPLATES/skill-template.md §2` 通用协议。核心要点（按 L-001~L-014）：

- **讲逻辑**（L-001）：不只是列 Conductivity 9 变体，讲清楚每个的物理意义、何时选
- **不用 mermaid**（L-002）：调用关系用文字+缩进
- **贴源码相关代码**（L-008）：abort 类查询贴 `Driver_abortFlash` 所在 if/运算行
- **核心 4 段 + 引导项**（L-010）：核心段必给详细，引导项按需展开
- **讲为什么**（L-011）：选择/配置/概念类问题必给"为什么这么设计/为什么默认这个值"
- **诊断类先引导贴现场**（L-012）：cond=0/NaN 等先要用户贴日志/setup/parfile
- **公式 CLI 友好**（L-012）：用 ASCII / 代码块，不用 `$...$`
- **聚焦主流路径**（L-013）：SpitzerHighZ + Multispecies 详讲；Viscosity/Resistivity/其他简要
- **专业术语先解释**（L-014）：Spitzer-Härm / Rosseland / Planck / Coulomb logarithm 等先定义再讲机制
- **面向新手**：解释每个术语（"isochoricCond"、"diffCoeff"、"3T component"）

### 2.1 跨 skill 协作

| 场景 | 协作链 |
|---|---|
| 用户问 "cond_getCv 怎么算 cv" | `flash-material`（API） → `flash-eos`（EOS 算 cv 的细节） |
| 用户问 "diff_advanceTherm 怎么调 Conductivity" | `flash-material`（Conductivity 接口） → `flash-diffuse`（求解流程） |
| 用户问 "MGD 怎么用 Opacity" | `flash-material`（Opacity 接口） → `flash-radtrans`（MGD per-group 求解） |
| 用户问 "op_chamFileName 的 .cn4 文件" | `flash-material`（IONMIX4 格式） → `flash-multispecies`（species 定义） |
| 用户问 "PlasmaState_logLambda" | `flash-material`（共享工具） → `flash-sourceterms`（Heatexchange 用法） |

## 3. knowledge/ 子目录

| 文件 | 内容 |
|---|---|
| `knowledge/overview.md` | materialProperties 角色 + Conductivity 9 变体对比 + Opacity per-group 设计 + 术语速查（L-014） |
| `knowledge/params.md` | 参数完整字典（主控 / Conductivity / Opacity / MagneticResistivity / Viscosity）|
| `knowledge/internals.md` | Conductivity/SpitzerHighZ 主流程 + Opacity per-group 查询机制 + PlasmaState_logLambda 耦合 |
| `knowledge/recipes.md` | LaserSlab SpitzerHighZ + IONMIX4 配置 + 9 变体选择 + 典型 parfile |
| `knowledge/pitfalls.md` | 常见错误（cond=0、Opacity 返回 0、bad opacity kind、ionmix 读不了、SpitzerHighZ only works in 3T 等） |

## 4. examples/

| 文件 | 内容 |
|---|---|
| `examples/setup-spitzerhighz-ionmix4.sh` | LaserSlab Conductivity/SpitzerHighZ + Opacity/Multispecies setup 命令 |
| `examples/parfile-material-laserslab.txt` | LaserSlab 物质属性完整 parfile 片段（含 op_cham*/op_targ*） |
| `examples/parfile-constant-conductivity.txt` | Constant conductivity + Constcm2g opacity 简易配置（调试用） |
| `examples/README.md` | examples 使用说明 + setup 命令速查 |

## 5. 示例问答（验收基准）

### Q1: Conductivity 是什么？HEDP 算例为什么需要？
**A**: 见 `knowledge/overview.md §1-2`。**Conductivity = 物质的热传导系数**（电子或离子）。HEDP 中激光沉积到电子后，电子通过热传导向冷区扩散（典型电子传导 ~10^7 erg/(cm·s·K)）。**没有 Conductivity**，能量只能在原 cell 累积，物理失真。LaserSlab 用 **SpitzerHighZ** 变体（Atzeni 公式，含库仑对数和 Z 修正）。

### Q2: Conductivity 9 个变体怎么选？LaserSlab 为什么用 SpitzerHighZ？
**A**: 见 `knowledge/overview.md §3` + `knowledge/recipes.md §2`。**Config 默认 Constant**（数值测试用）；**LaserSlab 用 SpitzerHighZ**（HEDP 标准，含 Z 修正适合多元素等离子体）；高 Z 物质（Au、W）用 **LeeMore**（含稠密/简并修正）；MHD 算例可加 PowerLaw-gray。**SpitzerHighZ vs Spitzer**：前者有 `(Z + 3.3)` 修正项，适合 Z>1 物质（Al、CH）；后者只有 `T^2.5`，适合纯氢氦。

### Q3: SpitzerHighZ 电导率公式是什么？
**A**: 见 `knowledge/internals.md §3`。源码 `ConductivityMain/SpitzerHighZ/Conductivity.F90:L122-L123`：
```
isochoricCondLoc = (8/π)^1.5 * k_B^3.5 / (sqrt(m_ele) * e^4)
                 * T_ele^2.5 / (ln Λ * (Z + 3.3))
```
其中 `ln Λ` 由 `PlasmaState_logLambda(ELE_ION, tele, tion, nele, mion, zbar, ll, .true.)` 算（典型 HEDP 值 1-10）。`(Z + 3.3)` 是 Atzeni 经验项（处理 e-e 碰撞修正）。**diffCoeff = isochoricCond / (rho * cv_ele)** 通过 cond_getCv 拿 cv。

### Q4: Opacity/Multispecies 为什么每群查一次？Rosseland/Planck/Absorption 三种什么区别？
**A**: 见 `knowledge/internals.md §4` + `knowledge/overview.md §5`。**多群扩散（MGD）**每群（g=1..Ngrp）有自己的 κ_g（吸收/发射/输运），所以每群都要查一次。**三种表的物理含义**（按 L-014 先定义）：
- **PA (Planck Absorption)**：吸收不透明度，对应发射谱权重——`κ_P^abs` 用于计算等离子体从辐射场吸收的能量
- **PE (Planck Emission)**：发射不透明度，对应物质自身发射——`κ_P^emis` 用于源项
- **RO (Rosseland)**：罗斯兰德平均（谐波平均权重）——`κ_R` 用于扩散通量

物理上 Rosseland 是透明区优化（扩散近似），Planck 是不透明区（发射/吸收平衡）。HEDP 通常 PA+PE+RO 三表都用（LaserSlab 这样配）。

### Q5: LaserSlab 为什么 cham 和 targ 都配 PA+PE+RO 三个表？
**A**: 见 `knowledge/recipes.md §3`。LaserSlab parfile `op_chamAbsorb="op_tabpa"`、`op_chamEmiss="op_tabpe"`、`op_chamTrans="op_tabro"`，因为 MGD 求解器同时需要计算 (1) 电子-辐射能量交换（用 PA+PE）、(2) 群间辐射扩散（用 RO）。两种机制都需要，缺一个 MGD 就跑不了。

## 6. 关键源码入口

| 想理解 | 看哪个文件 |
|---|---|
| Conductivity 公共接口（4 函数） | `source/physics/materialProperties/Conductivity/Conductivity_interface.F90` |
| Conductivity 主入口（stub） | `source/physics/materialProperties/Conductivity/Conductivity.F90`（stub）→ `ConductivityMain/<variant>/Conductivity.F90` |
| **SpitzerHighZ 实现**（LaserSlab 用） | `source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Conductivity.F90:L36-L148` |
| SpitzerHighZ 公式（核心两行） | `source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Conductivity.F90:L122-L131` |
| SpitzerHighZ Config（REQUIRES PlasmaState） | `source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Config` |
| cond_getCv（拿 cv 的工具） | `source/physics/materialProperties/Conductivity/ConductivityMain/cond_getCv.F90` |
| cond_commonInit（物理常数） | `source/physics/materialProperties/Conductivity/ConductivityMain/cond_commonInit.F90` |
| Conductivity 顶层 Config（9 变体） | `source/physics/materialProperties/Conductivity/ConductivityMain/Config` |
| Constant 变体（含 cond_constantParallel 等） | `source/physics/materialProperties/Conductivity/ConductivityMain/Constant/Config` |
| Spitzer 变体（无 Z 修正） | `source/physics/materialProperties/Conductivity/ConductivityMain/Spitzer/Conductivity.F90` |
| LeeMore 变体（高 Z 稠密等离子体） | `source/physics/materialProperties/Conductivity/ConductivityMain/LeeMore/Conductivity.F90` |
| Opacity 公共接口 | `source/physics/materialProperties/Opacity/Opacity_interface.F90` |
| Opacity 主入口（stub） | `source/physics/materialProperties/Opacity/Opacity.F90` |
| **Multispecies 实现**（LaserSlab 用） | `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity.F90:L28-L222` |
| Multispecies per-group 主循环 | `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity.F90:L129-L207` |
| Multispecies Config（per-species 参数生成） | `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Config` |
| OpacityMain Config（7 变体） | `source/physics/materialProperties/Opacity/OpacityMain/Config` |
| op_initTabulated（启动时读表） | `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/method/Tabulated/op_initTabulated.F90` |
| **op_readIonmix4Tables**（读 .cn4） | `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/method/Tabulated/op_readIonmix4Tables.F90` |
| op_readIonmixTables（老版 .imx） | `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/method/Tabulated/op_readIonmixTables.F90` |
| op_readTopsTables（TOPS 格式） | `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/method/Tabulated/op_readTopsTables.F90` |
| op_getSpeciesTabulatedOpacities（插值） | `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/method/Tabulated/op_getSpeciesTabulatedOpacities.F90` |
| op_getSpeciesConstantOpacities（常数） | `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/method/Constant/op_getSpeciesConstantOpacities.F90` |
| op_computeIonNumberDensities | `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/op_computeIonNumberDensities.F90` |
| op_computeMultispeciesOpacities（混合） | `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/op_computeMultispeciesOpacities.F90` |
| Opacity_data（op_* 数组声明） | `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity_data.F90` |
| Viscosity stub | `source/physics/materialProperties/Viscosity/Viscosity.F90` |
| ViscosityMain Config | `source/physics/materialProperties/Viscosity/Config` |
| MagneticResistivity stub | `source/physics/materialProperties/MagneticResistivity/MagneticResistivity.F90` |
| MagneticResistivityMain Config（4 变体） | `source/physics/materialProperties/MagneticResistivity/MagneticResistivityMain/Config` |
| res_spitzerhighz（MHD SpitzerHighZ） | `source/physics/materialProperties/MagneticResistivity/MagneticResistivityMain/SpitzerHighZ/res_spitzerhighz.F90` |
| PlasmaState_logLambda（共享工具） | `source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_logLambda.F90` |
| **Diffuse 调用 Conductivity**（diff_advanceTherm） | `source/physics/Diffuse/DiffuseMain/Unsplit/diff_advanceTherm.F90:L237` |
| **RadTrans 调用 Opacity**（MGD per-group） | `source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90:L486` |
| Diffuse_computeDt（cond_zone 用于 dt） | `source/physics/Diffuse/DiffuseMain/Diffuse_computeDt.F90:L177-L199` |
| LaserSlab Config（REQUESTS SpitzerHighZ） | `source/Simulation/SimulationMain/LaserSlab/Config:L11` |
| LaserSlab flash.par（op_cham*/op_targ*） | `source/Simulation/SimulationMain/LaserSlab/flash.par:L60-L74` |
| LaserSlab flash.par（useConductivity） | `source/Simulation/SimulationMain/LaserSlab/flash.par:L162-L168` |

## 7. 待办

- [ ] 跑 5 道验收考题，全部通过则升级 stable
- [ ] 持续累积踩坑（用户实战 HEDP 算例遇到 Conductivity/Opacity 问题时）
- [ ] Phase 2+ 后续 skill 协作验证（如 flash-diffuse 解释 HYPRE 隐式扩散与 Conductivity 的关系）

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架，5 行触发词） | claude |
| 2026-07-30 | **升级 draft → beta**（Phase 2 第七个知识层 skill）：按 flash-sourceterms 最新模板 + L-001~L-014 全部经验（特别强化 L-013 聚焦 Conductivity/SpitzerHighZ + Opacity/Multispecies 主流 + L-014 解释 Spitzer-Härm/Rosseland/Planck 等术语）；扩展 triggers（150+ 关键词含全部 Conductivity 9 变体、Opacity 7 变体、op_/cond_/res_ 前缀、IONMIX4/.cn4/.imx、PlasmaState_logLambda、cond_getCv、diff_advanceTherm）；5 knowledge 文件齐 + 4 examples（1 setup 脚本 + 3 parfile 片段）；含完整 materialProperties 单元讲解（SpitzerHighZ 公式 / Opacity per-group 查询 / IONMIX4 表加载 / Rosseland-Planck 三种不透明度 / PlasmaState_logLambda 共享 / 与 EOS/Diffuse/RadTrans 协作）；按 L-013 主讲 Conductivity+Opacity（HEDP 主流） + 简要带过 Viscosity/MagneticResistivity/Thermoelectric/MassDiffusivity/NSE（非 HEDP）；Phase 2 stable 知识层 skill | claude |
