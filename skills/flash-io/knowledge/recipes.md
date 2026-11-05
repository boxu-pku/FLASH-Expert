---
title: IO 典型配置 — HDF5 setup + parfile 输出控制 + checkpoint 策略 + restart 续跑
skill: flash-io
category: recipes
source_anchors:
  - source/Simulation/SimulationMain/LaserSlab/example.par:L14-L34
  - source/Simulation/SimulationMain/Sedov/flash.par:L78
  - source/IO/IOMain/Config:L52-L243
  - source/IO/IOMain/hdf5/parallel/PM_argonne/Config:L1-L20
  - cases/LaserSlab/setup_call:L1-L20
manual_ref: "FLASH 4.8 User Guide §10"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: draft
tags:
  - io
  - recipes
  - parfile
  - restart
---

# IO 典型配置（按 L-013 聚焦 HDF5 parallel 主流）

> **TL;DR**：按"教学顺序"组织（L-004）：最小可运行 → LaserSlab 典型 → 特殊（forced plotfile）→ 进阶（restart 续跑 / rolling / 多文件输出）。每个 recipe 标"适用场景"让用户按需选。

---

## 1. Recipe 0：最小可运行配置（HDF5 parallel + 默认值）

**适用场景**：新用户从 Sedov / LaserSlab 上手，希望最快出图。

### 1.1 setup 命令

```bash
# 标准 PM parallel（不带 typeIO）
./setup Sedov -auto -objdir=cases/Sedov +parallelIO

# LaserSlab + type-based parallel HDF5（PM_argonne，HEDP 主流）
./setup LaserSlab -2d -auto +cylindrical -nxb=16 -nyb=16 \
        +hdf5typeio \
        species=cham,targ +mtmmmt +laser +uhd3t +mgd mgd_meshgroups=6 \
        -objdir=cases/LaserSlab -parfile=example.par
```

**`+hdf5typeio` 的作用**（按 L-011 讲为什么）：

- 设 setup 变量 `typeIO = True`
- 触发 `source/IO/IOMain/hdf5/parallel/PM_argonne/Config` 的 `IF typeIO DEFAULT PM_argonne`
- 选 type-based parallel HDF5（用 MPI datatype 描述数据布局）
- 比 PM 标准 parallel 快 5-10x（HEDP 大算例 IO 时间从分钟降到秒）

### 1.2 最小 parfile

```
# IO 控制
basenm                = "myrun_"
output_directory      = "01-data/"

# 输出频率（HEDP 用户必设）
plotFileIntervalStep      = 100
plotFileIntervalTime      = 1.0e-11          # 10 ps（备份）
checkpointFileIntervalStep = 1000
checkpointFileIntervalTime = 1.0             # 默认值，不触发（HEDP simTime 远到不了）

# plot 变量（最多 12 个）
plot_var_1  = "dens"
plot_var_2  = "pres"
plot_var_3  = "tele"
plot_var_4  = "tion"
plot_var_5  = "velx"
plot_var_6  = "vely"

# restart 控制
restart              = .false.
checkpointFileNumber = 0
plotFileNumber       = 0
```

### 1.3 输出文件结构

跑完后 `01-data/` 下：

```
01-data/
├── myrun_hdf5_chk_0000         # checkpoint 0（初始）
├── myrun_hdf5_chk_0001         # checkpoint 1（每 1000 步）
├── myrun_hdf5_plt_cnt_0000     # plotfile 0（初始）
├── myrun_hdf5_plt_cnt_0001     # plotfile 1（每 100 步）
├── myrun_hdf5_plt_cnt_0002
├── ...
└── myrun.dat                   # 全局积分量（每步一行）
```

---

## 2. Recipe 1：LaserSlab 标准 IO 配置（HEDP 主流）

**适用场景**：HEDP 激光算例的标准输出配置（参考 `source/Simulation/SimulationMain/LaserSlab/example.par:L14-L34`）。

### 2.1 setup

```bash
./setup LaserSlab -2d -auto +cylindrical -nxb=16 -nyb=16 \
        +hdf5typeio \
        species=cham,targ +mtmmmt +laser +uhd3t +mgd mgd_meshgroups=6 \
        -objdir=cases/LaserSlab -parfile=example.par
```

### 2.2 parfile（IO 部分）

参考 `source/Simulation/SimulationMain/LaserSlab/example.par:L1-L34`：

```
# 文件名 / 日志
run_comment = "Laser Slab Example Simulation"
log_file    = "lasslab.log"
basenm      = "lasslab_"

### Checkpoint Options ###
checkpointFileIntervalTime = 1.0              # 默认值（HEDP 不触发）
checkpointFileIntervalStep = 1000             # 每 1000 步

### Plot Options ###
plotFileNumber       = 0
plotFileIntervalStep = 100
plotFileIntervalTime = 0.01e-09               # 10 ps（备份触发）

# HEDP 标准可视化变量（9 个）
plot_var_1           = "dens"                 # 密度
plot_var_2           = "depo"                 # 激光沉积率
plot_var_3           = "tele"                 # 电子温度
plot_var_4           = "tion"                 # 离子温度
plot_var_5           = "trad"                 # 辐射温度
plot_var_6           = "ye  "                 # 电子分数（注意空格补 4 字符）
plot_var_7           = "sumy"                 # 总离子数密度
plot_var_8           = "cham"                 # cham 物质分数
plot_var_9           = "targ"                 # targ 物质分数

### Restart Options ###
restart              = .false.
checkpointFileNumber = 0
```

### 2.3 为什么这样配（按 L-011 讲为什么）

- **checkpointFileIntervalStep = 1000**：每 1000 hydro 步出一个 chk。LaserSlab 典型跑 10k-100k 步，总共 10-100 个 chk，磁盘可承受。
- **plotFileIntervalStep = 100**：每 100 步出一个 plotfile（比 chk 密 10x）。可视化用。
- **plotFileIntervalTime = 0.01e-09**：simTime 备份触发（防 step 跳过时间点）。
- **plot_var_6 = "ye  "**：FLASH unk 名固定 4 字符（`useLegacyLabels=TRUE`），`ye` 后补 2 空格。
- **plot_var 不含 sumy 之外的 mass scalar 积分**：用 `io_writeMscalarIntegrals = .false.`（默认）让 flash.dat 只 7 基础量。

### 2.4 跑

```bash
cd cases/LaserSlab
make -j4
./flash4 -par_file=flash.par
```

---

## 3. Recipe 2：checkpoint 策略（防数据丢失）

**适用场景**：长时间算例（> 12 小时），希望墙钟触发 + RSS 限制保护数据。

### 3.1 parfile（追加）

```
# 墙钟触发（防 SLURM 队列到期）
wall_clock_checkpoint = 36000.                # 10 小时（SLURM 12h 队列留 2h 缓冲）

# RSS 限制（防内存吃爆节点）
memory_stat_freq      = 100                   # 每 100 步打内存统计
rss_limit             = 60000.                # RSS 超 60 GB → 写 chk 后退出（MB 单位）

# 滚动 checkpoint（磁盘紧张时）
rolling_checkpoint    = 10                    # 只保留最近 10 个 chk
```

### 3.2 触发逻辑

源码：`source/IO/IOMain/IO_output.F90:L293-L356` + `L526-L562`

```
每 hydro 步后 IO_output 检查：
├── wall_clock_checkpoint：MASTER_PE 测 MPI_Wtime() - io_lastWallClockCheckpoint
│   若 > wall_clock_checkpoint → 强制写 chk，更新 lastWallClock
├── memory_stat_freq：每 N 步打内存（io_memoryReport）
│   若 RSS >= rss_limit → 写 chk + endRun=.true.（退出）
```

### 3.3 为什么这样设值

- **wall_clock_checkpoint < queue 总时间**：留缓冲让 FLASH 正常退出（write chk + close log）
- **rss_limit < 节点物理内存**：留 OS 缓冲（典型留 20-30%）
- **rolling_checkpoint 适度**：太小（如 3）若算例崩溃可能丢最近；太大（如 1000）磁盘吃紧

---

## 4. Recipe 3：restart 续跑

**适用场景**：算例被队列杀死 / 用户主动 `.dump_restart` 后，从最后一个 chk 继续。

### 4.1 setup（关键：和原 run 完全一致）

```bash
# 必须用相同的 -2d / -nxb / -nyb / -nzb / species / +laser / ...
./setup LaserSlab -2d -auto +cylindrical -nxb=16 -nyb=16 \
        +hdf5typeio \
        species=cham,targ +mtmmmt +laser +uhd3t +mgd mgd_meshgroups=6 \
        -objdir=cases/LaserSlab_restart
```

**为什么必须一致**（按 L-011）：

- NXB / NYB / NZB 是编译时常量（setup `-nxb=16` → `#define NXB 16`）
- restart 时 `io_checkBlockShape`（`source/IO/IOMain/io_checkBlockShape.F90:L39-L41`）会校验：
  ```
  if (fileNxb .NE. NXB) call Driver_abortFlash("NXB in checkpoint does not match this executable!")
  ```
- 编译选项不同 → abort

### 4.2 parfile（restart 配置）

```
### Restart Options ###
restart              = .true.                 # ★ 开启 restart
checkpointFileNumber = 15                     # ★ 要读的 chk 编号（flash_hdf5_chk_0015）

# 输出编号续接（不要重置！）
plotFileNumber       = 7                      # plotfile 从 8 开始（不覆盖之前）
                                                      # 实际重启后 plot 编号会 +1
                                                      # ↑ 见 IO_init.F90:L93-L95

# 输出频率（保持和原 run 一致）
plotFileIntervalStep      = 100
checkpointFileIntervalStep = 1000
```

### 4.3 跑

```bash
cd cases/LaserSlab_restart
# 把原 run 的 chk 文件链接 / 拷贝过来
cp ../LaserSlab/lasslab_hdf5_chk_0015 .
# 跑
./flash4 -par_file=flash.par
```

### 4.4 自动 restart（appendParRestart）

源码：`source/IO/IOMain/IO_writeCheckpoint.F90:L124-L141`

如果想全自动续跑（不需要手动改 parfile）：

```
appendParRestart = .true.
```

每次写 chk 后会**自动追加**到 parfile：

```
### BEGIN written by [IO_writeCheckpoint] ###
restart = .true.
checkpointFileNumber = 0015
plotFileNumber = 0007
### END written by [IO_writeCheckpoint] ###
```

下次跑同一个 parfile 就会自动 restart。

**为什么默认 false**：用户可能希望 parfile 保持不变（template 用）。

---

## 5. Recipe 4：触发文件控制（运行时干预）

**适用场景**：算例正在跑，用户想中途出 plotfile / 强制 chk / 杀掉。

### 5.1 触发文件清单

源码：`source/IO/IOMain/IO_output.F90:L422-L595`

| 文件 | 动作 | 创建命令 |
|---|---|---|
| `.dump_plotfile` | 写 forced plotfile（编号 9999）后继续 | `touch .dump_plotfile` |
| `.dump_checkpoint` | 写 checkpoint（编号 9999）后继续 | `touch .dump_checkpoint` |
| `.dump_restart` | 写 checkpoint 后**退出**（endRun=.true.） | `touch .dump_restart` |
| `.kill` | **立即退出**（不写 chk） | `touch .kill` |

### 5.2 实战场景

**场景 A：SLURM 队列快到期**

```bash
# 提交脚本里设：在 walltime 前 30 分钟触发
sbatch --time=12:00:00 my_script.sh

# my_script.sh 末尾：
( sleep $((11*3600 + 30*60)) && touch .dump_restart ) &
./flash4 -par_file=flash.par
```

FLASH 在 11.5 小时后下个 hydro 步检查到 `.dump_restart`，写 chk 后正常退出。

**场景 B：用户想看当前状态出图**

```bash
cd cases/LaserSlab
touch .dump_plotfile
# 下一个 hydro 步（可能几秒-几分钟后）就会出 forced_hdf5_plt_cnt_0000
```

**场景 C：算例跑飞了，立即停**

```bash
touch .kill
# 下一个 hydro 步立刻退出，不写 chk（数据丢失，慎用）
```

更安全：用 `.dump_restart`（写完 chk 才退）。

### 5.3 触发文件检测频率

源码：`source/IO/IOMain/IO_output.F90:L422-L428`

```fortran
if (io_globalMe == MASTER_PE) then
   inquire(file = ".dump_plotfile", EXIST=dumpPlotfileExist)
end if

call MPI_Bcast(dumpPlotfileExist, 1, MPI_LOGICAL, MASTER_PE, io_globalComm, ierr)
```

**关键**：

- 仅 MASTER_PE 检测（避免 N 个进程各自看不同文件系统）
- 每 hydro 步后检查一次（不是每秒）
- 所以响应延迟 = 1 个 hydro 步（典型 ms-s）

### 5.4 强制 plotfile 的特殊编号

源码：`source/IO/IOMain/IO_writePlotfile.F90:L135-L139` + `L169-L173`

```
if(fileIsForced) then
   call io_initFile( io_forcedPlotFileNumber, fileID, filename, '_plt_cnt_', fileIsForced)
else
   call io_initFile( io_plotFileNumber, fileID, filename, '_plt_cnt_', fileIsForced)
end if
```

forced plotfile 用 `forcedPlotFileNumber`（默认 0），文件名前缀加 `forced_`：

```
forced_lasslab_hdf5_plt_cnt_0000      ← 第一次 .dump_plotfile
forced_lasslab_hdf5_plt_cnt_0001      ← 第二次
```

不覆盖正常序列（`lasslab_hdf5_plt_cnt_0000` ...）。

---

## 6. Recipe 5：debugging 配置

**适用场景**：调试 IO 问题（plotfile 不出 / chk 损坏 / 性能调优）。

### 6.1 全 IO 日志打开

```
# 强制每次写 chk 都 restrict（防数据不一致）
alwaysRestrictCheckpoint = .true.              # 默认 true，不要改

# 写 guard cell 到 chk（调试用，文件大 30%）
chkGuardCellsOutput = .true.                   # 仅 PM parallel 支持

# 双精度 plotfile（精度问题排查，文件 2x）
plotfileGridQuantityDP = .true.
plotfileMetadataDP     = .true.

# 内存统计每步打
memory_stat_freq = 1
```

### 6.2 dry-run（只写 flash.dat，不出文件）

```
summaryOutputOnly = .true.
```

源码：`source/IO/IOMain/IO_init.F90:L515-L542`

效果：

- 强制 `io_nextPlotFileStep = -1`（永不触发）
- 强制 `io_nextCheckpointStep = -1`
- 强制 `io_wallClockCheckpoint = -1.0`
- 仅 `.dump_*` 触发文件还能用

**用途**：调 hydro 收敛性时省盘（只看 flash.dat 时序）。

### 6.3 collective IO 切回 independent（调试）

```
useCollectiveHDF5 = .false.
```

如果怀疑 collective IO 有 bug（如 HDF5 版本问题），切回 independent（慢但稳定）。

### 6.4 调试 type-based IO

```
# 关 typeIO，切回 PM 标准（更稳定但慢）
# setup 不加 +hdf5typeio，改用 +parallelIO
./setup LaserSlab -2d +parallelIO +cylindrical -nxb=16 -nyb=16 ...
```

---

## 7. Recipe 6：进阶 - outputSplitNum（多文件输出，HEDP 罕用）

**适用场景**：超大算例（10⁵+ blocks），单文件 IO 太慢；多文件并行写。

### 7.1 parfile

```
outputSplitNum = 4                            # 每 4 进程写一个文件（总进程数必须整除 4）
```

### 7.2 约束

源码：`source/IO/IOMain/IO_init.F90:L311-L313`

```fortran
if((mod(io_meshNumProcs, io_outputSplitNum) /= 0)) then
   call Driver_abortFlash('mod(io_meshNumProcs, io_outputSplitNum) /= 0!')
end if
```

进程数必须整除 `outputSplitNum`。

### 7.3 输出文件

```
01-data/
├── myrun_s0000_hdf5_chk_0000      # 进程 0-3 写
├── myrun_s0001_hdf5_chk_0000      # 进程 4-7 写
├── myrun_s0002_hdf5_chk_0000      # 进程 8-11 写
├── myrun_s0003_hdf5_chk_0000      # 进程 12-15 写
```

restart 时需要所有 split 文件都在。

### 7.4 为什么 HEDP 不用

- HEDP 算例典型 10²-10⁴ blocks，单文件够快（PM_argonne collective IO）
- 多文件管理复杂（restart 时漏一个文件就崩）
- 仅 10⁵+ blocks 大算例才有收益

---

## 8. Recipe 7：自定义 plot 变量

### 8.1 用 plot_grid_var_N 写 scratch grid var

源码：`source/IO/IOMain/IO_init.F90:L273-L302`

如果用户在 Config 里声明了 GRIDVAR（scratch grid var）：

```
# 在 Simulation Config 或 source/Simulation/SimulationMain/MyCase/Config
GRIDVAR vrtz                       # 声明一个 scratch grid var
```

然后 parfile：

```
plot_grid_var_1 = "vrtz"
```

这样 `vrtz` 会写到 plotfile。

### 8.2 用 IO_setScalar 写自定义标量

源码：`source/IO/IOMain/IO_setScalar.F90`

如果用户想往 chk 写一个自定义标量（如某个时间积分量）：

```fortran
! 在 Simulation_init.F90 或类似 hook 里：
call IO_setScalar("my_total_deposition", my_value)
```

这个标量会写到 chk 的 `/scalars` 组，restart 时用 `IO_getPrevScalar("my_total_deposition", val)` 读。

### 8.3 用 IO_writeUserArray 写自定义数组

源码：`source/IO/IO_writeUserArray.F90`

用户可实现 `IO_writeUserArray` subroutine，往 chk 写额外数组（如激光束参数表）。详见 StirTurb 算例的实现。

---

## 9. 延伸阅读

- **IO 参数完整字典**：`knowledge/params.md`
- **IO_output 内部流程**：`knowledge/internals.md`
- **常见错误**：`knowledge/pitfalls.md`
- **物理单元 parfile 参考**：`source/Simulation/SimulationMain/LaserSlab/example.par`
- **Sedov 简单 parfile**：`source/Simulation/SimulationMain/Sedov/flash.par:L78`

---

## 10. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（draft）：9 段 recipes + 最小配置 + LaserSlab 标准 + checkpoint 策略（wall_clock/rss/rolling）+ restart 续跑（NXB 一致性 + appendParRestart）+ 触发文件（4 种 + 实战场景）+ debugging 配置 + outputSplitNum + 自定义 plot var；按 L-004 教学顺序（最小→典型→特殊→进阶）+ L-013 聚焦 LaserSlab 主流 + L-011 讲为什么这样配 | claude |
