---
title: 全阶段踩坑汇总——setup / make / run / restart
skill: flash-case-runner
category: pitfalls
source_anchors:
  - agent/pitfalls/libmpi-conflict.md
  - agent/pitfalls/mpi-errors.md
  - agent/pitfalls/restart-incompatibility.md
  - agent/pitfalls/setup-unit-not-found.md
  - agent/pitfalls/site-not-found.md
  - agent/pitfalls/ffpe-trap-and-nan.md
---

# 全阶段踩坑汇总

> 本文是 flash-case-runner skill 的**踩坑速查**——覆盖 setup / make / run / restart 四阶段常见错误。
>
> **每条按 L-012 结构**：
> - **错误信息**：完整错误模式（grep 友好）
> - **贴什么现场**：具体命令（用户复制粘贴就行）
> - **机制**：为什么会触发（L-008：非源码错不贴凑数代码）
> - **修复**：具体步骤
> - **关联**：agent/pitfalls/ 详细文档（如有）

## 速查索引

| 阶段 | 错误 | 跳转 |
|---|---|---|
| setup | `SetupError: Unit not found` | §1.1 |
| setup | `site not found` | §1.2 |
| setup | `species` 数量错 | §1.3 |
| setup | parfile 找不到 | §1.4 |
| setup | parfile 顶部 setup 注释不可信 | §1.5 |
| make | `libmpi.so.40 may conflict` | §2.1 |
| make | `undefined reference to X` | §2.2 |
| make | `ld: cannot find -lX` | §2.3 |
| make | `cannot open module file X.mod` | §2.4 |
| make | `Error: Type mismatch` | §2.5 |
| make | `No rule to make target X` | §2.6 |
| make | make 卡住不动 | §2.7 |
| run | `SIGSEGV in Driver_initParallel.F90:92` | §3.1 |
| run | `forrtl: error (65) floating invalid` | §3.2 |
| run | `forrtl: error (72) floating overflow` | §3.3 |
| run | `forrtl: error (408)` | §3.4 |
| run | `[ed_xxx]: abort` | §3.5 |
| run | `[Multitype]: abort` | §3.6 |
| run | `[MGD]: abort` | §3.7 |
| run | NaN in solnData | §3.8 |
| run | `below floor` for density | §3.9 |
| run | block count 暴涨 | §3.10 |
| run | mpirun 报错 | §3.11 |
| run | dt 突然变小 | §3.12 |
| restart | NXB 不一致 abort | §4.1 |
| restart | species 数变了 abort | §4.2 |
| restart | restartFile 无效参数 / 找不到 chk | §4.3 |
| restart | 续跑覆盖旧 plotfile（plotFileNumber 未设） | §4.3 + `agent/pitfalls/restart-plotfilenumber-overwrite.md` |
| restart | 续跑后定时 plotfile 是空壳（无物理场数据集，日志却正常） | `agent/pitfalls/restart-skeleton-plotfiles.md` |
| run/IO | plotfile 数量爆炸（每步一个） | §5.4 + `agent/pitfalls/plotfile-interval-too-dense.md` |
| run | `-parfile=X` 被静默忽略（读了默认 flash.par） | `agent/pitfalls/parfile-flag-ignored.md`（正确：`-par_file X`） |
| run | 长跑后 `internal_Allreduce ... MPI_COMM_NULL` | §3.1.1 + `agent/pitfalls/mpi-romio-null-comm-allreduce.md` |

---

## 1. setup 阶段踩坑

### 1.1 SetupError: Unit not found

**错误信息**：
```
SetupError: Could not find Unit 'X' requested by 'Y'
```

**贴什么现场**（按 L-012）：
```bash
# 1. 完整错误信息
./setup <算例> [选项] -auto -objdir=<PATH> 2>&1 | tee setup_error.log

# 2. setup-variables 当前值
cat setup_error.log | grep -A30 "Defined Setup Variables"
```

**机制**：setup.py 按依赖图找单元时，找不到 Config 声明的 `X`。

**最可能原因**：

| 原因 | 怎么验证 | 修复 |
|---|---|---|
| 单元名拼错 | `find source/ -name Config \| xargs grep -l "REQUIRES"` | 改 setup 命令或 Config |
| setup-variable 没开 | 看 setup_flags | 加 `+laser` 等 |
| Config 路径错 | `cat source/Simulation/SimulationMain/<算例>/Config` | 改 Config |

**详细**：见 `agent/pitfalls/setup-unit-not-found.md`。

### 1.2 site not found

**错误信息**：
```
SetupError: Site '<hostname>' not found in sites/ directory
```

**贴什么现场**：
```bash
echo "Hostname: $(hostname)"
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/sites/ 2>/dev/null || echo "sites/ 不存在"
```

**机制**：本机无 `sites/ares/`，setup.py 找不到 site 配置。

**修复**（按优先级）：
1. **创建 sites/ares/**（一劳永逸）：
   ```bash
   mkdir -p sites/ares
   cp cases/LaserSlab/Makefile.h sites/ares/Makefile.h
   ```
2. **从已有 case 复制**（临时）：
   ```bash
   ./setup <NewCase> -auto -objdir=cases/<NewCase>  # 失败
   cp cases/LaserSlab/Makefile.h cases/<NewCase>/Makefile.h
   ./setup <NewCase> -auto -objdir=cases/<NewCase>  # 重试
   ```

**详细**：见 `agent/pitfalls/site-not-found.md` + `setup_guide.md §4`。

### 1.3 species 数量错

**错误信息**：
```
SetupError: Number of species in 'species=' variable does not match ...
```

**机制**：算例 Config 期望 N 种物质（如 LaserSlab 期望 2 种 cham+targ），但用户给的 species= 数量不对。

**贴现场**：
```bash
# 看 Config 怎么处理 species
cat source/Simulation/SimulationMain/<算例>/Config | grep -A5 species
```

**修复**：对照 Config 期望的 species 数量。

**Sunliang_laser_CH 用 4 个 species**（cham, targ1, targ2, targ3）——是修改过 Config 的版本，支持多层靶。

### 1.4 parfile 找不到

**错误信息**：
```
SetupError: parfile 'X.par' not found
```

**机制**：`-parfile=X` 找 `X.par`，在 `source/Simulation/SimulationMain/<算例>/` 下找不到。

**修复**：
```bash
# 1. 看算例目录下有哪些 parfile
ls source/Simulation/SimulationMain/<算例>/*.par

# 2. 用存在的 parfile
./setup <算例> ... -parfile=<存在的名字>
```

### 1.5 parfile 顶部 setup 注释不可信（L-009）

**症状**：parfile 顶部注释的 setup 命令和实际 setup 不一致，导致按注释 setup 后跑出来不对。

**例子**：`cases/LaserSlab/example.par` 顶部可能写：
```
# setup: ./setup LaserSlab -2d +cylindrical ...
```
但 `cases/LaserSlab/setup_call` 里实际是：
```
./setup LaserSlab -2d -auto +cylindrical -nxb=16 -nyb=16 +hdf5typeio species=cham,targ +mtmmmt +laser +uhd3t +mgd mgd_meshgroups=6 ...
```

**修复**：**永远以 `setup_call` 为准**，不要看 parfile 注释。

**详细**：见 L-009。

---

## 2. make 阶段踩坑

### 2.1 libmpi.so.40 may conflict with libmpi.so.12（本机核心痛点）

**错误信息**：
```
/usr/bin/ld: warning: libmpi.so.12, needed by /home/ubuntu/local/flash/myFLASH4.8/hypre/lib/libHYPRE.so,
may conflict with libmpi.so.40
```

**贴什么现场**：
```bash
# 1. 确认这是 warning 还是 error
grep -A2 "libmpi" cases/<case>/make.log | head -10

# 2. 确认 Makefile.h 的 MPI_PATH
grep MPI_PATH cases/<case>/Makefile.h
```

**机制**（L-008：非源码错，详细讲机制）：

```
系统库路径 /lib/x86_64-linux-gnu/
└── libmpi.so.40  ← 系统 OpenMPI（Ubuntu apt 装的）

用户库路径 /home/ubuntu/local/flash/myFLASH4.8/mpich/lib/
└── libmpi.so.12  ← 用户自建 mpich（FLASH 编译用这个）
```

`libHYPRE.so` 内部依赖 `libmpi.so.12`（mpich），但 ld 默认搜索找到 `.40`（OpenMPI）。两个 MPI 实现的 ABI 不兼容 → ld warning。

**为什么是 warning 不是 error**：编译期能生成 flash4，但**运行时会爆炸**（SIGSEGV in Driver_initParallel.F90:92）。

**修复**：
```bash
# 编译期处理
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak
make -j4
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40

# 运行期处理
source /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/flash_env.sh
```

**详细**：见 `agent/pitfalls/libmpi-conflict.md` + `make_guide.md §3`。

### 2.2 undefined reference to 'X'

**错误信息**：
```
/usr/bin/ld: ...: undefined reference to `X'
collect2: error: ld returned 1 exit status
```

**贴什么现场**：
```bash
# 1. 完整错误
grep -B1 -A1 "undefined reference" cases/<case>/make.log | head -30

# 2. setup 选了哪些 unit
cat cases/<case>/setup_flags

# 3. Makefile.h 的库路径
grep -E "MPI_PATH|HDF5_PATH|HYPRE_PATH|LIB_" cases/<case>/Makefile.h
```

**机制**：链接阶段找不到符号定义。

**常见原因**：

| 错误符号 | 原因 | 修复 |
|---|---|---|
| `mpi_init_` 等 | MPI 库没链接 | 用 mpif90 / 检查 MPI_PATH |
| `hdf5_` 系列 | HDF5 没链接 | 加 `+hdf5typeio` / 检查 HDF5_PATH |
| `HYPRE_` 系列 | HYPRE 没链接 | 检查 HYPRE_PATH / 用 MGD 才需要 |
| `<SomeUnit>_*` | 某 unit 没选中 | 改 setup-variables 或 Config |
| `mpif90_*` | mpif90 wrapper 坏 | 重装 mpich |

### 2.3 ld: cannot find -lX

**错误信息**：
```
/usr/bin/ld: cannot find -lhdf5
/usr/bin/ld: cannot find -lmpi
/usr/bin/ld: cannot find -lHYPRE
```

**贴什么现场**：
```bash
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
ls /home/ubuntu/local/flash/myFLASH4.8/mpich/lib/ | grep -i mpi
ls /home/ubuntu/local/flash/myFLASH4.8/hdf5/lib/ 2>/dev/null
ls /home/ubuntu/local/flash/myFLASH4.8/hypre/lib/ 2>/dev/null
```

**机制**：ld 找不到库文件 `.so` / `.a`。

**修复**：确认库实际路径，更新 Makefile.h 的 `*_PATH`。

### 2.4 cannot open module file X.mod

**错误信息**：
```
fatal error: cannot open module file 'X.mod' for reading
```

**机制**：F90 `use X` 时找不到 X.mod（X 还没编译）。

**修复**：
```bash
# 重 make 第二次（第一次失败时大部分 .mod 已生成）
cd cases/<case>
make -j4
# 失败后：
make -j4
```

**为什么有效**：第一次 make 失败时大部分模块已生成 .mod，第二次能找到。

### 2.5 Error: Type mismatch / Cannot convert / Array bounds mismatch

**错误信息**：
```
Error: Type mismatch in argument at (1)
Error: Cannot convert REAL(8) to REAL(4)
Error: Array bounds mismatch
```

**贴什么现场**：
```bash
# 看完整错误（含文件名 + 行号）
grep -B2 -A5 "Error:" cases/<case>/make.log | head -40
```

**机制**：源码本身有问题。罕见（FLASH 已经过测试），常见原因：
- `make -j16` 时 race condition → 降 -j4 重 make
- 用户改了源码 → 还原
- setup 选了不兼容 unit 组合 → 检查 setup_flags

### 2.6 No rule to make target X

**错误信息**：
```
make: *** No rule to make target 'X'. Stop.
```

**机制**：Makefile 坏（缺文件引用）。

**修复**：
```bash
# 重 setup
cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
rm -rf cases/<case>
./setup <算例> [选项] -objdir=cases/<case>
```

### 2.7 make 卡住不动

**症状**：`make -j4` 长时间无输出。

**贴现场**：
```bash
# 看 make 在编哪个文件
ps -ef | grep gfortran | head
```

**修复**：
- 如果是合理大文件（如 IO_output.F90）→ 等几分钟
- 如果真的卡死 → Ctrl-C，降并行度 `make -j2`

---

## 3. run 阶段踩坑

### 3.1 SIGSEGV in Driver_initParallel.F90:92（本机核心痛点）

**错误信息**：
```
Program received signal SIGSEGV: Segmentation fault - invalid memory reference.

Backtrace for this error:
#0  ... in Driver_initParallel.F90:92
```

**贴什么现场**：
```bash
# 1. 看是否 source 了 flash_env.sh
echo "LD_PRELOAD: $LD_PRELOAD"
echo "PATH mpirun: $(which mpirun)"

# 2. 看 flash.log
grep -B2 -A10 "SIGSEGV\|Driver_initParallel" cases/<case>/01-data/flash.log
```

**机制**（L-008：非源码错）：

flash4 启动时 loader 找 `libmpi.so`：
- 没 source flash_env.sh → 找到 `libmpi.so.40`（OpenMPI）
- 但 libHYPRE 内部依赖 `libmpi.so.12`（mpich）
- 两个 ABI 不兼容 → 第一次 MPI 调用（Driver_initParallel.F90:92 的 `MPI_Comm_rank`）段错误

**修复**：
```bash
cd cases/<case>/01-data   # 硬约束：在 01-data/ 里跑，输出不散落 objdir 根目录
source /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/flash_env.sh
mpirun -np 2 ../flash4 -par_file ../flash.par
```

**详细**：见 `agent/pitfalls/libmpi-conflict.md` + `agent/pitfalls/mpi-errors.md` + `run_guide.md §1.4`。

### 3.1.1 长跑后 `internal_Allreduce ... MPI_COMM_NULL`（ROMIO 集合 I/O，2026-08-10 排查）

**错误信息**（指纹）：
```
Fatal error in internal_Allreduce: Invalid communicator, error stack:
internal_Allreduce(128): MPI_Allreduce(..., count=1, MPI_INT, op=0x98000000, MPI_COMM_NULL) failed
internal_Allreduce(45).: Null communicator
```

**机制**（一句话）：mpich ROMIO（MPI-IO）two-phase 集合写的 consensus Allreduce 拿到 NULL 通信子——C 层（非 FLASH Fortran/物理）故障，**非确定性**，高频集合 IO（每步一个 plotfile）是触发条件。

**关键特征**：长跑后（数千步）才出现；**restart 从最近 chk 续跑可越过崩溃点**（已实证）。

**修复**：① restart 续跑；② 降 plotfile 频率（`plotFileIntervalTime` 别小于 dt）；③ 复发则 `export ROMIO_CB_WRITE=disable` 绕过 two-phase。

**详细**：见 `agent/pitfalls/mpi-romio-null-comm-allreduce.md`（含完整证据链：handle 解码 + objdir Allreduce 穷举 + 反汇编 op 创建点 + 5 行 C 程序逐字复现指纹）。

### 3.2 forrtl: error (65): floating invalid

**错误信息**：
```
forrtl: error (65): floating invalid
forrtl: info : floating exception trap mask: invalid
```

**贴什么现场**：
```bash
# 1. 看哪一步炸
grep -B10 "forrtl: error (65)" cases/<case>/01-data/flash.log | head -30

# 2. 看 dt 演化
grep -E "nstep|dt" cases/<case>/01-data/flash.log | tail -20

# 3. 看 NaN
grep -i "nan\|below floor" cases/<case>/01-data/flash.log | head -10
```

**机制**：浮点 NaN 运算（除零、负开方、`log(<0)` 等）。

**常见原因**：

| 原因 | 怎么验证 | 修复 |
|---|---|---|
| CFL 太大 | `grep hydro_cfl cases/<case>/flash.par` | 降 hydro_cfl = 0.1-0.3 |
| 物理初值炸 | 看 Simulation_initBlock.F90 | 调 sim_rhoMin / sim_teleMin |
| EOS 表超范围 | `grep "EOS.*out of" cases/<case>/01-data/flash.log` | 扩展表范围或调 floor |
| 激光参数错 | `grep ed_ cases/<case>/flash.par` | 见 `flash-laser` |

**详细**：见 `agent/pitfalls/ffpe-trap-and-nan.md`。

### 3.3 forrtl: error (72): floating overflow

**错误信息**：
```
forrtl: error (72): floating overflow
```

**机制**：浮点溢出（数值大于 `HUGE(1.0)`）。

**修复**：降 CFL，调 parfile 的 `sim_rhoMin` / `sim_teleMin`。

### 3.4 forrtl: error (408): array bound exceeded

**错误信息**：
```
forrtl: error (408): fort: (3): Subscript #1 of the array X has value Y which exceeds the upper bound of Z
```

**机制**：数组越界。

**修复**：
- 用 `-debug` 重 build（含 `-fbounds-check`），跑出确切行号
- 看是否 NXB/NYB 不对、或物种数不对

### 3.5 [ed_xxx]: abort（激光参数错）

**错误信息**：
```
[Driver_abortFlash] ed_xxx: <详细错误信息>
```

**贴什么现场**：
```bash
# 1. 完整错误段
grep -B5 -A15 "ed_\[a-zA-Z\]*:" cases/<case>/01-data/flash.log | head -50

# 2. 激光 parfile 段
grep -E "^useLaser|^ed_|^laser_" cases/<case>/flash.par
```

**机制**：激光参数配置错。详见 `flash-laser` skill。

**典型错误**：
- `ed_setupBeams: Not enough beam runtime parameters`（束数错）
- `ed_createBeam: cannot determine beam domain`（束指向错）
- `ed_xcrossFn: alpha < 0`（截面函数参数错）

### 3.5.1 `ed_setupBeams: invalid 2D/3D beam grid type`（2026-08-07 CarbonSlab 实战）

**错误信息**（两种变体）：
```
ed_setupBeams: invalid 2D beam grid type!
  Beam # , grid type = square2D
  Should be: regular1D or statistical1D

ed_setupBeams: invalid 3D beam grid type!
  Beam # , grid type = regular1D
  Should be: square2D, radial2D, delta2D, rectangular2D or statistical2D
```

**贴什么现场**：
```bash
grep -n "ed_gridType\|ed_laser3Din2D" cases/<case>/flash.par
```

**机制**（L-008：源码 `EnergyDepositionMain/Laser/LaserBeams/ed_setupBeams.F90:118-132`）：

ED 单元按"光束几何"决定合法的光束网格类型，而光束几何由 `ed_gridGeometry` 和 `ed_laser3Din2D` 共同决定：

| 条件 | beams2D | beams3D | 合法 gridType |
|---|---|---|---|
| 2D 圆柱，`ed_laser3Din2D=.false.`(默认) | ✓ | ✗ | `regular1D` / `statistical1D` |
| 2D 圆柱，`ed_laser3Din2D=.true.` | ✗ | ✓ | `square2D` / `radial2D` / `delta2D` / `rectangular2D` / `statistical2D` |

两种变体对应两个条件分支：配了 `square2D` 但没设 `ed_laser3Din2D` → 报 "invalid 2D"；配了 `regular1D` 但设了 `ed_laser3Din2D=.true.` → 报 "invalid 3D"。

**修复**：让 `ed_gridType_1` 与 `ed_laser3Din2D` 配套即可（见上表），二选一：
```fortran
# 方案 A: 2D 光束 (2D 圆柱默认)
ed_gridType_1 = "regular1D"     # 或 statistical1D

# 方案 B: 3D 光束在 2D 几何 (LaserSlab example.par 的选择)
ed_laser3Din2D           = .true.
ed_laser3Din2DwedgeAngle = 0.1
ed_gridType_1            = "radial2D"
```

**重要前置教训（2026-08-07 实测）**：`LaserSlab` 源码目录的 `flash.par` 是 **3D 版**（`ed_gridType_1 = "square2D"`），直接用它在 2D 算例上跑必然报 "invalid 2D beam grid type"。**2D 圆柱算例必须用 `example.par` 作为修改基础**（LaserSlab setup_call 的 `-parfile=example.par` 也是这么用的）。

**详细**：见 `flash-laser` skill（ed_* 参数）+ `recipes/laser-slab-2d.md §4.8`。

### 3.5.2 [Opacity] abort：IONMIX 表群结构不匹配（2026-08-07 实战）

**错误信息**（两种）：
```
[op_readIonmix4Tables] ERROR: bad size of IONMIX4 energy group grid
[op_readIonmix4Tables] ERROR: Energy group mismatch (SEE LOG FILE)
[op_readIonmixTables]  ERROR: bad size of IONMIX energy group grid
[op_readIonmixTables]  ERROR: IONMIX / Opacity energy group mismatch
```

**贴什么现场**：
```bash
# 群数 vs 表群数
grep rt_mgdNumGroups cases/<case>/flash.par          # 由 setup 变量 mgd_meshgroups 决定
# 群边界 vs 表边界
grep rt_mgdBounds cases/<case>/flash.par
python3 /home/ubuntu/local/IONMIX/abjt_v1_0/ionmix2imx.py <ionmxout> --dump-groups   # 打印表内边界
```

**机制**：FLASH 读表时做两层校验（`op_readIonmixTables.F90:198` 和 `:229-237`）：
1. 表内群数 ≠ `op_nEnergyGroups`（= `mgd_meshgroups`）→ `bad size` abort；
2. 表内群边界与 `rt_mgdBounds_*` 相对差 > `op_tableEnergyTolerance`（默认 1e-4）→ `group mismatch` abort。

**修复**：让三者一致——表群数 = `mgd_meshgroups`，表边界 = `rt_mgdBounds_*`。两个方向都行：
- 改 IONMIX 输入（`ngrups` + `isw(13)=1` + `grupbd`）重算，再重新转换；
- 或把 parfile 的 `rt_mgdBounds_*` 改成表内边界。

**注意**：`ionmix4` 与 `ionmix` 是两种不同格式（头部布局、dummy 块数不同），`op_*FileType` 必须与文件实际格式一致，配错会在读表时错位 abort。

**详细**：见 `flash-radtrans` skill `knowledge/pitfalls.md` §D + `recipes/laser-slab-2d.md §4.9`。

### 3.6 [Multitype] / [Tabulated]: abort（EOS 超范围）

**错误信息**：
```
[Driver_abortFlash] Multitype: requested EOS point is outside of the table bounds
```

**贴什么现场**：
```bash
# 看错误前几步的密度/温度
grep -B10 "Multitype\|Tabulated" cases/<case>/01-data/flash.log | head -30
```

**机制**：EOS 表的密度/温度范围不够覆盖算例的物理条件。

**修复**：
- 调 `sim_rhoMin` / `sim_teleMin` / `sim_tionMin`（parfile）
- 或换更大范围的 EOS 表（如 `he-imx-005` → `he-imx-010`）

### 3.7 [MGD]: abort（MGD 不收敛）

**错误信息**：
```
[Driver_abortFlash] Diffuse_solveScalar: BoomerAMG did not converge
```

**机制**：HYPRE 求解器不收敛。

**修复**：
- 降 `mgd_theta`（隐式度，1.0 = 全隐）
- 增 `mgd_maxiter`（最大迭代数）
- 见 `flash-radtrans` skill

### 3.8 NaN in solnData

**错误信息**：
```
[Driver_abortFlash] Hydro: detected NaN in solution data
```

**贴什么现场**：
```bash
# 看哪个变量 NaN
grep -B5 -A5 "NaN" cases/<case>/01-data/flash.log | head -30

# 看 dt 演化
grep -E "nstep|dt" cases/<case>/01-data/flash.log | tail -30
```

**机制**：物理数值炸。

**修复**：见 `flash-pitfall-finder`（NaN 类）+ 降 CFL + 调 floor。

### 3.8.1 SIGSEGV in `op_writeOpacity.F90`（2026-08-07 实战：opacity_writeOpacityInfo 的 FLASH bug）

**错误信息**：
```
Program received signal SIGSEGV: Segmentation fault - invalid memory reference.
Backtrace:
#0  ... in op_writeopacity_  at .../op_writeOpacity.F90:97
#1  ... in opacity_init_      at .../Opacity_init.F90:193
```

**贴什么现场**：
```bash
grep -A10 "Backtrace" run_stdout.log | head -12
```

**机制**：`opacity_writeOpacityInfo = .true.` 时，FLASH 在初始化最后额外调用 `op_writeOpacity`（写 opacplot 格式文件，`Opacity_init.F90:193`），该功能在本机 FLASH 4.8 上**必然段错误**（`op_writeOpacity.F90:97`），与不透明度表本身无关。

**关键点**：段错误发生在 `op_writeTables`（写 `opacity_printout_tables.txt`）**之后**——`opacity_printout_tables.txt` 内容完整可用。因此这个选项仍可临时用于"让 FLASH 打印读入的表、与源表逐值对比"的验证流程，验证完删除即可。

**修复**：验证完删除该参数：
```bash
sed -i '/opacity_writeOpacityInfo/d' flash.par
rm -f opacity_printout_tables.txt
```

**验证流程**：见 `recipes/laser-slab-2d.md §4.10` + IONMIX 转换教程。

### 3.9 below floor for density

**错误信息**：
```
Density below EOS floor: dens = 1.23e-25 < dens_floor = 1.0e-24
```

**机制**：算例某处密度低于 EOS 表的最小值。

**修复**：
```fortran
# parfile 调高 floor
sim_rhoMin = 1.0e-3   # 物理单位
eos_smallx = 1.0e-30  # 单物种质量分数 floor
```

### 3.10 block count 暴涨

**症状**：AMR 一直加密，block 数从 100 涨到 10000+。

**贴现场**：
```bash
grep -i "leaf block\|total block" cases/<case>/01-data/flash.log | tail -30
```

**机制**：激波传出 domain，AMR 一直 refine。

**修复**：
- 限制 AMR 层数（`lrefine_max = 4` 而非自动）
- 扩大 domain
- 调 refine/derefine 阈值

### 3.11 mpirun 报错

**贴现场**：
```bash
cd cases/<case>/01-data && mpirun -np 2 ../flash4 -par_file ../flash.par 2>&1 | head -30
```

**常见错**：

| 错误 | 原因 | 修复 |
|---|---|---|
| `mpirun: command not found` | PATH 不对 | source flash_env.sh |
| `cannot find libmpi.so.12` | LD_LIBRARY_PATH 不对 | source flash_env.sh |
| `slots not enough` | mpirun 资源不够 | `mpirun --oversubscribe -np N` |
| `proxy: cannot connect` | mpich 的 hydra proxy 坏 | 重启 shell |

### 3.12 dt 突然变小

**症状**：dt 从 1e-12 突然掉到 1e-14。

**贴现场**：
```bash
# 看 dt 限制项
grep -i "dt.*limit\|cfl\|hx_dt\|ed_dt" cases/<case>/01-data/flash.log | tail -30
```

**机制**：物理炸了（密度低 / 温度高 → 声速大 → CFL 限制 dt 小）。

**修复**：降 CFL，或排查物理。

---

## 4. restart 阶段踩坑

### 4.1 NXB 不一致 abort

**错误信息**：
```
[Driver_abortFlash] Grid_init: NXB mismatch between checkpoint (32) and current build (16)
```

**贴什么现场**：
```bash
# 1. 看原算例 setup
cat cases/<case>/setup_flags | grep -E "NXB|NYB|NZB"

# 2. 看当前 flash4 编译期
strings cases/<case>/flash4 | grep -E "NXB=|N_DIM=" | head

# 3. 看 checkpoint 元数据
h5dump -A cases/<case>/<basenm>_hdf5_chk_0020.h5 | grep -i "nxb\|nyb"
```

**机制**：NXB/NYB/NZB 是编译期 baked in 的宏（`setup_defines` 里 `-DNXB=16`），checkpoint 里存的也是这个值。续跑时如果重 build 的 NXB 不同，abort。

**修复**：续跑前确认 setup_flags 的 NXB 一致：
```bash
# 用原 setup 命令重 build
./setup <算例> -nxb=<原 NXB> ... -objdir=cases/<case>
```

**详细**：见 `agent/pitfalls/restart-incompatibility.md`。

### 4.2 species 数变了 abort

**错误信息**：
```
[Driver_abortFlash] Multispecies: species count mismatch
```

**机制**：species 数编译期 baked in（`NSPECIES=2`），改 species= 后重 build 会变。

**修复**：续跑必须用**完全相同的 species 列表**重 build。

### 4.3 restart 参数名错 / 找不到 restart 文件（2026-08-10 实证重写）

**错误信息**：
```
RuntimeParameters_read:  ignoring unknown parameter "restartFile"...
[Driver_abortFlash] IO: cannot open restart file: <basenm>_hdf5_chk_0000
```

**贴什么现场**：
```bash
# 1. 看 parfile 的 restart 三件套
grep -E "^restart|^checkpointFileNumber|^plotFileNumber|^basenm" cases/<case>/flash.par

# 2. 看实际 checkpoint 文件（在 01-data/ 里）
ls cases/<case>/01-data/*_hdf5_chk_*
```

**机制**（2026-08-10 实证纠正）：~~`restartFile`~~ **不是 FLASH 4.8 的有效参数**——写了会被 ignore，
然后按 `checkpointFileNumber`（默认 0）拼文件名 `<basenm>_hdf5_chk_<编号>` 去读，找不到就 abort。
正确机制：**restart 文件名 = basenm + "hdf5_chk_" + checkpointFileNumber**，相对 CWD 解析。

**修复**（续跑三件套，缺一不可）：
```fortran
restart              = .true.
checkpointFileNumber = 8      # 读哪个 chk（编号对应 _hdf5_chk_0008）
plotFileNumber       = 1630   # 写 plt 续接编号 = 原序列最后编号 + 1
```

**⚠️ 连带坑**：不设 `plotFileNumber`，parfile 里遗留的 `plotFileNumber = 0` 会覆盖 chk 存的计数器，
新 plt 从 0 重编号并**静默覆盖**旧 plotfile（2026-08-10 Sunliang_Xray 实战，损失 22 个早期 plt）。
见 `agent/pitfalls/restart-plotfilenumber-overwrite.md`。

### 4.4 续跑后 block 数暴涨

**症状**：续跑从 checkpoint 开始，立刻 abort（block 不一致）。

**机制**：续跑时 AMR 树必须从 checkpoint 恢复，不能改 `lrefine_max` 等参数。

**修复**：续跑 parfile 不要改 AMR 参数（保持和原跑一致）。

### 4.5 checkpoint 文件损坏

**症状**：续跑时 `HDF5-DIAG: ... truncated`。

**机制**：上次跑没写完 checkpoint 就被杀。

**修复**：用前一个 checkpoint：
```bash
ls cases/<case>/01-data/*_hdf5_chk_* | sort | tail -3
# 用倒数第二个（最新的可能损坏）
```

---

## 5. 跨阶段综合问题

### 5.1 parfile 改了不生效

**症状**：改了 flash.par 的某个参数，跑出来不变。

**可能原因**：
- 改的不是 parfile（如改了 setup_datafiles）
- parfile 用的是 CONSTANT 参数（编译期 baked in，运行时改无效）
- restart 模式下某些参数不读

**贴现场**：
```bash
# 1. 看 parfile 实际内容
grep "<参数名>" cases/<case>/flash.par

# 2. 看参数定义（是否 CONSTANT）
grep "<参数名>" cases/<case>/setup_params
```

### 5.2 plotfile 打不开 / 损坏

**贴现场**：
```bash
# 用 h5dump 验证（plotfile 在 01-data/ 里）
h5dump -H cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050 | head -20
```

**常见原因**：
- HDF5 库版本不匹配
- 写文件时算例被杀（中断）
- 磁盘满

### 5.3 跑通一次，再跑就报错

**机制**：第一次跑写了 plotfile/chk，第二次跑默认覆盖（或冲突）。

**修复**：
```bash
# 1. 改 basenm（parfile 里的 IO 输出前缀）
# basenm = "<新名字>"

# 2. 或清空旧文件（在 01-data/ 里）
rm cases/<case>/01-data/*_hdf5_plt_*
rm cases/<case>/01-data/*_hdf5_chk_*
```

### 5.4 plotfile 数量爆炸（每步一个 plotfile）

**症状**：`ls cases/<case>/01-data/*_hdf5_plt_cnt_* | wc -l` 接近总步数；
磁盘占用数 GB；长跑后期步速变慢。

**机制**：`plotFileIntervalTime`（模拟时间间隔，不是 wall time）< dt 时，
每一步都满足写出条件。Sunliang_Xray 实证：0.01e-9 < dt≈1.35e-11 →
8041 步写出 1630 个 plt（6.7 GB），并诱发 ROMIO 集合写崩溃（§3.1.1）。

**修复**：
```fortran
plotFileIntervalTime = 0.1e-09   # ≥ 5×dt；或按步 plotFileIntervalStep = 50
```
**经验法则**：整个算例 plt 总量控制在 100~500 个。
详见 `agent/pitfalls/plotfile-interval-too-dense.md`。

---

## 6. 怎么用本文档

1. **看到错误先贴现场**（按 L-012 §"贴什么现场"）
2. **匹配本文档的错误模式** → 跳到对应 §
3. **看机制** → 理解为什么会触发
4. **按修复步骤操作**
5. **如果本 skill 不覆盖** → 转 `flash-pitfall-finder` skill
