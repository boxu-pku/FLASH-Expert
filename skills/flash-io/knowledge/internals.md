---
title: IO 内部实现 — IO_output 流程 + HDF5 写入机制 + AMR 域分解 + restart 加载
skill: flash-io
category: internals
source_anchors:
  - source/IO/IOMain/IO_output.F90:L114-L600
  - source/IO/IOMain/IO_init.F90:L34-L544
  - source/IO/IOMain/IO_writeCheckpoint.F90:L62-L186
  - source/IO/IOMain/IO_writePlotfile.F90:L72-L190
  - source/IO/IOMain/IO_readCheckpoint.F90:L31-L69
  - source/IO/IOMain/hdf5/parallel/PM_argonne/io_writeData.F90:L59-L500
  - source/IO/IOMain/hdf5/parallel/PM/io_readData.F90:L62-L500
manual_ref: "FLASH 4.8 User Guide §10"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: draft
tags:
  - io
  - internals
  - hdf5
  - parallel-io
  - restart
---

# IO 单元内部实现（IO_output 流程 + HDF5 写入 + restart 加载）

> **TL;DR**：本文件深入 IO_output 主调度（每 hydro 步后调）、io_writeData（HDF5 实际写入）、io_readData（restart 加载）的源码逻辑。按 L-002 用文字+缩进（不用 mermaid），按 L-008 贴关键 abort 代码，按 L-011 讲设计动机。

---

## 1. IO_output 主调度流程（每 hydro 步后调）

源码：`source/IO/IOMain/IO_output.F90:L114-L600`

### 1.1 总体流程

```
IO_output(simTime, dt, nstep, nbegin, endRun, outputType) [L114]
│
├── Step 0: 解 outputType 标志 [L163-L175]
│   if present(outputType) then
│       outputCheckpoint = IAND(outputType, CHECKPOINT_FILE_ONLY) /= 0
│       outputPlotfile   = IAND(outputType, PLOTFILE_ONLY) /= 0
│       outputParticleFile = IAND(outputType, PARTICLE_FILE_ONLY) /= 0
│   else
│       outputCheckpoint = .true.  → 全开
│       outputPlotfile   = .true.
│       outputParticleFile = .true.
│   end if
│
├── Step 1: 设 io_outputInStack = .true. [L184]
│   ↑ 告诉 io_restrictBeforeWrite 是 IO_output 调的（强制 restrict）
│
├── Step 2: 写 flash.dat（每 wr_integrals_freq 步） [L205-L212]
│   if (mod(nstep, io_integralFreq) == 0) then
│       if (abs(simTime - lastSimTime) > TINY) then
│           call IO_writeIntegralQuantities(0, simTime)
│           lastSimTime = simTime
│       end if
│   end if
│   ↑ 同一 simTime 只写一次（防 dt 太小时重复写）
│
├── Step 3: 步 / 时间触发 checkpoint [L224-L278]
│   if (((nstep == io_nextCheckpointStep) .or.
│        (io_checkpointFileIntervalTime > 0 .and. simTime >= io_nextCheckpointTime) .or.
│        (io_checkpointFileIntervalZ < HUGE(1.) .and. currentRedshift <= io_nextCheckpointZ))
│       .and. nstep /= nbegin                                  ! 首步不算
│       .and. outputCheckpoint) then
│       call Grid_computeUserVars()                            ! 计算 user var
│       do while (simTime >= io_nextCheckpointTime)            ! 推进下次时间
│           io_nextCheckpointTime += io_checkpointFileIntervalTime
│       end do
│       io_checkpointFileNumber = mod(io_checkpointFileNumber, io_rollingCheckpoint)  ★ 滚动
│       call IO_writeCheckpoint()                              ★ 写
│       io_nextCheckpointStep = nstep + io_checkpointFileIntervalStep
│       io_justCheckpointed = .true.
│   end if
│
├── Step 4: 墙钟触发 checkpoint [L293-L356]
│   if (io_wallClockCheckpoint > 0 .and. outputCheckpoint) then
│       if (MASTER_PE) then
│           dtCheckpoint = MPI_Wtime() - io_lastWallClockCheckpoint
│           if (dtCheckpoint > io_wallClockCheckpoint) forceCheckpoint = .true.
│       end if
│       call MPI_Bcast(forceCheckpoint, ...)                   ! 广播给所有进程
│       if (forceCheckpoint .and. .not. io_justCheckpointed) then    ! 不重复写
│           call IO_writeCheckpoint()
│       end if
│       io_lastWallClockCheckpoint = MPI_Wtime()
│   end if
│
├── Step 5: 步 / 时间触发 plotfile [L366-L398]
│   if (((nstep == io_nextPlotFileStep) .OR.
│        (io_plotFileIntervalTime > 0 .AND. simTime >= io_nextPlotfileTime) .OR.
│        (io_plotFileIntervalZ < HUGE(1.) .AND. currentRedshift <= io_nextPlotFileZ))
│       .and. outputPlotfile) then
│       do while (simTime >= io_nextPlotfileTime)              ! 推进
│           io_nextPlotfileTime += io_plotFileIntervalTime
│       end do
│       call IO_writePlotfile()                                ★ 写
│       io_nextPlotFileStep = nstep + io_plotFileIntervalStep
│   end if
│
├── Step 6: 粒子输出（HEDP 不用） [L411]
│   if (outputParticleFile) call IO_writeParticles(.false.)
│
├── Step 7: 触发文件检查（4 个）[L422-L595]
│   ├── .dump_plotfile  → IO_writePlotfile(.true.)  [forced]
│   ├── .dump_checkpoint → IO_writeCheckpoint()
│   ├── .dump_restart   → IO_writeCheckpoint() + endRun=.true.  ★ 退出
│   ├── (RSS check)     → if RSS 超限，IO_writeCheckpoint() + endRun=.true.
│   └── .kill           → endRun=.true.（不写 chk）  ★ 立即退出
│
└── Step 8: 复位 io_outputInStack = .false. [L598]
```

### 1.2 关键设计：io_outputInStack

源码：`source/IO/IOMain/io_restrictBeforeWrite.F90:L30-L80`

```fortran
! io_restrictBeforeWrite.F90:L52-L70
if (oldsimTime == lsimTime .and. oldsimGen == lsimGen) then
   restrictNeeded = .false.                                  ! 同步同 generation → 不用 restrict
else
   if (.NOT. io_outputInStack .AND. .NOT. io_alwaysRestrictCheckpoint) then
      restrictNeeded = .FALSE.                               ! 不在 IO_output 栈 + 用户关 always
   else
      restrictNeeded = .true.                                ! IO_output 调 或 alwaysRestrict=TRUE → restrict
      oldsimTime = lsimTime
      oldsimGen = lsimGen
   end if
end if
```

**逻辑**：

- `io_outputInStack = .true.`：调用者是 IO_output / IO_outputInitial / IO_outputFinal → **强制 restrict**（让全树自洽）
- `io_outputInStack = .false.`：用户代码（如 Grid_computeUserVars 之后直接 IO_writeCheckpoint）→ 看 `alwaysRestrictCheckpoint`

**为什么这么设计**：用户直接调 IO_writeCheckpoint 时可能不希望 restrict（性能考虑），但 IO_output 一定要 restrict（保证数据正确）。

### 1.3 nextCheckpointTime 推进的微妙性

源码：`source/IO/IOMain/IO_output.F90:L236-L272`

```fortran
sav_nextPlotfileTime = io_nextPlotfileTime                  ! 保存
if ( io_plotFileIntervalTime > 0.e0 ) then
   if (simTime >= io_nextPlotfileTime) then
      io_nextPlotfileTime = io_nextPlotfileTime + &
           (int((simTime-io_nextPlotfileTime)/io_plotFileIntervalTime) + 1)*io_plotFileIntervalTime
   end if
end if

! ... checkpoint 写入 ...
call IO_writeCheckpoint()                                    ! 写时 io_nextPlotfileTime 是"未来"值

io_nextPlotfileTime = sav_nextPlotfileTime                  ! 恢复
```

**为什么先存再恢复**：写 checkpoint 时要把"下次 plotfile 时间"存到 chk 里（restart 时用）。但 IO_output 还要继续走 plotfile 触发逻辑（Step 5），那时需要的是"当前"的 io_nextPlotfileTime。所以先存"未来"值到 chk，写完恢复到"当前"值。

### 1.4 do while 循环防漏触发

源码：`source/IO/IOMain/IO_output.F90:L247-L251`

```fortran
do while (simTime >= io_nextCheckpointTime)
   io_nextCheckpointTime = io_nextCheckpointTime + io_checkpointFileIntervalTime
end do
```

**为什么 do while 不 if**：如果一次 dt 跨过多个 IntervalTime（如 dt = 0.1s, IntervalTime = 0.01s），一次 hydro 步可能跳过 10 个触发点。do while 推进直到 `nextCheckpointTime > simTime`，保证下次触发在未来。

但实际只写一次 checkpoint（不在循环内调 IO_writeCheckpoint）。

---

## 2. IO_writeCheckpoint / IO_writePlotfile（顶层 wrapper）

### 2.1 IO_writeCheckpoint 流程

源码：`source/IO/IOMain/IO_writeCheckpoint.F90:L62-L186`

```
IO_writeCheckpoint()
│
├── io_doublePrecision = .true.                              ★ 双精度
├── call IO_updateScalars()                                  ← 收集 Driver/Grid/Hydro 标量
├── call io_prepareSimInfo()                                 ← setup_call / build_date / 等
├── call io_restrictBeforeWrite(restrictNeeded)
│   if (restrictNeeded) call Grid_restrictAllLevels()       ← 让全树自洽
├── if (io_alwaysComputeUserVars) call Grid_computeUserVars()
│
├── call io_initFile(io_checkpointFileNumber, io_chkptFileID, filename, "_chk_", .false.)
│   ↑ HDF5 文件创建（H5Fcreate），返回 fileID
│
├── if (MASTER_PE .and. io_appendParRestart) then           ← appendParRestart 写 parfile
│       open(110, file=io_parmFile, position='append')
│       if (io_appendParRestartNotFirst) then
│           write(110, *) "restart = .true."
│           write(110, *) "checkpointFileNumber = ", io_checkpointFileNumber
│           write(110, *) "plotFileNumber = ", io_plotFileNumber
│       end if
│       close(110)
│   end if
│
├── do i = UNK_VARS_BEGIN, UNK_VARS_END                     ← 收集 unk 名
│       call Simulation_mapIntToStr(i, io_unklabels(i), MAPBLOCK_UNK)
│   end do
│
├── call io_writeData(io_chkptFileID)                        ★ HDF5 实际写入
│
├── call IO_writeParticles(.true.)                           ← 粒子（HEDP 不用）
├── call IO_writeUserArray()                                 ← 用户扩展
│
├── call io_closeFile(io_chkptFileID)                        ← H5Fclose
│
└── if (io_checkpointFileNumber /= DUMP_IOFILE_NUM) then    ← 不是 .dump 触发则递增
       io_checkpointFileNumber += 1
    end if
```

### 2.2 IO_writePlotfile 流程

源码：`source/IO/IOMain/IO_writePlotfile.F90:L72-L190`

差异（vs checkpoint）：

```
io_doublePrecision = .false.                                 ★ 单精度
fileIsForced = present(forced) .and. .not. io_ignoreForcedPlot
if (fileIsForced) then
   call io_initFile(io_forcedPlotFileNumber, fileID, filename, '_plt_cnt_', .true.)
   ↑ 用 forcedPlotFileNumber（默认 0，可独立序列）
else
   call io_initFile(io_plotFileNumber, fileID, filename, '_plt_cnt_', .false.)
end if

call Grid_computeUserVars()                                  ← plotfile 总是算 user var
call io_writeData(fileID)

if (.not. fileIsForced) then
   io_plotFileNumber += 1                                    ← 递增（forced 不递增 forced 编号？错，见下）
else
   io_forcedPlotFileNumber += 1                              ← forced 编号递增
end if
```

### 2.3 为什么 plotfile 不写 guard cell 但 chk 可选

源码：`source/IO/IOMain/hdf5/parallel/PM/io_writeData.F90:L158`

```fortran
logical :: writeGuardCells = .true.     ! PM 标准：默认写（但被 io_chkGuardCellsOutput 控制）
```

实际上 `io_chkGuardCellsOutput`（默认 false）控制是否写 guard cell 到 chk。plotfile 不受此参数控制——**plotfile 永远不写 guard cell**（单精度省空间 + 可视化用不到 guard cell）。

---

## 3. io_writeData（HDF5 实际写入，以 PM_argonne 为例）

源码：`source/IO/IOMain/hdf5/parallel/PM_argonne/io_writeData.F90:L59-L500`

### 3.1 流程总览

```
io_writeData(fileID)
│
├── call io_prepareListsWrite()                              ← 准备 runtime params + scalars 链表
├── call Grid_getLocalNumBlks(localNumBlocks)
│
├── 计算 splitOffset / localOffset / io_splitNumBlks         ← AMR 域分解
│   if (io_outputSplitNum > 1) then
│       call MPI_ALLREDUCE(gr_globalOffset, splitOffset, ..., MPI_MIN, io_comm, ...)
│       localOffset = gr_globalOffset - splitOffset
│       call MPI_ALLREDUCE(localNumBlocks, io_splitNumBlks, ..., MPI_SUM, ...)
│   else
│       localOffset = gr_globalOffset
│       io_splitNumBlks = gr_globalNumBlocks
│   end if
│
├── if (io_doublePrecision) then                             ← checkpoint 路径
│       call io_h5write_header(..., ubound(io_unklabelsGlobal,1), ...)   ← 写所有 unk
│   else                                                     ← plotfile 路径
│       call io_h5write_header(..., io_nPlotVars, ...)                   ← 写 plot_var 子集
│   end if
│
├── call io_h5write_header(...)                              ← HDF5 头（file_format_version, setup_call, ...）
│
├── call io_xfer_tree_data(tree_data, fileID, ...)           ← 树元数据（bnd_box, coord, bsize, ...）
│   ↑ type-based IO 一次写完所有树数据（datatype 描述）
│
├── do u = 1, ubound(io_unklabelsGlobal, 1)                  ← 每个 unk 一个 dataset
│       if (io_doublePrecision .or. isPlotVar(io_unklabelsGlobal(u))) then
│           call io_h5write_unknowns(fileID, ..., unk, ...)   ← 双精度
│       else
│           call io_h5write_unknowns_sp(fileID, ..., unkt, ...) ← 单精度（plotfile）
│       end if
│   end do
│
├── do i = 1, NFACE_VARS                                     ← face var（HEDP 罕用）
│       call io_h5write_facevar(...)
│   end do
│
├── do i = 1, io_nPlotGridVars                               ← scratch grid var
│       call io_h5write_scratch(...)
│   end do
│
├── call io_h5write_generic_real_arr(..., realParmValues, ...)  ← runtime params (reals)
├── call io_h5write_generic_int_arr(..., intParmValues, ...)
├── call io_h5write_generic_*_arr(..., logParmValues, ...)
├── call io_h5write_generic_*_arr(..., strParmValues, ...)
│
├── call io_h5write_lists(..., realScalarValues, ...)        ← scalars
├── call io_h5write_lists(..., intScalarValues, ...)
│
└── 计算 globalVarMin / Max 等 extrema                       ← 写 attribute 给 yt 用
```

### 3.2 AMR 域分解（关键）

每个进程持有部分 block（leaf block 在该进程），写到 HDF5 文件时**每个进程写自己那段**：

```
HDF5 file:  [unk(dens, pres, ...) shape (NXB, NYB, NZB, globalNumBlocks)]
                                              ↑
                              ┌───────────────┴───────────────┐
                              │                                 │
            proc 0 写 block 0..N0-1           proc 1 写 block N0..N0+N1-1
                              │                                 │
                              └───────────────┬───────────────┘
                                                ↑
                                  globalOffset（本进程之前有多少 block）

io_splitNumBlks = 全局 block 总数（io_outputSplitNum=1 时）
                  或本 split 文件的 block 数（outputSplitNum>1 时）
```

源码：`source/IO/IOMain/hdf5/parallel/PM/io_writeData.F90:L193-L195`

```fortran
localOffset = gr_globalOffset                            ! 本进程之前有多少 block
io_splitNumBlks = gr_globalNumBlocks                     ! 文件总 block 数
```

`gr_globalOffset` 由 Grid 单元算（每进程 leaf block 数累加）。

### 3.3 type-based IO（PM_argonne 核心技术）

源码：`source/IO/IOMain/hdf5/parallel/PM_argonne/io_writeData.F90`

PM_argonne（type-based）vs PM（standard）的关键差异：

**PM 标准**（io_writeData.F90:PM/io_writeData.F90:L200-L260）：

```
对每个 unk：
  allocate(unkBuf(1, NXB, NYB, NZB, MAXBLOCKS))     ← 临时缓冲
  do lb = 1, localNumBlocks
     unkBuf(1, :, :, :, lb) = unk(u, :, :, :, lb)   ← 拷贝
  end do
  call io_h5write_unknowns(fileID, ..., unkBuf, ..., localOffset, ...)
  deallocate(unkBuf)
```

**PM_argonne type-based**：

```
对每个 unk：
  call io_typeInit(...)                              ← 一次性建 MPI datatype
  call io_h5write_unknowns(fileID, ..., unk, ..., datatype, ...)  ← 直接传 unk，datatype 描述布局
  HDF5 用 collective H5Dwrite 一次写完
```

**优势**：

1. 无需 `unkBuf` 缓冲（省 MAXBLOCKS × NXB × NYB × NZB × 8B 内存）
2. HDF5 collective IO 一次调用，HDF5 + MPI-IO 调度最优
3. 支持 mesh replication（NONREP）

### 3.4 useCollectiveHDF5 在 io_writeData 中的作用

源码：`source/IO/IOMain/hdf5/io_h5_xfer.c`（不在本 skill 范围，简述）

```
if (useCollectiveHDF5) {
    H5Pset_dxpl_mpio(dxpl_id, H5FD_MPIO_COLLECTIVE);   ← 集体模式
} else {
    H5Pset_dxpl_mpio(dxpl_id, H5FD_MPIO_INDEPENDENT);  ← 独立模式
}
H5Dwrite(dataset_id, mem_type_id, mem_space_id, file_space_id, dxpl_id, buf);
```

**collective 模式要求所有进程一起调 H5Dwrite**——这就是 NoFBS UG 强制 false 的原因（NoFBS UG 仅 master 写元数据，其他进程不参与 → collective 死锁）。

---

## 4. IO_init（启动时一次性）

源码：`source/IO/IOMain/IO_init.F90:L34-L544`

### 4.1 主要流程

```
IO_init()
│
├── 读所有 IO runtime parameters (L89-L145)
│   call RuntimeParameters_get('plotFileIntervalTime', io_plotfileIntervalTime)
│   call RuntimeParameters_get('basenm', io_baseName)
│   call RuntimeParameters_get('useCollectiveHDF5', io_useCollectiveHDF5)
│   call RuntimeParameters_get('rolling_checkpoint', io_rollingCheckpoint)
│   call RuntimeParameters_get('wall_clock_checkpoint', io_wallClockCheckpoint)
│   ...
│
├── 解析 plot_var_N（L236-L259）
│   do i = 1, io_maxPlotVars
│       call RuntimeParameters_get('plot_var_' // numToStr, io_plotVarStr(i))
│       call makeLowercase(io_plotVarStr(i))
│   end do
│   do i = 1, io_maxPlotVars
│       if (any(io_plotVarStr(i) == io_unklabelsGlobal)) then    ← 必须是 unk 名
│           call Simulation_mapStrToInt(io_plotVarStr(j), io_plotVar(j), MAPBLOCK_UNK)
│       else if (io_plotVarStr(i) != "none") then
│           call Logfile_stamp("[IO_init] ignoring unrecognized plot variable")  ← 仅 warning
│       end if
│   end do
│
├── 检查 mesh replication 一致性（L198-L222）  ← 仅 NONREP_COUNT > 0 时
│   if (.not. IO_HDF5_PARALLEL .and. io_acrossNumProcs > 1) then
│       call Driver_abortFlash("mesh replication is only supported by parallel HDF5...")
│   end if
│   if (any(io_unkToGlobal == 0)) then
│       call Driver_abortFlash("Unused UNK due to NONREP Config directive...")
│   end if
│
├── 解析 plot_grid_var_N（L273-L302）                          ← scratch grid var
├── 检查 outputSplitNum 整除（L311-L313）
│   if (mod(io_meshNumProcs, io_outputSplitNum) /= 0) then
│       call Driver_abortFlash('mod(io_meshNumProcs, io_outputSplitNum) /= 0!')
│   end if
│
├── 设 HDF5 传输模式（L340-L368）
│   call RuntimeParameters_get("useCollectiveHDF5", io_useCollectiveHDF5)
│   if (NoFBS UG .and. io_useCollectiveHDF5) then              ← 强制 false
│       io_useCollectiveHDF5 = .false.
│   end if
│   call io_h5set_xfer_mode(collectiveHDF5)                    ← C 函数，设全局变量
│
├── if (io_restart) then                                       ← restart 路径
│       call IO_readCheckpoint()                              ← 加载 chk
│       call IO_getPrevScalar("nstep", step)
│       call IO_getPrevScalar("time", simTime)
│       call IO_getPrevScalar("nextCheckpointTime", io_nextCheckpointTime)
│       call IO_getPrevScalar("nextPlotfileTime", io_nextPlotfileTime)
│   else
│       call RuntimeParameters_get("nbegin", step)
│       call RuntimeParameters_get("tinitial", simTime)
│       io_nextCheckpointTime = simTime + io_checkpointFileIntervalTime
│       io_nextPlotfileTime = simTime + io_plotFileIntervalTime
│   end if
│
├── io_nextCheckPointStep = step + io_checkpointFileIntervalStep
├── io_nextPlotFileStep    = step + io_plotfileIntervalStep
│
├── call io_ptInit()                                           ← 粒子 IO（HEDP 不用）
├── call io_wsInit()                                           ← single cell 写入子单元
│
└── io_outputInStack = .false.                                 ← 初始状态
```

### 4.2 NONREP / mesh replication abort

源码：`source/IO/IOMain/IO_init.F90:L198-L221`

```fortran
! source/IO/IOMain/IO_init.F90:L198-L221
#if defined(IO_HDF5_PARALLEL) || (defined(FLASH_IO_PNETCDF) && defined(FLASH_IO_EXPERIMENTAL))
#else
  if(io_acrossNumProcs > 1) then
     call Driver_abortFlash('[' // FILE_AT_LINE // '] ERROR: ' // &
        'mesh replication is only supported by parallel HDF5 ' //&
        'and derived datatype pnetCDF I/O units.')
  end if
#endif
  if(any(io_unkToGlobal == 0)) then
     call Logfile_stamp('ERROR: all unks allocated for a NONREP variable array must be in use.')
     call Driver_abortFlash('[' // FILE_AT_LINE // '] ERROR: Unused UNK ' // & 
          'due to NONREP Config directive and IO unit. LOOK AT THE LOG FILE.')
  end if
#endif
```

**含义**：

- mesh replication（多组同构算例，`io_acrossNumProcs > 1`）需要 parallel HDF5（或 type-based pnetcdf）
- 用 serial IO 时如果 `acrossNumProcs > 1` → abort
- 如果 unk 没被全用（NONREP 配置和实际 unk 数不一致）→ abort

**HEDP 用户通常不碰**——单组算例 `acrossNumProcs = 1`。

### 4.3 io_outputInStack 状态机

源码：`source/IO/IOMain/IO_init.F90:L510-L513`

```fortran
io_outputInStack = .false.   ! 初始 false
```

后续由 IO_output / IO_outputInitial / IO_outputFinal 设 true（进入栈）再 false（退出栈）。io_restrictBeforeWrite 读这个标志决定是否 restrict。

---

## 5. restart 加载链（io_readData）

源码：`source/IO/IOMain/IO_readCheckpoint.F90:L31-L69` + `hdf5/parallel/PM/io_readData.F90:L62-L500`

### 5.1 总体流程

```
IO_readCheckpoint()
│
├── 收集 unklabels（L46-L48）
│   do i = UNK_VARS_BEGIN, UNK_VARS_END
│      call Simulation_mapIntToStr(i, io_unklabels(i), MAPBLOCK_UNK)
│   end do
│
├── call io_readData()                                       ★ 实际 HDF5 读
├── call io_rescaleCellBoxes()                               ← 校正 cell box（PM 树）
├── call IO_readParticles()
├── call IO_readUserArray()
├── call io_closeFile(io_chkptFileID)
└── io_checkpointFileNumber += 1                             ← 下一个 chk 编号
```

### 5.2 io_readData 详细流程

源码：`source/IO/IOMain/hdf5/parallel/PM/io_readData.F90:L62-L500`

```
io_readData()
│
├── 读 header（setup_call, flash_version, ...）
├── 读 lists（runtime parameters + scalars 链表）
│   call io_h5read_lists(...)
│   call io_h5read_lists(... int scalars ...)
│   call io_finalizeListsRead()                              ← 把链表固化到数组
│
├── 读 globalNumBlocks（L186）
│   call IO_getScalar("globalNumBlocks", gr_globalNumBlocks)
│
├── NXB 校验（L187）
│   call io_checkBlockShape(gr_globalNumBlocks)
│   ↑ 内部调 IO_getPrevScalar("nxb", fileNxb) 等，比较 NXB/NYB/NZB
│   ↑ 不匹配 → Driver_abortFlash("NXB in checkpoint does not match this executable!")
│
├── if (io_outputSplitNum /= 1) then
│       call IO_getScalar("splitNumBlocks", io_splitNumBlks)
│   end if
│
├── 计算 block 分布（L201-L269）
│   alnblocks = int(gr_globalNumBlocks/io_meshNumProcs) + 1   ← 每进程平均 block 数
│   if (alnblocks > MAXBLOCKS) then
│       call Driver_abortFlash("num blocks per proc exceeds maxblocks")    ★ abort
│   end if
│   yy = (io_meshNumProcs*alnblocks) - gr_globalNumBlocks
│   xx = io_meshNumProcs - yy
│   do i = 0, io_meshNumProcs - 2                              ← 计算 gr_nToLeft（每进程左侧总 block 数）
│      if (i < xx) then
│         procBlocks = alnblocks
│      else
│         procBlocks = alnblocks - 1
│      end if
│      gr_nToLeft(i+1) = procBlocks + gr_nToLeft(i)
│   end do
│   if (io_meshMe < xx) then
│      localNumBlocks = alnblocks
│   else
│      localNumBlocks = alnblocks - 1
│   end if
│   gr_globalOffset = gr_nToLeft(io_meshMe)                   ← 本进程之前有多少 block
│
├── call Grid_putLocalNumBlks(localNumBlocks)
│
├── 读树元数据（bnd_box, coord, bsize, nodetype, lrefine, gid, which_child, bflags, gsurr_blks）
│   call io_xfer_tree_data(tree_data, ..., IO_READ_XFER, ...)
│
├── call Grid_receiveInputData(localNumBlocks, alnblocks, xx) ← 把 gr_gid / gsurr_blks 注入 Grid
│
├── 读 unk（每个一个 dataset）
│   allocate(unkBuf(1, NXB, NYB, NZB, MAXBLOCKS))
│   do u = 1, ubound(io_unklabelsGlobal, 1)
│      call Simulation_mapStrToInt(io_unklabelsGlobal(u), i, MAPBLOCK_UNK)
│      doread = 0
│      if (i /= NONEXISTENT) doread = 1                       ← 找到对应 unk 才读
│      call io_h5read_unknowns(io_chkptFileID, NXB, NYB, NZB, unkBuf,
│                              io_unklabelsGlobal(u), localNumBlocks,
│                              io_splitNumBlks, localOffset, doread)
│      if (i /= NONEXISTENT) then
│         unk(i, io_ilo:io_ihi, io_jlo:io_jhi, io_klo:io_khi, 1:MAXBLOCKS) = &
│              unkBuf(1, 1:NXB, 1:NYB, 1:NZB, 1:MAXBLOCKS)
│      end if
│   end do
│   deallocate(unkBuf)
│
├── 读 facevar（HEDP 不用）
├── 读 scratch grid var
│
└── (PM 标准) call Grid_verify(20)                            ← 校验（可选）
```

### 5.3 NXB 校验 abort

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

**修法**：setup 时和原 run 用相同的 `-nxb -nyb -nzb`。

### 5.4 block 分布算法（精细）

源码：`source/IO/IOMain/hdf5/parallel/PM/io_readData.F90:L201-L269`

假设：globalNumBlocks = 100，io_meshNumProcs = 7

```
alnblocks = int(100/7) + 1 = 15      # 每进程最多 15 个
yy = (7*15) - 100 = 5                # 5 个进程少一个（拿 14 个）
xx = 7 - 5 = 2                       # 2 个进程拿 15 个（meshMe=0,1）
                                      # 5 个进程拿 14 个（meshMe=2,3,4,5,6）

gr_nToLeft(0) = 0
gr_nToLeft(1) = 15                   # meshMe=0 拿 15
gr_nToLeft(2) = 30                   # meshMe=1 拿 15
gr_nToLeft(3) = 44                   # meshMe=2 拿 14
gr_nToLeft(4) = 58
gr_nToLeft(5) = 72
gr_nToLeft(6) = 86
（合计 100）

io_meshMe=3 → localNumBlocks = 14, gr_globalOffset = 44
```

---

## 6. io_initFile / io_closeFile（HDF5 文件创建 / 关闭）

### 6.1 io_initFile（parallel HDF5）

源码：`source/IO/IOMain/hdf5/parallel/io_initFile.F90:L35-L62`

```fortran
! source/IO/IOMain/hdf5/parallel/io_initFile.F90:L35-L62
subroutine io_initFile( filenum, fileID, filename, outputType, forced)
  call io_getOutputName(filenum, "hdf5", outputType, filename, forced)    ! 拼文件名

  existing = 0
  fileID = -1
  call io_h5init_file(fileID, filename, io_comm, io_outputSplitNum, existing)   ! H5Fcreate
  if(fileID == -1) then
     call Driver_abortFlash("unable to initialize hdf5 file")
  end if
end subroutine io_initFile
```

### 6.2 io_getOutputName（文件命名）

源码：`source/IO/IOMain/io_getOutputName.F90:L41-L103`

```fortran
! io_getOutputName.F90:L78-L97
write (fnumStr, '(i4.4)') fileNum                  ! 4 位 0 填充

if (io_outputSplitNum > 1) then                    ! 多文件输出
   write (splitFileNumStr, '(i4.4)') io_splitFileNum
   if(forced) then
      filename = io_baseName(:pos-1) // 'forced_' // 's' // splitFileNumStr // '_' // fileTypeStr // strname // fnumStr
   else
      filename = io_baseName(:pos-1) // 's' // splitFileNumStr // '_' // fileTypeStr // strname // fnumStr
   end if
else
   if(forced) then
      filename = io_baseName(:pos-1) // 'forced_' // fileTypeStr // strname // fnumStr
   else
      filename = io_baseName(:pos-1) // fileTypeStr // strname // fnumStr
   end if
end if

filename = io_outputDir(:pos-1) // filename        ! 加目录前缀
```

例：

- `basenm="lasslab_"`, `outputDir="01-data/"`, `filenum=15`, `outputType="_chk_"`, `forced=.false.`
- → `01-data/lasslab_hdf5_chk_0015`

---

## 7. 延伸阅读

- **IO_output 顶层流程图 + 周期关系**：`knowledge/overview.md §1-2`
- **参数完整字典**：`knowledge/params.md`
- **典型 parfile 配置 + restart 续跑**：`knowledge/recipes.md`
- **常见错误（NXB 不匹配 / HDF5 库冲突等）**：`knowledge/pitfalls.md`
- **Driver 主循环（IO_output 在哪被调）**：`flash-driver` skill
- **Grid / AMR 块结构**：`flash-grid` skill

---

## 8. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（draft）：8 段 internals + IO_output 主调度（8 步流程）+ io_outputInStack 设计 + nextCheckpointTime 推进 + IO_writeCheckpoint / IO_writePlotfile wrapper + io_writeData (PM_argonne) HDF5 写入 + AMR 域分解 + collective vs independent + IO_init 启动流程 + NONREP abort + io_readData restart 加载链 + NXB 校验 + block 分布算法 + io_initFile / io_getOutputName；按 L-002 文字+缩进 + L-008 贴 abort 代码 + L-011 讲设计动机 | claude |
