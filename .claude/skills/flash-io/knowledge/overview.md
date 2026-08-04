---
title: IO 单元总览 — HDF5 parallel 主流 + 4 backend 对比 + plotfile 结构 + restart
skill: flash-io
category: overview
source_anchors:
  - source/IO/IOMain/Config:L52-L243
  - source/IO/IOMain/IO_output.F90:L114-L600
  - source/IO/IOMain/hdf5/Config:L1-L29
  - source/IO/IOMain/hdf5/parallel/PM_argonne/Config:L1-L20
  - source/IO/IOMain/hdf5/parallel/PM_argonne/io_writeData.F90:L59-L500
  - source/IO/IOMain/hdf5/hdf5_flash.h:L36-L77
  - source/Simulation/SimulationMain/LaserSlab/example.par:L14-L34
manual_ref: "FLASH 4.8 User Guide §10 (IO)"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: draft
tags:
  - io
  - hdf5
  - plotfile
  - checkpoint
  - restart
  - overview
---

# IO 单元总览（HDF5 parallel 聚焦）

> **TL;DR**：IO 单元负责 FLASH 的 **3 类输出文件**——checkpoint（双精度续跑文件）、plotfile（单精度可视化文件）、flash.dat（全局积分量）。按 L-013 聚焦主流——**HDF5 parallel IO**（LaserSlab 用 `+hdf5typeio` = PM_argonne，type-based collective IO）。其他 backend（serial HDF5 / pnetcdf / direct）简要带过。

---

## 0. 术语速查（按 L-014，先解释再讲机制）

| 术语 | 解释 |
|---|---|
| **plotfile** | **可视化文件**，单精度（4 字节 / float32）的 HDF5 文件，用 yt / Visit / fidlr 读。文件名 `*_hdf5_plt_cnt_<NNNN>`。**只写用户在 plot_var_N 列的变量**，文件较小 |
| **checkpoint** | **续跑文件**，双精度（8 字节 / float64）的 HDF5 文件。文件名 `*_hdf5_chk_<NNNN>`。**写所有 unk + facevar + scratch + 所有 runtime parameter + 标量**，文件大但可完整 restart |
| **flash.dat** | **ASCII 文本**，每 N 步写一行（`wr_integrals_freq`），记 total energy / mass / momentum 等全局积分量。用 gnuplot / xmgrace 快速看时序 |
| **HDF5** | **Hierarchical Data Format v5**——科学数据存储的标准格式（HDF Group 维护），支持元数据、分组、并行访问。`.h5` / `.hdf5` 后缀。FLASH 4.8 默认 IO 格式 |
| **parallel HDF5** | HDF5 + MPI-IO 后端，多进程**同时**写一个文件。比"主进程聚合再写"快 10-100x。需 HDF5 编译时启用 `--enable-parallel` |
| **collective IO** | HDF5 的一种 IO 模式——所有进程**一起**调 `H5Dwrite`，HDF5 库 + MPI-IO 自动调度到文件不同位置。比 independent mode（各写各的，靠 lock）快 |
| **type selection / type-based IO** | 用 MPI 派生数据类型（`MPI_Type_create_struct` 等）描述每个进程在 block 数据里的非连续分布，让 collective IO 一次写完。PM_argonne 实现的核心技术 |
| **unk** | **unknowns**，cell-centered 网格变量（密度 / 压力 / 温度 / 物质分数等）。存在 `unk(NUNK_VARS, NXB, NYB, NZB, MAXBLOCKS)` 数组 |
| **facevar** | face-centered 变量（CT 磁场的 Bx/By/Bz）。存在 `facevarx/y/z`。HEDP 算例一般不用 |
| **scratch grid var** | GRIDVAR 声明的临时网格变量（不参与物理演进，IO 写出用）。`plot_grid_var_N` 选择 |
| **guard cell** | block 边界外的"幽灵 cell"（NGUARD 个），用于邻居 block 通信。**checkpoint 默认不写 guard cell**（`chkGuardCellsOutput=FALSE`），节省空间 |
| **scalar** | 单值量（不是网格量）——如 simTime / dt / nstep / globalNumBlocks。存 HDF5 的 `/scalars` 组 |
| **runtime parameter** | parfile 配置参数（如 plotFileIntervalStep / cfl）。存 HDF5 的 `/runtime parameters` 组。checkpoint 完整保存，restart 时可恢复 |
| **NONREP / mesh replication** | "non-replicated" 变量——多组同构算例（mesh replication）下不同进程组持有不同 unk 集（如 MGD 不同 group）。需要 parallel IO 支持 |
| **rolling checkpoint** | "滚动覆盖"——只保留最近 N 个 chk 文件。`rolling_checkpoint=10` 意味着写完第 11 个时第 1 个被覆盖（按 `mod` 循环）。节省磁盘 |
| **wall clock checkpoint** | 按**墙钟时间**触发 checkpoint（秒）。`wall_clock_checkpoint=43200` = 12 小时写一个 chk。用于"队列快到期了赶紧 dump" |
| **trigger file** | **触发生成的哨兵文件**——在执行目录创建空文件触发动作：`.dump_plotfile`（出 plotfile）/ `.dump_checkpoint`（出 chk）/ `.dump_restart`（出 chk 后退出）/ `.kill`（立即退出）。集群 queue 系统常用 |
| **basenm** | 输出文件名前缀。默认 `flash_` → 文件名 `flash_hdf5_chk_0001`。LaserSlab 用 `lasslab_` → `lasslab_hdf5_chk_0001` |
| **DUMP_IOFILE_NUM** | 强制触发的特殊编号（= 9999），`.dump_plotfile` 写的文件用这个号，避免覆盖正常序列 |
| **MAXBLOCKS** | 单进程最多持有的 block 数（编译时常量，setup `-maxBlocks=`）。restart 时若 globalNumBlocks/MAXBLOCKS > 进程数会 abort |

---

## 1. IO 单元在 FLASH 算例里扮演什么角色

### 1.1 一句话定位

IO 单元 = **每 hydro 步后调一次的"输出调度器"**，根据 4 类触发条件决定要不要写文件、写什么类型：

```
Driver_evolveFlash 主循环
├── Hydro（推 fluid 方程）
├── Eos_wrapped（让 PRES/TEMP 自洽）
├── Diffuse / RadTrans / sourceTerms ...
├── Grid_updateRefinement（AMR）
└── IO_output(simTime, dt, nstep, ...)  ← 每步都调
    ├── 写 flash.dat（wr_integrals_freq 控制）
    ├── 检查 checkpoint 触发
    │   ├── nstep == io_nextCheckpointStep?              (步触发)
    │   ├── simTime >= io_nextCheckpointTime?            (simTime 触发)
    │   ├── wall_clock_checkpoint 到时间?                (墙钟触发)
    │   ├── .dump_checkpoint 文件存在?                   (触发文件)
    │   ├── .dump_restart 文件存在?                      (写完退出)
    │   └── RSS 超过 rss_limit?                          (内存触发)
    ├── 检查 plotfile 触发
    │   ├── nstep == io_nextPlotFileStep?
    │   ├── simTime >= io_nextPlotfileTime?
    │   └── .dump_plotfile 文件存在?
    ├── 检查 .kill 文件（立即退出）
    └── 返回 endRun 标志给 Driver
```

### 1.2 HEDP 视角（LaserSlab）

LaserSlab 实际用的 IO 设置（按 setup_call + example.par）：

| 设置项 | 值 | 说明 |
|---|---|---|
| backend | `+hdf5typeio` (= PM_argonne, parallel HDF5 + MPI datatype) | 主流 HEDP |
| `basenm` | `"lasslab_"` | 文件前缀 |
| `output_directory` | `"01-data/"`（或 `""` = 当前目录） | 输出位置 |
| `plotFileIntervalStep` | `100` | 每 100 步出 plotfile |
| `plotFileIntervalTime` | `0.01e-09` | 每 0.01 ns 出 plotfile（HEDP 时间尺度）|
| `checkpointFileIntervalStep` | `1000` | 每 1000 步出 checkpoint |
| `checkpointFileIntervalTime` | `1.0` | （默认值，simTime 永远达不到，实际靠 step 触发）|
| `plot_var_1..9` | `dens, depo, tele, tion, trad, ye, sumy, cham, targ` | HEDP 标准可视化变量 |

### 1.3 与其他单元的耦合

```
Driver_evolveFlash 主循环（每步）
├── Hydro / Eos / Diffuse / RadTrans / sourceTerms
├── Grid_updateRefinement（AMR 重构）
└── IO_output ★ 本 skill 主角
    ├── IO_updateScalars  ← 收集 Driver / Grid / Hydro / Eos 的标量
    ├── Grid_restrictAllLevels ← 把 leaf block 数据 restrict 到父 block（让全树自洽）
    ├── Grid_computeUserVars ← 计算 user-defined vars（如 mach 数）
    ├── IO_writeIntegralQuantities ← 写 flash.dat
    ├── IO_writeCheckpoint / IO_writePlotfile
    │   └── io_writeData (HDF5 实际写)
    │       ├── io_h5write_header
    │       ├── io_h5write_unknowns (cell data)
    │       ├── io_h5write_facevar (face data，HEDP 罕用)
    │       ├── io_h5write_scratch (scratch grid var)
    │       ├── io_h5write_tree_data (bnd_box, coord, bsize, nodetype, ...)
    │       └── io_h5write_generic_*_arr (runtime params + scalars)
    ├── IO_writeParticles（HEDP 不用）
    └── IO_writeUserArray（用户扩展钩子）
```

---

## 2. 4 类 IO backend 对比（按 L-013 主流在前）

源码：`source/IO/IOMain/Config:L7-L26`

```
DEFAULT hdf5                                   # 默认
EXCLUSIVE *
USESETUPVARS IO                                # 让 setup 变量 IO= 决定
IF IO=="direct"   DEFAULT direct/UG
ELSEIF IO=="MPIDump" DEFAULT MPIDump
ELSEIF IO=="pnetcdf" DEFAULT pnetcdf
ELSEIF IO=="MPIHybrid" DEFAULT MPIHybrid
ELSEIF IO=="hdf5"
```

| backend | 描述 | HEDP 必需？ | 详见 |
|---|---|---|---|
| **hdf5/parallel** ⭐ | HDF5 + MPI-IO（**LaserSlab 用的**） | ✓ 主流 | 本 skill 详讲 |
| hdf5/serial | HDF5 但只 master 写，其他进程 send 到 master | ✗ 慢 | 简要 |
| pnetcdf | parallel NetCDF（同构 HDF5 替代） | ✗ HEDP 不用 | 简要 |
| direct | 直接 binary 文件（UG 专用） | ✗ 罕用 | 简要 |

### 2.1 HDF5 backend 内部分支

源码：`source/IO/IOMain/hdf5/Config:L1-L29`

```
LIBRARY HDF5 [hdf5::hdf5]
DEFAULT serial                                   # 默认 serial
USESETUPVARS parallelIO, IO
IF parallelIO
   DEFAULT parallel                              # +parallelIO 时切 parallel
ENDIF
IF not fixedBlockSize                            # NoFBS UG 强制 parallel
   DEFAULT parallel
ENDIF
EXCLUSIVE serial parallel
PPDEFINE FLASH_IO_HDF5
```

**parallel 内部再分**（源码：`source/IO/IOMain/hdf5/parallel/Config`）：

```
DEFAULT PM                                       # 默认 PM (Paramesh)
IF Grid=='UG'      DEFAULT UG                    # UG 网格用 UG 实现
IF not fixedBlockSize DEFAULT NoFbs              # NoFBS UG 用 NoFbs
IF typeIO          DEFAULT PM_argonne            # +hdf5typeio → type-based
```

### 2.2 LaserSlab 选 PM_argonne（type-based parallel HDF5）

setup：`+hdf5typeio` → `typeIO=True` → 选 PM_argonne。

**PM_argonne 是什么**：

- **PM**：Paramesh（block-AMR 网格）
- **argonne**：来自 Argonne National Laboratory 的实现（A. Adelmann 等 ~2010）
- **核心技术**：MPI 派生数据类型（MPI derived datatype）描述每个进程的 block 在全局 unk 数组里的非连续分布，让 HDF5 collective IO 一次写完

**为什么 LaserSlab 用它**（按 L-011 讲为什么）：

1. **快**：避免把所有 block 数据拷贝到主进程，省一次 memcpy
2. **collective IO 友好**：MPI datatype 让 HDF5 一次 collective H5Dwrite 完成 N 个进程的写入
3. **支持 mesh replication**：多组同构算例（NONREP 变量）下不同进程组同写一份

### 2.3 PM_argonne vs PM（标准 parallel）

| 特性 | PM（标准）| PM_argonne（type-based）|
|---|---|---|
| 数据布局 | 各进程独立 H5Dwrite（hyperslab） | MPI datatype 描述 + collective H5Dwrite |
| 速度（HEDP 大算例）| 慢（争用） | 快（5-10x） |
| 内存 | 拷贝缓冲 | 直接指针 |
| PPDEFINE | `IO_HDF5_PARALLEL_PM` | `FLASH_IO_EXPERIMENTAL` |
| setup | `+parallelIO` | `+hdf5typeio` |
| NonFBS UG 支持 | 是 | 是 |
| LaserSlab 用 | 否 | **是** |

源码：`source/IO/IOMain/hdf5/parallel/PM_argonne/Config:L18`

```
PPDEFINE FLASH_IO_EXPERIMENTAL
```

### 2.4 非 HDF5 backend（按 L-013 简要）

| backend | 一句话 |
|---|---|
| **serial HDF5** | `+serialIO` 选；非 master 进程 send 到 master 写。慢，但不需要 parallel HDF5 库 |
| **pnetcdf** | parallel NetCDF；与 HDF5 平行的另一种科学数据格式；FLASH 历史早期 IO，现 HEDP 不用 |
| **direct** | 直接二进制文件（无库）；UG 网格专用；调试用 |
| **MPIDump** | 简单 MPI send/recv dump；调试用 |

---

## 3. HDF5 plotfile / checkpoint 内部结构

### 3.1 文件命名规则

源码：`source/IO/IOMain/io_getOutputName.F90:L78-L97`

```
filename = <outputDir> + <basenm> + <fileType> + <strname> + <NNNN>
```

例：

```
basenm     = "lasslab_"
outputDir  = "01-data/"        # 末尾自动加 /
fileType   = "hdf5"            # HDF5 backend
strname    = "_chk_" / "_plt_cnt_"
NNNN       = 4 位 0 填充整数（0001-9999）

→ 文件名：
  01-data/lasslab_hdf5_chk_0001     (checkpoint #1)
  01-data/lasslab_hdf5_plt_cnt_0001 (plotfile #1)
```

**forced plotfile**（`.dump_plotfile` 触发）前缀加 `forced_`：

```
01-data/lasslab_forced_hdf5_plt_cnt_0001
```

**outputSplitNum > 1**（多文件输出）加 `s<NNNN>_` 前缀：

```
01-data/lasslab_s0000_hdf5_chk_0001
01-data/lasslab_s0001_hdf5_chk_0001
...
```

### 3.2 HDF5 内部层次

源码：`source/IO/IOMain/hdf5/hdf5_flash.h` + `io_writeData.F90`

每个 FLASH HDF5 文件（chk 或 plt）的顶层 group `/` 下含：

```
/                                    # 根 group
├── (attributes / metadata)
│   ├── file_format_version          # 9（FILE_FORMAT_VERSION）
│   ├── setup_call                   # setup 命令
│   ├── flash_version                # FLASH 4.8.x
│   ├── build_date / build_dir / build_machine
│   ├── cflags / fflags
│   ├── file_creation_time           # 时间戳
│   └── geometry                     # "cartesian" / "cylindrical" / "spherical"
│
├── <cell-centered unk dataset>      # 每个 unk 一个 dataset
│   ├── dens                         # shape (NXB, NYB, NZB, globalNumBlocks)
│   ├── pres
│   ├── tele / tion / trad           # 3T 变量
│   ├── ye / sumy / cham / targ      # 物质分数
│   ├── ... (NUNK_VARS 个)
│   └── (含 extrema 属性：min / max)
│
├── <face-centered vars>             # HEDP 一般不用（CT 磁场）
│   ├── fcx1, fcy1, fcz1
│   └── ...
│
├── <scratch grid vars>              # 用户 GRIDVAR 声明的
│   └── <varname>
│
├── <tree data>                      # AMR 树元数据
│   ├── bnd_box                      # block bounding box, shape (2, MDIM, globalNumBlocks)
│   ├── coord                        # block 中心坐标
│   ├── bsize                        # block 物理尺寸
│   ├── nodetype                     # 1=leaf, 2=parent, 3=...
│   ├── lrefine                      # refinement level
│   ├── gid                          # global block ID
│   ├── which_child                  # parent 的第几个 child
│   ├── bflags                       # block flags
│   └── procnumber                   # block 在哪个进程
│
├── "runtime parameters"             # 所有 PARAMETER 名值对
│   ├── integers (name + value list)
│   ├── reals
│   ├── strings
│   └── logs
│
├── "scalars"                        # 单值标量
│   ├── integers (含 nstep, globalNumBlocks, nxb, nyb, nzb)
│   ├── reals (含 time, dt, redshift)
│   ├── strings
│   └── logs
│
└── (plotfile only)
    ├── coordinates / bounding box (作为 attribute)
    └── plot var labels list
```

### 3.3 plotfile vs checkpoint 关键差异

源码：`source/IO/IOMain/IO_writeCheckpoint.F90:L93` + `IO_writePlotfile.F90:L117`

```
io_doublePrecision = .true.   # checkpoint（双精度）
io_doublePrecision = .false.  # plotfile（单精度，省空间）
```

| 特性 | checkpoint | plotfile |
|---|---|---|
| 精度 | double (8B) | single (4B) |
| 写哪些变量 | **所有** NUNK_VARS + facevar + scratch | 仅 `plot_var_N` 列的（≤ MAX_PLOT_VARS=12） |
| 写 runtime params | 是（完整） | 是（完整） |
| 写 scalars | 是 | 是 |
| 可 restart | 是 | **否**（单精度 + 缺变量，restart 会 abort）|
| 可视化 | 不推荐（数据全但大） | 是（yt/Visit 首选）|
| 文件大小 | 大（~ NXB×NYB×NZB×NUNK×8B×Nblocks）| 小（1/2 ~ 1/10） |

### 3.4 fileFormatVersion 演进

源码：`source/IO/IOMain/hdf5/hdf5_flash.h:L9-L31`

```
4 -- extrema attributes added
5 -- redshift included
6 -- added the Module data to the attributes of "/"
7 -- made build info attributes instead of datasets
8 -- flash3 IO.  Differences handling scalars, also
     no longer has sim_params structure holding time, dt, nxb, etc
     -- These values are now stored in the scalars list
9 -- Fields that were formerly of size NDIM are now MDIM
     so that data is not lost when Flash uses Paramesh in 2.5d mode
```

当前版本 **9**。读老文件（version < 9）时 io_readData 会触发兼容路径。

---

## 4. restart 机制（checkpoint 加载）

### 4.1 restart 用法

源码：`source/IO/IOMain/IO_init.F90:L383-L399`

parfile：

```
restart              = .true.
checkpointFileNumber = 15        # 读 flash_hdf5_chk_0015
```

启动时 `IO_init` 检测到 `io_restart = .true.`，调 `IO_readCheckpoint`：

```
IO_init
├── 读 runtime parameters
├── if (io_restart) then
│   ├── io_numRealParmsPrev = io_numRealParms + io_prevParmPad   # 多分配空间
│   ├── io_numRealScalars = io_maxParms                           # 防 chk 里 scalar 多
│   └── IO_readCheckpoint
│       ├── 读 unklabels
│       ├── io_readData
│       │   ├── io_h5read_header
│       │   ├── io_h5read_lists (runtime params + scalars)
│       │   ├── io_finalizeListsRead
│       │   ├── IO_getScalar("globalNumBlocks", ...)
│       │   ├── io_checkBlockShape(gr_globalNumBlocks)          # ★ NXB/NYB/NZB 校验
│       │   ├── io_h5read_tree_data (bnd_box, coord, ...)
│       │   ├── io_h5read_unknowns (每个 unk)
│       │   ├── io_h5read_facevarx/y/z
│       │   └── io_h5read_scratch
│       ├── io_rescaleCellBoxes
│       ├── IO_readParticles
│       ├── IO_readUserArray
│       └── io_closeFile
├── IO_getPrevScalar("nstep", step)
├── IO_getPrevScalar("time", simTime)
├── IO_getPrevScalar("nextCheckpointTime", ...)
└── 计算 io_nextCheckpointStep = step + checkpointFileIntervalStep
```

### 4.2 NXB 不匹配会 abort

源码：`source/IO/IOMain/io_checkBlockShape.F90:L35-L41`

```fortran
! source/IO/IOMain/io_checkBlockShape.F90:L35-L41
call IO_getPrevScalar("nxb", fileNxb)
call IO_getPrevScalar("nyb", fileNyb)
call IO_getPrevScalar("nzb", fileNzb)

if (fileNxb .NE. NXB) call Driver_abortFlash("NXB in checkpoint does not match this executable!")
if (fileNyb .NE. NYB) call Driver_abortFlash("NYB in checkpoint does not match this executable!")
if (fileNzb .NE. NZB) call Driver_abortFlash("NZB in checkpoint does not match this executable!")
```

**含义**：restart 时 chk 文件里存的 NXB/NYB/NZB 必须和**当前可执行文件**编译时的 NXB/NYB/NZB 一致。

**怎么做到**：setup 时用**完全相同的** `-nxb=N -nyb=N -nzb=N`。LaserSlab restart 必须 `-2d -nxb=16 -nyb=16`（和原 run 一致）。

### 4.3 block 数过多会 abort

源码：`source/IO/IOMain/hdf5/parallel/PM/io_readData.F90:L205-L218`

```fortran
! source/IO/IOMain/hdf5/parallel/PM/io_readData.F90:L201-L218
alnblocks = int(gr_globalNumBlocks/io_meshNumProcs) + 1

if (alnblocks .GT. MAXBLOCKS) then
   print *, '********** ERROR in READ_DATA ************'
   print *, ' Number of blocks per processor exceeds maxblocks.'
   print *, ' Suggest you reset maxblocks to a larger number or'
   print *, ' run on a larger number of processors.'
   print *, ' globalNumBlocks, io_meshNumProcs = ', gr_globalNumBlocks, io_meshNumProcs
   call Driver_abortFlash('[io_readData] ERROR: num blocks per proc exceeds maxblocks')
end if
```

**修法**：setup 时 `-maxBlocks=2000`（或更大），或增加进程数。

### 4.4 restart 不重新输出 chk 0

源码：`source/IO/IOMain/IO_outputInitial.F90:L74-L82`

```fortran
! source/IO/IOMain/IO_outputInitial.F90:L74-L82
if(.not. io_restart) then
   call IO_writeCheckpoint()       # 非 restart 才写 chk 0
   io_justCheckpointed = .true.
else
   io_justCheckpointed = .false.   # restart 跳过，避免覆盖刚读的 chk
end if

if( io_restart) forcePlotfile = .true.   # restart 后强制出 plotfile 0
call IO_writePlotfile(forcePlotfile)
```

### 4.5 appendParRestart 自动续跑

源码：`source/IO/IOMain/Config:L243`

```
PARAMETER appendParRestart BOOLEAN FALSE
```

设 `appendParRestart = .true.` 后，每次写 checkpoint 时会**自动追加**几行到 parfile：

```
### BEGIN written by [IO_writeCheckpoint] ###
restart = .true.
checkpointFileNumber = 0007
plotFileNumber = 0003
### END written by [IO_writeCheckpoint] ###
```

下一次启动用同一个 parfile 就会自动 restart。

**为什么默认 false**：用户可能不希望 parfile 被修改（如 template 用）。

---

## 5. 触发文件机制（哨兵文件）

源码：`source/IO/IOMain/IO_output.F90:L422-L595`

每 hydro 步后 `IO_output` 检查执行目录下是否存在以下文件：

| 文件 | 动作 | 谁创建 |
|---|---|---|
| `.dump_plotfile` | 写 plotfile（编号 9999）后继续跑 | 用户 / 集群脚本 |
| `.dump_checkpoint` | 写 checkpoint（编号 9999）后继续跑 | 用户 / 集群脚本 |
| `.dump_restart` | 写 checkpoint 后**退出**（endRun=.true.） | 集群 queue 到期前 |
| `.kill` | **立即退出**（不写 checkpoint） | 用户手动 |

**典型场景**：

- SLURM / PBS queue 快到期 → 提交脚本创建 `.dump_restart`，FLASH 在下个 hydro 步检查到后写 chk 然后退出
- 用户想看出图但没到 plotFileIntervalStep → `touch .dump_plotfile`，下步立刻出
- 用户怀疑算例跑飞了 → `touch .kill`，立刻退出（**注意**：不写 chk，数据丢失）

源码（贴关键 if）：

```fortran
! source/IO/IOMain/IO_output.F90:L482-L516
if (  io_globalMe == MASTER_PE) then
   inquire(file = ".dump_restart", EXIST=dumpRestartExist)
end if

call MPI_Bcast(dumpRestartExist, 1, MPI_LOGICAL, MASTER_PE, io_globalComm, ierr)

if ( outputCheckpoint .and. dumpRestartExist ) then
   endRun = .true.                            ! ★ 告诉 Driver 退出
   call IO_writeCheckpoint()                  ! 写 chk 后退出
   call Logfile_stamp( '.dump_restart file found, exiting' , '[IO_OUTPUT]')
end if
```

---

## 6. 输出频率参数关系（按 L-011 讲为什么）

源码：`source/IO/IOMain/IO_output.F90:L224-L228`（checkpoint 触发条件）+ `L366-L368`（plotfile）

```
checkpoint 触发：
   (nstep == io_nextCheckpointStep)  .OR.
   (io_checkpointFileIntervalTime > 0 .AND. simTime >= io_nextCheckpointTime)  .OR.
   (io_checkpointFileIntervalZ < HUGE(1.) .AND. currentRedshift <= io_nextCheckpointZ)

plotfile 触发：
   (nstep == io_nextPlotFileStep)  .OR.
   (io_plotFileIntervalTime > 0 .AND. simTime >= io_nextPlotfileTime)  .OR.
   (io_plotFileIntervalZ < HUGE(1.) .AND. currentRedshift <= io_nextPlotFileZ)
```

### 6.1 为什么默认 `*IntervalStep = 0` 且 `*IntervalTime = 1.`

源码：`source/IO/IOMain/Config:L91-L107`

```
PARAMETER checkpointFileIntervalStep  INTEGER  0       # 默认步触发关
PARAMETER checkpointFileIntervalTime  REAL     1.     # 默认 simTime=1 触发
PARAMETER plotFileIntervalStep        INTEGER  0
PARAMETER plotFileIntervalTime        REAL     1.
```

**为什么默认 0 / 1.**：

- `IntervalStep = 0` 意味着 `nstep == 0 + 0 == 0` 永远 false（除非 nstep=0 但 IO_output 在 step 完后调）
- `IntervalTime = 1.` 在 HEDP 算例里 simTime 永远到不了 1.0 秒（典型 HEDP simTime ~ ns = 1e-9 s）
- **意图**：强迫用户**必须**在 parfile 显式设置（否则不出文件，避免占盘）

**HEDP 用户必设**：

```
plotFileIntervalStep      = 100
plotFileIntervalTime      = 1.0e-11           # 10 ps
checkpointFileIntervalStep = 1000
```

### 6.2 step 触发 vs time 触发优先级

两者**只要一个满足就触发**（OR 关系）。同时设是为了：

- **step 触发**：保证至少每 N 步出一个（防止 simTime 跳过 time 阈值）
- **time 触发**：保证 simTime 间隔均匀（变 dt 时步数不均匀）

### 6.3 nextCheckpointTime 推进算法

源码：`source/IO/IOMain/IO_output.F90:L245-L251`

```fortran
if ( io_checkpointFileIntervalTime > 0.e0 ) then 
   do while (simTime >= io_nextCheckpointTime)
      io_nextCheckpointTime = io_nextCheckpointTime + io_checkpointFileIntervalTime
   end do
end if
```

**关键**：`do while` 循环——如果一次 dt 跨过多个 IntervalTime，连续推进直到 `io_nextCheckpointTime > simTime`。这保证下次触发在"未来"而不是"过去"。

---

## 7. 全局积分量（flash.dat）

### 7.1 IO_writeIntegralQuantities

源码：`source/IO/IOMain/IO_writeIntegralQuantities.F90:L38-L260`

每 `wr_integrals_freq` 步（默认 1）调用，写一行到 `stats_file`（默认 `flash.dat`）：

```
# [STEP]    [TIME]         [MASS]         [XMOM]       [YMOM]       [ZMOM]      [ENER]       [KINEN]   [MAGP_EN]   ...
        0   0.00000e+00    1.23456e-03    ...         ...         ...         ...         ...       ...
       10   1.00000e-12    1.23456e-03    ...         ...         ...         ...         ...       ...
```

默认变量（`IO_writeIntegralQuantities.F90:L69-L73`）：

```fortran
#ifdef MAGP_VAR
   integer, parameter ::  nGlobalSumProp = 8     # 含磁压
#else
   integer, parameter ::  nGlobalSumProp = 7     # 不含磁压
#endif
integer, parameter ::  nGlobalSum = nGlobalSumProp + NMASS_SCALARS
```

7 个基础量：mass / x-mom / y-mom / z-mom / total energy / kinetic energy / internal energy（+ mag pressure if MAGP_VAR）。再加每个 mass scalar（如 cham / targ 质量分数积分）。

### 7.2 stats_file 命名

源码：`source/IO/IOMain/IO_init.F90:L129-L134`

```
if (basenm != "flash_" .AND. stats_file == "flash.dat") then
   stats_file = basenm(去掉末尾_) + ".dat"
end if
```

LaserSlab 的 `basenm="lasslab_"` → `stats_file="lasslab.dat"`。

---

## 8. 延伸阅读

- **IO 参数完整字典**：`knowledge/params.md`
- **IO_output 内部流程**：`knowledge/internals.md`
- **典型 parfile 配置**：`knowledge/recipes.md`
- **常见错误**：`knowledge/pitfalls.md`
- **Driver 主循环（IO_output 在哪被调）**：`flash-driver` skill
- **Grid / AMR 结构（unk / facevar / scratch）**：`flash-grid` skill
- **手册**：FLASH 4.8 User Guide §10（IO 单元章节）

---

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（draft）：9 段总览 + 术语速查（L-014，28 个术语）+ 4 backend 对比 + HDF5 plotfile 内部结构 + restart 机制 + 触发文件 + 输出频率参数关系 + flash.dat；按 L-011 重点讲"为什么默认这个值" + L-013 聚焦 HDF5 parallel PM_argonne（LaserSlab 主流）+ L-014 解释专业术语 + L-012 公式 ASCII + L-008 贴 NXB 校验 abort 代码 | claude |
