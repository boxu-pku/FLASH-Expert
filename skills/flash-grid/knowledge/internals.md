---
title: Grid 内部实现 — Grid_* API 调用图 + leaf 遍历 + AMR 调度 + guard cell 填充
skill: flash-grid
category: internals
source_anchors:
  - source/Grid/Grid_interface.F90:L1-L1259
  - source/Grid/GridMain/Grid_getBlkPtr.F90:L61
  - source/Grid/GridMain/Grid_releaseBlkPtr.F90:L32
  - source/Grid/Grid_fillGuardCells.F90:L233
  - source/Grid/GridMain/paramesh/Grid_getListOfBlocks.F90:L1
  - source/Grid/GridMain/paramesh/Grid_markRefineDerefine.F90:L44
  - source/Grid/GridMain/paramesh/Grid_updateRefinement.F90:L42
manual_ref: "FLASH 4.8 User Guide §7-8"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai-waiting
status: draft
tags:
  - grid
  - internals
  - API
  - call-graph
  - AMR
  - guardcell
---

# Grid 内部实现

> **TL;DR**：本文件讲 Grid 怎么"内部运作"：~70 个 Grid_* API 怎么分工、leaf block 怎么遍历、AMR 怎么调度、guard cells 怎么填。物理单元的代码只需要会**调用** Grid_*，但理解内部机制能帮你写出更高效、更不容易出错的代码。

---

## 1. 公共 API 总览

源码：`source/Grid/Grid_interface.F90`（1259 行）

`Grid_interface` 是一个 Fortran 模块，含 ~70 个 `interface` 块，每个对应一个 Grid_* 公共函数。所有物理单元用 `use Grid_interface, ONLY: Grid_xxx, ...` 引入。

### 1.1 API 分类

按用途分 8 类：

| 类别 | 代表函数 | 数量 |
|---|---|---|
| **生命周期** | `Grid_init`、`Grid_initDomain`、`Grid_finalize` | 3 |
| **取 block 列表** | `Grid_getListOfBlocks`、`Grid_getLocalNumBlks` | 2 |
| **取/放 block 指针** | `Grid_getBlkPtr`、`Grid_releaseBlkPtr` | 2 |
| **取 block 元信息** | `Grid_getBlkIndexLimits`、`Grid_getBlkBoundBox`、`Grid_getDeltas`、`Grid_getCellCoords`、`Grid_getBlkRefineLevel`、`Grid_getBlkType`、`Grid_getBlkBC`、`Grid_getBlkPhysicalSize`、`Grid_getBlkCornerID` | ~10 |
| **数据访问（拷出）** | `Grid_getBlkData`、`Grid_getPlaneData`、`Grid_getRowData`、`Grid_getPointData` | 4 |
| **数据访问（写入）** | `Grid_putBlkData`、`Grid_putPlaneData`、`Grid_putRowData`、`Grid_putPointData` | 4 |
| **guard cell 填充** | `Grid_fillGuardCells` | 1 |
| **AMR 调度** | `Grid_updateRefinement`、`Grid_markRefineDerefine`、`Grid_markBlkRefine`、`Grid_markBlkDerefine`、`Grid_markRefineSpecialized`、`Grid_restrictAllLevels`、`Grid_restrictByLevels` | ~7 |
| **几何 / 域** | `Grid_getGeometry`、`Grid_getDomainBoundBox`、`Grid_getGlobalIndexLimits`、`Grid_getMaxRefinement`、`Grid_getSingleCellCoords`、`Grid_getSingleCellVol`、`Grid_subcellGeometry` | ~10 |
| **求解器接口** | `Grid_solvePoisson`、`Grid_advanceImplicit`、`Grid_advanceDiffusion`、`Grid_advanceAnisoDiffusion`、`Grid_advanceMagDiffusion`、`Grid_advanceMultiDiffusion` | ~6 |
| **粒子 / BC / 其他** | `Grid_mapMeshToParticles`、`Grid_mapParticlesToMesh`、`Grid_moveParticles`、`Grid_applyBCEdge`、`Grid_bcApplyToRegion`、`Grid_conserveFluxes`、`Grid_notifySolnDataUpdate` | ~20 |

---

## 2. 取/放 block 指针（最常用）

源码：`source/Grid/GridMain/Grid_getBlkPtr.F90:L61`、`Grid_releaseBlkPtr.F90:L32`

### 2.1 标准调用

```fortran
use Grid_interface, ONLY: Grid_getBlkPtr, Grid_releaseBlkPtr
real, pointer :: solnData(:,:,:,:)

call Grid_getBlkPtr(blockID, solnData, CENTER)
! 现在可以读/写 solnData(DENS_VAR, i, j, k) 等
call Grid_releaseBlkPtr(blockID, solnData, CENTER)
```

### 2.2 gridDataStruct 取值

第 3 参数 `gridDataStruct` 决定拿哪种数据：

| 值 | 拿到的数据 | 典型用途 |
|---|---|---|
| `CENTER` | cell-centered（unk） | 密度、压力、速度、温度等 |
| `FACEX` | IAXIS 面心（facevarx） | MHD Bx |
| `FACEY` | JAXIS 面心（facevary） | MHD By |
| `FACEZ` | KAXIS 面心（facevarz） | MHD Bz |
| `WORK` | work 数据（paramesh 内部） | 罕见 |

来自 `constants.h`。

### 2.3 必须配对（重要）

`Grid_getBlkPtr` 和 `Grid_releaseBlkPtr` **必须严格配对**，否则：

- **轻**：内存延迟释放，性能下降
- **重**（`NO_PERMANENT_GUARDCELLS` 模式）：数据不一致或 abort
- **重**（同时持有两个 block 指针）：在 NO_PERMANENT_GUARDCELLS 下直接 abort

源码：`source/Grid/GridMain/Grid_getBlkPtr.F90:L19-L22`

```
! Paramesh 4 dev 的 NO_PERMANENT_GUARDCELLS 模式下，
! 你不能同时持有两个 block 的指针！
```

### 2.4 反例（避免）

```fortran
! ❌ 错误：嵌套持有两个 block 指针
do b = 1, blockCount
   call Grid_getBlkPtr(b, dataA, CENTER)
   do c = 1, blockCount
      call Grid_getBlkPtr(c, dataB, CENTER)   ! NO_PERMANENT_GUARDCELLS 下 abort
      ...
      call Grid_releaseBlkPtr(c, dataB, CENTER)
   end do
   call Grid_releaseBlkPtr(b, dataA, CENTER)
end do
```

```fortran
! ✅ 正确：用 Grid_getBlkData 把数据拷出来再操作
do b = 1, blockCount
   call Grid_getBlkPtr(b, dataA, CENTER)
   ...
   call Grid_releaseBlkPtr(b, dataA, CENTER)
end do
```

---

## 3. Leaf block 遍历（**核心模式**）

### 3.1 标准遍历模板

```fortran
use Grid_interface, ONLY: Grid_getListOfBlocks, Grid_getBlkPtr, &
                          Grid_releaseBlkPtr, Grid_getBlkIndexLimits
use physicaldata, ONLY: LEAF

integer :: blockCount, b, blockID
integer :: listOfBlocks(MAXBLOCKS)
integer, dimension(2, MDIM) :: blkLimits, blkLimitsGC
real, pointer :: solnData(:,:,:,:)

call Grid_getListOfBlocks(LEAF, listOfBlocks, blockCount)

do b = 1, blockCount
   blockID = listOfBlocks(b)

   call Grid_getBlkPtr(blockID, solnData, CENTER)
   call Grid_getBlkIndexLimits(blockID, blkLimits, blkLimitsGC, CENTER)

   ! 遍历内部 cell（不含 guard cell）
   do k = blkLimits(LOW, KAXIS), blkLimits(HIGH, KAXIS)
      do j = blkLimits(LOW, JAXIS), blkLimits(HIGH, JAXIS)
         do i = blkLimits(LOW, IAXIS), blkLimits(HIGH, IAXIS)
            ! 读 solnData(DENS_VAR, i, j, k) 等
            ! 写 solnData(ENER_VAR, i, j, k) 等
         end do
      end do
   end do

   call Grid_releaseBlkPtr(blockID, solnData, CENTER)
end do
```

源码：`source/Grid/GridMain/paramesh/Grid_getListOfBlocks.F90`、`Grid_getBlkIndexLimits.F90:L105`

### 3.2 blockType 参数

`Grid_getListOfBlocks(blockType, ...)` 第 1 参数（来自 `constants.h`）：

| 值 | 含义 | 典型用途 |
|---|---|---|
| `LEAF` | 所有叶块 | **最常用**——物理计算只对叶块做 |
| `ALL_BLKS` | 所有块（含 PARENT、ANCESTOR） | 罕见 |
| `IBDRY_BLKS` / `JBDRY_BLKS` / `KBDRY_BLKS` | 触碰域边界的块（各轴） | 边界条件 |
| `ANY_BDRY_BLKS` | 任一轴触边界的块 | 边界条件 |
| `ACTIVE_BLKS` | 活动块（本地有数据的） | MPI 通信 |
| `PARENT_BLK` | 父块 | AMR 操作 |
| `ANCESTOR` | 祖先块 | AMR 操作 |
| `REFINEMENT` | 指定细化层级的块 | 配合第 4 参数 `refinementLevel` |
| `INREGION` | 区域内的块 | 配合第 5 参数 `region_bndBox` |

### 3.3 为什么只遍历 LEAF

AMR 树里，**只有 leaf block 持有实际的解算数据**。PARENT 和 ANCESTOR 只是树节点，没有真实的物理量。所以：

- 物理计算 → 只对 LEAF 做
- AMR 操作（refine/derefine）→ 操作整棵树
- IO 输出 → 输出 LEAF 数据（restrict 后）

### 3.4 blkLimits vs blkLimitsGC

`Grid_getBlkIndexLimits` 返回两个范围：

| 返回 | 范围 | 含义 |
|---|---|---|
| `blkLimits(LOW:HIGH, MDIM)` | `i ∈ [GRID_ILO, GRID_IHI]` 等 | **内部 cell**（NXB × NYB × NZB） |
| `blkLimitsGC(LOW:HIGH, MDIM)` | `i ∈ [GRID_ILO_GC, GRID_IHI_GC]` 等 | **含 guard cell** |

**常用规则**：
- 物理计算遍历 → 用 `blkLimits`
- 模板/插值需要邻居 → 用 `blkLimitsGC`（前提是 guard cell 已填）

---

## 4. AMR 调度

### 4.1 Driver 每步调一次

源码：`source/Grid/GridMain/paramesh/Grid_updateRefinement.F90:L42`

```fortran
subroutine Grid_updateRefinement(nstep, time, gridChanged)
   ! 每 nrefs 步触发一次：
   if (mod(nstep, gr_nrefs) == 0) then
      call gr_ptFillBlkParticleInfo()       ! 1. 保留粒子 block 信息
      call amr_restrict(gr_meshMe, 1, 1)    ! 2. PARAMESH 树 restrict
      call Grid_markRefineDerefine()        ! 3. 应用用户细化准则
      call gr_updateRefinement(gridChanged) ! 4. refine/derefine + prolong + gcfill + EOS
   end if
end subroutine
```

### 4.2 markRefineDerefine 做什么

源码：`source/Grid/GridMain/paramesh/Grid_markRefineDerefine.F90:L44`

```
Grid_markRefineDerefine
├── 1. 对每个 refine_var_N（1..4）调 gr_markVarThreshold
│      ├── 算每个 cell 的误差估计（梯度 / 均值）
│      ├── err > refine_cutoff_N → 标记 refine
│      ├── err < derefine_cutoff_N → 标记 derefine
│      └── 用 refine_filter_N 滤掉小幅震荡
├── 2. refine_on_particle_count=TRUE → 检查粒子数
│      ├── 粒子数 > max_particles_per_blk → refine
│      └── 粒子数 < min_particles_per_blk → derefine
├── 3. 特殊标记（如 forceDerefInRadius、logR 衰减）
└── 4. lrefine_max 强制约束（gr_enforceMaxRefine）
```

### 4.3 误差估计公式

源码：`source/Grid/GridMain/paramesh/gr_markVarThreshold.F90`

近似（详细见 Paramesh 文档）：

```
err = |var(neighbor) - var(cell)| / max(|var(cell)|, small)
```

阈值比较：
- `err > refine_cutoff_N` → 标记 refine
- `err < derefine_cutoff_N` → 标记 derefine
- 否则保持

### 4.4 Specialized Markers

源码：`source/Grid/GridMain/paramesh/Grid_markRefineSpecialized.F90`

`Grid_markRefineSpecialized(criterion, size, specs, lref)` 允许用预定义准则标记：

| criterion | 含义 |
|---|---|
| `-radius` / `rectangle` / `ellipsoid` | 几何形状内 refine/derefine |
| `-var-threshold` | 变量阈值（更细粒度） |
| `-logradius-derefine` | 按 log 半径 derefine |

具体底层函数：`gr_markInRadius.F90`、`gr_markInRectangle.F90`、`gr_markEllipsoid.F90`、`gr_markWithRadius.F90`、`gr_markDerefineByLogRadius.F90`、`gr_markDerefineByTime.F90`、`gr_forceDerefInRadius.F90`

### 4.5 Prolong / Restrict

**Prolong**（粗 → 细）：refine 时把父块数据插值到 8 个子块（3D）
**Restrict**（细 → 粗）：derefine 时把 8 个子块数据平均到父块

源码：
- Prolong：`source/Grid/GridMain/paramesh/interpolation/prolong/`
- Restrict（树）：`source/Grid/GridMain/paramesh/paramesh4/gr_restrictTree.F90`
- Restrict（按层级）：`source/Grid/GridMain/paramesh/paramesh4/Grid_restrictByLevels.F90`

由 `gr_restrictAllMethod` 控制（默认 3 = `Grid_restrictByLevels`）。

---

## 5. Guard cell 填充

### 5.1 标准调用

源码：`source/Grid/Grid_fillGuardCells.F90:L233`（dispatch）；paramesh 实现 `source/Grid/GridMain/paramesh/paramesh4/Grid_fillGuardCells.F90`

```fortran
call Grid_fillGuardCells(CENTER, ALLDIR)
```

参数：
| 位置 | 含义 | 常用值 |
|---|---|---|
| 1 | gridDataStruct | `CENTER` / `FACEX` / `FACEY` / `FACEZ` |
| 2 | 方向 | `ALLDIR`（所有方向）/ `IAXIS` / `JAXIS` / `KAXIS` |
| 3+ | 可选关键字 | `minLayers` / `eosMode` / `doEos` / `mask` / `selectBlockType` |

### 5.2 填充流程

```
Grid_fillGuardCells(CENTER, ALLDIR)
│
├── 1. 内部 guard cell（block 之间）
│   ├── 邻居是同层级 leaf → 直接 copy
│   ├── 邻居是粗块（父级）→ prolong 插值
│   ├── 邻居是细块（子级）→ restrict 平均
│   └── MPI 远端块 → 通过 Paramesh 通信
│
├── 2. 域边界 guard cell
│   ├── 调用各面 BC（periodic / outflow / reflecting / ...）
│   └── 角点处理（按 bndPriorityOne/Two/Three）
│
└── 3. 可选 EOS 调和
    └── 如果 doEos=TRUE，对填充的 guard cell 调 EOS 让变量一致
```

### 5.3 何时必须 fillGuardCells

| 场景 | 要不要 fillGuardCells |
|---|---|
| 物理计算前（Hydro/EOS/RadTrans） | **要**（否则 guard cell 是旧值） |
| AMR refine/derefine 之后 | **要**（Grid_updateRefinement 内部已做） |
| 修改 solnData 之后 | **要**（让邻居 block 看到新值） |
| 读完 plotfile 之后 | 不要（IO 不依赖 guard cell） |
| `Grid_getBlkPtr` 之后直接读 | 不要（guard cell 是之前的值，可能能用） |

### 5.4 NO_PERMANENT_GUARDCELLS 模式（重要）

源码：`source/Grid/GridMain/paramesh/Grid_data.F90:L243-L252`

默认 Paramesh 4 dev 行为：guard cell **不永久保存**，每次需要时重新填。

含义：
- `Grid_getBlkPtr` 时 guard cell 可能是脏的（未填）
- 修改 solnData 后，guard cell 自动失效
- 同时持有两个 block 指针 → abort

**应对**：
- 每次物理计算前显式 `Grid_fillGuardCells`
- getBlkPtr/releaseBlkPtr 严格配对
- 不要嵌套持有多个指针

---

## 6. 数据访问 API（拷出 vs 指针）

### 6.1 两种模式对比

| 方式 | 优点 | 缺点 | 何时用 |
|---|---|---|---|
| **指针**（Grid_getBlkPtr） | 快（直接访问 unk 内存） | 必须 releaseBlkPtr 配对 | **优先用**——大多数物理计算 |
| **拷出**（Grid_getBlkData/PlaneData/RowData/PointData） | 安全（自己拥有拷贝） | 慢（要拷贝） | 需要同时操作多个 block、或要长期持有数据 |

### 6.2 4 个拷出函数

| 函数 | 取什么 | 形状 |
|---|---|---|
| `Grid_getBlkData` | 一个 block 的 3D 子块 | `datablock(var, i, j, k)` |
| `Grid_getPlaneData` | 一个 block 的 2D 平面 | `datablock(var, i, j)`（plane=IAXIS/JAXIS/KAXIS） |
| `Grid_getRowData` | 一个 block 的 1D 行 | `datablock(var, i)` |
| `Grid_getPointData` | 单个 cell 或派生量（CELL_VOLUME 等） | `datablock(var)` |

### 6.3 4 个写入函数

对应：`Grid_putBlkData`、`Grid_putPlaneData`、`Grid_putRowData`、`Grid_putPointData`。

### 6.4 例子

```fortran
! 取一个 block 的密度 3D 块
real :: densBlock(NUNK_VARS, GRID_ILO_GC:GRID_IHI_GC, &
                  GRID_JLO_GC:GRID_JHI_GC, GRID_KLO_GC:GRID_KHI_GC)
call Grid_getBlkData(blockID, CENTER, DENS_VAR, EXTERIOR, &
                     [1,1,1], densBlock, [NXB, NYB, NZB])

! 取一个 cell 的密度
real :: densPoint
call Grid_getPointData(blockID, CENTER, DENS_VAR, EXTERIOR, [i,j,k], densPoint)

! 写一个 cell 的密度
call Grid_putPointData(blockID, CENTER, DENS_VAR, EXTERIOR, [i,j,k], newDens)
```

---

## 7. 几何 / 坐标 API

### 7.1 取 cell 坐标

源码：`source/Grid/GridMain/paramesh/Grid_getCellCoords.F90:L119`

```fortran
real :: coords(GRID_ILO_GC:GRID_IHI_GC)
call Grid_getCellCoords(IAXIS, blockID, CENTER, .true., coords, size(coords))
! 现在 coords(i) = 第 i 个 cell 的 x 中心坐标
```

参数：
- 1：轴（`IAXIS` / `JAXIS` / `KAXIS`）
- 2：blockID
- 3：edge（`CENTER` / `LEFT_EDGE` / `RIGHT_EDGE`）
- 4：guardcell（`.true.` = 含 guard cell，`.false.` = 只内部）
- 5：返回的坐标数组
- 6：数组大小

### 7.2 取 block 元信息

```fortran
real :: boundBox(LOW:HIGH, MDIM)
call Grid_getBlkBoundBox(blockID, boundBox)   ! 物理边界框

real :: blockSize(MDIM)
call Grid_getBlkPhysicalSize(blockID, blockSize)  ! 物理尺寸

real :: del(MDIM)
call Grid_getDeltas(blockID, del)             ! (dx, dy, dz)

integer :: refineLevel
call Grid_getBlkRefineLevel(blockID, refineLevel)  ! lrefine

integer :: blkType
call Grid_getBlkType(blockID, blkType)        ! LEAF / PARENT / ANCESTOR
```

### 7.3 cell 体积（几何感知）

源码：`source/Grid/GridMain/paramesh/Grid_getSingleCellVol.F90`

```fortran
real :: cellVolume
call Grid_getSingleCellVol(blockID, EXTERIOR, [i,j,k], cellVolume)
! cylindrical 下，cellVolume = 2π * r * dr * dz / numPhiCells
! spherical 下，cellVolume = r² sin(θ) dr dθ dφ
```

**重要**：写物理量方程时（如有限体积法），用 `cellVolume` 加权，**不要**假设 cartesian 的 `dx*dy*dz`。

---

## 8. 边界条件机制

### 8.1 域边界 BC

源码：`source/Grid/GridBoundaryConditions/gr_bcApplyToAllBlks.F90`

`Grid_fillGuardCells` 内部调 `Grid_bcApplyToRegion`，按 parfile 的 `xl_/xr_/yl_/yr_/zl_/zr_boundary_type` 应用。

### 8.2 BC 类型实现

每种 BC 类型对应一个处理逻辑（在 `GridBoundaryConditions/`）：
- `periodic`：从对面 block 拷
- `outflow`：导数 = 0（零梯度）
- `reflecting`：奇偶对称（速度、磁场翻转）
- `axisymmetric`：径向轴对称（类似 reflecting 但更专用）
- `user`：用户实现的 `Grid_applyBCEdge`

### 8.3 角点冲突解决

源码：`source/Grid/GridMain/Config:L124-L130`

8 个角点同时属于 3 个面的 guard cell。当 3 个面 BC 不同时，按 `bndPriorityOne/Two/Three` 顺序优先（默认 IAXIS > JAXIS > KAXIS）。

---

## 9. 完整调用关系（文字 + 缩进）

```
Driver_evolveFlash
│
├── (初始化) Driver_initFlash
│   └── Grid_init
│       └── 读所有 grid 相关 runtime parameter 到 gr_*
│   └── Grid_initDomain
│       ├── 按 nblockx/y/z 切顶层块
│       ├── 调 Simulation_initBlock 填初值
│       └── refine 到 lrefine_min_init
│
├── (主循环每步)
│   ├── Grid_getListOfBlocks(LEAF, ...)     ★ 取叶块列表
│   │
│   ├── Grid_fillGuardCells(CENTER, ALLDIR) ★ 填 guard cell
│   │   ├── 内部：prolong / restrict / copy（邻居 block 间）
│   │   ├── 边界：Grid_bcApplyToRegion（按 xl_/xr_/... 等 BC 类型）
│   │   └── 可选 EOS 调和（doEos=TRUE 时）
│   │
│   ├── Hydro / Eos / sourceTerms（含激光） ★ 物理计算
│   │   ├── Grid_getBlkPtr
│   │   ├── Grid_getBlkIndexLimits
│   │   ├── 读/写 solnData(VAR, i, j, k)
│   │   └── Grid_releaseBlkPtr
│   │
│   ├── Grid_updateRefinement(nstep, time) ★ 每 nrefs 步重新细化
│   │   ├── amr_restrict
│   │   ├── Grid_markRefineDerefine
│   │   │   └── gr_markVarThreshold（按 refine_cutoff/derefine_cutoff）
│   │   ├── gr_updateRefinement
│   │   │   ├── amr_refine_derefine
│   │   │   ├── prolong（粗→细插值）
│   │   │   ├── Grid_fillGuardCells（重填）
│   │   │   └── EOS（让新 block 的变量一致）
│   │
│   └── IO_output（写 plotfile）
│       ├── Grid_restrictByLevels（restrict 树到统一层）
│       ├── Grid_sendOutputData
│       └── 写 HDF5 文件
│
└── (收尾) Driver_finalizeFlash
    └── Grid_finalize
```

---

## 10. NO_PERMANENT_GUARDCELLS 详解（容易踩坑）

源码：`source/Grid/GridMain/paramesh/Grid_data.F90:L243-L252`

### 10.1 模式区别

| 模式 | guard cell 持久性 | 优点 | 缺点 |
|---|---|---|---|
| 默认（PERMANENT） | guard cell 永久保存 | 简单 | 内存大 |
| **NO_PERMANENT_GUARDCELLS** | guard cell 临时填，用完丢 | 省内存 | 严格配对要求 |

### 10.2 Paramesh 4 dev 默认

`+pm4dev` 默认启用 NO_PERMANENT_GUARDCELLS（FlashAvoidOrrery=True 的副作用之一）。

### 10.3 影响的代码模式

```fortran
! ❌ 危险：修改 solnData 后立刻读 guard cell
call Grid_getBlkPtr(blockID, solnData, CENTER)
solnData(DENS_VAR, i, j, k) = new_value
val = solnData(DENS_VAR, i-1, j, k)   ! 这个 guard cell 可能是脏的！

! ✅ 正确：修改后先 fillGuardCells 再读 guard cell
call Grid_getBlkPtr(blockID, solnData, CENTER)
solnData(DENS_VAR, i, j, k) = new_value
call Grid_releaseBlkPtr(blockID, solnData, CENTER)
call Grid_fillGuardCells(CENTER, ALLDIR)
call Grid_getBlkPtr(blockID, solnData, CENTER)
val = solnData(DENS_VAR, i-1, j, k)   ! 现在是最新值
call Grid_releaseBlkPtr(blockID, solnData, CENTER)
```

---

## 11. 延伸阅读

- **参数字典**：`knowledge/params.md`
- **总览（backend、数据结构、几何）**：`knowledge/overview.md`
- **典型 setup + parfile**：`knowledge/recipes.md`
- **常见错误**：`knowledge/pitfalls.md`
- **Grid_* 函数源码定位**：`flash-source-reader` skill（含 snippets/）
- **Driver 何时调 Grid**：`flash-driver` skill

---

## 12. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft）：12 段 internals；70+ Grid_* API 分类；leaf 遍历标准模板；AMR 调度流程；guard cell 填充机制；NO_PERMANENT_GUARDCELLS 详解；完整文字调用图（不用 mermaid，按 L-002） | claude |
