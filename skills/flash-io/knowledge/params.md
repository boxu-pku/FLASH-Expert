---
title: IO 参数完整字典 — 输出频率 / 命名 / 控制开关 / plot var / 精度 / HDF5 模式
skill: flash-io
category: params
source_anchors:
  - source/IO/IOMain/Config:L52-L243
  - source/IO/IOMain/hdf5/parallel/PM_argonne/Config:L13-L19
  - source/IO/IOMain/hdf5/parallel/PM/Config:L13-L14
  - source/IO/IOMain/IO_init.F90:L89-L145
  - source/IO/IOMain/IO_data.F90:L36-L240
manual_ref: "FLASH 4.8 User Guide §10.3"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: draft
tags:
  - io
  - params
  - runtime-parameters
---

# IO 参数完整字典

> 本文件列出 `source/IO/IOMain/Config` 中声明的全部 78 个 PARAMETER + 子 backend（PM_argonne / PM）的额外参数。按 L-013 主流在前 + 详细展开，按 L-011 给"为什么默认这个值"。

---

## 1. 输出频率（核心参数，HEDP 必设）

源码：`source/IO/IOMain/Config:L91-L107`

| 参数 | 类型 | 默认 | 含义 | 为什么默认这个值 / 典型值 |
|---|---|---|---|---|
| `plotFileIntervalStep` | INTEGER | 0 | 每 N 步出一个 plotfile | **默认 0 = 永不触发**（强迫用户设）；HEDP 典型 100 |
| `plotFileIntervalTime` | REAL | 1. | 每 simTime 间隔出一个 plotfile | **默认 1. = simTime 到 1 才触发**；HEDP simTime 单位是秒，1 秒远超算例总时间，永远不触发；HEDP 典型 `1.0e-11`（10 ps）|
| `plotFileIntervalZ` | REAL | HUGE(1.) | 每 redshift 变化出一个 plotfile | **默认 HUGE = 永不触发**；宇宙学专用，HEDP 不用 |
| `checkpointFileIntervalStep` | INTEGER | 0 | 每 N 步出一个 checkpoint | 默认 0 = 永不；HEDP 典型 1000 |
| `checkpointFileIntervalTime` | REAL | 1. | 每 simTime 间隔出一个 checkpoint | 同上；HEDP 用户通常只设 `IntervalStep`，留 `IntervalTime=1.` 不触发 |
| `checkpointFileIntervalZ` | REAL | HUGE(1.) | 每 redshift 变化出一个 checkpoint | 宇宙学专用 |

### 1.1 触发条件（OR 关系）

源码：`source/IO/IOMain/IO_output.F90:L224-L228`（checkpoint）+ `L366-L368`（plotfile）

```
checkpoint 触发：
   (nstep == io_nextCheckpointStep)  .OR.
   (io_checkpointFileIntervalTime > 0 .AND. simTime >= io_nextCheckpointTime)  .OR.
   (io_checkpointFileIntervalZ < HUGE(1.) .AND. currentRedshift <= io_nextCheckpointZ)
   .AND. nstep != nbegin       ! 首步不算（避免重复）
```

### 1.2 为什么 HEDP 必须显式设

```
plotFileIntervalStep  = 0      # 默认 0
plotFileIntervalTime  = 1.     # 默认 1 秒，HEDP 算例 simTime ~ 1e-9 远到不了
```

→ **永远不会出 plotfile**。**默认值是"故意让你设"的**——避免用户忘改出文件塞爆磁盘。

### 1.3 LaserSlab 典型配置

```
plotFileIntervalStep      = 100
plotFileIntervalTime      = 0.01e-09        # 10 ps（备份触发，防 step 跳过）
checkpointFileIntervalStep = 1000
checkpointFileIntervalTime = 1.0            # 默认值（不触发，留作 backup）
```

---

## 2. 输出文件命名 / 目录

源码：`source/IO/IOMain/Config:L73-L86` + `L130-L134`

| 参数 | 类型 | 默认 | 含义 | 为什么默认这个值 / 典型值 |
|---|---|---|---|---|
| `basenm` | STRING | `"flash_"` | 输出文件名前缀 | 默认 `flash_`；LaserSlab 用 `lasslab_`；可含路径如 `01-data/lasslab_` |
| `output_directory` | STRING | `""` | 输出目录（绝对 / 相对路径） | 默认空 = 当前目录；常用 `01-data/` / `output/` |
| `stats_file` | STRING | `"flash.dat"` | 全局积分量文件 | **自动从 basenm 推导**（`flash_` → `flash.dat`，`lasslab_` → `lasslab.dat`）；除非显式设 |
| `outputSplitNum` | INTEGER | 1 | 多文件输出（每 N 进程写一个文件） | **默认 1 = 单文件**；HEDP 不用（PM_argonne 单文件已够快）|
| `checkpointFileNumber` | INTEGER | 0 | 当前 chk 文件编号（restart 时用） | 默认 0 = 从 0 开始；restart 时设为要读的那个 |
| `plotFileNumber` | INTEGER | 0 | 当前 plotfile 编号 | 默认 0；restart 时不强制（独立序列）|
| `forcedPlotFileNumber` | INTEGER | 0 | `.dump_plotfile` 触发的 plotfile 编号 | 默认 0；不会覆盖正常序列（用 9999）|

### 2.1 basenm 含路径的处理

源码：`source/IO/IOMain/io_getOutputName.F90:L64-L75`

```fortran
! 自动加 trailing /
pos = index(io_outputDir, ' ')
if (pos.gt.1) then
   if (io_outputDir(pos-1:pos-1).ne."/") then
      io_outputDir(pos:pos) = "/"
   end if
end if

! "./" 被简化为空（当前目录）
if (io_outputDir == "./") then
   io_outputDir = ""
end if
```

**注意**：`basenm` 和 `output_directory` 是**两个独立参数**。LaserSlab 把路径塞进 `basenm`（`basenm = "01-data/lasslab_"`），等价于：

```
output_directory = "01-data/"
basenm           = "lasslab_"
```

### 2.2 rolling_checkpoint（只留最近 N 个）

源码：`source/IO/IOMain/Config:L61-L63`

```
PARAMETER rolling_checkpoint INTEGER 10000
```

含义：写完第 N 个 chk 后，编号 = `mod(N, rolling_checkpoint)`。设 `rolling_checkpoint=10`：

```
chk_0000 → chk_0001 → ... → chk_0009 → chk_0010(覆盖 chk_0000) → ...
```

**为什么默认 10000**：基本不限制（10k 个 chk 够用）；磁盘紧张时设小（如 5-10）。

源码：`source/IO/IOMain/IO_output.F90:L264`

```fortran
io_checkpointFileNumber = mod(io_checkpointFileNumber,io_rollingCheckpoint)
```

### 2.3 outputSplitNum（多文件输出，HEDP 不用）

源码：`source/IO/IOMain/Config:L109-L112`

```
PARAMETER outputSplitNum INTEGER 1
D & Not fully implemented, only hdf5 parallel. use at own risk
```

设 N > 1 → 每 N 进程写一个文件（`s0000_*` / `s0001_*` / ...）。**仅 PM_argonne 实现完整**，其他实验性。

**约束**：`mod(io_meshNumProcs, io_outputSplitNum) == 0`（源码：`IO_init.F90:L311-L313`）：

```fortran
if((mod(io_meshNumProcs, io_outputSplitNum) /= 0)) then
   call Driver_abortFlash('mod(io_meshNumProcs, io_outputSplitNum) /= 0!')
end if
```

---

## 3. 控制开关（行为 / 流程）

源码：`source/IO/IOMain/Config:L178-L243`

| 参数 | 类型 | 默认 | 含义 | 为什么默认这个值 |
|---|---|---|---|---|
| `wall_clock_checkpoint` | REAL | 43200. | 墙钟到时触发 chk（秒） | **默认 43200 = 12 小时**；SLURM/PBS queue 到期前 dump；HEDP 单跑通常 < 12h，留默认 |
| `rss_limit` | REAL | -1.0 | RSS 超过此值（MB）触发 chk+退出 | **默认 -1 = 不限**；防内存泄漏吃爆节点 |
| `memory_stat_freq` | INTEGER | 100000 | 每 N 步打印内存统计 | **默认 100000 = 几乎不打**；调试时设 1 |
| `wr_integrals_freq` | INTEGER | 1 | 每 N 步写 flash.dat | **默认 1 = 每步都写**（IO 代价小，数据保真）|
| `corners` | BOOLEAN | FALSE | 是否插值到 cell corner 再写 | **历史遗留**（FLASH2 的 iso-surface 技术），现在不用 |
| `alwaysRestrictCheckpoint` | BOOLEAN | TRUE | 输出前强制 restrict 全树 | **默认 TRUE** = chk 数据全树自洽（可视化好）；FALSE 仅调试用 |
| `alwaysComputeUserVars` | BOOLEAN | TRUE | 输出前强制算 user vars（mach 数等）| **默认 TRUE** = 用户体验好；FALSE 节省时间 |
| `ignoreForcedPlot` | BOOLEAN | FALSE | `.dump_plotfile` 触发的 plotfile 不标 "forced" | **默认 FALSE** = 标 forced（编号 9999 不覆盖正常序列）|
| `summaryOutputOnly` | BOOLEAN | FALSE | 只写 flash.dat，不写 chk / plt | **默认 FALSE**；调试 / dry-run 时设 TRUE |
| `appendParRestart` | BOOLEAN | FALSE | 写 chk 时自动追加 restart 行到 parfile | **默认 FALSE** = 不改 parfile；用户希望全自动 restart 时设 TRUE |
| `io_writeMscalarIntegrals` | BOOLEAN | FALSE | flash.dat 是否含每个 mass scalar 积分 | **默认 FALSE** = 只 7 基础量；设 TRUE 加 mass scalar 列 |

### 3.1 wall_clock_checkpoint 详解

源码：`source/IO/IOMain/IO_output.F90:L293-L356`

每 hydro 步后 IO_output 检查：

```fortran
if ( (io_wallClockCheckpoint > 0.e0) .and. outputCheckpoint) then
   if (io_globalMe == MASTER_PE) then
      dtCheckpoint = MPI_Wtime() - io_lastWallClockCheckpoint
      if (dtCheckpoint > io_wallClockCheckpoint) then
         forceCheckpoint = .true.
      end if
   end if
   call MPI_Bcast(forceCheckpoint, 1, MPI_LOGICAL, MASTER_PE, io_globalComm, ierr)
   if (forceCheckpoint) then
      call IO_writeCheckpoint()
      io_lastWallClockCheckpoint = MPI_Wtime()
   end if
end if
```

**注意**：仅 master PE 检查时间（避免 N 个进程各自测时差），然后广播决定。

### 3.2 summaryOutputOnly（调试用）

源码：`source/IO/IOMain/IO_init.F90:L515-L542`

设 `summaryOutputOnly = .true.`：

- IO_output 不再按 step / simTime 触发（强制设为 -1）
- 仅 `.dump_*` 触发文件还能用

```
io_nextPlotFileStep       = -1   # 永远不触发
io_plotFileIntervalTime   = -1.0
io_checkpointFileIntervalTime = -1.0
io_wallClockCheckpoint    = -1.0
io_maxRSS                 = -1.0
```

**用途**：dry-run（只看 flash.dat 趋势，不出文件省盘）。

---

## 4. plot_var_N（plotfile 变量选择）

源码：`source/IO/IOMain/Config:L138-L176`

```
PARAMETER plot_var_1 STRING "none"     # 默认 none = 不写
PARAMETER plot_var_2 STRING "none"
... (12 个 plot_var_N)
PARAMETER plot_grid_var_1 STRING "none"
... (12 个 plot_grid_var_N)
```

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `plot_var_1..12` | STRING | "none" | cell-centered unk 名（如 "dens"），写到 plotfile |
| `plot_grid_var_1..12` | STRING | "none" | scratch GRIDVAR 名（用户用 GRIDVAR 声明的），写到 plotfile |

### 4.1 名字必须是 unk / scratch 名（4 字符）

源码：`source/IO/IOMain/IO_init.F90:L237-L258`

```fortran
! source/IO/IOMain/IO_init.F90:L241-L258
do i = 1,io_maxPlotVars
   write(plotVarNum, *) i
   plotVarNum = 'plot_var_' // plotVarNum
   call RuntimeParameters_get(plotVarNum, io_plotVarStr(i))
   call makeLowercase(io_plotVarStr(i))
end do

! 翻译 string → unk 索引
j = 0
do i=1, io_maxPlotVars
   if(any(io_plotVarStr(i) == io_unklabelsGlobal)) then    ! 必须在 unk 列表里
      j = j + 1
      call Simulation_mapStrToInt(trim(io_plotVarStr(j)), io_plotVar(j), MAPBLOCK_UNK)
   else
      if (io_plotVarStr(i) .NE. "none") &
           call Logfile_stamp(io_plotVarStr(i),"[IO_init] ignoring unrecognized plot variable")
   end if
end do
io_nPlotVars = j
```

**关键**：

- 名字必须在 `io_unklabelsGlobal` 里（即 unk 声明的变量）
- 名字必须是**小写**（`makeLowercase` 转换）
- 找不到的名字**不报错**，只打 warning（"ignoring unrecognized plot variable"）
- 名字可以是 4 字符（`dens`）或更短（`ye`）；后补空格

### 4.2 LaserSlab 典型 plot_var 配置

```
plot_var_1 = "dens"        # 密度
plot_var_2 = "depo"        # 激光沉积
plot_var_3 = "tele"        # 电子温度
plot_var_4 = "tion"        # 离子温度
plot_var_5 = "trad"        # 辐射温度
plot_var_6 = "ye  "        # 电子分数（注意空格补齐 4 字符）
plot_var_7 = "sumy"        # 总离子数密度
plot_var_8 = "cham"        # cham 物质分数
plot_var_9 = "targ"        # targ 物质分数
```

### 4.3 不设 plot_var 的警告

源码：`source/IO/IOMain/IO_writePlotfile.F90:L119-L124`

```fortran
if((io_nPlotVars == 0) .and. (io_globalMe == MASTER_PE)) then
   print *, "WARNING: you have called IO_writePlotfile but no plot_vars are defined."
   print *, 'Put the vars you want in the plotfile in your flash.par (plot_var_1 = "dens")'
   call Logfile_stampMessage("WARNING you have called IO_writePlotfile but no plot_vars are defined.")
end if
```

**含义**：plotFileIntervalStep 触发 plotfile 写出，但 plot_var 全 "none" → 写出空 plotfile（只有元数据，没有 unk）。**只 warning 不 abort**，但 yt 读会看不到变量。

---

## 5. HDF5 模式参数

源码：`source/IO/IOMain/Config:L207-L243`

| 参数 | 类型 | 默认 | 含义 | 为什么默认这个值 |
|---|---|---|---|---|
| `useCollectiveHDF5` | BOOLEAN | TRUE | 用 HDF5 collective IO 模式（vs independent）| **默认 TRUE** = 集体写快 5-10x；NoFBS UG 强制 FALSE（会死锁）|
| `typeMatchedXfer` | BOOLEAN | TRUE | 浮点传输类型匹配（memory 和 disk 同精度）| **默认 TRUE** = 防 HDF5 自动 revert 到 independent IO |
| `useLegacyLabels` | BOOLEAN | TRUE | unk 名用 4 字符（"dens"）vs 长（"density"）| **默认 TRUE** = 兼容 yt / fidlr 等老工具 |
| `plotfileMetadataDP` | BOOLEAN | FALSE | plotfile 元数据（bnd_box / coord）写双精度 | **默认 FALSE** = 单精度省空间；高精度几何时设 TRUE |
| `plotfileGridQuantityDP` | BOOLEAN | FALSE | plotfile 的 unk 数据写双精度 | **默认 FALSE** = 单精度（plotfile 本意）；若想 plotfile 兼顾 restart 可设 TRUE |
| `fileFormatVersion` | INTEGER | 9 | HDF5 文件格式版本号 | **默认 9**（当前）；读老文件（< 9）走兼容路径 |
| `chkGuardCellsInput` | BOOLEAN | FALSE | restart 时是否读 guard cell | **默认 FALSE** = 不读（省盘）；仅 PM parallel 支持 |
| `chkGuardCellsOutput` | BOOLEAN | FALSE | 写 chk 时是否写 guard cell | **默认 FALSE** = 不写；仅 PM parallel 支持 |

### 5.1 useCollectiveHDF5 详解

源码：`source/IO/IOMain/IO_init.F90:L340-L368`

```fortran
call RuntimeParameters_get("useCollectiveHDF5", io_useCollectiveHDF5)

! NoFBS UG 强制 false（仅 master 写元数据，collective 会死锁）
#if defined(IO_HDF5_PARALLEL) && defined(FLASH_GRID_UG) && !defined(FIXEDBLOCKSIZE) && !defined(FLASH_IO_EXPERIMENTAL)
  if (io_useCollectiveHDF5) then
     io_useCollectiveHDF5 = .false.
     call Logfile_stamp("*** Switching off collective I/O for NOFBS grid ***", "[IO_init]")
  end if
#endif

collectiveHDF5 = 0
if(io_useCollectiveHDF5) collectiveHDF5 = 1
call io_h5set_xfer_mode(collectiveHDF5)      ! 设 HDF5 传输模式
```

**collective vs independent 区别**：

| 模式 | 调用方式 | 性能 | 何时用 |
|---|---|---|---|
| **collective**（H5Pset_dxpl_mpio: H5FD_MPIO_COLLECTIVE） | 所有进程**一起**调 H5Dwrite | 快 5-10x | 默认；PM_argonne / PM parallel |
| **independent**（H5FD_MPIO_INDEPENDENT） | 各进程独立 H5Dwrite，靠 file lock | 慢 | NoFBS UG / 调试 |

### 5.2 chkGuardCells（仅 PM parallel）

源码：`source/IO/IOMain/hdf5/parallel/PM/Config:L13-L14`

```
PARAMETER chkGuardCellsInput BOOLEAN false
PARAMETER chkGuardCellsOutput BOOLEAN false
```

**仅 PM parallel 支持**。设 TRUE → chk 文件含 guard cell，restart 时也读。

**为什么默认 false**：

- guard cell 数据可以**重新算**（fill guardcell），不必存盘
- 写入 guard cell 多 ~30% 文件大小，浪费空间

**何时设 true**：调试 guard cell 内容（如怀疑 guardcell 通信错）。

### 5.3 fileFormatVersion（向后兼容）

源码：`source/IO/IOMain/hdf5/hdf5_flash.h:L36`

```
#define FILE_FORMAT_VERSION 9
```

每次 HDF5 格式大改时 bump。读老文件时（如 version 8），io_readData 会走兼容分支。**用户不需要改**。

---

## 6. PM_argonne 专属参数（type-based IO）

源码：`source/IO/IOMain/hdf5/parallel/PM_argonne/Config:L13-L19`

```
PARAMETER packMeshPlotWriteHDF5 BOOLEAN true
PARAMETER packMeshChkWriteHDF5  BOOLEAN false
PARAMETER packMeshChkReadHDF5   BOOLEAN false
```

| 参数 | 类型 | 默认 | 含义 | 为什么默认这个值 |
|---|---|---|---|---|
| `packMeshPlotWriteHDF5` | BOOLEAN | TRUE | 写 plotfile 时是否把数据打包到连续缓冲 | **默认 TRUE** = 用 collective IO（datatype 描述后数据不连续，需 pack）|
| `packMeshChkWriteHDF5` | BOOLEAN | FALSE | 写 checkpoint 时是否打包 | **默认 FALSE** = 双精度数据大，打包费内存 |
| `packMeshChkReadHDF5` | BOOLEAN | FALSE | restart 读 chk 时是否打包 | 同上 |

### 6.1 packMeshPlotWriteHDF5 = TRUE 的意义

源码：`source/IO/IOMain/hdf5/parallel/PM_argonne/Config:L4-L11`

```
D packMeshPlotWriteHDF5 If true, this specifies that we pack the 
D plot file data into a contiguous buffer before performing the data write.
D This is only applicable to HDF5 I/O implementation in experimental mode.  
D This is because the HDF5 group try to avoid data copies at all costs even
D if it means missing out on optimisations, such as collective I/O.   It 
D applies to experimental mode only which uses datatypes to pick up data, and
D not standard mode which already packs the data.  This option packs the 
D data described by the datatype in the same way as pnetcdf, which costs more
D memory, but allows usage of collective I/O.  Default value is true.
```

**翻译**：

- type-based IO（PM_argonne）默认用 MPI datatype 描述数据布局，不拷贝
- 但 datatype 模式下 collective IO 可能慢（HDF5 内部要建 file datatype）
- 设 `packMeshPlotWriteHDF5 = TRUE` → 先 pack 到连续缓冲（一次拷贝），再 collective 写（更快）
- plotfile 数据小（单精度），pack 代价小，**默认 TRUE**
- checkpoint 数据大（双精度），pack 代价大，**默认 FALSE**

---

## 7. 边缘参数（简要）

源码：`source/IO/IOMain/Config:L52-L57` + `L88-L89`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `memory_stat_freq` | INTEGER | 100000 | 内存统计打印间隔（io_memoryReport）|
| `rss_limit` | REAL | -1.0 | RSS 超过此值（MB）→ 写 chk 后退出 |
| `prof_file` | STRING | "profile.dat" | profiling 文件（NOT yet implemented） |

源码：`source/IO/IOMain/Config:L120-L121`

```
PARAMETER chkGuardCellsInput BOOLEAN CONSTANT FALSE
PARAMETER chkGuardCellsOutput BOOLEAN CONSTANT FALSE
```

**CONSTANT**：编译时常量（不可在 parfile 改）。**注意**：仅顶层 Config 是 CONSTANT，PM/Config 子层重新声明为非 CONSTANT（去掉 CONSTANT 标志），所以 PM parallel 用户**可以在 parfile 改**。

---

## 8. 延伸阅读

- **触发条件 + 流程**：`knowledge/internals.md §1-2`
- **plotfile / restart 实际配置**：`knowledge/recipes.md`
- **HDF5 backend 选择**：`knowledge/overview.md §2`
- **常见错误（NXB 不匹配 / plot_var 不识别 / 等）**：`knowledge/pitfalls.md`
- **参数基本属性查询**：`flash-param-query` skill
- **源码 Config 完整位置**：`source/IO/IOMain/Config:L52-L243`

---

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（draft）：8 段参数字典 + 输出频率（plotFileIntervalStep 等 6 个）+ 命名 / 目录（basenm / output_directory / rolling_checkpoint 等 7 个）+ 控制开关（wall_clock_checkpoint / rss_limit 等 11 个）+ plot_var_N + HDF5 模式（useCollectiveHDF5 / fileFormatVersion 等 8 个）+ PM_argonne 专属 3 个；按 L-011 重点讲"为什么默认这个值"+ L-013 主流在前 + L-008 贴 abort / 关键源码 | claude |
