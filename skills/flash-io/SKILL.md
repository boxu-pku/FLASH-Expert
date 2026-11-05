---
name: flash-io
description: |
  FLASH 4.8 IO 单元专家（输入输出 / HDF5 plotfile / checkpoint / restart）。
  按 L-013 聚焦主流量径——HDF5 parallel IO（LaserSlab 用的 +hdf5typeio，type-based
  parallel HDF5 写入）；覆盖：
  IO_output 主调度（每 hydro 步后调，按 step / simTime / wallclock / 触发文件 4 类触发）；
  IO_writeCheckpoint / IO_writePlotfile（双精度 chk / 单精度 plt）；
  IO_readCheckpoint（restart）；
  IO_init（plot_var_N 解析 / 输出列表生成 / restart 标志读取）；
  HDF5 backend 选择（+parallelIO + typeIO → PM_argonne；标准 → PM；UG/NoFbs 自动切）；
  plotfile HDF5 结构（cell-centered unk / facevarx,y,z / scratch / 树元数据 bnd_box/coord/bsize/nodetype/lrefine）；
  输出文件命名（basenm + _chk_/_plt_cnt_ + 4 位编号；output_directory）；
  plot_var_N（cell var）/ plot_grid_var_N（scratch grid var）；
  滚动 checkpoint（rolling_checkpoint）+ 墙钟触发（wall_clock_checkpoint）+ RSS 限制（rss_limit）；
  触发文件（.dump_plotfile / .dump_checkpoint / .dump_restart / .kill）；
  wr_integrals_freq + stats_file（flash.dat 全局积分量）；
  useCollectiveHDF5（并行 collective vs independent IO 模式）；
  fileFormatVersion（HDF5 plotfile 格式版本，当前 9）；
  chkGuardCellsInput / Output（guardcell 是否写入 checkpoint，仅 PM parallel 支持）；
  非 HDF5 简要：pnetcdf（同构输出版本，HEDP 不用）、direct（UG 专用、罕用）。
  触发词：io, IO_, hdf5, HDF5, plotfile, checkpoint, restart, basenm, plot_var,
        plotFileIntervalStep, plotFileIntervalTime, checkpointFileIntervalStep,
        checkpointFileIntervalTime, rolling_checkpoint, wall_clock_checkpoint,
        wr_integrals_freq, stats_file, flash.dat, output_directory, useCollectiveHDF5,
        fileFormatVersion, chkGuardCells, useLegacyLabels, typeMatchedXfer, summaryOutputOnly,
        appendParRestart, outputSplitNum, forcedPlotFileNumber, ignoreForcedPlot,
        IO_setScalar, IO_getScalar, IO_getPrevScalar, IO_output, IO_outputInitial,
        IO_outputFinal, IO_writeCheckpoint, IO_writePlotfile, IO_readCheckpoint,
        IO_writeIntegralQuantities, io_writeData, io_readData, io_initFile, io_closeFile,
        +hdf5typeio, +parallelIO, typeIO, PM_argonne, PM_parallel, NoFbs,
        .dump_plotfile, .dump_checkpoint, .dump_restart, .kill, flash.par
triggers:
  # 中文
  - 输入输出
  - 输入输出单元
  - 输出
  - 文件输出
  - 重启
  - 检查点
  - 重启文件
  - 检查点文件
  - 转存
  - 写出
  - 读入
  - 出图
  - 出图文件
  - 数据转存
  - 输出频率
  - 输出目录
  - 触发文件
  - 滚动检查点
  - 墙钟
  - 全局积分量
  - 单精度
  - 双精度
  # 英文 - 单元与核心 API
  - IO
  - io
  - IO_unit
  - IO_main
  - IOMain
  - IO_output
  - IO_outputInitial
  - IO_outputFinal
  - IO_init
  - IO_finalize
  - IO_writeCheckpoint
  - IO_writePlotfile
  - IO_readCheckpoint
  - IO_writeIntegralQuantities
  - IO_setScalar
  - IO_getScalar
  - IO_getPrevScalar
  - IO_updateScalars
  - IO_writeUserArray
  - IO_writeParticles
  - IO_sendOutputData
  - io_initFile
  - io_closeFile
  - io_writeData
  - io_readData
  - io_getOutputName
  - io_restrictBeforeWrite
  - io_prepareListsWrite
  - io_prepareSimInfo
  - io_checkBlockShape
  - io_finalizeListsRead
  # 英文 - 概念
  - plotfile
  - plotfiles
  - checkpoint
  - checkpoints
  - restart
  - scalar
  - scalars
  - previous scalar
  - runtime parameters
  - forced plotfile
  - dump file
  - rolling checkpoint
  - wall clock checkpoint
  - summary output
  - collective IO
  - independent IO
  - guard cells output
  # 英文 - 参数（IO 输出频率）
  - plotFileIntervalStep
  - plotFileIntervalTime
  - plotFileIntervalZ
  - plotFileNumber
  - checkpointFileIntervalStep
  - checkpointFileIntervalTime
  - checkpointFileIntervalZ
  - checkpointFileNumber
  - forcedPlotFileNumber
  # 英文 - 参数（命名 / 目录）
  - basenm
  - stats_file
  - flash.dat
  - output_directory
  - outputSplitNum
  # 英文 - 参数（控制 / 频率）
  - wr_integrals_freq
  - rolling_checkpoint
  - wall_clock_checkpoint
  - rss_limit
  - memory_stat_freq
  - corners
  - fileFormatVersion
  - useCollectiveHDF5
  - typeMatchedXfer
  - useLegacyLabels
  - plotfileMetadataDP
  - plotfileGridQuantityDP
  - chkGuardCellsInput
  - chkGuardCellsOutput
  - alwaysRestrictCheckpoint
  - alwaysComputeUserVars
  - ignoreForcedPlot
  - summaryOutputOnly
  - appendParRestart
  - io_writeMscalarIntegrals
  # 英文 - 参数（plot var）
  - plot_var_1
  - plot_var_2
  - plot_grid_var
  - plot_grid_var_1
  # 英文 - HDF5 / backend
  - HDF5
  - hdf5
  - hdf5typeio
  - +hdf5typeio
  - +parallelIO
  - parallelIO
  - typeIO
  - +typeIO
  - serialIO
  - PM_argonne
  - PM_parallel
  - PM_serial
  - NoFbs
  - pnetcdf
  - pnetcdf parallel
  - direct IO
  - H5_USE_16_API
  - HDF5_PATH
  - file format version
  - collective HDF5
  - experimental IO
  - FLASH_IO_EXPERIMENTAL
  - FLASH_IO_HDF5
  - IO_HDF5_PARALLEL
  - IO_FLASH_INT
  - IO_FLASH_DOUBLE
  # 英文 - 触发文件
  - .dump_plotfile
  - .dump_checkpoint
  - .dump_restart
  - .kill
  # 英文 - 文件结构
  - unk labels
  - facevar
  - facevarx
  - facevary
  - facevarz
  - scratch grid var
  - tree data
  - bnd_box
  - coord
  - bsize
  - nodetype
  - lrefine
  - which_child
  - bflags
  - gid
  - gsurr_blks
  - globalNumBlocks
  - nToLeft
  - globalOffset
  # 工具
  - yt
  - yt frontend
  - fidlr
  - visit
  - reader
when_to_use: |
  调用本 skill 的场景：
  1. 用户问 plotfile / checkpoint 怎么生成（"为什么没输出"、"多久写一次"、"basenm 怎么改"）
  2. 用户问 plot_var_N 怎么配置（"想加 tele 到 plotfile"、"plot_var 怎么写"）
  3. 用户问输出频率（plotFileIntervalStep / plotFileIntervalTime / checkpointFileInterval*）
  4. 用户问 restart（"restart = .true. 怎么用"、"checkpointFileNumber 怎么续跑"）
  5. 用户问 HDF5 backend 选择（"+hdf5typeio 是什么"、"parallelIO 默认开吗"、"PM_argonne"）
  6. 用户问 plotfile HDF5 内部结构（"unk 怎么存"、"facevar 在哪"、"yt 怎么读"）
  7. 用户问触发文件（".kill 文件"、"强制 checkpoint"、".dump_plotfile"）
  8. 用户问墙钟 / RSS 控制（"wall_clock_checkpoint"、"rss_limit"、"队列到时间怎么办"）
  9. 用户问 useCollectiveHDF5 / fileFormatVersion（"集体写"、"版本号"）
  10. 用户调试 IO（"plotfile 不出"、"checkpoint 写失败"、"restart 失败 NXB 不匹配"）
  11. 用户问 IO_setScalar / IO_getScalar（"怎么写一个标量到 checkpoint"）
  12. 用户问 wr_integrals_freq / flash.dat（"全局能量怎么记"、"stats_file"）
  13. 用户问 rolling_checkpoint（"只保留最近 N 个"、"磁盘吃紧"）
when_not_to_use: |
  **不调用本 skill 的场景**：
  - 物理变量含义（tele / dens 是什么） → 对应物理 skill（flash-eos / flash-hydro）
  - AMR 块结构（leaf / parent / nodetype） → `flash-grid`（本 skill 只讲 IO 怎么读它们）
  - Driver 主循环（IO_output 在哪被调用） → `flash-driver`（本 skill 只讲 IO_output 内部）
  - 参数基本属性查询（类型 / 默认 / 单位） → `flash-param-query`
  - 找 IO_* 源码位置 → `flash-source-reader`
  - 错误信息匹配 → `flash-pitfall-finder`
  - 跑算例 / 看结果 → `flash-case-runner` / `flash-result-analyzer`（Phase 3）
  - yt 后处理脚本 → `flash-result-analyzer`（Phase 3）
  - setup.py 解析 Config 的机制 → `flash-setup-builder`
layer: knowledge
phase: 2
status: stable
created: 2026-06-17
last_updated: 2026-07-31
owner: user
---

# flash-io — IO 输入输出单元专家（HDF5 plotfile / checkpoint / restart）

> **状态**：beta（待 5 道验收考题通过后升级 stable；Phase 2 第八个知识层 skill）
>
> **按 L-013 聚焦主流**：本 skill 主讲 **HDF5 parallel IO**（LaserSlab 用的 `+hdf5typeio` = type-based parallel HDF5，PM_argonne 实现）。其他 backend（serial HDF5 / pnetcdf / direct）简要带过。HEDP 用户 99% 用 HDF5 parallel。

## 1. 角色与边界

### 1.1 我是做什么的

回答 FLASH **IO 单元**相关问题——所有 checkpoint / plotfile / restart / 触发文件 / 输出频率 / HDF5 内部格式：

| 范畴 | 详见 |
|---|---|
| 物理原理 + 设计 | `knowledge/overview.md` — IO 角色 + 4 类 backend 对比 + HDF5 plotfile 结构 + restart 机制 + 术语速查（L-014）|
| 参数字典 | `knowledge/params.md` — plotFileIntervalStep / checkpointFileIntervalStep / basenm / plot_var_N / useCollectiveHDF5 等完整字典 |
| 内部实现 | `knowledge/internals.md` — IO_output 流程 + HDF5 写入机制 + AMR 域分解写入 + restart 加载 |
| 典型配置 | `knowledge/recipes.md` — HDF5 setup + parfile 输出控制 + checkpoint 策略 + restart 续跑 |
| 踩坑排查 | `knowledge/pitfalls.md` — 常见错误（HDF5 库冲突 / plotfile 不输出 / NXB 不匹配 / restart 失败等）|

### 1.2 我不做什么

| 用户问题类型 | 归属 skill |
|---|---|
| 物理变量含义（tele / dens / ye） | `flash-eos` / `flash-multispecies` |
| AMR 块结构（leaf / nodetype） | `flash-grid` |
| Driver 主循环（IO_output 调用点） | `flash-driver` |
| 参数基本属性 | `flash-param-query` |
| 找 IO_* 源码位置 | `flash-source-reader` |
| 错误匹配 | `flash-pitfall-finder` |
| yt 后处理脚本 | `flash-result-analyzer`（Phase 3）|

## 2. 行为协议

按 `agent/TEMPLATES/skill-template.md §2` 通用协议。核心要点（按 L-001~L-014）：

- **讲逻辑**（L-001）：不只是"plotFileIntervalStep = 10"，讲为什么默认 0（用户必须自己设）、HEDP 怎么选值
- **不用 mermaid**（L-002）：调用关系用文字+缩进
- **贴源码相关代码**（L-008）：abort 类查询贴 `Driver_abortFlash` 所在 if；如 NXB 不匹配贴 `io_checkBlockShape.F90:L39-L41`
- **核心 4 段 + 引导项**（L-010）：核心段（输出频率 / plot_var / HDF5 backend / restart）必给详细，引导项（direct / pnetcdf）按需展开
- **讲为什么**（L-011）：选择/配置/概念类问题必给"为什么这么设计/为什么默认这个值"
- **诊断类先引导贴现场**（L-012）：plotfile 不出 / checkpoint 写失败等先要用户贴日志/setup/parfile
- **公式 CLI 友好**（L-012）：触发条件用 ASCII（`mod(nstep, plotFileIntervalStep) == 0`）
- **聚焦主流路径**（L-013）：HDF5 parallel PM_argonne 详讲；serial / pnetcdf / direct 简要
- **专业术语先解释**（L-014）：plotfile / checkpoint / HDF5 / parallel IO / type selection 等先定义再讲机制
- **面向新手**：解释每个术语（"guard cell"、"UNK"、"plot var"、"scalar"、"rolling"）

## 3. knowledge/ 子目录

| 文件 | 内容 |
|---|---|
| `knowledge/overview.md` | IO 角色 + 4 类 backend 对比 + HDF5 plotfile 结构 + restart 机制 + 术语速查（L-014）|
| `knowledge/params.md` | IO 参数完整字典（输出频率 / 命名 / 控制开关 / plot var / 精度 / HDF5 模式）|
| `knowledge/internals.md` | IO_output 主调度流程 + io_writeData HDF5 写入 + AMR 域分解 + restart 加载链 |
| `knowledge/recipes.md` | HDF5 parallel setup（+hdf5typeio）+ parfile 输出控制 + checkpoint 策略 + restart 续跑 |
| `knowledge/pitfalls.md` | 常见错误（plotfile 不出 / NXB 不匹配 / HDF5 库冲突 / chk 损坏 / 滚动覆盖）|

## 4. examples/

| 文件 | 内容 |
|---|---|
| `examples/setup-hdf5-parallel.sh` | LaserSlab + hdf5typeio setup 命令（HEDP 标准）|
| `examples/parfile-io-control.txt` | 完整 IO 控制 parfile 片段（输出频率 / plot_var / restart） |
| `examples/restart-recipe.txt` | restart 续跑 parfile 片段（restart=.true. + checkpointFileNumber）|
| `examples/README.md` | examples 目录说明 + 使用方法 |

## 5. 示例问答（验收基准）

### Q1: plotfile 和 checkpoint 有什么区别？分别什么时候输出？

**A**: 见 `knowledge/overview.md §1, §4`。**plotfile = 单精度可视化文件**（用 yt/Visit 看）；**checkpoint = 双精度 restart 文件**（续跑专用）。两者都按 `plotFileIntervalStep` / `checkpointFileIntervalStep`（步触发）或 `*IntervalTime`（时间触发）输出。区别在：plotfile 只写用户在 `plot_var_N` 列的变量；checkpoint 写**所有** unk + facevar + scratch + 所有 runtime parameter。LaserSlab 典型：checkpoint 1000 步 / plotfile 100 步。

### Q2: 我的 plotfile 没输出，可能什么问题？

**A**: 见 `knowledge/pitfalls.md §A`。**先贴现场**（按 L-012）：日志（找 "Wrote plotfile"）、parfile（plotFileIntervalStep / plotFileIntervalTime / plot_var_1）、setup。常见原因：(1) `plotFileIntervalStep=0` 且 `plotFileIntervalTime=1.`（默认值，永远不会触发，因为 simTime 不会达到 1）；(2) `plot_var_1="none"`（默认，warning 但不出变量）；(3) `summaryOutputOnly=.true.`（只写 .dat 不写文件）；(4) `.dump_plotfile` 触发文件意外存在被忽略。

### Q3: LaserSlab 用的 `+hdf5typeio` 是什么？为什么用它？

**A**: 见 `knowledge/overview.md §3` + `knowledge/recipes.md §1`。**+hdf5typeio = type-based parallel HDF5 IO**（PM_argonne 实现），用 MPI 派生数据类型（MPI datatype）描述每个进程的 block 分布，让 HDF5 collective IO 一次写完所有进程的数据。**为什么用它**：(1) 比 standard PM parallel 更快（避免数据拷贝到主进程）；(2) 支持 mesh replication（多进程组同写一份数据）；(3) HEDP 大算例（10⁴+ blocks）IO 时间从分钟降到秒。

### Q4: restart 怎么用？checkpointFileNumber 是什么？

**A**: 见 `knowledge/recipes.md §4`。续跑：(1) 在 flash.par 加 `restart = .true.`；(2) 设 `checkpointFileNumber = <N>`（要读的那个 chk 文件编号）；(3) `./flash4 -par_file=flash.par`。FLASH 读 `flash_hdf5_chk_<NNNN>` 后从该 checkpoint 继续。**注意**：编译时 NXB/NYB/NZB/N_DIM 必须和原 run 一致（`io_checkBlockShape.F90:L39-L41` 会 abort）。

### Q5: `useCollectiveHDF5 = .true.` 是什么意思？

**A**: 见 `knowledge/params.md §5` + `knowledge/internals.md §3`。**useCollectiveHDF5 = .true.** 让 HDF5 用 collective IO 模式（所有进程**一起**调用 H5Dwrite，HDF5 库 + MPI-IO 自动调度）。**.false.** 则 independent mode（各进程独立 H5Dwrite，靠 file lock 串行化）。**为什么默认 true**：collective 模式在大算例上快 5-10x（少 lock 争用，好缓存）。但 NoFBS UG 会**强制 false**（仅 master 写元数据，collective 会死锁，见 `IO_init.F90:L356-L361`）。

## 6. 关键源码入口

| 想理解 | 看哪个文件 |
|---|---|
| IO 公共接口（IO_output / writeCheckpoint 等） | `source/IO/IO_interface.F90` |
| IO 顶层 Config（plotFileInterval* / checkpointFileInterval* / basenm 等 78 个 PARAMETER） | `source/IO/IOMain/Config:L52-L243` |
| **IO_output 主调度**（每 hydro 步后调） | `source/IO/IOMain/IO_output.F90:L114-L600` |
| IO_outputInitial（首步输出） | `source/IO/IOMain/IO_outputInitial.F90:L37-L96` |
| IO_outputFinal（结束输出） | `source/IO/IOMain/IO_outputFinal.F90:L29-L62` |
| **IO_init**（参数读取 + plot_var 解析 + restart 启动） | `source/IO/IOMain/IO_init.F90:L34-L544` |
| IO 数据模块（所有 io_ 变量） | `source/IO/IOMain/IO_data.F90` |
| **IO_writeCheckpoint**（顶层 wrapper） | `source/IO/IOMain/IO_writeCheckpoint.F90:L62-L186` |
| **IO_writePlotfile**（顶层 wrapper） | `source/IO/IOMain/IO_writePlotfile.F90:L72-L190` |
| IO_readCheckpoint（restart 加载） | `source/IO/IOMain/IO_readCheckpoint.F90:L31-L69` |
| IO_writeIntegralQuantities（flash.dat） | `source/IO/IOMain/IO_writeIntegralQuantities.F90:L38-L260` |
| IO_setScalar / IO_getScalar（标量读写） | `source/IO/IOMain/IO_setScalar.F90` / `IO_getScalar.F90` |
| IO_getPrevScalar（读 checkpoint 中的旧值） | `source/IO/IOMain/IO_getPrevScalar.F90` |
| io_getOutputName（文件命名） | `source/IO/IOMain/io_getOutputName.F90:L41-L103` |
| io_restrictBeforeWrite（输出前 restrict 决策） | `source/IO/IOMain/io_restrictBeforeWrite.F90:L30-L80` |
| io_checkBlockShape（NXB 校验） | `source/IO/IOMain/io_checkBlockShape.F90:L23-L43` |
| **HDF5 backend 选择 Config**（4 选 1） | `source/IO/IOMain/hdf5/Config:L1-L29` |
| **PM_argonne Config**（type-based parallel） | `source/IO/IOMain/hdf5/parallel/PM_argonne/Config:L1-L20` |
| **io_writeData**（HDF5 实际写入，LaserSlab 用 PM_argonne） | `source/IO/IOMain/hdf5/parallel/PM_argonne/io_writeData.F90:L59-L500` |
| io_writeData（PM 标准版） | `source/IO/IOMain/hdf5/parallel/PM/io_writeData.F90:L62-L500` |
| io_readData（restart HDF5 读） | `source/IO/IOMain/hdf5/parallel/PM/io_readData.F90:L62-L500` |
| io_initFile（HDF5 文件创建） | `source/IO/IOMain/hdf5/parallel/io_initFile.F90:L35-L62` |
| HDF5 plotfile 格式常量 | `source/IO/IOMain/hdf5/hdf5_flash.h` |
| IO 通用常量（IO_FILE_HDF5 / IO_FLASH_INT 等） | `source/IO/IOMain/io_flash.h` |
| IOParticles（粒子 IO，HEDP 罕用） | `source/IO/IOParticles/` |
| pnetcdf backend（HEDP 不用） | `source/IO/IOMain/pnetcdf/` |
| direct backend（UG 专用） | `source/IO/IOMain/direct/` |
| LaserSlab setup_call（含 +hdf5typeio） | `cases/LaserSlab/setup_call`（IO --> hdf5 / typeIO --> True）|
| LaserSlab example.par IO 段 | `source/Simulation/SimulationMain/LaserSlab/example.par:L14-L34` |

## 7. 待办

- [ ] 跑 5 道验收考题，全部通过则升级 stable
- [ ] 持续累积踩坑（用户实战 HEDP 算例遇到 IO 问题时）
- [ ] Phase 3 后续 skill 协作验证（如 flash-result-analyzer 用 yt 读 plotfile）

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-07-30 | **升级 draft → beta**（Phase 2 第八个知识层 skill）：按 flash-laser/driver/grid/hydro/eos/radtrans/sourceterms 模板 + L-001~L-014 全部经验（特别强化 L-013 聚焦 HDF5 parallel 主流 + L-014 解释 plotfile/checkpoint/HDF5/type selection 等术语）；扩展 triggers（150+ 关键词含 IO_output / writeCheckpoint / plotFileInterval* / plot_var / chkGuardCells / useCollectiveHDF5 / fileFormatVersion / PM_argonne / hdf5typeio / 触发文件 / tree data 等）；5 knowledge 文件齐 + 4 examples（setup 脚本 + 2 parfile 片段 + README）；含完整 IO 单元讲解（IO_output 调度 / HDF5 写入 / AMR 域分解 / restart 加载 / 触发文件 / 滚动 checkpoint / 墙钟触发 / plot_var 解析 / collective IO / fileFormatVersion=9）；按 L-013 主讲 HDF5 parallel PM_argonne（HEDP 主流）+ 简要带过 pnetcdf/direct/serial（非主流）；Phase 2 stable 知识层 skill | claude |
