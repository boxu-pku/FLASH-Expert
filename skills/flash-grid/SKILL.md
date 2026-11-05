---
name: flash-grid
description: |
  FLASH 4.8 Grid 单元专家（数据结构 + AMR + 几何）。
  处理 4 个 backend（paramesh PM4dev/PM4/PM2、UG、Chombo、Samrai）选择与差异；
  block-AMR 数据结构（unk/facevarx/y/z/scratch）、guard cells 填充（Grid_fillGuardCells）、
  leaf block 遍历模式（Grid_getListOfBlocks + getBlkPtr/releaseBlkPtr）、refinement 标记与调度
  （lrefine_min/max、refine_var_N/cutoff、Grid_markRefineDerefine、Grid_updateRefinement）、
  4 种几何（cartesian/cylindrical/spherical/polar）的轴向映射、Grid_get* / Grid_put* 数据访问 API、
  block 物理坐标（Grid_getCellCoords、Grid_getBlkBoundBox、Grid_getDeltas）。
  触发词：grid, AMR, paramesh, pm4dev, UG, guard cell, refinement, leaf block, 块结构, 几何,
        cartesian, cylindrical, spherical, polar, Grid_, gr_, lrefine, nblock
triggers:
  # 中文
  - 网格
  - 自适应网格
  - 网格细化
  - 加细
  - 加粗
  - 块
  - 块结构
  - 守护单元
  - 边界单元
  - 叶块
  - 几何
  - 柱坐标
  - 球坐标
  - 极坐标
  - 直角坐标
  # 英文（单元名 + 关键概念）
  - Grid
  - Grid_
  - AMR
  - adaptive mesh
  - paramesh
  - pm4dev
  - pm40
  - pm4
  - pm3
  - pm2
  - Paramesh4dev
  - UG
  - uniform grid
  - Chombo
  - Samrai
  - guard cell
  - guardcell
  - NGUARD
  - leaf block
  - LEAF
  - PARENT_BLK
  - ANCESTOR
  - refinement
  - refine
  - derefine
  - lrefine
  - lrefine_max
  - lrefine_min
  - nrefs
  - block
  - blockID
  - blockCount
  - nblock
  - nblockx
  - nblocky
  - nblockz
  - block size
  - NXB
  - NYB
  - NZB
  - MAXBLOCKS
  # 几何
  - geometry
  - cartesian
  - cylindrical
  - spherical
  - polar
  - cylindricalRZ
  - axisymmetric
  - reflecting
  # Grid_* API（高频函数名）
  - Grid_getBlkPtr
  - Grid_releaseBlkPtr
  - Grid_fillGuardCells
  - Grid_getBlkIndexLimits
  - Grid_getListOfBlocks
  - Grid_getBlkData
  - Grid_putBlkData
  - Grid_getPointData
  - Grid_putPointData
  - Grid_getPlaneData
  - Grid_putPlaneData
  - Grid_getRowData
  - Grid_putRowData
  - Grid_getDeltas
  - Grid_getCellCoords
  - Grid_getBlkBoundBox
  - Grid_getBlkPhysicalSize
  - Grid_getBlkRefineLevel
  - Grid_getBlkType
  - Grid_getBlkBC
  - Grid_getGeometry
  - Grid_getLocalNumBlks
  - Grid_getMaxRefinement
  - Grid_getGlobalIndexLimits
  - Grid_markRefineDerefine
  - Grid_markRefineSpecialized
  - Grid_updateRefinement
  - Grid_initDomain
  - Grid_restrictByLevels
  - Grid_solvePoisson
  # 关键参数
  - xmin
  - xmax
  - ymin
  - ymax
  - zmin
  - zmax
  - xl_boundary_type
  - xr_boundary_type
  - yl_boundary_type
  - yr_boundary_type
  - zl_boundary_type
  - zr_boundary_type
  - interpolate
  - interpol_order
  - flux_correct
  - refine_var
  - refine_cutoff
  - derefine_cutoff
  - refine_filter
  - refine_on_particle_count
  # 数据结构
  - unk
  - facevarx
  - facevary
  - facevarz
  - scratch
  - gridBlock
  - physicaldata
  - Grid_data
  - gr_
  - NO_PERMANENT_GUARDCELLS
  - FIXED_BLOCKSIZE
when_to_use: |
  调用本 skill 的场景：
  1. 用户问 Grid 后端选择（"用 paramesh 还是 UG"、"+pm4dev 什么意思"）
  2. 用户问 AMR（"怎么细化"、"lrefine_max 设几"、"refine_var 怎么用"）
  3. 用户问几何（"cartesian/cylindrical/spherical/polar 怎么选"、"R-Z 怎么搞"）
  4. 用户问边界条件（"xl_boundary_type 有哪些"、"outflow 怎么写"）
  5. 用户问 Grid_* API（"Grid_getBlkPtr 怎么用"、"怎么遍历 leaf block"）
  6. 用户问 block 数据结构（"unk 是什么"、"solnData 怎么索引"）
  7. 用户问 guard cells（"Grid_fillGuardCells 何时调"、"NGUARD 是什么"）
  8. 用户问 setup 报错（"backend not found"、"geometry mismatch"）
  9. 用户问 domain decomposition（"nblockx/y/z 怎么定"、"procs 怎么分块"）
  10. 用户问 Poisson/扩散求解器接口（"Grid_solvePoisson 怎么调"）
when_not_to_use: |
  **不调用本 skill 的场景**：
  - 物理求解器内部（Hydro/EOS/RadTrans 的算法） → `flash-hydro` / `flash-eos` / `flash-radtrans`（Phase 2 后）
  - 求解器对 Grid 数据的具体运算 → 对应物理 skill（如 unsplit Hydro 怎么用 unk）
  - 主循环何时调 Grid_fillGuardCells → `flash-driver`
  - 时间步计算（Driver_computeDt）→ `flash-driver`
  - 找 Grid_* 源码位置 → `flash-source-reader`（本 skill 只讲用法和机制）
  - 错误信息匹配 → `flash-pitfall-finder`
  - 查参数含义（不深入）→ `flash-param-query`
  - 跑算例（setup/make/run）→ `flash-case-runner`（Phase 3）
  - 物理 sourceTerm（Burn/Cool/Laser）→ 对应 `flash-sourceterms` / `flash-laser`
layer: knowledge
phase: 2
status: stable
created: 2026-06-17
last_updated: 2026-07-19
owner: user
---

# flash-grid — Grid 单元专家（数据结构 + AMR + 几何）

> **状态**：✅ stable（5 道验收考题全部通过，2026-07-19；Phase 2 第二个知识层 skill）

## 1. 角色与边界

### 1.1 我是做什么的

回答 FLASH **Grid 单元**相关的所有问题——FLASH 所有物理过程的"数据底座"：

| 范畴 | 详见 |
|---|---|
| 物理原理 + 设计 | `knowledge/overview.md` — Grid 角色、4 backend 对比、block-AMR 数据结构、几何映射 |
| 参数字典 | `knowledge/params.md` — 几何 / AMR / 边界 / guardcell / refinement 完整字典 |
| 内部实现 | `knowledge/internals.md` — Grid_* API 调用图、leaf 遍历模式、refinement 调度 |
| 典型配置 | `knowledge/recipes.md` — backend 选择 setup + 几何选择 + AMR parfile |
| 踩坑排查 | `knowledge/pitfalls.md` — geometry 错、refine 不触发、guardcell 未填等 |

### 1.2 我不做什么

| 用户问题类型 | 归属 skill |
|---|---|
| Hydro 求解器算法 | `flash-hydro`（Phase 2） |
| EOS 三温耦合 | `flash-eos`（Phase 2） |
| RadTrans / MGD | `flash-radtrans`（Phase 2） |
| 激光 | `flash-laser` |
| Driver 主循环何时调 Grid_* | `flash-driver` |
| 找源码位置 | `flash-source-reader` |
| 错误匹配 | `flash-pitfall-finder` |
| 参数基本属性 | `flash-param-query` |
| 跑算例 | `flash-case-runner`（Phase 3） |

## 2. 行为协议

按 `agent/TEMPLATES/skill-template.md §2` 通用协议。核心要点（按 L-001~L-010）：

- **讲逻辑**（L-001）：不只是列 Grid_* 函数，讲清楚为什么有 4 个 backend、为什么 leaf block 是核心、为什么 guard cells 这么填
- **不用 mermaid**（L-002）：调用关系用文字+缩进
- **贴源码相关代码**（L-008）：abort 类查询贴 `Driver_abortFlash` 所在 if；AMR 机制贴关键算法段
- **核心 4 段 + 引导项**（L-010）：核心段必给详细，引导项按需展开
- **面向新手**：解释每个术语（"leaf block"、"guard cell"、"refine level"、"axisymmetric"）

## 3. knowledge/ 子目录

| 文件 | 内容 |
|---|---|
| `knowledge/overview.md` | Grid 角色 + 4 backend 对比 + block-AMR 数据结构（unk/facevarx/scratch）+ 几何映射表 |
| `knowledge/params.md` | Grid 参数完整字典（几何 / AMR / 边界 / guardcell / refinement；区分 setup 变量 vs runtime parameter） |
| `knowledge/internals.md` | Grid_* API 调用图 + leaf 遍历模式 + refinement 调度 + guard cell 填充流程 |
| `knowledge/recipes.md` | 4 backend setup 命令 + 几何选择 + AMR parfile 配置 + 边界条件组合 |
| `knowledge/pitfalls.md` | 常见错误（geometry mismatch / refine 不触发 / guardcell 未填 / getBlkPtr 不释放等） |

## 4. examples/

Grid 的"例子"是 setup 命令变体 + AMR parfile 片段：

| 文件 | 内容 |
|---|---|
| `examples/setup-pm4dev.sh` | 默认 paramesh 4 dev backend setup 命令 |
| `examples/setup-ug.sh` | Uniform Grid backend setup 命令（无 AMR） |
| `examples/parfile-amr.txt` | AMR 配置 parfile 片段（refine_var / cutoff / lrefine_max） |
| `examples/parfile-geometry.txt` | 4 种几何 + 边界条件组合片段 |

## 5. 示例问答（验收基准）

### Q1: 怎么选 backend？默认是哪个？
**A**: 见 `knowledge/recipes.md §1` + `knowledge/overview.md §2`。默认 paramesh 4 dev（`+pm4dev`），适合大多数 AMR 算例；UG（`+ug`）无 AMR 适合 PIC/FFT/均匀网格；Chombo 半成熟；Samrai 未实现。

### Q2: 怎么遍历所有 leaf block 做计算？
**A**: 见 `knowledge/internals.md §3`。标准模式：`Grid_getListOfBlocks(LEAF, list, count)` → 循环 `Grid_getBlkPtr` + `Grid_getBlkIndexLimits` → 计算 → `Grid_releaseBlkPtr`。

### Q3: 怎么让网格在密度大的地方细化？
**A**: 见 `knowledge/recipes.md §3`。parfile 设 `refine_var_1 = "dens"`、`refine_cutoff_1 = 0.8`、`derefine_cutoff_1 = 0.2`、`lrefine_max = 6`。

### Q4: 我用 cylindrical + 2d，是 R-Z 还是 R-φ？
**A**: 见 `knowledge/overview.md §4`。cylindrical + 2D = R-Z 平面（IAXIS=R，JAXIS=Z，φ 被丢掉）。如果想要 R-φ 用 polar + 2D。

### Q5: `Grid_getBlkPtr` 后忘 `Grid_releaseBlkPtr` 会怎样？
**A**: 见 `knowledge/pitfalls.md §C.2`。轻则内存延迟释放，重则在 `NO_PERMANENT_GUARDCELLS` 模式下数据不一致或 abort。必须配对。

## 6. 关键源码入口

| 想理解 | 看哪个文件 |
|---|---|
| Grid 公共接口（~70 函数声明） | `source/Grid/Grid_interface.F90` |
| 取/放 block 数据指针 | `source/Grid/GridMain/Grid_getBlkPtr.F90` + `Grid_releaseBlkPtr.F90` |
| 填充 guard cells（dispatch） | `source/Grid/Grid_fillGuardCells.F90` |
| 列 leaf blocks | `source/Grid/GridMain/paramesh/Grid_getListOfBlocks.F90` |
| 取 block 索引范围 | `source/Grid/GridMain/paramesh/Grid_getBlkIndexLimits.F90` |
| 标记 refine/derefine | `source/Grid/GridMain/paramesh/Grid_markRefineDerefine.F90` |
| 每步 refinement 调度 | `source/Grid/GridMain/paramesh/Grid_updateRefinement.F90` |
| Grid 全局状态（gr_*） | `source/Grid/GridMain/paramesh/Grid_data.F90` |
| 几何初始化（轴向映射） | `source/Grid/GridMain/gr_initGeometry.F90` |
| 域初始化（建初始树） | `source/Grid/GridMain/paramesh/Grid_initDomain.F90` |
| 边界条件应用 | `source/Grid/GridBoundaryConditions/gr_bcApplyToAllBlks.F90` |
| Backend 选择 Config | `source/Grid/GridMain/Config` |
| paramesh 专属 Config | `source/Grid/GridMain/paramesh/Config` |
| UG 专属 Config | `source/Grid/GridMain/UG/Config` |
| UG physicaldata（unk 数组） | `source/Grid/GridMain/UG/physicaldata.F90` |

## 7. 待办

- [ ] 跑 5 道验收考题，全部通过则升级 stable
- [ ] 持续累积踩坑（用户实战算例遇到 Grid 相关问题时）
- [ ] Phase 2+ 后续 skill 协作验证（如 flash-hydro 调本 skill 解释 unk 布局）

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-07-19 | **升级 draft → beta**（Phase 2 第二个知识层 skill）：按 flash-laser/driver 模板 + L-001~L-010 全部经验；扩展 triggers（100+ 关键词含全部 Grid_/gr_ 前缀、backend 名、几何名、关键参数）；5 knowledge 文件齐（overview/params/internals/recipes/pitfalls）；4 examples（2 setup 脚本 + 2 parfile 片段）；含完整 Grid 单元讲解（4 backend / 几何映射 / AMR 调度 / Grid_* API）；待验收 | claude |
| 2026-07-19 | **升级 beta → stable**：5 道验收考题全部通过（用户评分）；首轮反馈"回答要讲为什么不只是列选项"→ 沉淀 L-011 + 重答 5 题（每题加"为什么"必给段）→ 二轮通过；flash-grid 成为 Phase 2 第二个 stable 知识层 skill | claude |
