---
title: IO 常见错误 — plotfile 不出 / NXB 不匹配 / HDF5 库冲突 / chk 损坏
skill: flash-io
category: pitfalls
source_anchors:
  - source/IO/IOMain/IO_output.F90:L366-L398
  - source/IO/IOMain/IO_writePlotfile.F90:L119-L124
  - source/IO/IOMain/io_checkBlockShape.F90:L39-L41
  - source/IO/IOMain/IO_init.F90:L196-L221
  - source/IO/IOMain/IO_init.F90:L311-L313
  - source/IO/IOMain/hdf5/parallel/PM/io_readData.F90:L205-L218
  - source/IO/IOMain/hdf5/parallel/io_initFile.F90:L57-L60
manual_ref: "FLASH 4.8 User Guide §10"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: draft
tags:
  - io
  - pitfalls
  - debugging
  - hdf5
---

# IO 常见错误（按 L-012 引导贴现场 + L-008 贴源码 + L-013 主流优先）

> **TL;DR**：本文件列 IO 单元最常见错误，按发生频率排序。每条按 L-012 两层结构（先引导贴现场，再展开通用原因）+ L-008 贴出 abort 触发代码（如适用）。

---

## A. plotfile 不出（最高频）

### Step 0：引导贴现场

按 L-012，先要用户提供：

```
请贴以下信息以便诊断：

1. 日志末尾 50 行（找 "Wrote plotfile" / "Wrote checkpoint"）：
   tail -50 01-data/<basenm>*.log

2. parfile IO 段（确认触发条件设了）：
   grep -E "plotFile|checkpointFile|basenm|summaryOutput" flash.par

3. setup 命令（确认 IO backend 编译进去了）：
   cat cases/<case>/setup_call | grep -i "io\|hdf5"

4. 输出目录现状（确认文件确实不存在）：
   ls -la 01-data/
```

### Step 1：通用原因列表

| 原因 | 检查 | 修复 |
|---|---|---|
| **`plotFileIntervalStep=0` + `plotFileIntervalTime=1.`**（默认值） | `grep plotFileInterval flash.par` | 设 `plotFileIntervalStep=100`（或 `plotFileIntervalTime=1.0e-11`）|
| **`plot_var_1="none"`**（默认值，写空 plotfile） | 日志找 "WARNING: you have called IO_writePlotfile but no plot_vars are defined" | 设 `plot_var_1 = "dens"` 等 |
| **`summaryOutputOnly=.true.`** | `grep summaryOutputOnly flash.par` | 改 `.false.` |
| **`plotFileIntervalTime` 单位错** | HEDP simTime 单位是秒（典型 1e-9），若设 `1.0`（默认）永不触发 | 改 `1.0e-11`（10 ps） |
| **`.dump_plotfile` 触发文件不存在**（用户期望手动触发） | `ls -la .dump_plotfile` | `touch .dump_plotfile` |
| **算例还没跑到触发步** | `grep nstep 01-data/<basenm>.log` | 等到 nstep 达到 plotFileIntervalStep |
| **plotFileIntervalStep 不是 nstep 的因子** | 检查 `mod(nstep, plotFileIntervalStep) == 0` 是否会触发 | 不必因子（nextPlotFileStep 推进），但若 step 跨过则靠 nextPlotFileTime 兜底 |

### Step 2：源码确认

源码：`source/IO/IOMain/IO_output.F90:L366-L368`

```fortran
! source/IO/IOMain/IO_output.F90:L366-L368
if (((nstep == io_nextPlotFileStep) .OR. &
     (io_plotFileIntervalTime > 0.e0 .AND. simTime >= io_nextPlotfileTime) .OR. &
     (io_plotFileIntervalZ < HUGE(1.) .AND. currentRedshift <= io_nextPlotFileZ)) .and. outputPlotfile) then
```

三个条件都 false → 不出。

源码（plot_var 空 warning）：`source/IO/IOMain/IO_writePlotfile.F90:L119-L124`

```fortran
! source/IO/IOMain/IO_writePlotfile.F90:L119-L124
if((io_nPlotVars == 0) .and. (io_globalMe == MASTER_PE)) then
   print *, "WARNING: you have called IO_writePlotfile but no plot_vars are defined."
   print *, 'Put the vars you want in the plotfile in your flash.par (plot_var_1 = "dens")'
end if
```

---

## B. NXB in checkpoint does not match this executable

### Step 0：引导贴现场

```
请贴以下信息：

1. 完整错误信息（含 [io_checkBlockShape] 前缀）：
   grep -B 2 -A 5 "NXB in checkpoint" 01-data/<basenm>.log

2. 原始 setup 命令（写 chk 的那次）：
   cat <原始 case>/setup_call | grep -E "nxb|nyb|nzb|2d|3d"

3. 当前 setup 命令（restart 的这次）：
   cat <restart case>/setup_call | grep -E "nxb|nyb|nzb|2d|3d"

4. chk 文件里的 NXB（用 h5dump 读）：
   h5dump -A -g "scalars" <basenm>_hdf5_chk_<NNNN> | grep -A 2 nxb
```

### Step 1：原因（基本只有一个）

restart 时**当前可执行文件的 NXB / NYB / NZB 编译时常量**和**chk 文件里存的 NXB / NYB / NZB** 不一致。

典型场景：

- 原 run：`./setup ... -2d -nxb=16 -nyb=16 ...`
- restart：`./setup ... -2d -nxb=8 -nyb=8 ...`（忘了改）

### Step 2：源码（触发 abort 的 if）

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

### Step 3：修复

restart 时用**和原 run 完全相同**的 setup 选项：

```bash
./setup LaserSlab -2d -auto +cylindrical -nxb=16 -nyb=16 \
        +hdf5typeio \
        species=cham,targ +mtmmmt +laser +uhd3t +mgd mgd_meshgroups=6 \
        -objdir=cases/LaserSlab_restart
```

**注意**：维度（`-2d` / `-3d`）、block size（`-nxb/-nyb/-nzb`）、setup 变量（`+laser` / `+mgd` 等）都要一致。若改了任何 -D 编译选项，可能 unk 数（NUNK_VARS）也对不上 → 别的 abort。

---

## C. num blocks per proc exceeds maxblocks

### Step 0：引导贴现场

```
请贴以下信息：

1. 完整错误信息（含 [io_readData]）：
   grep -B 5 "num blocks per proc exceeds" 01-data/<basenm>.log

2. globalNumBlocks 和 io_meshNumProcs（错误信息会打这两个值）

3. 当前 setup 的 maxBlocks：
   grep -i maxBlocks cases/<case>/setup_call
```

### Step 1：原因

restart 时全局 block 数除以进程数 +1 > MAXBLOCKS（编译时常量）。

```
alnblocks = int(gr_globalNumBlocks / io_meshNumProcs) + 1
if (alnblocks > MAXBLOCKS) → abort
```

例：

- 原 run：10000 blocks，100 进程，maxBlocks=200 → alnblocks = 10000/100+1 = 101 < 200 ✓
- restart：10000 blocks，50 进程 → alnblocks = 10000/50+1 = 201 > 200 ✗ abort

### Step 2：源码（触发 abort 的 if）

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

### Step 3：修复

选项 A：增加 maxBlocks（重新 setup）

```bash
./setup ... -maxBlocks=500 ...
```

选项 B：增加进程数

```bash
mpirun -np 200 ./flash4 -par_file=flash.par    # 原 100 → 200
```

---

## D. HDF5 库冲突 / 链接错误

### Step 0：引导贴现场

```
请贴以下信息：

1. 链接错误完整信息：
   make -j4 2>&1 | grep -i "hdf5\|undefined"

2. HDF5 库版本：
   grep HDF5_PATH cases/<case>/Makefile.h
   ls -la ${HDF5_PATH}/lib

3. flash4 链接的 HDF5：
   ldd cases/<case>/flash4 | grep hdf5

4. 系统是否有冲突的 HDF5：
   find / -name "libhdf5*.so*" 2>/dev/null
```

### Step 1：常见原因

| 错误信息 | 原因 | 修复 |
|---|---|---|
| `undefined reference to H5Fcreate` | HDF5 库没链接 | Makefile.h 加 `-lhdf5 -lz` |
| `H5_USE_16_API` warning | API 版本不匹配 | Makefile.h CFLAGS 加 `-DH5_USE_16_API` |
| `libhdf5.so.103 vs libhdf5.so.100` | 系统 HDF5 vs 用户 HDF5 冲突 | `LD_LIBRARY_PATH=${HDF5_PATH}/lib:$LD_LIBRARY_PATH` |
| `HDF5-DIAG: H5Fcreate failed` | 文件系统问题 / 权限 | 检查 `output_directory` 是否存在 + 可写 |
| `unable to initialize hdf5 file` | HDF5 库初始化失败 | 见下 io_initFile abort |

### Step 2：源码（io_initFile abort）

源码：`source/IO/IOMain/hdf5/parallel/io_initFile.F90:L57-L60`

```fortran
! source/IO/IOMain/hdf5/parallel/io_initFile.F90:L57-L60
call io_h5init_file(fileID, filename, io_comm, io_outputSplitNum, existing)
if(fileID == -1) then
   print *, "Error: unable to initialize file"
   call Driver_abortFlash("unable to initialize hdf5 file")
end if
```

### Step 3：HDF5 parallel vs serial 校验

HDF5 库编译时必须启用 parallel：

```bash
# 检查：
h5cc -showconfig | grep Parallel
# 应输出：Parallel HDF5: yes
```

若 `no`，重装 HDF5：

```bash
./configure --enable-parallel --prefix=${HDF5_PATH}
make && make install
```

### Step 4：本机 libmpi 冲突（参考 note.txt）

CLAUDE.md 提到的本机问题：

```bash
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak
make -j4
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40
```

详见 `skills/flash-pitfall-finder/knowledge/pitfalls/` 或 `note.txt`（系统级问题，非本 skill 范围）。

---

## E. mod(io_meshNumProcs, io_outputSplitNum) /= 0

### Step 0：引导贴现场

```
请贴 parfile 的 outputSplitNum 和 mpirun -np：
grep outputSplitNum flash.par
grep "np" run_script.sh
```

### Step 1：原因

用了 `outputSplitNum > 1`（多文件输出），但进程数不能整除 `outputSplitNum`。

例：`outputSplitNum=4`，进程数 6 → `mod(6, 4) = 2 != 0` → abort。

### Step 2：源码

源码：`source/IO/IOMain/IO_init.F90:L311-L313`

```fortran
! source/IO/IOMain/IO_init.F90:L311-L313
if((mod(io_meshNumProcs, io_outputSplitNum) /= 0)) then
   call Driver_abortFlash('mod(io_meshNumProcs, io_outputSplitNum) /= 0!')
end if
```

### Step 3：修复

选项 A：进程数整除 outputSplitNum

```
outputSplitNum = 4
mpirun -np 8 ./flash4 ...        # mod(8, 4) = 0 ✓
```

选项 B：关 outputSplitNum

```
outputSplitNum = 1               # 单文件输出（HEDP 主流）
```

---

## F. Unused UNK due to NONREP

### Step 0：引导贴现场

```
请贴日志（找 "Unused UNK" 详细信息）：
grep -B 2 -A 20 "Unused UNK" 01-data/<basenm>.log
```

### Step 1：原因

用了 mesh replication（NONREP 变量数组）但 IO backend 不支持 / 配置不对。

典型场景：

- Config 里声明了 `NONREP MGDR ... rt_mgdNumGroups`（MGD 多群扩散用）
- 但 `rt_mgdNumGroups` 配置和 NONREP 声明的不一致
- 或用了 serial IO（不支持 mesh replication）

### Step 2：源码

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
     call Logfile_stamp('Possible Solutions:')
     call Logfile_stamp('1) Try using parallel IO (+parallelIO in setup line)')
     call Logfile_stamp('2) Remove NONREP config file commands')
     call Logfile_stamp('3) Make sure that number of unks in use matches the global NONREP array size.')
     call Logfile_stamp('   For example, when using, MGD, make sure that rt_mgdNumGroups is equal to ')
     call Logfile_stamp('   meshCopyCount*{number of local MGDR NONREPs} This number comes from the MGDR ')
     call Logfile_stamp('   NONREP command in Config File')
     call Driver_abortFlash('[' // FILE_AT_LINE // '] ERROR: Unused UNK ' // & 
          'due to NONREP Config directive and IO unit. LOOK AT THE LOG FILE.')
  end if
```

### Step 3：修复

按日志提示 3 个选项：

1. **加 parallel IO**：setup 加 `+parallelIO` 或 `+hdf5typeio`
2. **删 NONREP 配置**：从 Config 移除非 NONREP 变量声明
3. **改 rt_mgdNumGroups**：让 mgdNumGroups = meshCopyCount × (NONREP 数)

---

## G. checkpoint 文件损坏 / restart 读到一半失败

### Step 0：引导贴现场

```
请贴以下信息：

1. restart 错误（找 HDF5-DIAG）：
   grep -A 10 "HDF5-DIAG\|H5Dread\|io_readData" 01-data/<basenm>.log

2. chk 文件大小（是否被截断）：
   ls -la 01-data/<basenm>_hdf5_chk_<NNNN>

3. 用 h5dump 验证文件结构：
   h5dump -H 01-data/<basenm>_hdf5_chk_<NNNN> 2>&1 | head -50
```

### Step 1：原因

| 原因 | 现象 | 修复 |
|---|---|---|
| **chk 写入时算例被 kill**（中断） | 文件截断 / h5dump 报错 | 用上一个 chk（如 chk_0014 而不是 chk_0015）|
| **磁盘满** | 写入中途磁盘空间不足 | 清盘 / 换盘 |
| **NFS 延迟**（集群共享盘） | h5dump 报 metadata 错 | sync 后重试 / fsck |
| **HDF5 库版本不兼容** | h5dump 报 file format version 不识别 | 用相同 HDF5 版本读 |
| **fileFormatVersion 不匹配**（老 chk） | io_readData 走兼容路径失败 | 不能跨大版本 restart（如 v7 → v9）|

### Step 2：诊断

```bash
# 用 h5dump 看 chk 头
h5dump -H 01-data/<basenm>_hdf5_chk_<NNNN>

# 应输出类似：
# HDF5 "lasslab_hdf5_chk_0015" {
# GROUP "/" {
#    ATTRIBUTE "file_format_version" { DATATYPE  H5T_STD_I32BE; DATASIZE 4 }
#    ATTRIBUTE "setup_call" { ... }
#    DATASET "dens" { DATATYPE ...; DATASPACE (16, 16, 1, 1234) }
#    ...
# }
```

若 `h5dump` 报错 → 文件损坏，必须用上一个 chk。

### Step 3：预防

- 用 `rolling_checkpoint = 10`（保留 10 个 chk，损坏 1 个还有 9 个）
- 关键算例用 `wall_clock_checkpoint` 频繁 dump
- 不要在写入时 `kill -9`（用 `.dump_restart` 优雅退出）

---

## H. plotfile 写出但 yt 读不到变量

### Step 0：引导贴现场

```
请贴：

1. plotfile 文件存在性：
   ls -la 01-data/<basenm>_hdf5_plt_cnt_*

2. yt 报错信息：
   python -c "import yt; ds = yt.load('01-data/<basenm>_hdf5_plt_cnt_0001'); print(ds.field_list)"

3. plotfile 里的变量名：
   h5dump -H 01-data/<basenm>_hdf5_plt_cnt_0001 | grep DATASET
```

### Step 1：原因

| 原因 | 现象 | 修复 |
|---|---|---|
| **plot_var 名拼错**（如 "Dens" 不是 "dens"）| yt field_list 里没这个 | parfile 改小写 "dens"（IO_init 自动小写，但 unk 名本身必须匹配）|
| **plot_var 不是 unk 名** | IO_init 打 warning "ignoring unrecognized plot variable" | 用 `Simulation_mapStrToInt` 能识别的名字 |
| **plotfile 是空的**（plot_var_1="none"）| yt 看到 0 个 unk dataset | parfile 设 plot_var_1 |
| **yt 版本太老**（不认 file format 9）| yt 报 unsupported | 升级 yt（>4.0） |

### Step 2：源码（plot_var 解析）

源码：`source/IO/IOMain/IO_init.F90:L241-L258`

```fortran
! source/IO/IOMain/IO_init.F90:L249-L258
j = 0
do i=1, io_maxPlotVars
   if(any(io_plotVarStr(i) == io_unklabelsGlobal)) then    ! 必须在 unk 列表
      j = j + 1
      call Simulation_mapStrToInt(trim(io_plotVarStr(j)), io_plotVar(j), MAPBLOCK_UNK)
   else
      if (io_plotVarStr(i) .NE. "none") &
           call Logfile_stamp(io_plotVarStr(i),"[IO_init] ignoring unrecognized plot variable")
   end if
end do
io_nPlotVars = j
```

### Step 3：修复

- 日志找 "ignoring unrecognized plot variable" → 改 plot_var 名
- 用 `h5dump -H` 看实际写出的变量名
- 确认 unk 名（看 unklabels）：`h5dump -A -g "scalars" *.chk | grep unklabel` 或参考 `source/IO/IOMain/IO_data.F90:L147`

---

## I. checkpoint 写入很慢（性能调优）

### Step 0：引导贴现场

```
请贴：

1. IO 时间统计（看 Timers 报告）：
   grep -E "writeCheckpoint|writePlotfile|checkpointing" 01-data/<basenm>.log | tail -20

2. 进程数 / block 数：
   grep "globalNumBlocks\|meshNumProcs" 01-data/<basenm>.log

3. 当前 IO 配置：
   grep -E "useCollective|outputSplitNum|packMesh" flash.par
```

### Step 1：性能优化清单

| 调整 | 效果 | 代价 |
|---|---|---|
| **用 `+hdf5typeio`**（PM_argonne）| 5-10x 快 | 需 MPI datatype 支持 |
| **`useCollectiveHDF5 = .true.`**（默认） | collective IO 快 | NoFBS UG 会强制 false |
| **`packMeshPlotWriteHDF5 = .true.`**（默认） | plotfile 写快 | 多一份内存拷贝 |
| **`packMeshChkWriteHDF5 = .true.`**（默认 false） | checkpoint 写快 | 双精度大，内存压力大 |
| **`outputSplitNum > 1`** | 多文件并行写 | restart 管理复杂 |
| **关 `chkGuardCellsOutput`**（默认 false）| 文件小 30% | 不能调试 guard cell |
| **关 `alwaysComputeUserVars`** | 省计算 | user var 不在 plotfile |

### Step 2：典型 HEDP 配置（最优）

```
# setup
+hdf5typeio                                  # PM_argonne

# parfile
useCollectiveHDF5         = .true.           # 默认
packMeshPlotWriteHDF5     = .true.           # 默认（plotfile 小）
packMeshChkWriteHDF5      = .false.          # 默认（chk 大，不 pack）
chkGuardCellsOutput       = .false.          # 默认（不写 guard cell）
outputSplitNum            = 1                # 单文件（HEDP 够用）
```

---

## J. 延伸阅读

- **IO_output 流程 / io_writeData 内部**：`knowledge/internals.md`
- **参数完整字典**：`knowledge/params.md`
- **典型 parfile 配置**：`knowledge/recipes.md`
- **Driver 主循环（IO_output 在哪被调）**：`flash-driver` skill
- **错误匹配（按错误信息）**：`flash-pitfall-finder` skill

---

## K. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（draft）：10 段 pitfalls + plotfile 不出 + NXB 不匹配 + maxblocks 超 + HDF5 库冲突 + outputSplitNum 整除 + NONREP unused UNK + chk 损坏 + yt 读不到变量 + 性能调优；按 L-012 引导贴现场 + L-008 贴 abort 源码（io_checkBlockShape / io_initFile / io_readData / IO_init NONREP / IO_init outputSplitNum）+ L-013 主流在前（plotfile 不出最高频）| claude |
