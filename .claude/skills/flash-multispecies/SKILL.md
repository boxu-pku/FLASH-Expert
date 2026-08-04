---
name: flash-multispecies
description: |
  FLASH 4.8 Multispecies 单元专家（多物质追踪 / 质量分数 / Abar-Zbar 自动计算）。
  按 L-013 聚焦主流——HEDP 多物质算例（LaserSlab 的 cham+targ 双物质、Sunliang_laser_CH 的
  cham+4 层靶 targ1/targ2/targ3 多层靶）；覆盖：
  species setup 变量自动生成机制（./setup species=cham,targ 自动创建 ms_cham*/ms_targ*/eos_*/op_* 参数）、
  质量分数 X_i 存储（SPECIES_VAR(SPECIES_BEGIN..SPECIES_END) 是 UNK 中心变量）、
  属性类型 multispecies_type（A 质量数 / Z 电荷数 / N 中子数 / E 电子数 / EB 结合能 / GAMMA / ZMin / NumElems + ZElems/AElems/Fractions 多元素）；
  8 个核心 API：getSum / getSumInv / getSumFrac / getSumSqr / getAvg / getProperty / setProperty / list；
  Helmholtz EOS 用 getSumInv(A) + getSumFrac(Z) 自动算 Abar/Zbar（mass-fraction weighted）；
  与 Opacity（per-species 不透明度表绑定）、Burn（核反应改物种）、Laser（per-species 吸收）耦合；
  Abar = 1 / Σ(X_i/A_i)，Zbar = Abar × Σ(X_i·Z_i/A_i) 公式；
  CHAM_SPEC/TARG_SPEC 物种索引常量（Flash.h 自动生成）；
  speciesMask + weights 选子集求和机制；归一化（fractions 自动 Σ 归一）。
  非 HEDP 简要：核合成（Burn 网络 NI56/CO61/MG23/FE51 等多物种演化）。
  触发词：multispecies, MultiSpecies, 物种, 多物质, 多组分, 多元素,
        质量分数, mass fraction, X_i, abundance,
        Abar, Zbar, 平均原子量, 平均电荷数, 平均离子化,
        species setup 变量, species=cham,targ, ms_maxelems, MS_MAXELEMS,
        CHAM_SPEC, TARG_SPEC, SPECIES_BEGIN, SPECIES_END, NSPECIES, NPROP_VARS,
        SPECIES_VAR, SPECIES_SETUPVAR,
        ms_chamA, ms_targA, ms_chamZ, ms_targZ, ms_<spec>A, ms_<spec>Z,
        ms_<spec>NumElems, ms_<spec>ZElems_1, ms_<spec>AElems_1, ms_<spec>Fractions_1,
        ms_<spec>ZMin, ms_<spec>BindEnergy, ms_<spec>Neutral, ms_<spec>Negative, ms_<spec>Gamma,
        eos_<spec>EosType, eos_<spec>SubType, eos_<spec>TableFile, eos_<spec>GroupName,
        op_<spec>LowTemp, op_<spec>Absorb,
        Multispecies_getSum, Multispecies_getSumInv, Multispecies_getSumFrac,
        Multispecies_getSumSqr, Multispecies_getAvg, Multispecies_getProperty,
        Multispecies_setProperty, Multispecies_list, Multispecies_init, Multispecies_finalize,
        Multispecies_getPropertyVector, Multispecies_getIntegerProperty, Multispecies_getStringProperty,
        ms_Array, multispecies_type, ms_mapMSIndex,
        Simulation_initSpecies, Simulation_mapIntToStr, MAPBLOCK_UNK,
        A, Z, N, E, EB, GAMMA, MS_ZMIN, MS_OPLOWTEMP, MS_NUMELEMS, MS_ZELEMS, MS_AELEMS, MS_FRACTIONS,
        MS_EOSTYPE, MS_EOSSUBTYPE, MS_EOSZFREEFILE, MS_EOSENERFILE, MS_EOSPRESFILE, MS_EOSGROUPNAME,
        UNDEFINED_REAL, UNDEFINED_INT, MS_UNDEFINED_STRING, ms_tinyNumber,
        mass scalar, volume fraction, Ye, electron fraction, sumy,
        多元素物种, multi-element species, fraction normalization,
        核合成, nucleosynthesis, NI56_SPEC, CO61_SPEC
triggers:
  # 中文
  - 物种
  - 多物质
  - 多组分
  - 多元素
  - 质量分数
  - 平均原子量
  - 平均电荷数
  - 平均离子化
  - 物种定义
  - 物质追踪
  - 物质分数
  - 物质演化
  - 物种列表
  - 核合成
  - 多层靶
  - 双物质
  # 英文 - 单元名
  - Multispecies
  - multispecies
  - MultiSpecies
  - MULTISPECIES
  # 英文 - 概念
  - species
  - mass fraction
  - massFraction
  - mass_scalar
  - abundance
  - Abar
  - Zbar
  - abar
  - zbar
  - average atomic mass
  - average atomic number
  - electron fraction
  - Ye
  - sumy
  - nucleosynthesis
  - multi-element
  - multiElement
  # 英文 - setup 变量
  - species=
  - "species=cham"
  - "species=targ"
  - ms_maxelems
  - MS_MAXELEMS
  - SPECIES_SETUPVAR
  - FLASH_MULTISPECIES
  - ManualSpeciesDirectives
  # 英文 - 物种索引常量（Flash.h 生成）
  - CHAM_SPEC
  - TARG_SPEC
  - SPECIES_BEGIN
  - SPECIES_END
  - NSPECIES
  - NPROP_VARS
  - SPECIES_VAR
  - "_SPEC"
  # 英文 - 属性参数前缀
  - "ms_cham"
  - "ms_targ"
  - "ms_"
  - "ms_<"
  - ms_chamA
  - ms_targA
  - ms_chamZ
  - ms_targZ
  - ms_chamZMin
  - ms_targZMin
  - ms_chamGamma
  - ms_chamBindEnergy
  - ms_chamNeutral
  - ms_chamNegative
  - ms_chamNumElems
  - ms_chamZElems
  - ms_chamAElems
  - ms_chamFractions
  - ms_targNumElems
  - ms_targZElems
  - ms_targAElems
  - ms_targFractions
  # 英文 - EOS 表绑定参数
  - "eos_cham"
  - "eos_targ"
  - "eos_<"
  - eos_chamEosType
  - eos_targEosType
  - eos_chamSubType
  - eos_targSubType
  - eos_chamTableFile
  - eos_targTableFile
  - eos_chamGroupName
  - eos_chamSesDblFmt
  # 英文 - Opacity 表绑定
  - "op_cham"
  - "op_targ"
  - "op_<"
  - op_chamLowTemp
  - op_targLowTemp
  - op_chamAbsorb
  - op_chamEmiss
  - op_chamTrans
  - op_chamFileType
  - op_chamFileName
  # 英文 - API 函数
  - Multispecies_getSum
  - Multispecies_getSumInv
  - Multispecies_getSumFrac
  - Multispecies_getSumSqr
  - Multispecies_getAvg
  - Multispecies_getProperty
  - Multispecies_getIntegerProperty
  - Multispecies_getStringProperty
  - Multispecies_getRealArrProperty
  - Multispecies_getIntArrProperty
  - Multispecies_getPropertyVector
  - Multispecies_setProperty
  - Multispecies_setIntegerProperty
  - Multispecies_setStringProperty
  - Multispecies_setRealArrProperty
  - Multispecies_setIntArrProperty
  - Multispecies_list
  - Multispecies_init
  - Multispecies_finalize
  - Multispecies_unitTest
  - ms_mapMSIndex
  - ms_Array
  - multispecies_type
  - Multispecies_interface
  - Multispecies_data
  # 英文 - 属性宏（Multispecies.h）
  - "#define A"
  - "#define Z"
  - "#define N"
  - "#define E"
  - "#define EB"
  - "#define GAMMA"
  - "#define MS_ZMIN"
  - "#define MS_OPLOWTEMP"
  - "#define MS_NUMELEMS"
  - "#define MS_ZELEMS"
  - "#define MS_AELEMS"
  - "#define MS_FRACTIONS"
  - "#define MS_EOSTYPE"
  - "#define MS_EOSSUBTYPE"
  - "#define MS_EOSZFREEFILE"
  - "#define MS_EOSENERFILE"
  - "#define MS_EOSPRESFILE"
  - "#define MS_EOSGROUPNAME"
  - "#define MS_EOSSESDBLFMT"
  - UNDEFINED_REAL
  - UNDEFINED_INT
  - MS_UNDEFINED_STRING
  # 英文 - 关键文件 / hook
  - Simulation_initSpecies
  - Simulation_mapIntToStr
  - MAPBLOCK_UNK
  - "Multispecies.h"
  # 英文 - HEDP 算例
  - LaserSlab
  - Sunliang_laser_CH
when_to_use: |
  调用本 skill 的场景：
  1. 用户问"怎么加多种物质"（"我想加一层 CHBr 怎么写"、"cham+targ 是什么意思"）
  2. 用户问 species setup 变量（"species=cham,targ1,targ2 怎么自动建参数"、"为什么 ./setup 后多了 ms_chamA 等"）
  3. 用户问质量分数怎么存（"X_i 在哪个变量"、"SPECIES_VAR 是什么"、"怎么初始化 cham 区域"）
  4. 用户问 Abar/Zbar（"Helmholtz 怎么自动算 Abar"、"abundance-weighted 平均怎么算"、"Abar 公式"）
  5. 用户问 ms_<spec>* 参数（"ms_chamA 是什么"、"ms_targZMin 默认多少"、"ms_chamNumElems 什么时候用"）
  6. 用户问多元素物质（"怎么定义 H₂O 这种多元素物质"、"ZElems/AElems/Fractions 怎么填"）
  7. 用户问 EOS 表绑定（"eos_chamEosType 怎么设"、"eos_targTableFile 指向哪个文件"、"eos_<spec>GroupName 是什么"）
  8. 用户问 Opacity 表绑定（"op_chamFileName 怎么填"、"op_<spec>LowTemp 作用"）
  9. 用户问 API（"Multispecies_getSumInv 怎么用"、"speciesMask 怎么填"、"weights 数组什么意思"）
  10. 用户问核合成场景（"Burn 网络怎么改物种"、"NI56_SPEC 怎么用"）—— 简要回答，按 L-013 非 HEDP
  11. 用户调试 Multispecies（"ms_chamA 没生效"、"Abar 是 0"、"speciesMask wrong size"）
  12. 用户问物种和 EOS/Opacity/Laser 怎么耦合（"EOS 怎么知道用哪种物质"、"激光吸收怎么按物种分"）
when_not_to_use: |
  **不调用本 skill 的场景**：
  - EOS Abar/Zbar 计算机制 / EOS 模式系统 → `flash-eos`（本 skill 只讲 Abar/Zbar 公式来自 Multispecies 哪段）
  - per-species 不透明度表 / 电导率表 / 表格式（.cn4/.imx/.ses）→ `flash-material`（本 skill 只讲 op_<spec> 参数绑定关系）
  - 激光沉积 / EnergyDeposition → `flash-laser`（本 skill 只讲 per-species 吸收的物种侧）
  - 核反应网络本身（Burn 物理机制）→ 未来 burn skill；本 skill 只讲 Burn 怎么调 Multispecies 改物种
  - Driver 主循环 / Driver_initFlash 调用顺序 → `flash-driver`
  - Grid / AMR / UNK 变量机制 → `flash-grid`
  - IO 输出（plotfile 里 SPECIES_VAR） → `flash-io`
  - 找 Multispecies_* 源码位置 → `flash-source-reader`
  - 错误信息匹配 → `flash-pitfall-finder`
  - 参数基本属性 → `flash-param-query`
  - 跑算例 → `flash-case-runner`（Phase 3）
layer: knowledge
phase: 2
status: stable
created: 2026-06-17
last_updated: 2026-08-02
owner: user
---

# flash-multispecies — Multispecies 多物质追踪专家

> **状态**：✅ beta（Phase 2 第十一个知识层 skill，知识层 11/11 收尾，待验收）
>
> **按 L-013 聚焦主流**：本 skill 主讲 **HEDP 多物质算例**——LaserSlab 双物质（cham 真空腔气体 + targ 靶）、
> Sunliang_laser_CH 多层靶（cham + targ1/targ2/targ3 不同密度的 CH/CHBr 层）。核合成场景（Burn 网络多物种
> 演化）简要带过。

## 1. 角色与边界

### 1.1 我是做什么的

回答 FLASH **Multispecies 单元**相关问题——多物质追踪机制：

| 范畴 | 详见 |
|---|---|
| 物理原理 + 设计 | `knowledge/overview.md` — Multispecies 角色 + species setup 机制 + 质量分数存储 + Abar/Zbar 自动计算 + 术语速查（L-014）|
| 参数字典 | `knowledge/params.md` — ms_<spec>* / eos_<spec>* / op_<spec>* 完整字典 + setup 变量 species / ms_maxelems |
| 内部实现 | `knowledge/internals.md` — 8 个 API + multispecies_type + ms_mapMSIndex + 与 EOS/Opacity/Burn 耦合 |
| 典型配置 | `knowledge/recipes.md` — LaserSlab 双物质 + Sunliang_laser_CH 多层靶 + 多元素物质 + parfile |
| 踩坑排查 | `knowledge/pitfalls.md` — ms_<spec>A 没生效、Abar=0、speciesMask wrong size、归一化陷阱 |

### 1.2 我不做什么

| 用户问题类型 | 归属 skill |
|---|---|
| EOS Abar/Zbar 计算机制 / EOS 模式 | `flash-eos` |
| 不透明度 / 电导率 / 表格式 | `flash-material` |
| 激光沉积（EnergyDeposition） | `flash-laser` |
| 核反应物理（Burn 网络本身） | 未来 burn skill |
| Driver 主循环 / 调用顺序 | `flash-driver` |
| Grid / AMR / UNK 机制 | `flash-grid` |
| IO / plotfile | `flash-io` |
| 找源码位置 | `flash-source-reader` |
| 错误匹配 | `flash-pitfall-finder` |
| 参数基本属性 | `flash-param-query` |

## 2. 行为协议

按 `agent/TEMPLATES/skill-template.md §2` 通用协议。核心要点（按 L-001~L-014）：

- **讲逻辑**（L-001）：不只是列 ms_<spec>* 参数，讲清楚每个参数的物理含义、何时填、为什么默认这个值
- **不用 mermaid**（L-002）：调用关系用文字+缩进
- **贴源码相关代码**（L-008）：abort 类查询贴 `Driver_abortFlash` 所在 if；setProperty 不识别属性时贴那段
- **核心 4 段 + 引导项**（L-010）：核心段必给详细，引导项按需展开
- **讲为什么**（L-011）：每个参数/选择都给"为什么默认这个值"
- **诊断类先引导贴现场**（L-012）：Abar=0 / speciesMask wrong size 先要用户贴日志/setup/parfile
- **公式 CLI 友好**（L-012）：Abar 公式用 ASCII 代码块，不用 `$...$`
- **聚焦主流路径**（L-013）：HEDP 多物质详讲；核合成多物种演化简要
- **专业术语先解释**（L-014）：Abar/Zbar/质量分数/species/物种等先定义再讲机制
- **面向新手**：解释每个术语（"species"、"mass fraction"、"Abar"）

## 3. knowledge/ 子目录

| 文件 | 内容 |
|---|---|
| `knowledge/overview.md` | Multispecies 角色 + species setup 机制 + 质量分数存储 + Abar/Zbar 自动计算 + 与 EOS/Opacity/Burn/Laser 耦合 + 术语速查（L-014）|
| `knowledge/params.md` | 参数完整字典（主控 / ms_<spec>* / eos_<spec>* / op_<spec>* / setup 变量）|
| `knowledge/internals.md` | 8 个 API + multispecies_type 结构 + ms_mapMSIndex + Config 自动生成机制 + 与 EOS Helmholtz 耦合 |
| `knowledge/recipes.md` | LaserSlab 双物质配置 + Sunliang_laser_CH 多层靶 + 多元素物质 + parfile + setup 命令 |
| `knowledge/pitfalls.md` | 常见错误（ms_<spec>A 没生效、Abar=0、speciesMask wrong size、归一化陷阱、CHAM_SPEC 未定义等）|

## 4. examples/

| 文件 | 内容 |
|---|---|
| `examples/setup-species-basics.sh` | LaserSlab 双物质 + Sunliang_laser_CH 多层靶 setup 命令 |
| `examples/parfile-multispecies.txt` | 物种相关 parfile 完整片段（ms_*/eos_*/op_*）|
| `examples/README.md` | 使用说明 + 物种配置工作流 |

## 5. 示例问答（验收基准）

### Q1: Multispecies 是什么？为什么 HEDP 算例需要它？
**A**: 见 `knowledge/overview.md §1-2`。**Multispecies = 多物质追踪单元**，跟踪流体里每种物质的质量分数 X_i（0~1，所有 species 之和应为 1）。**HEDP 需要**因为 LaserSlab 同时有 chamber 气体（He）和 target 靶（Al），两者 EOS 表 / 不透明度表完全不同。Multispecies 让每个 cell 知道"我在这里是 He 多还是 Al 多"，从而按 X_i 加权查询 EOS 和 Opacity。

### Q2: `species=cham,targ` setup 变量做了什么？
**A**: 见 `knowledge/overview.md §3` + `knowledge/params.md §2`。setup 看到 `species=cham,targ` 后，**Multispecies/Config 的 Python 段自动生成**：编译宏 `FLASH_MULTISPECIES` + `NSPECIES=2`；Flash.h 里 `CHAM_SPEC`、`TARG_SPEC` 索引常量；UNK 中心变量 `SPECIES_VAR(SPECIES_BEGIN..SPECIES_END)` 存质量分数；以及完整参数族 `ms_chamA/Z/ZMin/NumElems/...`、`ms_targA/Z/...`、`eos_chamEosType/SubType/TableFile/...`、`op_chamLowTemp/...`。**用户在 parfile 填这些参数即可，不用写 Simulation_initSpecies**（虽然 hook 仍提供）。

### Q3: Abar/Zbar 怎么自动算？公式是什么？
**A**: 见 `knowledge/internals.md §4` + `knowledge/overview.md §5`。Helmholtz/Tabulated EOS 用 **mass-fraction weighted**（质量分数加权）算 Abar/Zbar：

```
Abar = 1 / Σ_i( X_i / A_i )          ! Multispecies_getSumInv(A, ...) 返回这个倒数和
Zbar = Abar × Σ_i( X_i × Z_i / A_i ) ! Multispecies_getSumFrac(Z, ...) 返回这个加权和
```

`X_i = mass fraction of species i`，`A_i = species i 的质量数（A in Multispecies.h）`，`Z_i = species i 的电荷数（Z in Multispecies.h）`。LaserSlab cham(He A=4.002 Z=2) + targ(Al A=26.98 Z=13) 混合区域自动得到过渡的 Abar/Zbar。

### Q4: 怎么定义多元素物质（如 H₂O 或 CH 塑料）？
**A**: 见 `knowledge/recipes.md §4` + `knowledge/params.md §3.5`。用 **NumElems + ZElems/AElems/Fractions** 三件套。CH 塑料：`ms_chNumElems=2`、`ms_chZElems_1=6 ms_chAElems_1=12 ms_chFractions_1=0.857`（C 占比）、`ms_chZElems_2=1 ms_chAElems_2=1 ms_chFractions_2=0.143`（H 占比）。Multispecies_init 自动归一化 fractions，并按 dot_product 重算 A 和 Z（如果用户没显式填 A/Z）。

### Q5: Abar 算出来是 0 / NaN，怎么排查？
**A**: 见 `knowledge/pitfalls.md §B`。**先贴现场**（按 L-012）：日志、parfile 的 ms_*/eos_* 段、setup_call。常见原因：(1) parfile 没填 `ms_<spec>A`（默认 -999.，触发 getSumInv divide by ZERO abort）；(2) `species=` setup 变量没传（`SPECIES_SETUPVAR` 未定义，参数族不会自动生成）；(3) `eos_<spec>EosType/eos_<spec>TableFile` 不匹配（EOS 跑 Gamma 但物种指向表）；(4) Simulation_initBlock 没设质量分数（默认 0 → ΣX=0）。

## 6. 关键源码入口

| 想理解 | 看哪个文件 |
|---|---|
| Multispecies 顶层 Config（仅 DEFAULT） | `source/Multispecies/Config:L1` |
| **MultispeciesMain/Config**（**自动生成机制核心**） | `source/Multispecies/MultispeciesMain/Config:L1-L42`（Python genLines） |
| **属性宏定义**（A/Z/N/E/EB/GAMMA/MS_*） | `source/Multispecies/Multispecies.h:L22-L51` |
| **数据结构 multispecies_type** | `source/Multispecies/MultispeciesMain/Multispecies_data.F90:L32-L58` |
| **初始化主流程**（参数族读取 + 归一化 + Simulation_initSpecies hook） | `source/Multispecies/MultispeciesMain/Multispecies_init.F90:L33-L200` |
| getSum 加权和 | `source/Multispecies/MultispeciesMain/Multispecies_getSum.F90` |
| **getSumInv**（Abar 倒数和，Helmholtz 用） | `source/Multispecies/MultispeciesMain/Multispecies_getSumInv.F90:L87-L159` |
| **getSumFrac**（Zbar 加权和，Helmholtz 用） | `source/Multispecies/MultispeciesMain/Multispecies_getSumFrac.F90` |
| getSumSqr | `source/Multispecies/MultispeciesMain/Multispecies_getSumSqr.F90:L88-L154` |
| getAvg 平均值 | `source/Multispecies/MultispeciesMain/Multispecies_getAvg.F90:L98-L182` |
| getProperty / setProperty / getIntegerProperty / getStringProperty / getRealArrProperty | `source/Multispecies/MultispeciesMain/Multispecies_getProperty.F90:L45-L309`、`Multispecies_setProperty.F90:L44-L200` |
| ms_mapMSIndex（name → msindex） | `source/Multispecies/MultispeciesMain/ms_mapMSIndex.F90:L29-L40` |
| list（写日志） | `source/Multispecies/MultispeciesMain/Multispecies_list.F90:L23-L144` |
| 公共接口 | `source/Multispecies/Multispecies_interface.F90:L6-L136` |
| 单元测试 | `source/Multispecies/MultispeciesMain/unitTest/Multispecies_unitTest.F90` |
| **Helmholtz 用 Multispecies 算 Abar/Zbar** | `source/physics/Eos/EosMain/Helmholtz/SpeciesBased/eos_helmholtz.F90:L326-L337` |
| multiTemp Multigamma 同样机制 | `source/physics/Eos/EosMain/multiTemp/Multigamma/eos_mgamma.F90:L402-L413` |
| Opacity 用 Multispecies（per-species 多元素） | `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/op_setSpeciesElementsData.F90:L101-L185` |
| LaserSlab Simulation_initBlock（**质量分数初始化范式**） | `source/Simulation/SimulationMain/LaserSlab/Simulation_initBlock.F90:L100-L153` |
| LaserSlab example.par（物种参数） | `source/Simulation/SimulationMain/LaserSlab/example.par:L221-L237` |
| Sunliang_laser_CH 多层靶 example_xubo.par | `source/Simulation/SimulationMain/Sunliang_laser_CH/example_xubo.par:L248-L277` |
| 单元 finalize | `source/Multispecies/Multispecies_finalize.F90` |

## 7. 待办

- [ ] 跑 5 道验收考题，全部通过则升级 stable
- [ ] 持续累积踩坑（用户实战 HEDP 多物质算例遇到问题时）
- [ ] Phase 2 收尾后，确认 flash-material / flash-eos 跨 skill 协作链路完整

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-07-31 | **升级 draft → beta**（Phase 2 第十一个知识层 skill，知识层 11/11 收尾）：按 flash-sourceterms/eos 等模板 + L-001~L-014 全部经验（特别 L-013 聚焦 HEDP 多物质 LaserSlab/Sunliang_laser_CH + L-014 解释 Abar/Zbar/质量分数/species 等术语）；扩展 triggers（200+ 关键词含 species setup 变量、ms_/eos_/op_ 前缀全族、8 个 API 函数、Multispecies.h 全部属性宏、CHAM_SPEC/TARG_SPEC/SPECIES_BEGIN 等 Flash.h 常量、Helmholtz/multiTemp/Opacity 耦合点、核合成 NI56_SPEC 等）；5 knowledge 文件齐 + 3 examples（setup 脚本 + parfile 片段 + README）；含完整 Multispecies 单元讲解（species setup 自动生成 / 质量分数 UNK 存储 / Abar-Zbar 公式 / multispecies_type / 8 API / speciesMask+weights 选子集 / 多元素物质 NumElems+ZElems/AElems/Fractions / 与 EOS Helmholtz 耦合 / 与 Opacity per-species 绑定 / Burn 改物种简要 / 核合成场景简要）；按 L-013 主讲 HEDP 多物质（LaserSlab/Sunliang_laser_CH 是主流）+ 简要带过核合成多物种（Burn 网络本身）；不重复 flash-eos 的 EOS 模式 / flash-material 的表格式（加互补声明）；待验收 | claude |
