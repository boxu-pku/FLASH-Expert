---
title: run 阶段完整指南——flash_env.sh + mpirun + 日志解析 + restart
skill: flash-case-runner
category: run
source_anchors:
  - flash_env.sh
  - skills/flash-pitfall-finder/knowledge/pitfalls/libmpi-conflict.md
  - skills/flash-pitfall-finder/knowledge/pitfalls/mpi-errors.md
  - source/Driver/DriverMain/Driver_evolveFlash.F90
  - source/Driver/DriverMain/Driver_abortFlash.F90
---

# run 阶段完整指南
> 路径约定：`$FLASH_ROOT` = FLASH 4.8 仓库根目录（本机 `$FLASH_ROOT`）；`$FLASH_LIBS` = 外部库根目录（本机 `$FLASH_LIBS`，含 mpich/hdf5/hypre）。其它机器按实际路径替换。


> 本文讲 FLASH 算例生命周期的**第三、四阶段**：run + restart。
>
> 按 L-015，先讲 run 的完整故事线，再讲细节。
>
> 按 L-012，所有错误诊断先引导贴现场。

## 1. run 的完整故事线

### 1.1 run 是什么

"run" = 用 `mpirun` 启动 `flash4`，让它读 parfile、初始化、按时间步推进模拟、定期写 plotfile/checkpoint。

### 1.2 run 的端到端旅程

```
1. 用户 cd cases/<case>/01-data（硬约束：CWD=01-data，所有输出落这里）
   ↓
2. source flash_env.sh（本机必需，设 LD_PRELOAD）
   ↓
3. mpirun -np 2 ../flash4 -par_file ../flash.par
   ↓
3. MPI 初始化（MPI_COMM_WORLD 建立）
   ↓ 这里曾出 SIGSEGV（libmpi 冲突）—— flash_env.sh 解决
4. Driver_initFlash()
   ├── 读 flash.par（所有 runtime parameter）
   ├── Grid 初始化（创建 block、设几何）
   ├── Multispecies 初始化（物质定义）
   ├── EOS 初始化（读表、EOS_MODE 设定）
   ├── Opacity 初始化（读 .imx 表）
   ├── Conductivity 初始化
   ├── MGD 初始化（HYPRE setup）
   ├── EnergyDeposition 初始化（激光束）
   ├── IO 初始化（plotfile 路径）
   └── Simulation_init（算例特定初始化：密度/温度/速度场）
5. Driver_evolveFlash()（主循环）
   while (simTime < sim_maxTime .and. nstep < sim_maxSteps):
       1. Driver_computeDt（取 CFL/HX/Laser 等最小 dt）
       2. Hydro（解 Euler 方程）
       3. sourceTerms（Heatexchange / EnergyDeposition / ...）
       4. Diffuse（电子/离子热传导 + MGD 辐射扩散）
       5. Grid 更新（AMR refine/derefine）
       6. IO_output（按 sim_ioWriteTime 写 plt/chk）
       7. simTime += dt
6. Driver_finalize / 退出
```

### 1.3 为什么必须用 mpirun（L-011 讲为什么）

**即使单进程也要用 mpirun**：
- FLASH 编译期就含 MPI 调用（`MPI_COMM_WORLD`、`MPI_Bcast` 等）
- 直接 `./flash4` 会卡在第一次 MPI 调用（没初始化 MPI 环境）
- `mpirun -np 1 ./flash4` 才能正确初始化

**为什么用 mpich 的 mpirun（不是系统 OpenMPI）**：
- FLASH 编译时用 mpich，运行时也必须用 mpich 的 mpirun
- 系统 `/usr/bin/mpirun` 是 OpenMPI 版本
- flash_env.sh 把 mpich/bin 放 PATH 前面，确保用 mpich

### 1.4 为什么本机必须 source flash_env.sh

**机制**（详见 `make_guide.md §3` + `skills/flash-pitfall-finder/knowledge/pitfalls/libmpi-conflict.md`）：

```
系统库路径 /lib/x86_64-linux-gnu/
└── libmpi.so.40  ← 系统 OpenMPI

用户库路径 $FLASH_LIBS/mpich/lib/
└── libmpi.so.12  ← 用户 mpich（FLASH 链接这个）
```

**flash4 启动时**，loader 按以下顺序找 libmpi：
1. `LD_PRELOAD`（最高优先级）
2. RPATH（编译时写进可执行文件）
3. `LD_LIBRARY_PATH`
4. 系统默认路径 `/lib/x86_64-linux-gnu/`

**不 source flash_env.sh 时**：
- loader 找到 `libmpi.so.40`（OpenMPI）
- 但 libHYPRE.so 内部依赖 `libmpi.so.12`（mpich）
- 两个 MPI 实现的 ABI 不兼容 → SIGSEGV in Driver_initParallel.F90:92

**source flash_env.sh 后**：
- `LD_PRELOAD=$FLASH_LIBS/mpich/lib/libmpi.so`
- loader 最先加载 mpich 的 libmpi.so.12
- libHYPRE 也用这个版本 → 无冲突

## 2. flash_env.sh 详解

### 2.1 flash_env.sh 做什么（5 步）

项目根 `$FLASH_ROOT/flash_env.sh`：

```bash
#!/bin/bash

# 1. 库根路径
FLASH_LIBS=$FLASH_LIBS
MPI_PATH=$FLASH_LIBS/mpich
HDF5_PATH=$FLASH_LIBS/hdf5
HYPRE_PATH=$FLASH_LIBS/hypre

# 2. PATH：mpich 的 mpirun/mpicc 在前
export PATH=$MPI_PATH/bin:$PATH

# 3. LD_LIBRARY_PATH：loader 优先找 mpich/hdf5/hypre 库
export LD_LIBRARY_PATH=$MPI_PATH/lib:$HDF5_PATH/lib:$HYPRE_PATH/lib:${LD_LIBRARY_PATH:-}

# 4. LD_PRELOAD：终极保险，强制最先加载 mpich 的 libmpi
export LD_PRELOAD=$MPI_PATH/lib/libmpi.so

# 5. 验证输出（打印当前环境）
echo "FLASH 4.8 运行环境已配置 ..."
```

### 2.2 怎么用

```bash
# 每次开新 shell / 跑 flash4 前都要 source
cd $FLASH_ROOT
source flash_env.sh

# 然后进 01-data/ 跑（硬约束：输出只落 01-data/，不散落 objdir 根目录）
cd cases/LaserSlab/01-data
mpirun -np 2 ../flash4 -par_file ../flash.par
```

**为什么用 source 不用 bash**：
- `bash flash_env.sh`：启动新 shell，export 只在新 shell 生效，新 shell 退出后失效
- `source flash_env.sh`：在当前 shell 执行，export 在当前 shell 生效

### 2.3 没用 source flash_env.sh 的后果

```bash
# 直接跑（不 source）
cd cases/LaserSlab/01-data
mpirun -np 2 ../flash4 -par_file ../flash.par

# 可能的错误：
# 1. SIGSEGV in Driver_initParallel.F90:92（libmpi 冲突）
# 2. mpirun --version 显示 OpenMPI（系统版）
# 3. MPI_ERRORS_ABORT 或其他 MPI 调用错
```

### 2.4 验证 flash_env.sh 生效

```bash
source $FLASH_ROOT/flash_env.sh

# 应该看到：
# MPI:  MPICH ...
# PATH: mpirun → $FLASH_LIBS/mpich/bin/mpirun
# LD_PRELOAD:    $FLASH_LIBS/mpich/lib/libmpi.so
```

如果 `mpirun --version` 显示 OpenMPI，PATH 没生效——检查 shell 是不是用了 `bash` 不是 `sh`。

## 3. 标准 run 流程

### 3.1 完整命令（含环境配置）

> **硬约束（2026-08-10 起）**：flash4 必须在 `cases/<case>/01-data/` 下启动（CWD=01-data）。
> 所有运行输出（plt / chk / .dat / .log）落 `01-data/`，objdir 根目录只留编译产物和 parfile。
>
> **为什么用 CWD 法而不用 parfile `output_directory` 参数**：`output_directory` 只作用于 plt/chk
> （`source/IO/IOMain/io_getOutputName.F90` 拼路径），`.log` 和 `.dat`（如 `*_LaserEnergyProfile.dat`）
> 始终写 CWD——只有在 01-data/ 里启动才能一刀切全覆盖。

```bash
cd $FLASH_ROOT

# 1. source 运行环境（每次开新 shell 都要做）
source flash_env.sh

# 2. 进 case 的 01-data/ 目录（首次先创建）
cd cases/LaserSlab
mkdir -p 01-data && cd 01-data

# 3. 看一眼 parfile（可选——确认参数；parfile 留在 objdir 根目录）
less ../flash.par

# 4. 跑（前台，看输出）——flash4 和 parfile 都在上一级，用 ../ 引用
mpirun -np 2 ../flash4 -par_file ../flash.par 2>&1 | tee flash.log

# 或者后台跑（长算例）
nohup mpirun -np 4 ../flash4 -par_file ../flash.par > flash.log 2>&1 &
echo $!  # 记录 PID
tail -f flash.log  # 跟踪进度
```

### 3.2 -np N 怎么选

**机制**（L-011 讲为什么）：
- `-np N` = 用 N 个 MPI 进程
- 每个进程独立 CPU 核
- FLASH 把 domain 分成 N 块，每进程一块

**怎么选**：

| 场景 | 推荐 N | 理由 |
|---|---|---|
| 调试（Sedov）| 1-2 | 快速验证 |
| 小算例（LaserSlab 短跑）| 2-4 | 平衡速度和 overhead |
| 生产（LaserSlab 完整跑）| 8-16 | HEDP 主流 |
| 大算例（3D / 高分辨率）| 32-128 | HPC 集群 |

**本机 CPU 核数**：
```bash
nproc
# 输出本机逻辑核数
```

**N 不要超过 nproc**（否则进程抢核，更慢）。

### 3.3 后台跑长算例

```bash
cd cases/LaserSlab/01-data
source ../../../flash_env.sh

# 后台启动（nohup 让进程不受 shell 退出影响）
nohup mpirun -np 4 ../flash4 -par_file ../flash.par > flash.log 2>&1 &
FLASH_PID=$!
echo "FLASH PID: $FLASH_PID"

# 看进度
tail -f flash.log
# Ctrl-C 退出 tail（不杀 flash4）

# 检查是否还在跑
ps -p $FLASH_PID

# 杀进程（如果需要中断）
kill $FLASH_PID
# 或杀所有 flash4
pkill -f flash4
```

### 3.4 修改 parfile 后重跑

parfile 是**运行时**读，改了不用重 make：
```bash
# 改 parfile（如 dt 改小、写的频率改高）——parfile 在 objdir 根目录
vi cases/LaserSlab/flash.par

# 直接重跑（在 01-data/ 里）
cd cases/LaserSlab/01-data
source ../../../flash_env.sh
mpirun -np 2 ../flash4 -par_file ../flash.par
```

**注意**：改 parfile 会从头开始（除非 restart）。想续跑看 §5。

## 4. 日志解析

### 4.1 日志关键字段（按 L-012 引导贴）

```bash
# 用 examples/flash_log_parser.sh 自动提取
bash $FLASH_ROOT/skills/flash-case-runner/examples/flash_log_parser.sh \
  cases/LaserSlab/01-data/flash.log
```

**或手动 grep**：

```bash
# 1. 看最后进度
tail -30 cases/<case>/01-data/flash.log

# 2. 看 dt 演化（dt 应该缓慢变化）
grep -E "^\s*dt\s|time step|nstep" cases/<case>/01-data/flash.log | tail -30

# 3. 看 simTime 推进
grep "simTime\|Simulation time" cases/<case>/01-data/flash.log | tail -20

# 4. 看 block 数变化（AMR）
grep -i "leaf block\|total block" cases/<case>/01-data/flash.log | tail -20

# 5. 找 NaN / Inf / below floor
grep -i "nan\|inf\|below floor" cases/<case>/01-data/flash.log | head -20

# 6. 找 abort / Error / forrtl
grep -B2 -A20 -i "abort\|forrtl: error\|SIGSEGV\|MPI_ERRORS" cases/<case>/01-data/flash.log | head -50

# 7. 看写 plotfile / checkpoint 的次数
grep -i "writing\|plotfile\|checkpoint" cases/<case>/01-data/flash.log | tail -20
```

### 4.2 正常日志结构

flash.log 典型结构（简化）：

```
[setup 信息]
FLASH 4.8 release ...
setup: ./setup LaserSlab -2d ...
flags: --with-library=mpi ...

[初始化]
Driver_initFlash ...
Grid_init: ...
  geometry = cylindrical
  nxb=16 nyb=16
Eos_init: ...
Multispecies_init: ...
  species 1: cham
  species 2: targ
RadTrans_init: ...
EnergyDeposition_init: ...
  beam 1: ...
IO_init: ...
Simulation_init: ...

[主循环]
nstep = 0
  dt = 1.234e-12
  Hydro ...
  Diffuse ...
  sourceTerms ...
  step completed: simTime = ...
nstep = 1
  dt = 1.345e-12
  ...
[IO_output]
writing plotfile LaserSlab_hdf5_plt_cnt_0000
writing checkpoint LaserSlab_hdf5_chk_0000

[正常结束]
Simulation completed successfully.
```

### 4.3 异常日志模式

| 模式 | 含义 | 见 |
|---|---|---|
| `SIGSEGV` 在 `Driver_initParallel.F90:92` | libmpi 冲突（运行时） | §3 + `skills/flash-pitfall-finder/knowledge/pitfalls/libmpi-conflict.md` |
| `forrtl: error (65): floating invalid` | 数值 NaN（除零/负开方） | `skills/flash-pitfall-finder/knowledge/pitfalls/ffpe-trap-and-nan.md` |
| `forrtl: error (72): floating overflow` | 数值溢出 | 降 CFL |
| `forrtl: error (408)` | 数组越界 | 检查 NXB / 几何 |
| `[ed_xxx]: abort` | 激光参数错 | `flash-laser` skill |
| `[Multitype]: abort` | EOS 表超范围 | 检查 sim_rhoMin / 温度初值 |
| `[MGD]: abort` | MGD 不收敛 | 检查 mgd_* |
| `NaN` in solnData | 数值爆炸 | `flash-pitfall-finder` |
| `below floor` for density | 密度低于 EOS 表最小值 | 调 sim_rhoMin |

### 4.4 dt 突然变小（典型异常）

```
nstep = 100, dt = 1.234e-12
nstep = 101, dt = 1.234e-12
nstep = 102, dt = 1.234e-12
nstep = 103, dt = 1.234e-13  ← 突然变小 10 倍
nstep = 104, dt = 1.234e-14  ← 继续变小
```

**含义**：物理炸了（密度变低 / 温度变高 → 声速变大 → CFL 限制 dt 变小）。

**诊断**：
```bash
# 看哪个 dt 限制项主导
grep -i "dt.*limit\|cfl\|hx_dt" cases/<case>/01-data/flash.log | tail -20
```

**修复**：降 CFL（`hydro_cfl = 0.1` 而非 0.8）或排查物理。

## 5. restart 续跑

### 5.1 checkpoint 是什么

**checkpoint** = 算例的完整存档文件，含 grid 状态、所有 unk 变量、当前 simTime/nstep、IO 计数器。

**命名**：
```
<basenm>_hdf5_chk_<NNNN>.h5
```

例：
```
LaserSlab_hdf5_chk_0000.h5
LaserSlab_hdf5_chk_0010.h5
LaserSlab_hdf5_chk_0020.h5
```

每 N 步写一个（由 parfile `chk_checkpointFileIntervalTime` / `IntervalStep` 控制）。

### 5.2 plotfile vs checkpoint

| 文件 | 用途 | 含变量 |
|---|---|---|
| **plotfile** (`_plt_cnt_`) | 可视化/后处理 | 主流变量（dens/tele/tion/...）|
| **checkpoint** (`_chk_`) | restart 续跑 | 全部状态（含内部计数器、AMR 树等）|

**restart 必须用 checkpoint，不能用 plotfile**（plotfile 不含 AMR 树结构）。

### 5.3 续跑流程（完整故事线，L-015）

```
1. 找最新 checkpoint（在 01-data/ 里）
   ls cases/<case>/01-data/*_hdf5_chk_* | sort | tail -3

2. 改 flash.par（objdir 根目录那份）——续跑三件套，缺一不可：
   restart              = .true.
   checkpointFileNumber = <NNNN>  # 读哪个 chk（编号对应 _hdf5_chk_<NNNN>）
   plotFileNumber       = <最新 plt 编号 + 1>  # ⚠️ 不设会从 0 重编号，覆盖旧 plotfile！

3. 用相同 setup 命令重 build（保险——确保 NXB/species 一致）
   ⚠️ 不能改 setup-variables，否则 abort（见 §5.5）

4. 跑（在 01-data/ 里，硬约束）：
   cd cases/<case>/01-data
   source flash_env.sh
   mpirun -np N ../flash4 -par_file ../flash.par
```

### 5.4 parfile 续跑参数

```fortran
# flash.par 续跑段——三件套，缺一不可
restart              = .true.
checkpointFileNumber = 20     # 读哪个 chk（编号对应 <basenm>_hdf5_chk_0020）
plotFileNumber       = 1630   # 写 plt 从几号继续 = 原序列最后编号 + 1

# 其他参数（如 sim_maxTime）通常保留
sim_maxTime = 1.0e-9  # 续跑到这个时间结束
```

**注意**（2026-08-10 实证纠正）：
- ~~`restartFile`~~ **不是有效参数**——FLASH 4.8 会报 `ignoring unknown parameter "restartFile"` 并从 0 号 chk 读。续跑靠 `checkpointFileNumber`，文件名由 basenm + 编号自动拼出
- **`plotFileNumber` 必须设**——chk 里虽存了 plt 计数器，但 parfile 的显式值（原算例留的 0）优先级更高，不设会把新 plt 从 0 重新编号并**静默覆盖**旧 plotfile。见 `skills/flash-pitfall-finder/knowledge/pitfalls/restart-plotfilenumber-overwrite.md`

### 5.5 续跑兼容性检查（关键陷阱）

**NXB/NYB/nDim/species 数必须和原算例一致**（编译期 baked in）。

**验证方法**：
```bash
# 1. 看原算例的 setup_flags
cat cases/<case>/setup_flags | grep -E "NXB|NYB|NZB|N_DIM"

# 2. 看当前 flash4 的编译期 defines
strings flash4 | grep -E "NXB=|N_DIM=" | head

# 3. 看 checkpoint 里的元数据（用 h5dump；chk 在 01-data/ 里）
h5dump -A cases/<case>/01-data/<basenm>_hdf5_chk_0020 | grep -i "nxb\|nyb\|integer"

# 4. 看 species 数
cat cases/<case>/setup_vars | grep species
```

**不兼容的情况**：
- 改了 `-nxb=16` 为 `-nxb=32` → abort
- 改了 `species=cham,targ` 为 `species=cham,targ1,targ2,targ3` → abort
- 改了几何（cartesian → cylindrical）→ abort

**详细**：见 `skills/flash-pitfall-finder/knowledge/pitfalls/restart-incompatibility.md`。

### 5.6 续跑的实际命令

```bash
cd $FLASH_ROOT
source flash_env.sh

cd cases/LaserSlab/01-data

# 1. 找最新 chk（就在本目录）
LATEST_CHK=$(ls *_hdf5_chk_* | sort | tail -1)
echo "Latest chk: $LATEST_CHK"

# 2. 改 parfile（手动或 sed；改 objdir 根目录那份 ../flash.par）
# 在 ../flash.par 里设三件套：
#   restart              = .true.
#   checkpointFileNumber = <最新 chk 编号>
#   plotFileNumber       = <最新 plt 编号 + 1>   # 不设会覆盖旧 plt！

# 3. 跑（CWD=01-data，chk 和续跑输出都在本目录）
mpirun -np 2 ../flash4 -par_file ../flash.par 2>&1 | tee flash_restart.log
```

### 5.7 续跑后文件编号

续跑后写的 plt/chk **接着**原编号：
- 原 chk：0000, 0010, 0020
- 续跑从 0020 开始，写 0030, 0040, ...

**如果想重置编号**：parfile 加 `chk_checkpointFileNumber = 0`、`plot_plotFileNumber = 0`（但通常**不要重置**，避免覆盖原有文件）。

## 6. 运行错误诊断（按 L-012 引导贴现场）

### 6.1 通用贴现场模板

```bash
# 1. 看完整 flash.log（特别是 abort 段）
grep -B2 -A30 -i "abort\|forrtl\|sigsegv\|mpi_error" cases/<case>/01-data/flash.log | head -100

# 2. 看最后 50 行（看 abort 前 dt / nstep）
tail -50 cases/<case>/01-data/flash.log

# 3. 看 NaN 检测
grep -i "nan\|inf\|below floor" cases/<case>/01-data/flash.log | head -20

# 4. 看 setup_call（确认 setup 命令）
cat cases/<case>/setup_call

# 5. 看 parfile 关键段
grep -E "useXxx|sim_|cfl|ed_|mgd_|hx_" cases/<case>/flash.par | head -40

# 6. 看 AMR block 数变化
grep -i "leaf block\|total block" cases/<case>/01-data/flash.log | tail -30

# 7. 看 ldd flash4（确认 libmpi 链接）
ldd cases/<case>/flash4 | grep -i "mpi\|hdf5\|hypre"
```

### 6.2 常见运行错误

**A. SIGSEGV in Driver_initParallel.F90:92**

→ libmpi 冲突（运行时）。修复：`source flash_env.sh`。详见 `make_guide.md §3` + `skills/flash-pitfall-finder/knowledge/pitfalls/libmpi-conflict.md`。

**B. forrtl: error (65): floating invalid**

→ 数值 NaN。常见原因：
- CFL 太大（hydro_cfl > 0.5）
- 物理初值炸（密度/温度极端）
- EOS 表超范围

**贴现场后定位**：
```bash
# 看哪一步炸
grep -B5 "forrtl: error (65)" cases/<case>/01-data/flash.log
```

**详细**：见 `skills/flash-pitfall-finder/knowledge/pitfalls/ffpe-trap-and-nan.md` + `flash-pitfall-finder`。

**C. abort in [ed_xxx]**

→ 激光参数错。详见 `flash-laser` skill。

**贴现场**：
```bash
grep -B5 -A10 "ed_" cases/<case>/01-data/flash.log | head -50
grep -E "^useLaser|^ed_" cases/<case>/flash.par
```

**D. abort in [Multitype] / [Tabulated]**

→ EOS 表超范围。常见：
- 密度低于表最低值
- 温度高于表最高值
- 物种比例错（Xfluid 不为 1）

**修复**：调 parfile 的 `sim_rhoMin` / `sim_teleMin` 等 floor。

**E. NaN in solnData**

→ 数值爆炸。按 L-012 + `flash-pitfall-finder`。

**F. block count 暴涨**

→ 激波传出 domain，AMR 一直加密。

**修复**：调 parfile AMR 参数（`lrefine_max` / `refine_var_` 等）或扩大 domain。

**G. mpirun 报错**

```bash
# 看具体错（在 01-data/ 里跑）
cd cases/<case>/01-data
mpirun -np 2 ../flash4 -par_file ../flash.par 2>&1 | head -30
```

常见：
- `mpirun: command not found` → source flash_env.sh
- `cannot find libmpi.so.12` → source flash_env.sh
- `slots not enough` → mpirun --oversubscribe -np N

## 7. 速查：运行命令模板

```bash
# 标准 run（前台）——硬约束：在 01-data/ 里跑
cd cases/<case>/01-data
source ../../../flash_env.sh
mpirun -np 2 ../flash4 -par_file ../flash.par 2>&1 | tee flash.log

# 后台 run（长算例）
cd cases/<case>/01-data
source ../../../flash_env.sh
nohup mpirun -np 4 ../flash4 -par_file ../flash.par > flash.log 2>&1 &
tail -f flash.log

# restart 续跑
cd cases/<case>/01-data
source ../../../flash_env.sh
# 改 ../flash.par 设三件套：restart=.true. / checkpointFileNumber=<最新chk号> / plotFileNumber=<最新plt号+1>
mpirun -np 2 ../flash4 -par_file ../flash.par 2>&1 | tee flash_restart.log

# Debug run（-debug build 的 objdir）
cd cases/<case>_debug/01-data
source ../../../flash_env.sh
mpirun -np 2 ../flash4 -par_file ../flash.par 2>&1 | tee flash_debug.log
```

## 8. 怎么知道跑通了

```bash
# 1. 看最后几行日志
tail -10 cases/<case>/01-data/flash.log
# 应该看到：
# "Simulation completed successfully" 或
# "Reached maximum simulation time"

# 2. 看 plotfile 数量
ls cases/<case>/01-data/*_hdf5_plt_* | wc -l

# 3. 看最新 plotfile 时间
ls -lh cases/<case>/01-data/*_hdf5_plt_* | tail -5

# 4. 看 checkpoint 数
ls cases/<case>/01-data/*_hdf5_chk_* | wc -l

# 5. 验证最新 plotfile 没坏
h5dump -H cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050 | head -20
```
