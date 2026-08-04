---
name: flash-eos
description: |
  FLASH 4.8 Eos 单元专家（状态方程）。
  处理 6 个互斥变体（Gamma / Multigamma / Helmholtz / Tabulated / multiTemp / multiFluid）；
  Helmholtz 3 子变体（SpeciesBased / Ye / ExternalAbarZbar）；
  multiTemp 5 子变体（Gamma / Multigamma / Helmholtz / MatRad3 / Multitype）；
  EOS 模式系统（MODE_DENS_IE/PRES/TEMP + 3T _EQUI/_GATHER/_SCATTER/_RECAL_GATHER/_SELE_GATHER 等）；
  Helmholtz 表（helm_table.dat 7.7MB，211×71 网格）+ ionmix/sesame/OPACPLOT 表读取；
  3T 三温耦合（TEION/TELE/TERAD + EION/EELE/ERAD + Heatexchange 单元）；
  Eos_wrapped 内部流程（getData → Eos → putData，含 eos_mapLookup 间接映射）；
  12 个 Eos_* 公共 API；与 Hydro/Grid/sourceTerms/RadTrans 的耦合时机。
  触发词：eos, EOS, equation of state, 状态方程,
        Helmholtz, helm_table, Timmes, electron degeneracy,
        ionmix, sesame, OPACPLOT, table EOS,
        multiTemp, 3T, three temperature, TEION, TELE, TERAD,
        Multitype, MatRad3, Gamma, ideal gas,
        MODE_DENS_IE, MODE_DENS_PRES, MODE_DENS_TEMP, dens_ie, dens_pres, dens_temp,
        Heatexchange, electron-ion coupling, equilibration,
        eosMode, eosModeInit, eintSwitch, gamma, gammaEle, gammaRad, gammaIon,
        abar, zbar, Ye, sumY, mass fractions, Multispecies,
        PRES_VAR, EINT_VAR, TEMP_VAR, DENS_VAR, GAMC_VAR, GAME_VAR,
        Coulomb correction, Newton-Raphson
triggers:
  # 中文
  - 状态方程
  - 物态方程
  - 三温
  - 电子温度
  - 离子温度
  - 辐射温度
  - 物质温度
  - 简并
  - 电子简并
  - 费米气体
  - 库仑修正
  - 电离
  - 阿巴
  - 中子分数
  - 平衡
  - 热交换
  - 耦合
  - 比热比
  - 绝热指数
  # 英文（单元名 + 关键概念）
  - Eos
  - EOS
  - eos
  - equation of state
  - state equation
  - Hydrogen
  - Helmholtz
  - helmholtz
  - helm_table
  - helmholtzTable
  - Timmes
  - electron degeneracy
  - degenerate
  - Fermi gas
  - Gamma
  - ideal gas
  - Multigamma
  - Multitype
  - MatRad3
  - multiTemp
  - multiFluid
  - Tabulated
  - ionmix
  - .imx
  - sesame
  - OPACPLOT
  - PROPACE
  - Hdf5TableRead
  - EosNuclear
  - nuclear EOS
  # EOS 模式
  - eosMode
  - eosModeInit
  - MODE_DENS_IE
  - MODE_DENS_PRES
  - MODE_DENS_TEMP
  - MODE_DENS_EI
  - dens_ie
  - dens_pres
  - dens_temp
  - dens_ie_recal_gather
  - dens_equi
  - dens_gather
  - dens_scatter
  - MODE_EOS_NOP
  - MODE_EOS_WRAPPERONLY
  - MODE_DENS_TEMP_EQUI
  - MODE_DENS_EI_RECAL_GATHER
  - MODE_DENS_EI_GATHER
  - MODE_DENS_EI_SCATTER
  - MODE_DENS_EI_SELE_GATHER
  - MODE_DENS_EI_MAT_EQUI
  # 3T 变量
  - 3T
  - 3t
  - three temperature
  - multiTemp
  - TEION
  - TELE
  - TERAD
  - TEION_VAR
  - TELE_VAR
  - TERAD_VAR
  - EION_VAR
  - EELE_VAR
  - ERAD_VAR
  - PION_VAR
  - PELE_VAR
  - PRAD_VAR
  - EOS_TEMPION
  - EOS_TEMPELE
  - EOS_TEMPRAD
  - EOS_EINTION
  - EOS_EINTELE
  - EOS_EINTRAD
  # 关键参数
  - eintSwitch
  - gamma
  - gammaIon
  - gammaEle
  - gammaRad
  - eos_tolerance
  - eos_maxNewton
  - eos_forceConstantInput
  - eos_coulombMult
  - eos_coulombAbort
  - eos_combinedTempRule
  - eos_smallEion
  - eos_smallEele
  - eos_smallErad
  - smalle
  - smallt
  - smallx
  - smlrho
  - eos_singleSpeciesA
  - eos_singleSpeciesZ
  - eos_largeT
  - eos_maxFactorUp
  - eos_maxFactorDown
  - eos_useLogTables
  - eos_tabUseGeoSpace
  - eos_logLevel
  # 物理量
  - abar
  - zbar
  - sumY
  - Ye
  - YE_VAR
  - SUMY_VAR
  - mass fractions
  - Abar
  - Zbar
  - Coulomb
  - Coulomb correction
  # UNK 变量
  - PRES_VAR
  - EINT_VAR
  - TEMP_VAR
  - DENS_VAR
  - ENER_VAR
  - GAMC_VAR
  - GAME_VAR
  - ENTR_VAR
  - CV_VAR
  # API
  - Eos_wrapped
  - Eos_arrayWrapped
  - Eos_getData
  - Eos_putData
  - Eos_getTempData
  - Eos_getAbarZbar
  - Eos_getParameters
  - Eos_guardCells
  - Eos_init
  - Eos_finalize
  - Eos_logDiagnostics
  - Eos_unitTest
  - eos_helmholtz
  - eos_helm
  - eos_idealGamma
  - eos_mgamma
  - eos_tabulated
  - eos_nuclear
  - eos_initHelmholtz
  # 耦合
  - Heatexchange
  - HeatexchangeMain
  - Constant
  - ConstCoulomb
  - Spitzer
  - LeeMore
  - Immediate
  - useHeatexchange
  # 表文件
  - helm_table.dat
  - helm_table.bdat
  - h-100grp-lte.imx
  - be-100grp-lte.imx
  - n-100grp-lte.imx
when_to_use: |
  调用本 skill 的场景：
  1. 用户问 EOS 变体选择（"用 Gamma 还是 Helmholtz"、"什么时候用 Tabulated"）
  2. 用户问 3T（"三温是什么"、"+3t 怎么用"、"TEION/TELE/TERAD"）
  3. 用户问 EOS 模式（"dens_ie 和 dens_pres 区别"、"eosMode 怎么设"）
  4. 用户问 Helmholtz 表（"helm_table.dat 在哪"、"电子简并"）
  5. 用户问 ionmix 表（"怎么加 .imx 文件"、"Tabulated EOS"）
  6. 用户问 abar/zbar/Ye（"怎么算 Abar"、"Multispecies 关系"）
  7. 用户问三温耦合（"电子-离子怎么平衡"、"Heatexchange"）
  8. 用户问 EOS 在何处被调用（"Hydro 后为什么调 Eos"、"guard cell 后调"）
  9. 用户调试 EOS 相关 abort（"Newton 不收敛"、"out of table"、"压力变负"）
  10. 用户问 3T Multitype（"混合 EOS 怎么工作"、"为什么默认 +3t 用 recal_gather"）
when_not_to_use: |
  **不调用本 skill 的场景**：
  - Hydro 求解器内部 → `flash-hydro`
  - Grid / AMR → `flash-grid`
  - Driver 主循环何时调 Eos → `flash-driver`
  - 激光 / Burn / Cool 等 sourceTerm → 对应 skill
  - Heatexchange 单元内部（虽然和 EOS 紧密耦合） → 暂归 `flash-sourceterms`（Phase 2 后）
  - 不透明度 / 电导率 → `flash-material`（Phase 2）
  - 找 EOS 源码位置 → `flash-source-reader`
  - 错误信息匹配 → `flash-pitfall-finder`
  - 参数基本属性（不深入） → `flash-param-query`
  - 跑算例 → `flash-case-runner`（Phase 3）
layer: knowledge
phase: 2
status: stable
created: 2026-06-17
last_updated: 2026-07-19
owner: user
---

# flash-eos — Eos 单元专家（状态方程）

> **状态**：✅ stable（5 道验收考题全部通过 + 1 道追加测试题通过，2026-07-19；Phase 2 第四个 stable 知识层 skill）

## 1. 角色与边界

### 1.1 我是做什么的

回答 FLASH **Eos 单元**相关的所有问题——所有物理过程的"热力学底座"：

| 范畴 | 详见 |
|---|---|
| 物理原理 + 设计 | `knowledge/overview.md` — Eos 角色、6 变体对比、3T 设计动机、Helmholtz vs Tabulated |
| 参数字典 | `knowledge/params.md` — eosMode / 截断 / gamma / Newton 容差 / 表相关完整字典 |
| 内部实现 | `knowledge/internals.md` — 12 公共 API + Eos_wrapped 流程 + eos_mapLookup 机制 + EOS 模式枚举 |
| 典型配置 | `knowledge/recipes.md` — 6 变体 setup + EOS 模式选择 + 3T 配置 + 表加载 |
| 踩坑排查 | `knowledge/pitfalls.md` — Newton 不收敛、out of table、Helmholtz 修改输入、3T 不自洽等 |

### 1.2 我不做什么

| 用户问题类型 | 归属 skill |
|---|---|
| Hydro 求解器 | `flash-hydro` |
| Grid / AMR | `flash-grid` |
| Driver 主循环 | `flash-driver` |
| Heatexchange 单元内部 | `flash-sourceterms`（Phase 2 后） |
| 不透明度 / 电导率 | `flash-material`（Phase 2） |
| 激光 / Burn / Cool | 对应 sourceTerm skill |
| 找源码位置 | `flash-source-reader` |
| 错误匹配 | `flash-pitfall-finder` |
| 参数基本属性 | `flash-param-query` |

## 2. 行为协议

按 `agent/TEMPLATES/skill-template.md §2` 通用协议。核心要点（按 L-001~L-012）：

- **讲逻辑**（L-001）：不只是列 EOS 模式，讲清楚每种模式为何存在、何时用
- **不用 mermaid**（L-002）：调用关系用文字+缩进
- **贴源码相关代码**（L-008）：abort 类查询贴 `Driver_abortFlash` 所在 if
- **核心 4 段 + 引导项**（L-010）：核心段必给详细，引导项按需展开
- **讲为什么**（L-011）：选择/配置/概念类问题必给"为什么这么设计/为什么默认这个值"
- **诊断类先引导贴现场**（L-012）：NaN / 不收敛等先要用户贴日志/setup/parfile
- **公式 CLI 友好**（L-012）：用 ASCII / 代码块，不用 `$...$`
- **面向新手**：解释每个术语（"degenerate Fermi gas"、"Coulomb correction"、"3T equilibration"）

## 3. knowledge/ 子目录

| 文件 | 内容 |
|---|---|
| `knowledge/overview.md` | Eos 角色 + 6 变体对比 + EOS 模式系统 + 3T 设计 + Helmholtz vs Tabulated |
| `knowledge/params.md` | Eos 参数完整字典（主控 / 模式 / 截断 / Newton / Coulomb / 表 / 3T） |
| `knowledge/internals.md` | 12 公共 API + Eos_wrapped 流程 + eos_mapLookup + 表加载机制 |
| `knowledge/recipes.md` | 6 变体 setup + EOS 模式选择 + 3T 配置 + ionmix 表加载 |
| `knowledge/pitfalls.md` | 常见错误（Newton 不收敛、out of table、Helmholtz 修改输入、3T 不自洽） |

## 4. examples/

| 文件 | 内容 |
|---|---|
| `examples/setup-gamma.sh` | Gamma EOS setup（快速测试、教学） |
| `examples/setup-helmholtz.sh` | Helmholtz EOS setup（HEDP/ICF/激光默认） |
| `examples/setup-multitype-3t.sh` | 3T Multitype setup（激光 + 三温） |
| `examples/parfile-eos.txt` | EOS 参数 parfile 片段（eosMode/截断/gamma） |

## 5. 示例问答（验收基准）

### Q1: 6 个 EOS 变体怎么选？默认是哪个？
**A**: 见 `knowledge/overview.md §2`。默认 **Gamma**（理想气体，教学/快速测试）。激光/ICF/HEDP 推荐 **Helmholtz**（含电子简并）；多物质复杂算例用 **Multitype**（混合 EOS）；ionmix/sesame 表用 **Tabulated**。

### Q2: dens_ie / dens_pres / dens_temp 怎么选？
**A**: 见 `knowledge/overview.md §4`。**dens_ie（默认）**：Hydro 后（能量是守恒变量）。**dens_temp**：初始化（指定 ρ,T）。**dens_pres**：Riemann 后（已知压力）。Helmholtz 在 dens_ie/dens_pres 是**迭代**（Newton），dens_temp 是直接。

### Q3: 什么是 3T？为什么要分电子/离子/辐射温度？
**A**: 见 `knowledge/overview.md §5`。3T = TEION/TELE/TERAD 分开演化。**原因**：HEDP 中电子（激光直接加热，fs）、离子（电子碰撞加热，ps）、辐射（韧致辐射，ns）时间尺度差 3+ 数量级。假设平衡会**误算电子压力/不透明度/激波结构**。

### Q4: Helmholtz 表是什么？怎么工作？
**A**: 见 `knowledge/overview.md §6` + `knowledge/internals.md §4`。`helm_table.dat`（7.7 MB，211×71 网格，ρ∈[10⁻¹⁰, 10¹¹] g/cm³，T∈[10⁴, 10¹¹] K）存**电子自由能 + 8 阶导数**。PE0 读 ASCII → 写 bdat 缓存 → 21 次 MPI_BCAST 广播。Helmholtz = 表（电子）+ 解析（离子理想气体）+ 解析（黑体辐射）+ Coulomb 修正。

### Q5: 算例报"Helmholtz Newton not converge"或"out of table"？
**A**: 见 `knowledge/pitfalls.md`。**先贴现场**（按 L-012）：日志关键段、setup 命令、parfile EOS 段、smalle/smlrho 值。常见原因：(1) dens_ie 模式初始 T 猜测差；(2) 密度/温度超表范围；(3) Coulomb 修正导致负压；(4) eintSwitch 关了导致能量消去误差。

## 6. 关键源码入口

| 想理解 | 看哪个文件 |
|---|---|
| Eos 公共接口（12 函数） | `source/physics/Eos/Eos_interface.F90` |
| Eos 主调度（按 eos_type 分发） | `source/physics/Eos/EosMain/Eos.F90:L237` |
| Eos_wrapped（block 级包装） | `source/physics/Eos/EosMain/Eos_wrapped.F90:L91` |
| Eos_getData（block → eosData） | `source/physics/Eos/EosMain/Eos_getData.F90:L102` |
| Eos_putData（eosData → block） | `source/physics/Eos/EosMain/Eos_putData.F90:L96` |
| Eos_init（1T） | `source/physics/Eos/EosMain/Eos_init.F90:L43` |
| Eos_init（3T） | `source/physics/Eos/EosMain/multiTemp/Eos_init.F90:L67` |
| EOS_* 索引常量（1T） | `source/physics/Eos/Eos.h:L106-L111` |
| EOS_* 索引常量（3T） | `source/physics/Eos/EosMain/multiTemp/Eos.h:L68-L94` |
| MODE_DENS_* 模式常量 | `source/Simulation/constants.h:L297-L341` |
| eos_mapLookup（角色 → UNK 索引） | `source/physics/Eos/EosMain/Eos_data.F90:L91` |
| EOSMAP_* 角色常量 | `source/physics/Eos/EosMain/Eos_map.h:L39-L106` |
| Helmholtz 驱动（SpeciesBased） | `source/physics/Eos/EosMain/Helmholtz/SpeciesBased/eos_helmholtz.F90` |
| Helmholtz 底层（Timmes helmeos） | `source/physics/Eos/EosMain/Helmholtz/eos_helm.F90` |
| Helmholtz 表加载 | `source/physics/Eos/EosMain/Helmholtz/SpeciesBased/eos_initHelmholtz.F90` |
| Helmholtz 表数据 | `source/physics/Eos/EosMain/Helmholtz/helm_table.dat`（7.7 MB） |
| Helmholtz 表状态 | `source/physics/Eos/EosMain/Helmholtz/eos_helmData.F90` |
| Gamma 实现 | `source/physics/Eos/EosMain/Gamma/eos_idealGamma.F90` |
| Tabulated 调度 | `source/physics/Eos/EosMain/Tabulated/eos_tabulated.F90` |
| ionmix v4 表读取 | `source/physics/Eos/EosMain/Tabulated/eos_tabIonmix4.F90` |
| sesame 表读取 | `source/physics/Eos/EosMain/Tabulated/eos_tabReadSesameTables.F90` |
| 3T Multitype 调度 | `source/physics/Eos/EosMain/multiTemp/Multitype/Eos.F90` |
| 3T Eos_wrapped | `source/physics/Eos/EosMain/multiTemp/Eos_wrapped.F90` |
| 变体选择 Config | `source/physics/Eos/EosMain/Config` |
| Helmholtz Config | `source/physics/Eos/EosMain/Helmholtz/Config` |
| multiTemp Config | `source/physics/Eos/EosMain/multiTemp/Config` |
| 主控 eosMode/smalle（在 Grid！） | `source/Grid/GridMain/Config:L155-L185` |
| Heatexchange 单元 | `source/physics/sourceTerms/Heatexchange/` |

## 7. 待办

- [ ] 跑 5 道验收考题，全部通过则升级 stable
- [ ] 持续累积踩坑（用户实战算例遇到 EOS 相关问题时）
- [ ] Phase 2+ 后续 skill 协作验证（如 flash-sourceterms 解释 Heatexchange 内部）

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-07-19 | **升级 draft → beta**（Phase 2 第四个知识层 skill）：按 flash-laser/driver/grid/hydro 模板 + L-001~L-012 全部经验（特别强化 L-011 讲"为什么" + L-012 公式 CLI 友好 + 诊断引导）；扩展 triggers（200+ 关键词含全部 Eos_/eos_/EOS_* 前缀、6 变体 + 子变体、所有 MODE_DENS_* 模式、3T 变量、Heatexchange、表文件）；5 knowledge 文件齐 + 4 examples（3 setup 脚本 + 1 parfile 片段）；含完整 Eos 单元讲解（6 变体 / EOS 模式系统 / 3T 设计 / Helmholtz 表机制 / eos_mapLookup / 12 公共 API / 与 Hydro/Grid/sourceTerms 耦合时机）；待验收 | claude |
| 2026-07-19 | **升级 beta → stable + L-013 沉淀**：5 道验收考题全部通过 + 1 道追加测试题（EOS 表格式 + 获取）；追加题首轮反馈"全面铺开未聚焦主流 + 格式细节不准（cn4 错说成 HDF5）+ 缺实用工作流（FEOS）"→ 重答聚焦主流（IONMIX4 + SESAME 两种）+ 验证实际文件 + 加 FEOS 工作流 → 沉淀 L-013（聚焦用户实际场景，主流路径优先）+ 扫描已有 3 个 recipes.md（结论：已符合 L-013，不需要修订）；flash-eos 成为 Phase 2 第四个 stable 知识层 skill | claude |
