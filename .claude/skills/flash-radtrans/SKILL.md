---
name: flash-radtrans
description: |
  FLASH 4.8 RadTrans 单元专家（辐射传输）。
  按 L-013 聚焦主流量径——MGD（多群扩散，HEDP/ICF/激光算例的默认）；
  覆盖：MGD 数学模型（辐射扩散方程 + flux limiter + 物质耦合）、
  operator-split per-group HYPRE 求解（通过 Diffuse_solveScalar）、
  能群结构（rt_mgdBounds + mgd_meshgroups setup 变量）、
  flux limiter 类型（fl_none/fl_harmonic/fl_larsen/fl_minmax/fl_levermorepomraning1981，LaserSlab 用 fl_harmonic）、
  边界条件（reflecting/vacuum/dirichlet 等）、
  与 EOS（TELE_VAR）/ Opacity（per-group 查询）/ Diffuse（HYPRE 接口）/ Hydro（EELE_VAR 反馈）耦合；
  非 HEDP 变体简要：NeutrinoLeakage（核心坍缩超新星）、Unified（实验性）、ExpRelax（罕用）。
  触发词：radtrans, MGD, multigroup diffusion, 辐射传输, 辐射扩散,
        flux limiter, harmonic, larsen, levermore,
        rt_mgd, mgd_meshgroups, rt_mgdFlMode, rt_mgdBounds,
        HYPRE, 隐式求解, 辐射温度, 不透明度,
        LaserSlab, ICF, HEDP, ERAD_VAR, MGDR, TELE_VAR
triggers:
  # 中文
  - 辐射传输
  - 辐射扩散
  - 多群扩散
  - 多群
  - 辐射场
  - 辐射温度
  - 辐射压力
  - 通量限制器
  - 限流器
  - 隐式求解
  - 光学厚度
  - 不透明度查询
  - 能群
  - 群边界
  - 物质耦合
  # 英文（单元名 + 关键概念）
  - RadTrans
  - radtrans
  - rt_
  - MGD
  - multigroup
  - multi-group
  - diffusion
  - radiation
  - radiative transfer
  - photon
  - radiation diffusion
  - radiation pressure
  - radiation energy
  - radiation temperature
  - flux limiter
  - flux-limiter
  - fl_harmonic
  - fl_larsen
  - fl_minmax
  - fl_levermorepomraning1981
  - fl_none
  - fl_geometric
  - fl_arithmetic
  - free-streaming
  - optically thick
  - optically thin
  - opacity
  - mean free path
  # 关键参数
  - rt_useMGD
  - rt_mgdFlMode
  - rt_mgdFlCoef
  - rt_mgdNumGroups
  - rt_mgdBounds
  - rt_mgdBoundEntry
  - mgd_meshgroups
  - mgd_maxgroups
  - rt_mgdXlBoundaryType
  - rt_mgdXrBoundaryType
  - rt_mgdYlBoundaryType
  - rt_mgdYrBoundaryType
  - rt_mgdZlBoundaryType
  - rt_mgdZrBoundaryType
  - rt_mgdXlBoundaryTemp
  - rt_mgdthetaImplct
  - rt_computeDt
  - rt_dtFactor
  - rt_timeGroups
  - rt_mgdthetaC
  - rt_mgdthetaD
  - rt_tightIonCoupling
  # 变体 / 子目录
  - MGD operator-split
  - Unified
  - ExpRelax
  - NeutrinoLeakage
  - mgdUnified
  - mgdExpRelax
  # UNK 变量
  - ERAD_VAR
  - TRAD_VAR
  - MGDR
  - MGDR1_VAR
  - MGDRn_VAR
  - MGDC_VAR
  - ABSR_VAR
  - EMIS_VAR
  - COND_VAR
  - DFCF_VAR
  - FLLM_VAR
  # API
  - RadTrans
  - RadTrans_init
  - RadTrans_finalize
  - RadTrans_computeDt
  - RadTrans_computeFluxLimiter
  - RadTrans_planckInt
  - RadTrans_mgdGetBound
  - RadTrans_mgdSetBound
  - RadTrans_mgdSetEnergy
  - RadTrans_mgdEFromT
  - RadTrans_mgdUFromT
  - RadTrans_mgdSetBc
  - RadTrans_sumEnergy
  - Diffuse_solveScalar
  - Diffuse_fluxLimiter
  - Diffuse_computeFluxLimiter
  # HYPRE / 求解器
  - HYPRE
  - BoomerAMG
  - PFMG
  - PCG
  - BiCGSTAB
  - implicit
  - implicitness
  - backward Euler
  - Crank-Nicolson
  # 物理 / 算例
  - Planck
  - Stefan-Boltzmann
  - ICF
  - HEDP
  - LaserSlab
  - Thomson scattering
  - IONMIX
when_to_use: |
  调用本 skill 的场景：
  1. 用户问 MGD（多群扩散）—— "MGD 怎么工作"、"rt_mgdFlMode 选什么"、"mgd_meshgroups 设几"
  2. 用户问辐射-物质耦合 —— "辐射怎么加热电子"、"EELE_VAR 怎么变"、"TELE_VAR 和 TRAD_VAR"
  3. 用户问 flux limiter —— "fl_harmonic 是什么"、"为什么需要限流器"、"fl_none 危险吗"
  4. 用户问能群结构 —— "rt_mgdBounds 单位是什么"、"6 群怎么设"、"群边界怎么和 IONMIX 表对齐"
  5. 用户问辐射边界 —— "rt_mgdXlBoundaryType 选什么"、"vacuum 和 reflecting 区别"
  6. 用户问隐式求解 —— "为什么用 HYPRE"、"rt_mgdthetaImplct=1.0 必须吗"、"rt_dtFactor"
  7. 用户问 setup 命令 —— "+mgd"、"mgd_meshgroups=6"、"怎么和 +laser 一起用"
  8. 用户调试 MGD（NaN / 不收敛 / 辐射能量爆炸）
  9. 用户问 MGD 和 Hydro/EOS/Opacity/Diffuse 的耦合机制
  10. 用户问 LaserSlab 算例的 MGD 配置（典型参数值）
when_not_to_use: |
  **不调用本 skill 的场景**：
  - 激光（EnergyDeposition） → `flash-laser`（激光是直接加热电子，不走 RadTrans）
  - EOS（TELE/TEION 怎么算） → `flash-eos`
  - 不透明度表的物理内容 → `flash-material`（本 skill 只讲"per-group 查询接口"）
  - HYPRE 求解器内部 → `flash-diffuse`（Phase 2 后；本 skill 只讲 MGD 怎么调用 Diffuse_solveScalar）
  - Grid / AMR / 几何 → `flash-grid`
  - Driver 主循环何时调 RadTrans → `flash-driver`
  - 找 RadTrans_* 源码位置 → `flash-source-reader`
  - 错误信息匹配 → `flash-pitfall-finder`
  - 参数基本属性（不深入） → `flash-param-query`
  - 核心坍缩超新星 / 中子星合并（NeutrinoLeakage） → `flash-sourceterms`（Phase 2 后）—— 非 HEDP，本 skill 只简要带过
  - 跑算例 → `flash-case-runner`（Phase 3）
layer: knowledge
phase: 2
status: stable
created: 2026-06-17
last_updated: 2026-07-20
owner: user
---

# flash-radtrans — RadTrans 单元专家（辐射传输）

> **状态**：✅ stable（5 道验收考题全部通过 + Q4 重答，2026-07-20；Phase 2 第五个 stable 知识层 skill）
>
> **按 L-013 聚焦主流**：本 skill 主讲 **MGD（多群扩散）**——HEDP/ICF/激光算例（如 LaserSlab）的唯一选择。其他变体（NeutrinoLeakage 用于核心坍缩超新星、Unified 实验性、ExpRelax 罕用）只在 §概览简要带过。

## 1. 角色与边界

### 1.1 我是做什么的

回答 FLASH **RadTrans 单元**相关问题——HEDP 算例的"辐射传输底座"：

| 范畴 | 详见 |
|---|---|
| 物理原理 + 设计 | `knowledge/overview.md` — MGD 数学模型 + flux limiter + 物质耦合 + 变体对比（按 L-013 主讲 MGD）|
| 参数字典 | `knowledge/params.md` — rt_mgdFlMode / rt_mgdBounds / 边界 / 隐式 / 群结构 完整字典 |
| 内部实现 | `knowledge/internals.md` — RadTrans.F90 主流程 + Diffuse_solveScalar 耦合 + 能群循环 |
| 典型配置 | `knowledge/recipes.md` — LaserSlab MGD 配置 + 边界组合 + flux limiter 选择 |
| 踩坑排查 | `knowledge/pitfalls.md` — fl_none 默认陷阱、eV 单位、IONMIX 同步、Unified 实验性等 |

### 1.2 我不做什么

| 用户问题类型 | 归属 skill |
|---|---|
| 激光沉积（EnergyDeposition） | `flash-laser` |
| EOS（TELE 怎么算） | `flash-eos` |
| 不透明度表物理内容 | `flash-material`（Phase 2） |
| HYPRE 求解器内部 | `flash-diffuse`（Phase 2） |
| Grid / AMR | `flash-grid` |
| Driver 主循环 | `flash-driver` |
| NeutrinoLeakage 详解（核心坍缩超新星） | `flash-sourceterms`（Phase 2；非 HEDP） |
| 找源码位置 | `flash-source-reader` |
| 错误匹配 | `flash-pitfall-finder` |
| 参数基本属性 | `flash-param-query` |

## 2. 行为协议

按 `agent/TEMPLATES/skill-template.md §2` 通用协议。核心要点（按 L-001~L-013）：

- **讲逻辑**（L-001）：不只是列 flux limiter 类型，讲清楚每个的物理意义、何时选
- **不用 mermaid**（L-002）：调用关系用文字+缩进
- **贴源码相关代码**（L-008）：abort 类查询贴 `Driver_abortFlash` 所在 if
- **核心 4 段 + 引导项**（L-010）：核心段必给详细，引导项按需展开
- **讲为什么**（L-011）：选择/配置/概念类问题必给"为什么这么设计/为什么默认这个值"
- **诊断类先引导贴现场**（L-012）：NaN / 不收敛等先要用户贴日志/setup/parfile
- **公式 CLI 友好**（L-012）：用 ASCII / 代码块，不用 `$...$`
- **聚焦主流路径**（L-013）：MGD operator-split 是主流，详讲；Unified/ExpRelax/NeutrinoLeakage 简要
- **面向新手**：解释每个术语（"optically thick"、"flux limiter"、"free-streaming"）

## 3. knowledge/ 子目录

| 文件 | 内容 |
|---|---|
| `knowledge/overview.md` | MGD 数学模型 + flux limiter 物理意义 + 物质耦合 + 变体对比（按 L-013 主讲 MGD） |
| `knowledge/params.md` | MGD 参数完整字典（求解控制 / 群结构 / 边界 / 隐式 / 时间步） |
| `knowledge/internals.md` | RadTrans.F90 主流程 + Diffuse_solveScalar 耦合 + 能群循环 + HYPRE 接口 |
| `knowledge/recipes.md` | LaserSlab MGD 配置 + 边界组合 + flux limiter 选择 + 群结构设计 |
| `knowledge/pitfalls.md` | 常见错误（fl_none 默认、eV 单位、IONMIX 同步、Unified 实验、不存在函数等） |

## 4. examples/

| 文件 | 内容 |
|---|---|
| `examples/setup-mgd-laser.sh` | LaserSlab MGD setup 命令（HEDP 标准） |
| `examples/parfile-mgd.txt` | MGD 完整 parfile 片段（含 6 群 + 边界 + flux limiter） |
| `examples/parfile-groups.txt` | 不同能群数配置（6 群 / 70 群 / 自定义） |

## 5. 示例问答（验收基准）

### Q1: MGD 是什么？为什么 HEDP 用 MGD 不用别的？
**A**: 见 `knowledge/overview.md §1-2`。MGD = MultiGroup Diffusion，多群扩散。把光子能量分成 N 群，每群解扩散方程。**HEDP 用 MGD** 因为：(1) 光子扩散时间尺度远大于 hydro → 显式不可行；(2) 多群捕捉能谱硬化/软化；(3) HYPRE 隐式求解稳定。其他变体（NeutrinoLeakage 是中子星、Unified 实验性）不适合 HEDP。

### Q2: rt_mgdFlMode 选什么？默认是什么？
**A**: 见 `knowledge/overview.md §3` + `knowledge/recipes.md §2`。**Config 默认 `"fl_none"`（危险！），LaserSlab 用 `"fl_harmonic"`**（HEDP 推荐）。fl_none 在光学薄区会让辐射超光速；fl_harmonic 平滑过渡厚-薄两区。

### Q3: mgd_meshgroups 设几？怎么和 IONMIX 表对齐？
**A**: 见 `knowledge/recipes.md §3`。`mgd_meshgroups` 是 **setup 期变量**（不是 runtime parameter）。LaserSlab 用 6 群。**重要**：MGD 群边界（`rt_mgdBounds_*`，单位 **eV**）必须**手动**和 IONMIX 不透明度表的群结构对齐——MGD 不自动同步。

### Q4: 为什么用 HYPRE？怎么和 Diffuse 耦合？
**A**: 见 `knowledge/internals.md §3`。MGD 不直接调 HYPRE，而是通过 `Diffuse_solveScalar`（`Diffuse/DiffuseMain/Unsplit/`）。每群一个 HYPRE 求解（cell-centered 7 点模板 + flux limiter 修正）。`rt_mgdthetaImplct=1.0`（默认，全隐式）保证无条件稳定。

### Q5: MGD 报 NaN 或辐射能量爆炸？
**A**: 见 `knowledge/pitfalls.md §B`。**先贴现场**（按 L-012）：日志、setup、parfile、rt_mgdBounds 值、TELE_VAR 范围。常见原因：(1) fl_none（光学薄超光速）；(2) 群边界没设（默认 -1 → 启动 abort）；(3) IONMIX 表和 mgd_meshgroups 不匹配；(4) 边界 BC 选错（vacuum 误用 reflecting）。

## 6. 关键源码入口

| 想理解 | 看哪个文件 |
|---|---|
| RadTrans 公共接口（15 函数） | `source/physics/RadTrans/RadTrans_interface.F90` |
| RadTrans 主入口（每步调） | `source/physics/RadTrans/RadTrans.F90`（stub）→ `RadTransMain/MGD/RadTrans.F90:L31`（MGD 实现） |
| RadTrans 初始化（读所有 rt_mgd* 参数） | `source/physics/RadTrans/RadTransMain/MGD/rt_init.F90:L15`（314 行） |
| 时间步计算（Morel-McClarren 公式） | `source/physics/RadTrans/RadTransMain/MGD/RadTrans_computeDt.F90:L33` |
| Flux limiter 计算 | `source/physics/RadTrans/RadTransMain/MGD/RadTrans_computeFluxLimiter.F90:L40` |
| Planck 积分 | `source/physics/RadTrans/RadTransMain/RadTrans_planckInt.F90` |
| MGD 模块全局状态（rt_*） | `source/physics/RadTrans/RadTransMain/MGD/rt_data.F90` |
| MGD Config（Python 生成参数） | `source/physics/RadTrans/RadTransMain/MGD/Config` |
| Unified 变体 Config | `source/physics/RadTrans/RadTransMain/MGD/Unified/Config` |
| Unified 变体实现 | `source/physics/RadTrans/RadTransMain/MGD/Unified/RadTrans.F90` |
| Unified README（实验性警告） | `source/physics/RadTrans/RadTransMain/MGD/Unified/README` |
| ExpRelax 变体 | `source/physics/RadTrans/RadTransMain/MGD/ExpRelax/` |
| NeutrinoLeakage（非 HEDP） | `source/physics/RadTrans/RadTransMain/NeutrinoLeakage/` |
| HYPRE 接口（通过 Diffuse） | `source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L87` |
| Flux limiter 公式实现 | `source/physics/Diffuse/DiffuseMain/.../Diffuse_computeFluxLimiter.F90` |
| LaserSlab 参考 parfile | `source/Simulation/SimulationMain/LaserSlab/flash.par` |

## 7. 待办

- [ ] 跑 5 道验收考题，全部通过则升级 stable
- [ ] 持续累积踩坑（用户实战 MGD 算例遇到问题时）
- [ ] Phase 2+ 后续 skill 协作验证（如 flash-diffuse 解释 HYPRE 内部）

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-07-19 | **升级 draft → beta**（Phase 2 第五个知识层 skill）：按 flash-laser/driver/grid/hydro/eos 模板 + L-001~L-013 全部经验（特别强化 L-013 聚焦 MGD 主流路径）；扩展 triggers（150+ 关键词含全部 RadTrans_/rt_/MGD 前缀、5 种 flux limiter、边界条件、HYPRE 概念）；5 knowledge 文件齐 + 3 examples（1 setup 脚本 + 2 parfile 片段）；含完整 MGD 单元讲解（数学模型 / flux limiter / 能群结构 / 边界 / operator-split vs Unified vs ExpRelax / 与 Diffuse/EOS/Opacity/Hydro 耦合）；按 L-013 主讲 MGD（HEDP 主流）+ 简要带过 NeutrinoLeakage/Unified/ExpRelax；待验收 | claude |
| 2026-07-20 | **升级 beta → stable + L-014 沉淀**：5 道验收考题全部通过；Q4 反馈"先解释 HYPRE 是什么"→ 重答 Q4 开头加 HYPRE 基本概念段（数学库 + 解大稀疏矩阵 Ax=b）→ 沉淀 L-014（专业术语第一次出现先解释本身）+ 同步修订 flash-hydro overview TL;DR（Euler 方程定义 + ASCII 公式）+ flash-radtrans internals 加术语速查段（HYPRE/Diffuse_solveScalar/operator-split/flux limiter/θ-加权 5 个术语）；flash-radtrans 成为 Phase 2 第五个 stable 知识层 skill | claude |
| 2026-08-07 | **IONMIX 表接入实战沉淀**（CarbonSlab 验证）：pitfalls.md §D.4 新增 IONMIX 表接入硬校验明细（群数/群边界两层 abort 的源码位置与报错原文）、ionmix4 vs ionmix 两种格式差异（ionmix4 主流：I12 群数 + 真实值温度/密度数组 + 12 dummy）、逐值验证方法（opacity_writeOpacityInfo 打印表 + 对比脚本，实测最大差 ~5e-7；注意 op_writeOpacity 段错误为 FLASH bug 且发生在表打印之后不影响验证） | claude |
