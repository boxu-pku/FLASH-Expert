---
title: 算例生命周期总览 + 术语速查
skill: flash-case-runner
category: overview
source_anchors:
  - bin/setup.py
  - cases/LaserSlab/setup_call
  - cases/Sedov/setup_call
  - flash_env.sh
  - CLAUDE.md
---

# FLASH 算例生命周期总览

> 本文是 flash-case-runner skill 的**入口文档**。用户问"怎么跑 X" / "FLASH 算例怎么开始"时，先读这里建立心智模型（L-015 先讲完整故事线）。
>
> 按 L-014，本文第一节专门解释所有术语——避免后续文档读起来云里雾里。

## 1. 术语速查（L-014：先解释术语）

### 1.1 核心概念

| 术语 | 一句话定义 | 为什么存在 |
|---|---|---|
| **算例 (case / problem)** | 一次完整的 FLASH 模拟（如 Sedov 爆炸、LaserSlab 激光打靶） | 区分不同物理场景的代码组织单元 |
| **SimulationMain** | FLASH 源码里所有"算例模板"的根目录 `source/Simulation/SimulationMain/` | 每个算例一个子目录，含 Config + 初始化代码 + parfile |
| **setup** | 一条命令 `./setup <算例名> [选项] -objdir=<目录>`，把算例所需的源码 + Makefile 收集到一个目录 | FLASH 没有顶层 Makefile，每个算例都"按需组装" |
| **objdir** | setup 生成的"构建目录"，含 Makefile + 链接过来的源码 + 编译产物 | 隔离不同算例的构建；默认 `object/`，本机约定 `cases/<算例>/` |
| **site** | 一台机器的编译器/库路径配置（`Makefile.h`） | 不同机器的 MPI/HDF5 路径不同；每个 site 一份 |
| **make** | 在 objdir 里跑 `make -j4`，编译所有源码并链接出 `flash4` | 标准构建步骤；多核加速靠 `-jN` |
| **flash4** | 编译产出的可执行文件（在 objdir 里）| 4.8 版本叫 flash4，老版本叫 flash3 等 |
| **parfile** | 运行时参数文件（`flash.par` 等），含所有 runtime parameters | 改 parfile 不用重编译；用 `-parfile=<name>.par` 指定 |
| **mpirun** | 启动 MPI 并行任务的命令，`mpirun -np N ./flash4 -parfile=flash.par` | FLASH 是 MPI 并行代码，必须用 mpirun 启动（即使 N=1）|
| **checkpoint** | 模拟运行的"存档"文件（`*_hdf5_chk_<N>.h5`），含完整 grid state | 用于续跑（restart）；定期写 |
| **plotfile** | 模拟运行的"快照"文件（`*_hdf5_plt_cnt_<N>.h5`），用于后处理/画图 | 不含全部内部状态，只含可视化的变量 |
| **restart** | 从 checkpoint 续跑，避免从头开始 | 长时间模拟分段跑；算例中断后续跑 |

### 1.2 setup 语法术语（详见 `setup_guide.md`）

| 术语 | 含义 | 例子 |
|---|---|---|
| **setup-variable** | setup 阶段的"开关"或"配置值"，影响代码组装 | `+laser`（开激光单元）、`species=cham,targ`（设物质）|
| **`+foo` / `-foo`** | 把 setup-variable `foo` 设为 True/False | `+pm4dev`（用 Paramesh 4 dev backend）|
| **`key=value`** | 把 setup-variable `key` 设为 `value` | `mgd_meshgroups=6`（辐射 6 群）|
| **`-2d` / `-3d`** | 设维度（影响 NXB/NYB/NZB 和 N_DIM）| `-2d` = 二维 |
| **`-nxb=N`** | 设 block 在 x 方向的 cell 数（编译期）| `-nxb=16`（每个 block 16 个 cell 宽）|
| **`-geometry=xxx`** | 设几何 | `-geometry=cylindrical`（圆柱 r-z）|
| **`-auto`** | 跳过交互式提示 | 自动用 Config 里的 DEFAULT |
| **`-objdir=PATH`** | 设构建目录 | `-objdir=cases/LaserSlab` |
| **`-parfile=NAME`** | setup 时把 `<NAME>.par` 复制到 objdir 作为 `flash.par` | `-parfile=example.par` |
| **`-debug`** | 用 debug 编译选项（-O0, -ffpe-trap, bounds check）| 调 NaN / 越界用 |

### 1.3 本机特定术语（ares）

| 术语 | 含义 |
|---|---|
| **flash_env.sh** | 项目根的 bash 脚本，source 后设好 MPI/HDF5/HYPRE 库路径 + LD_PRELOAD |
| **libmpi 冲突** | 系统 OpenMPI (`libmpi.so.40`) 和用户 mpich (`libmpi.so.12`) 同时被找到，触发段错误 |
| **LD_PRELOAD** | loader 的"最高优先级"机制，强制最先加载某个 .so——本机用来强制加载 mpich 的 libmpi |

## 2. 算例生命周期四阶段（L-015：先讲故事线）

每个 FLASH 算例都走以下四步。本 skill 的每个文档对应一阶段：

```
[1. setup] ─→ [2. make] ─→ [3. run] ─→ [4. restart/analysis]
   │             │             │             │
   │             │             │             └─ 从 chk 续跑 / 分析 plotfile
   │             │             └─ mpirun ./flash4 → 写日志/plt/chk
   │             └─ 生成 flash4 可执行文件
   └─ 生成 objdir（Makefile + 源码链接 + parfile）
```

### 阶段 1: setup（详见 `setup_guide.md`）

**做什么**：根据用户命令，从 `source/` 树里挑选需要的单元（units），生成一个独立的 objdir。

**为什么需要**：FLASH 有几百个单元，一个算例只用其中几十个。setup 负责"按需组装"——读 Config 文件（声明单元依赖关系）+ 解析 setup-variables + 调用 `bin/setup.py` 工具链生成 Makefile + 链接源码 + 复制 parfile。

**最小命令**：
```bash
./setup Sedov -auto -objdir=cases/Sedov
```

**复杂命令（HEDP）**：
```bash
./setup LaserSlab -2d -auto +cylindrical \
  -nxb=16 -nyb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 \
  -objdir=cases/LaserSlab -parfile=example.par
```

**产物**：objdir 含
- `Makefile`、`Makefile.h`（site 配置）、`setup_call`（记录原始命令）
- 链接过来的 `.F90` 源码
- `flash.par`（如果指定了 `-parfile=`）
- `setup_flags` / `setup_defines` / `setup_units`（组装元信息）

### 阶段 2: make（详见 `make_guide.md`）

**做什么**：在 objdir 里跑 `make -j4`，编译所有源码，链接出 `flash4`。

**为什么需要**：FLASH 是 Fortran 90 + C + MPI 项目，几百个源文件，必须编译。

**典型命令**：
```bash
cd cases/LaserSlab
# 本机特殊：libmpi 冲突处理（详见 make_guide.md §3）
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak
make -j4 2>&1 | tee make.log
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40
```

**产物**：
- `flash4` 可执行文件
- 各种 `.o` / `.mod` 中间产物

**常见错误**：
- `libmpi.so.40 may conflict with libmpi.so.12`（warning，本机特有，按上面流程处理）
- `undefined reference to 'X'`（链接错，看 make_guide.md §4）
- `SetupError: Unit not found`（setup 阶段就报，看 setup_guide.md §5）

### 阶段 3: run（详见 `run_guide.md`）

**做什么**：用 mpirun 启动 flash4，读 parfile，开始模拟。

**为什么需要**：FLASH 是并行代码，即使单进程也必须用 mpirun 启动（初始化 MPI 环境）。

**典型命令**：
```bash
cd cases/LaserSlab
source /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/flash_env.sh
mpirun -np 2 ./flash4 -parfile=flash.par 2>&1 | tee flash.log
```

**为什么先 source flash_env.sh**：本机的 libmpi 冲突在运行时会触发段错误（SIGSEGV in Driver_initParallel.F90:92），flash_env.sh 设 LD_PRELOAD 让 mpich 的 libmpi.so.12 最先加载，避免冲突。

**产物**：
- `flash.log`（运行日志，含 dt / nstep / simTime）
- `*_hdf5_plt_cnt_<N>.h5`（plotfile，可视化用）
- `*_hdf5_chk_<N>.h5`（checkpoint，续跑用）

**常见错误**：
- `SIGSEGV in Driver_initParallel.F90:92`（libmpi 冲突，source flash_env.sh）
- `[ed_xxx]: abort`（激光参数错）
- `forrtl: error (65): floating invalid`（数值炸了，可能 NaN）

### 阶段 4: restart（详见 `run_guide.md §5`）

**做什么**：从最近一个 checkpoint 续跑，避免从头开始。

**为什么需要**：长时间模拟（HEDP 几 ns 物理时间可能跑几小时-几天）需要分段跑；算例中断后想接着跑。

**典型流程**：
```
1. 看 objdir 里最新的 chk 编号
   ls cases/<case>/*_hdf5_chk_*.h5 | tail -3
   # 假设最新是 _chk_0020

2. 改 flash.par：
   restart = .true.
   restartFile = "basenm_hdf5_chk_0020"  # 不带 .h5 后缀

3. 用相同 setup 命令重 build（保险——确保 NXB/species 一致）

4. 再跑：
   source flash_env.sh
   mpirun -np N ./flash4 -parfile=flash.par
```

**关键陷阱**：NXB/NYB/nDim/species 数必须和原算例一致（编译期 baked in），否则 abort。详见 `agent/pitfalls/restart-incompatibility.md`。

## 3. 常见算例一览（按 L-013 聚焦主流）

FLASH 源码里 `source/Simulation/SimulationMain/` 下有 30+ 个算例。本节按"用户实际场景"排序（不是按字母），主讲三个：

### 3.1 Sedov（入门，纯 Hydro）⭐

**是什么**：1959 年 Sedov 提出的"强点爆炸自相似解"——一点炸开，激波向外传播。

**为什么有这个算例**：经典激波管验证问题，最简单的 Hydro 算例。**最适合验证"环境配通没"**——能跑通 Sedov 说明 MPI/编译/loader 都 OK。

**物理**：单物质、单温、纯 Euler Hydro。

**setup**（最小）：
```bash
./setup Sedov -auto -objdir=cases/Sedov
```

**详细跑法**：见 `recipes/sedov.md`。

### 3.2 LaserSlab（HEDP 主流）⭐⭐⭐

**是什么**：HEDP（高能量密度物理）标准算例——激光打平面靶，2D 圆柱几何。

**为什么有这个算例**：用户实际工作场景（见 `CLAUDE.md` "用户从 LaserSlab 上手"）。覆盖 ICF/HEDP 所有核心物理：激光沉积（EnergyDeposition）+ 3T EOS（multiTemp）+ MGD 辐射 + Heatexchange（电子-离子平衡）+ 多物质（cham + targ）。

**物理**：多物质、3T、激光、辐射扩散。

**setup**（实证从 `cases/LaserSlab/setup_call`）：
```bash
./setup LaserSlab -2d -auto +cylindrical \
  -nxb=16 -nyb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 \
  -objdir=cases/LaserSlab -parfile=example.par
```

**详细跑法**：见 `recipes/laser-slab-2d.md`。

### 3.3 Sunliang_laser_CH（自定义多物质）⭐⭐

**是什么**：用户自定义算例（基于 LaserSlab 派生），多物质 CH/CHBr 平面靶激光打靶。

**为什么有这个算例**：用户实际研究算例——比 LaserSlab 复杂（4 个 species：cham, targ1, targ2, targ3），含 CHBr 不透明度表。

**setup**（实证从 `cases/Sunliang_laser_CH/setup_call`）：
```bash
./setup Sunliang_laser_CH -2d -auto +pm4dev \
  -geometry=cylindrical -nxb=16 -nyb=16 \
  +mtmmmt +laser +mgd +uhd3t \
  species=cham,targ1,targ2,targ3 mgd_meshgroups=6 \
  -parfile=example_xubo.par \
  -objdir=cases/Sunliang_laser_CH
```

**详细跑法**：见 `recipes/sunliang-laser-CH.md`。

### 3.4 其他算例（简要）

| 算例 | 用途 | 何时用 |
|---|---|---|
| `Blast2` | 类似 Sedov，含重力 | 测试激波 + 重力 |
| `DoubleMachReflection` | 经典 CFD 验证 | 测试 Hydro 精度 |
| `CapLaser*` / `CapLaserBAMPS` | HEDP 激光（不同 setup）| 替代 LaserSlab 的方案 |
| `RotatingBeam` / `RadBlastWave` | 辐射输运验证 | 测试 RadTrans |
| `Orbit` | 粒子轨道（有 Particles） | 测试 Particles 单元 |
| `magnetoHD` / `BrioWu` / `Rotor` | MHD 算例 | 测试 MHD（FLASH 4.8 已含 USM）|

**怎么浏览所有算例**：
```bash
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/
```

每个算例的 Config 文件第一段注释通常说明用途。

## 4. 本机 ares 的特殊性

### 4.1 无 sites/ares/

正常 FLASH 项目下，每台机器有 `sites/<hostname>/Makefile.h`。本机（hostname=`ares`）**没有** `sites/ares/`——site 配置已 baked in 各 `cases/<case>/Makefile.h`。

**为什么这样**：用户从其他机器拷贝 cases 过来时，配置也跟过来了。新建算例时要么：
- 从已有 case 复制 Makefile.h（推荐）
- 或自己创建 `sites/ares/Makefile.h`（更规范）

详见 `setup_guide.md §4`。

### 4.2 libmpi 冲突（核心痛点）

本机系统装了 OpenMPI（`libmpi.so.40`，apt 装的），但 FLASH 用的 mpich（`libmpi.so.12`，用户自建）。两个 MPI 实现的 ABI 不兼容，loader 找错版本会导致段错误。

**编译期**：用 `sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 .40.bak` 让 ld 找不到 .40，编译完恢复。

**运行期**：source `flash_env.sh` 设 LD_PRELOAD，让 mpich 的 libmpi 最先加载。

**详细**：见 `agent/pitfalls/libmpi-conflict.md` + 本 skill `knowledge/make_guide.md §3` + `knowledge/run_guide.md §3`。

### 4.3 外部库路径

本机外部库在 `/home/ubuntu/local/flash/myFLASH4.8/`：
- `mpich/` — MPI 实现
- `hdf5/` — HDF5 库（plotfile/chk 格式）
- `hypre/` — HYPRE 库（MGD 求解器用）

这些路径在 `cases/*/Makefile.h` 里硬编码。换机器时必须改。

## 5. 怎么用本 skill

| 用户场景 | 看哪份文档 |
|---|---|
| 第一次跑 FLASH，想跑通 Sedov | `recipes/sedov.md` + `examples/run-sedov.sh` |
| 要跑 LaserSlab HEDP | `recipes/laser-slab-2d.md` + `examples/run-laser-slab.sh` |
| 编译报错 | `knowledge/make_guide.md` + `knowledge/pitfalls.md` |
| 运行 abort | `knowledge/run_guide.md` + `knowledge/pitfalls.md` |
| 要续跑 | `knowledge/run_guide.md §5` |
| 不知道 setup 参数什么意思 | `knowledge/setup_guide.md §2` |
| 要加新算例 | `knowledge/setup_guide.md §6` + `flash-setup-builder` skill |

## 6. 速查：常见 bash 命令

```bash
# 看一个 case 的 setup 命令
cat cases/<case>/setup_call

# 看编译期 setup 选项展开
cat cases/<case>/setup_flags

# 看编译期 defines
cat cases/<case>/setup_defines

# 看 parfile
cat cases/<case>/flash.par | less

# 查找最新 checkpoint
ls cases/<case>/*_hdf5_chk_*.h5 | sort | tail -3

# 查找最新 plotfile
ls cases/<case>/*_hdf5_plt_*.h5 | sort | tail -3

# 看运行进度（最后 20 行日志）
tail -20 cases/<case>/flash.log

# 看 abort 位置
grep -B2 -A10 "abort\|forrtl" cases/<case>/flash.log | head -40

# 看 MPI 错误
grep -i "mpi\|sigsegv" cases/<case>/flash.log | head -20

# 看 dt 演化
grep -E "nstep|simTime" cases/<case>/flash.log | tail -30

# source 运行环境
source /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/flash_env.sh
```
