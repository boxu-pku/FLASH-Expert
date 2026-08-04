---
title: Grid 单元总览 — 角色、4 backend、block-AMR 数据结构、几何
skill: flash-grid
category: overview
source_anchors:
  - source/Grid/GridMain/Config:L16
  - source/Grid/GridMain/paramesh/Config:L9-L15
  - source/Grid/GridMain/paramesh/Grid_data.F90:L29-L173
  - source/Grid/GridMain/gr_initGeometry.F90:L121-L158
  - source/Grid/GridMain/UG/physicaldata.F90:L29-L58
  - source/Grid/GridMain/Grid_getBlkPtr.F90:L61
manual_ref: "FLASH 4.8 User Guide §7-8"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai-waiting
status: draft
tags:
  - grid
  - AMR
  - paramesh
  - block
  - geometry
  - overview
---

# Grid 单元总览

> **TL;DR**：Grid 是 FLASH 所有物理过程的"数据底座"。它把求解域切成一堆**块（block）**，每块含固定数量的**单元（cell）**；通过**自适应网格细化（AMR）**让块在物理量剧烈变化处加密；通过**几何（geometry）**支持 4 种坐标系。所有物理单元（Hydro/EOS/RadTrans/...）通过 `Grid_*` API 读写数据，不直接访问底层 `unk` 数组。

---

## 1. Grid 在 FLASH 里扮演什么角色

### 1.1 一句话定位

Grid 单元 = **数据结构 + AMR 调度 + 几何抽象** 的统一层。它对上层（Hydro/EOS/...）提供**与具体 backend 无关**的 API，对下层（paramesh/UG 库）屏蔽实现细节。

```
┌──────────────────────────────────────────┐
│  Driver / Hydro / EOS / RadTrans / ...   │  ← 物理单元
│         只调 Grid_getBlkPtr / put*        │
└────────────────┬─────────────────────────┘
                 │ Grid_* API（与 backend 无关）
┌────────────────▼─────────────────────────┐
│              Grid 单元                    │  ← 本 skill 范围
│   （Grid_interface.F90 声明 ~70 函数）    │
└────────────────┬─────────────────────────┘
                 │ dispatch by setup-time Grid var
┌────────────────▼─────────────────────────┐
│  paramesh / UG / Chombo / Samrai backend │  ← 真正的实现
└──────────────────────────────────────────┘
```

### 1.2 设计目标（为什么这么分层）

- **物理单元不关心 backend**：用户可以切换 paramesh/UG 不改任何物理代码
- **统一数据访问模式**：所有物理单元用 `solnData(VAR, i, j, k)` 索引，不需要知道 `unk` 的内存布局
- **AMR 透明**：物理循环只遍历 leaf block，AMR 的细化/粗化由 Grid 自动调度

---

## 2. 4 个 Backend

### 2.1 一览表

| Backend | setup 变量 | 路径 | 状态 | 用途 |
|---|---|---|---|---|
| **paramesh 4 dev**（默认） | `Grid=PM4DEV` 或 setup 命令 `+pm4dev` | `GridMain/paramesh/paramesh4/Paramesh4dev/` | 🟢 主力 | 大多数 AMR 算例 |
| paramesh 4.0 | `Grid=PM40` / `+pm40` | `GridMain/paramesh/paramesh4/Paramesh4.0/` | 🟢 维护 | 兼容旧算例 |
| paramesh 3 / 2 | `Grid=PM3` / `+pm3`、`Grid=PM2` / `+pm2` | `GridMain/paramesh/paramesh4/...` 或 `Paramesh2/` | 🟡 遗留 | 极少用 |
| **UG**（Uniform Grid） | `Grid=UG` / `+ug` | `GridMain/UG/` | 🟢 完整 | 无 AMR；PIC、FFT、nofbs |
| Chombo | `Grid=Chombo` / `+chombo` | `GridMain/Chombo/` | 🟡 部分 | 需要 Chombo 库；AMR 进行中 |
| Samrai | `Grid=Samrai` / `+samrai` | `GridMain/Samrai/` | ⚫ 未实现 | Config 写明 "not yet implemented!!!!!" |

### 2.2 默认选择规则

源码：`source/Grid/GridMain/Config:L16`

```
DEFAULT paramesh                       # 不指定 Grid 变量时默认 paramesh
IF Grid=='UG'      DEFAULT UG
IF Grid=='Samrai'  DEFAULT Samrai
IF Grid=='Chombo'  DEFAULT Chombo
```

然后 paramesh 内部（`source/Grid/GridMain/paramesh/Config:L11`）：

```
DEFAULT paramesh4                      # 默认 paramesh 4
IF Grid=='PM2'  DEFAULT Paramesh2      # 选 PM2 时回退到 Paramesh 2
```

paramesh4 内部（`source/Grid/GridMain/paramesh/paramesh4/Config:L16`）：

```
DEFAULT Paramesh4dev                   # 默认 paramesh 4 dev 版
IF Grid=='PM40' DEFAULT Paramesh4.0    # 选 PM40 时用 4.0 版
```

**结论**：不指定时 = `paramesh` → `paramesh4` → `Paramesh4dev`。所以**默认就是 Paramesh 4 dev**，对应 setup 快捷方式 `+pm4dev`。

### 2.3 什么时候选 UG 而不是 paramesh

| 场景 | 推荐 backend | 原因 |
|---|---|---|
| 一般 AMR 算例（激波、ICF、激光） | paramesh (pm4dev) | 自适应节省内存和算力 |
| PIC 粒子模拟 | UG | 粒子-场映射需要均匀网格 |
| FFT-based 求解（如 Pfft Poisson） | UG | FFT 要均匀网格 |
| nofbs（无场反演 MHD） | UG | 算法假设均匀网格 |
| 想做基准对比（固定网格分辨率） | UG | 排除 AMR 干扰 |
| 内存极度紧张 | UG | paramesh 的树结构有额外开销 |

### 2.4 +pm4dev 额外做什么

源码：`bin/setup_shortcuts.txt:L56-L58`

`+pm4dev` 不只设 `Grid=PM4DEV`，还设 `FlashAvoidOrrery=True`。Orrery 是 Paramesh 4 dev 的一个新框架（默认启用），关闭它让代码用老的 Paramesh 4 接口。如果你不需要 Paramesh 4 dev 新功能，`+pm4dev` 是最稳的选择。

---

## 3. Block-AMR 数据结构

### 3.1 核心概念：block

**block**（块）是 Grid 的基本单元。每个 block 含固定数量的 **cell**（单元）：

| 属性 | 来源 | 典型值 |
|---|---|---|
| `NXB` × `NYB` × `NZB`（每轴 cell 数） | setup 命令 `-nxb=8 -nyb=8 -nzb=8` | 8×8×8（3D） / 8×8（2D） |
| `NGUARD`（每边 guard cell 数） | unit Config `GUARDCELLS N`（默认 4，PPM Upwind 用 6） | 4 |
| `MAXBLOCKS`（每进程最大 block 数） | setup 命令 `-maxblocks=N` | 取决于算例，几百到几千 |

**注意**：这些都是 **setup 期编译常量**（写到 `Flash.h`），不是 runtime parameter。改它们要重新 setup+make。

### 3.2 解算数据（unk）

源码：`source/Grid/GridMain/UG/physicaldata.F90:L29-L58`（UG 模式）；paramesh 模式由 Paramesh 自己的 `physicaldata` 提供，FLASH 用 `use physicaldata, ONLY: unk, ...` 引入。

`unk` 是**所有 cell-centered 物理量**的大数组：

```fortran
! 简化布局（FIXEDBLOCKSIZE 模式）
real, pointer :: solnData(:,:,:,:,:)   ! ← Grid_getBlkPtr 返回的指针
! 实际指向 unk(UNK_VARS_BEGIN:UNK_VARS_END,   ! 变量维度
!              GRID_ILO_GC:GRID_IHI_GC,        ! x 方向（含 guard）
!              GRID_JLO_GC:GRID_JHI_GC,        ! y 方向（含 guard）
!              GRID_KLO_GC:GRID_KHI_GC,        ! z 方向（含 guard）
!              1)                             ! block 维度
```

**索引方式**：`solnData(VAR_INDEX, i, j, k)`

常见 `VAR_INDEX`（来自 `Flash.h`）：
- `DENS_VAR`：密度
- `PRES_VAR`：压力
- `TELE_VAR`：电子温度
- `VELX_VAR` / `VELY_VAR` / `VELZ_VAR`：速度
- `EINT_VAR` / `ENER_VAR`：内能 / 总能
- `EELE_VAR`：激光沉积能量（flash-laser 用）
- `MAGX_VAR` / `MAGY_VAR` / `MAGZ_VAR`：磁场（MHD）

**guard cell 索引**：
- 内部 cell：`i ∈ [GRID_ILO, GRID_IHI]`（NGUARD+1 到 NGUARD+NXB）
- guard cell：`i ∈ [GRID_ILO_GC, GRID_ILO-1]` 和 `[GRID_IHI+1, GRID_IHI_GC]`

### 3.3 面心数据（facevarx/y/z）

源码：`source/Grid/GridMain/UG/physicaldata.F90:L36-L48`

MHD 用面心磁场：

```fortran
real, pointer :: facevarx(:,:,:,:,:)   ! IAXIS 面心（比 unk 多一个面，IHI_GC+1）
real, pointer :: facevary(:,:,:,:,:)   ! JAXIS 面心
real, pointer :: facevarz(:,:,:,:,:)   ! KAXIS 面心
```

**注意**：变量名是 `facevarx` / `facevary` / `facevarz`（**没有 `s` 后缀**）。`facevarxs` 是常见拼写错误。

### 3.4 暂存数组（scratch）

源码：`source/Grid/GridMain/paramesh/Grid_data.F90:L84-L141`

5 类暂存空间：
- `scratch`：cell-centered
- `scratch_ctr`：cell-centered（另一种）
- `scratch_facevarx/y/z`：face-centered

物理单元做计算时用 `Grid_getBlkPtr(blockID, dataPtr, gridDataStruct=CENTER/FACEX/FACEY/FACEZ/WORK)` 拿对应类型的指针。

### 3.5 Grid_data 模块（全局状态）

源码：`source/Grid/GridMain/paramesh/Grid_data.F90:L29-L286`（~286 行）

模块名 `Grid_data`，含全部 `gr_*` 全局变量：

```
gr_iloGc/ihiGc/jloGc/...              # 索引范围
gr_iguard / gr_jguard / gr_kguard     # 每轴 guard cell 数
gr_globalComm/Me/NumProcs             # MPI 通信器
gr_oneBlock(MAXBLOCKS)                # 每 block 的元信息（corner ID, boundbox, 类型）
gr_geometry / gr_dirGeom(MDIM)        # 几何代码 + 每轴几何类型
gr_eosMode / gr_eosModeInit           # EOS 模式
gr_refine_var / refine_cutoff / ...   # AMR 阈值
gr_globalDomain(LOW:HIGH, MDIM)       # 物理域范围
gr_nblockX/Y/Z                        # 初始 block 切分
gr_blkCount / gr_blkList(MAXBLOCKS)   # 本地 block 列表
gr_lrefineMax / gr_lrefineMin         # AMR 层级上下限
```

**重要**：物理单元**不应该**直接 `use Grid_data` 读这些变量。应该走 `Grid_get*` API（如 `Grid_getGeometry`、`Grid_getBlkBoundBox`）。

---

## 4. 4 种几何

### 4.1 几何选项

源码：`source/Grid/GridMain/Config:L76`

```
PARAMETER STRING geometry "cartesian" [ cartesian, polar, cylindrical, spherical ]
```

| 几何 | setup 命令 | 维度 |
|---|---|---|
| cartesian（直角） | `+cartesian` 或 `-geometry=cartesian` | 1D / 2D / 3D |
| cylindrical（柱） | `+cylindrical` | 2D / 3D（**1D 不合法**） |
| spherical（球） | `+spherical` | 1D / 2D / 3D |
| polar（极） | `+polar` | 2D（**3D 不合法**） |

### 4.2 轴向映射表（**重要**）

源码：`source/Grid/GridMain/gr_initGeometry.F90:L121-L143`

每种几何下，IAXIS / JAXIS / KAXIS 对应的物理坐标：

| 几何 | IAXIS（轴 1） | JAXIS（轴 2） | KAXIS（轴 3） |
|---|---|---|---|
| cartesian | x（XYZ） | y（XYZ） | z（XYZ） |
| cylindrical | r（RAD_CYL） | z（XYZ） | φ（PHI_CYL，角向） |
| spherical | r（RAD_SPH） | θ（THETA，极角） | φ（PHI_SPH，方位角） |
| polar | r（RAD_CYL） | φ（PHI_CYL，方位角） | z（XYZ） |

**2D 含义**（`-2d`）：

| 几何 + 2D | 物理平面 | 第三维 |
|---|---|---|
| cartesian -2d | x-y | 丢 z |
| cylindrical -2d | **R-Z**（最常见） | 丢 φ |
| spherical -2d | r-θ | 丢 φ |
| polar -2d | r-φ | 丢 z |

**常见误解**：用户想算柱坐标 R-Z 平面，应该用 `cylindrical + 2d`（不是 `cylindricalRZ`，没这个选项）。

### 4.3 角度单位（重要）

源码：`source/Grid/GridMain/gr_initGeometry.F90:L222-L228, L253-L259`

**parfile 里角度用度数**（不是弧度），写到 `ymin`/`ymax`/`zmin`/`zmax`：
- spherical θ：[0, 180]（极角范围）
- φ（cylindrical / spherical / polar）：[0, 360]（方位角范围）

Grid 在 `gr_initGeometry` 内部转成弧度。

### 4.4 径向约束

源码：`source/Grid/GridMain/gr_initGeometry.F90:L172-L184`

- 径向（r）下界 **必须 ≥ 0**
- 如果 r 下界 = 0，对应面的边界条件**必须是** `REFLECTING` 或 `AXISYMMETRIC`（否则 abort）

---

## 5. 块（block）的生命周期

### 5.1 初始化

`Grid_initDomain`（`source/Grid/GridMain/paramesh/Grid_initDomain.F90`）建初始 AMR 树：

1. 按 `nblockx` × `nblocky` × `nblockz` 切顶层块（level 1）
2. 调 `Simulation_initBlock` 填每个 block 的初值
3. 标记需要细化的 block，refine 到 `lrefine_min_init`
4. 输出初始网格

### 5.2 每步演化

Driver 主循环（`Driver_evolveFlash`）每步调：

```
Grid_getListOfBlocks(LEAF, ...)         # 取 leaf 列表
Grid_fillGuardCells(CENTER, ALLDIR)     # 填 guard cell（物理计算前）
Hydro / Eos / sourceTerms ...           # 物理计算（用 solnData）
Grid_updateRefinement(nstep, time, ...) # 每 nrefs 步重新细化/粗化
```

### 5.3 块类型（来自 `constants.h`）

- **LEAF**：叶块，有实际数据，物理计算只对这些块做
- **PARENT_BLK**：父块，子块全部是 LEAF 或 ANCESTOR
- **ANCESTOR**：祖先块，至少有一个子块是 PARENT 或 ANCESTOR

**遍历原则**：物理循环只遍历 `LEAF` block。

### 5.4 Refinement 层级

- `lrefine(blockID)`：block 的细化层级（整数，1 起算）
- `lrefine_min`：算例中允许的最小层级（runtime parameter，默认 1）
- `lrefine_max`：允许的最大层级（默认 1，**需要在 parfile 调大**才有 AMR）
- 相邻 block 的层级差不超过 1（Paramesh 保证）

---

## 6. Guard cells（守护单元）

### 6.1 概念

每个 block 的 `NXB × NYB × NZB` 内部单元周围，还有一圈（或几圈）**guard cell**，用来存：
- **邻接 block 的数据**（用于有限差分跨边界）
- **边界条件**（域边界）
- **粗细网格过渡**（AMR 中父块/子块数据）

```
   ┌───────────────────────────────┐
   │  G │  G │  G │  G │  G │  G  │  G = guard cell
   │  G │────┼────┼────┼────│  G  │  ── = 内部 cell
   │  G │ I1 │ I2 │ I3 │ I4 │  G  │  I  = 内部
   │  G │ I5 │ I6 │ I7 │ I8 │  G  │
   │  G │────┼────┼────┼────│  G  │
   │  G │  G │  G │  G │  G │  G  │
   └───────────────────────────────┘
```

### 6.2 NGUARD 由谁定

源码：`bin/Flash.h.tpl:L440`、`bin/unitCfg.py:L260-L267`

`NGUARD` 是 setup 期编译常量，由各 unit 的 Config 文件 `GUARDCELLS N` 声明：

| 单元 | GUARDCELLS 值 |
|---|---|
| 默认（多数 unit） | 4 |
| Hydro/HydroMain/unsplit（PPM Upwind） | 6 |
| Hydro/HydroMain/unsplit（WENO） | 6 |

**取最大值**：如果多个 unit 都声明 GUARDCELLS，取最大值。

**不是 runtime parameter**：想改 NGUARD 要改 unit Config 文件，重新 setup+make。

### 6.3 填充时机

`Grid_fillGuardCells`（`source/Grid/Grid_fillGuardCells.F90:L233`）：

- **物理计算前**：填内部 guard（从邻居 block 拷贝或插值）
- **物理计算后**：可能要重填（如果数据被改了）
- **AMR 重细化后**：必须重填（block 结构变了）

参数：
```fortran
call Grid_fillGuardCells(CENTER, ALLDIR,     ! gridDataStruct, direction
                         eosMode=MODE_DENS_PRES, ...)
```

详细机制见 `knowledge/internals.md §5`。

---

## 7. 与其他单元的耦合

### 7.1 上游（谁调 Grid）

| 调用方 | 典型调用 |
|---|---|
| Driver | `Grid_initDomain`、`Grid_fillGuardCells`、`Grid_updateRefinement`、`Grid_finalize` |
| Hydro | `Grid_getBlkPtr` + `Grid_getBlkIndexLimits` + `Grid_releaseBlkPtr` |
| Eos | `Grid_getBlkPtr`（读 dens/ener/eos）→ 算 → `Grid_putBlkPtr` |
| RadTrans | 同 Hydro |
| sourceTerms（Laser/Burn/...） | 同 Hydro |
| Particles | `Grid_mapMeshToParticles` / `Grid_mapParticlesToMesh` |
| IO | `Grid_sendOutputData`（写 plotfile 前调） |

### 7.2 下游（Grid 调谁）

- **paramesh 库**：`amr_restrict`、`amr_refine_derefine`、`mpi_amr_communication`
- **MPI**：通过 Paramesh 的通信机制
- **Simulation_initBlock**（用户自定义初值）

### 7.3 边界

| Grid 不做 | 谁做 |
|---|---|
| 物理变量怎么演化 | Hydro/EOS/RadTrans/... |
| 时间步怎么算 | Driver_computeDt |
| 主循环何时调 Grid | Driver_evolveFlash |
| 物理参数含义 | 各物理 skill |

---

## 8. 延伸阅读

- **参数完整字典**：`knowledge/params.md`
- **Grid_* API 调用图**：`knowledge/internals.md`
- **典型 setup 配置**：`knowledge/recipes.md`
- **常见错误**：`knowledge/pitfalls.md`
- **相关 skill**：`flash-driver`（主循环何时调 Grid_*）、`flash-hydro`（怎么用 solnData，Phase 2）
- **手册章节**：FLASH 4.8 User Guide §7-8（待 opencode 转）
- **源码入口**：见 SKILL.md §6

---

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft）：8 段总览 + 4 backend 对比 + block-AMR 数据结构 + 4 种几何轴向映射 + guard cell 概念 + 与其他单元耦合 | claude |
