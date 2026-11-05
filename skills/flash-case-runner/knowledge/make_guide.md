---
title: make 阶段完整指南——编译流程 + libmpi 冲突 + 编译错误诊断
skill: flash-case-runner
category: make
source_anchors:
  - cases/LaserSlab/Makefile
  - cases/LaserSlab/Makefile.h
  - skills/flash-pitfall-finder/knowledge/pitfalls/libmpi-conflict.md
  - source/Driver/DriverMain/Driver_abortFlash.F90
---

# make 阶段完整指南
> 路径约定：`$FLASH_ROOT` = FLASH 4.8 仓库根目录（本机 `$FLASH_ROOT`）；`$FLASH_LIBS` = 外部库根目录（本机 `$FLASH_LIBS`，含 mpich/hdf5/hypre）。其它机器按实际路径替换。


> 本文讲 FLASH 算例生命周期的**第二阶段**：make。
>
> 按 L-015，先讲 make 的完整故事线，再讲细节。
>
> 按 L-012，所有错误诊断先引导贴现场。

## 1. make 的完整故事线

### 1.1 make 是什么

`make` 是标准的 Unix 构建工具——读 `Makefile`，按依赖规则编译源码。

在 FLASH objdir 里跑 `make -j4`，会：
1. 读 `Makefile`（setup 时生成）
2. 读 `Makefile.h`（site 配置）
3. 编译所有 `.F90` / `.c` 源文件 → `.o`
4. 链接所有 `.o` + 外部库（MPI/HDF5/HYPRE）→ `flash4`

### 1.2 make 的端到端旅程

```
1. 用户在 objdir 里跑
   cd cases/LaserSlab
   make -j4 2>&1 | tee make.log

2. make 读 Makefile，按依赖图：
   - 先编译低层单元（Driver/monitors/RuntimeParameters）
   - 再编译物理单元（Grid/Hydro/Eos/RadTrans/...）
   - 最后编译 Simulation（含算例特定代码）

3. gfortran + mpif90 编译每个 .F90 → .o + .mod
   - 预处理：展开 #include、setup_defines 的 -D 宏
   - 编译：F90 → assembly
   - 汇编：assembly → .o

4. mpif90 链接所有 .o + 外部库 → flash4
   - ld 找符号（libmpi.so、libhdf5.so、libHYPRE.so）
   - 这里会发生 libmpi 冲突 warning（本机特有）

5. 产出 ./flash4 可执行文件
```

### 1.3 为什么 make 慢（L-011 讲为什么）

**典型耗时**（本机）：
- Sedov：~30s（make -j4）
- LaserSlab：~3-5 分钟（make -j4）
- 全物理 + 多物质：~10+ 分钟

**为什么这么久**：
- 几百个 `.F90` 文件，每个几 KB-几十 KB
- F90 编译器（gfortran）做模块依赖分析（`.mod` 文件）开销大
- HEDP 算例含 MGD（HYPRE 模板）、3T（更多变量）、Laser（长函数）—— 比纯 Hydro 多 3-5 倍代码量
- 默认 `-O3` 优化（按 FFLAGS_OPT）开销大

**加速技巧**：
- 用 `-j8` / `-j16`（看 CPU 核数 `nproc`）
- 已 build 过的 objdir，改 parfile 不用重 make（只改运行时参数）
- 改 setup-variables 才需要重 make（影响代码集）

## 2. 标准编译流程

### 2.1 完整命令（含本机 libmpi 处理）

```bash
cd $FLASH_ROOT

# 1. setup（如果 objdir 不存在）
./setup LaserSlab -2d -auto +cylindrical \
  -nxb=16 -nyb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 \
  -objdir=cases/LaserSlab -parfile=example.par

# 2. 进 objdir
cd cases/LaserSlab

# 3. 处理 libmpi 冲突（本机必需，详见 §3）
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak

# 4. 编译
make -j4 2>&1 | tee make.log

# 5. 恢复 libmpi.so.40
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40

# 6. 检查 flash4 是否生成
ls -lh flash4
# 应该看到 -rwxrwxr-x ... flash4
```

### 2.2 增量编译

objdir 已经 build 过，改了某个 `.F90` 后：
```bash
cd cases/LaserSlab
make -j4 2>&1 | tee make_incremental.log
# 只编译改了的 + 依赖的
```

### 2.3 完全重 build

改了 setup-variables（如换 species 数）后必须重 setup + 重 build：
```bash
cd $FLASH_ROOT

# 备份 Makefile.h（site 配置）
cp cases/LaserSlab/Makefile.h /tmp/Makefile.h.bak

# 删除 objdir 重来（保险）
rm -rf cases/LaserSlab
# 或者只 make clean（保留 setup 元信息）
# cd cases/LaserSlab && make clean

# 重 setup
./setup LaserSlab -2d -auto +cylindrical ... -objdir=cases/LaserSlab -parfile=example.par

# 恢复 Makefile.h（如果 setup 覆盖了）
cp /tmp/Makefile.h.bak cases/LaserSlab/Makefile.h

# make
cd cases/LaserSlab
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak
make -j4
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40
```

### 2.4 debug 模式

调 NaN / 数组越界 / 浮点异常 时用：
```bash
# 重 setup 时加 -debug
./setup LaserSlab -2d -auto -debug +cylindrical ... -objdir=cases/LaserSlab_debug

# 编译时会用 FFLAGS_DEBUG（-O0 -g -ffpe-trap=invalid,zero,overflow -fbounds-check）
cd cases/LaserSlab_debug && make -j4

# 跑时会捕获浮点异常（NaN/除零立即 abort）——在 01-data/ 里跑（硬约束）
mkdir -p 01-data && cd 01-data
mpirun -np 2 ../flash4 -par_file ../flash.par
```

**-debug 做什么**（L-011 讲为什么）：
- `-O0`：关闭优化（避免优化器重组代码隐藏 bug）
- `-g`：加调试信息（gdb 可用）
- `-ffpe-trap=invalid,zero,overflow`：浮点异常触发 SIGFPE（NaN / 除零立即 abort，不传播）
- `-fbounds-check`：数组越界立即 abort
- `-fcheck=all`：所有运行时检查

**为什么默认不用**：debug 模式慢 2-3 倍；正常运行用 -O3。

## 3. libmpi 冲突详解（本机核心痛点）

### 3.1 冲突是什么

**现象**（make 链接阶段）：
```
/usr/bin/ld: warning: libmpi.so.12, needed by /home/ubuntu/local/flash/myFLASH4.8/hypre/lib/libHYPRE.so,
may conflict with libmpi.so.40
```

**机制**（L-008：非源码错，详细讲机制）：

```
系统库路径 /lib/x86_64-linux-gnu/
├── libmpi.so.40  ← 系统 OpenMPI（Ubuntu apt 装的）

用户库路径 $FLASH_LIBS/mpich/lib/
└── libmpi.so.12  ← 用户自建 mpich（FLASH 用这个编译）
```

`libHYPRE.so` 内部链接记录：依赖 `libmpi.so.12`（mpich）。
但 ld 链接时默认搜索 `/lib/x86_64-linux-gnu/`，找到了 `libmpi.so.40`（OpenMPI）。
两个 MPI 实现的 ABI 不兼容 → ld 发出 warning。

**为什么只是 warning**：
- ld 仍然能生成 flash4
- 链接期不需要解析符号（运行时才解析）
- 警告含义："可能运行时有问题"

**但运行时会爆炸**（详见 `run_guide.md §3`）：
- loader 先加载 .40（系统路径优先）
- libHYPRE 看到 .12 符号缺失/冲突
- 触发 `SIGSEGV in Driver_initParallel.F90:92`

### 3.2 编译期修复（make 阶段用）

**方案 1：sudo mv（推荐，本机用）**

```bash
# 备份系统的 libmpi.so.40
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak

# ld 现在找不到 .40，只能找 mpich 的 .12 → 无 warning
make -j4 2>&1 | tee make.log

# 恢复（重要！否则其他 MPI 程序会坏）
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40
```

**为什么有效**：ld 找不到 `.40`，loader 路径只有 mpich 的 `.12`，无冲突。

**为什么必须恢复**：系统其他 MPI 程序（如 Python 的 mpi4py）依赖 `.40`，长时间不恢复会坏。

**方案 2：包装成 safe_make.sh**

```bash
#!/bin/bash
# safe_make.sh - 自动处理 libmpi 冲突
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak
make "$@"
EXIT_CODE=$?
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40
exit $EXIT_CODE
```

**方案 3：改 site 配置（永久修复）**

在 `cases/<case>/Makefile.h` 加 `-Wl,-rpath`：
```makefile
LIB_MPI = -L${MPI_PATH}/lib -lmpi -Wl,-rpath,${MPI_PATH}/lib
LFLAGS_OPT = -ggdb -o -Wl,-rpath,${MPI_PATH}/lib
```

`-Wl,-rpath` 把 mpich 路径写进 flash4 的 RPATH，运行时优先用 mpich 的 .12。

**为什么不推荐**：每次 setup 会重新生成 Makefile.h（如改 site 配置在 `sites/ares/Makefile.h` 才会持久）。详见 `setup_guide.md §4`。

### 3.3 编译期 vs 运行期

| 阶段 | 现象 | 修复 |
|---|---|---|
| **make 链接** | ld warning（"may conflict"）| sudo mv .40 |
| **make 完成** | flash4 已生成 | / |
| **mpirun 启动** | SIGSEGV in Driver_initParallel.F90:92 | source flash_env.sh（LD_PRELOAD）|

**核心要点**：
- 编译期 warning 不可忽略——它意味着运行时会爆炸
- 编译期用 sudo mv 一次，运行期永远 source flash_env.sh

详见 `skills/flash-pitfall-finder/knowledge/pitfalls/libmpi-conflict.md`（含 LD_PRELOAD 方案，2026-08-02 实战验证）。

## 4. 编译错误诊断（按 L-012 先引导贴现场）

### 4.1 通用贴现场模板

接到用户"编译报错"时，**第一步**（按 L-012）：

```bash
# 1. 完整 make 输出（含 warning + error）
cd cases/<your_case>
make -j4 2>&1 | tee make.log

# 2. 只看 Error 行
grep -B2 -A10 -i "error" make.log | head -60

# 3. 看 undefined reference（链接错常见）
grep -B1 -A1 "undefined reference\|ld: error" make.log | head -30

# 4. 看 setup 元信息
cat setup_call
cat setup_flags

# 5. 看 Makefile.h site 配置
grep -E "MPI_PATH|HDF5_PATH|HYPRE_PATH" Makefile.h
```

**贴完后能给出针对性诊断**（不要直接列通用原因，先看现场）。

### 4.2 undefined reference

**完整错误**：
```
/usr/bin/ld: ...: undefined reference to `X'
collect2: error: ld returned 1 exit status
```

**机制**（L-008：非源码错）：
- 编译阶段成功（每个 .F90 编译通过）
- 链接阶段失败（找不到符号定义）
- 原因：某 unit 引用了 X，但 X 所在的 unit 没被链接

**常见原因**：

| 错误 | 原因 | 修复 |
|---|---|---|
| `undefined reference to 'mpi_init_'` | MPI 库没链接 | 检查 Makefile.h 的 MPI_PATH；用 mpif90 而非 gfortran |
| `undefined reference to 'hdf5_'` | HDF5 库没链接 | 检查 HDF5_PATH；加 `+hdf5typeio` |
| `undefined reference to 'HYPRE_'` | HYPRE 库没链接 | 检查 HYPRE_PATH；用 MGD 才需要 |
| `undefined reference to '<SomeUnit>_'` | 某 unit Config 没声明 REQUIRES | 改 Config |
| `undefined reference to 'mpif90_'` | mpif90 wrapper 坏 | 重装 mpich |

**贴现场后定位**：用户给的符号名 + setup_flags → 哪个 unit 该提供这个符号 → 是不是 setup 没选中。

### 4.3 SetupError: Unit not found

**这是 setup 阶段（make 之前）的错误**，见 `setup_guide.md §5.1` + `skills/flash-pitfall-finder/knowledge/pitfalls/setup-unit-not-found.md`。

### 4.4 module 'X' not found

**完整错误**：
```
fatal error: cannot open module file 'X.mod' for reading
```

**机制**（F90 模块系统）：
- F90 用 `module X` 定义模块，编译时生成 `X.mod`
- 其他文件 `use X` 时需要先编译 X（生成 .mod）

**原因**：make 依赖图没识别到模块依赖。

**修复**：
```bash
# 重新顺序编译（先 make 一次失败，再 make 第二次）
make -j4
# 失败后再来一次：
make -j4
```

**为什么有效**：第一次失败时已生成大部分 .mod，第二次能找到。

### 4.5 ld: cannot find -lX

**完整错误**：
```
/usr/bin/ld: cannot find -lhdf5
/usr/bin/ld: cannot find -lmpi
/usr/bin/ld: cannot find -lHYPRE
```

**机制**：ld 找不到库文件 `.so` / `.a`。

**贴什么现场**：
```bash
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
ls $FLASH_LIBS/mpich/lib/ | grep -i mpi
ls $FLASH_LIBS/hdf5/lib/ 2>/dev/null | head
ls $FLASH_LIBS/hypre/lib/ 2>/dev/null | head
```

**修复**：确认库实际路径，更新 Makefile.h 的 `*_PATH`。

### 4.6 gfortran 编译器错（语法/类型）

**完整错误**：
```
Error: Type mismatch in argument at (1)
Error: Cannot convert REAL(8) to REAL(4)
Error: Array bounds mismatch
```

**机制**：源码本身有问题（罕见，FLASH 已经过测试）。

**贴现场**：
```bash
# 看完整错误（含文件名 + 行号）
grep -B2 -A5 "Error:" make.log | head -40
```

**常见原因**：
- 用 `make -j16` 时 race condition（少用，按 -j4）→ 重 make
- 用户改了源码（不该改）→ 还原
- setup 选了不兼容的 unit 组合 → 检查 setup_flags

### 4.7 ld: libmpi.so.40 may conflict

见本文 §3。是 warning，按 §3 流程处理。

### 4.8 make 卡住不动

**症状**：`make -j4` 长时间无输出，CPU 100%。

**原因**：
- gfortran 在编译大文件（如 `IO_output.F90` 几千行）
- 死锁（罕见）

**修复**：
```bash
# 看 make 在编哪个文件
ps -ef | grep gfortran | head

# 如果是合理的文件，等几分钟
# 如果真的卡死，Ctrl-C 中断，重新 make -j2（降并行度）
```

## 5. 编译产物与文件清单

编译成功后，objdir 里：

| 文件 | 大小 | 说明 |
|---|---|---|
| `flash4` | 30-100 MB | ⭐ 可执行文件 |
| `*.o` | 几十 MB | 中间产物，可删 |
| `*.mod` | 几 MB | F90 模块二进制 |
| `make.log` | 几 MB | 编译日志（用户 tee 出来的）|

**清理中间产物**（节省磁盘）：
```bash
cd cases/<case>
make clean  # 删 .o / .mod，保留 flash4
make distclean  # 删所有产物，包括 flash4（可能不可逆，慎用）
```

**注意**：`make clean` 后重 make 不需要重 setup（Makefile 仍在）。

## 6. 怎么知道编译成功

```bash
# 1. 看 make.log 最后几行
tail -5 make.log
# 应该看到：
# gfortran ... -o flash4 ...
# （没有 Error 行）

# 2. 检查 flash4 是否生成
ls -lh flash4
# 应该看到 -rwxrwxr-x ... 30M+ ... flash4

# 3. 测试 flash4 能启动（看 usage）
./flash4 --help 2>&1 | head -10
# 或直接 ./flash4（无 -parfile 会报错但能启动）

# 4. 验证链接的库
ldd flash4 | grep -E "mpi|hdf5|HYPRE"
# 应该看到 mpich 的 libmpi.so.12，不是 libmpi.so.40
```

## 7. 速查：编译命令模板

```bash
# 标准 build（含本机 libmpi 处理）
cd cases/<case>
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak
make -j4 2>&1 | tee make.log
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40

# Debug build
cd cases/<case>_debug  # 用 -debug setup 的 objdir
make -j4 2>&1 | tee make_debug.log

# 增量 build（改了 .F90 后）
cd cases/<case>
make -j4 2>&1 | tee make_incr.log

# 看 make 在干什么
cd cases/<case>
make -j1 V=1 2>&1 | tee make_verbose.log  # 单线程 + 详细命令
```

## 8. 常见 make.log 错误速查

| 错误模式 | 含义 | 见本文 |
|---|---|---|
| `Error: ...` （F90 编译错）| 源码或 setup-variables 错 | §4.6 |
| `undefined reference to X` | 链接错，X 没定义 | §4.2 |
| `ld: cannot find -lX` | 找不到库 | §4.5 |
| `cannot open module file X.mod` | 模块依赖 | §4.4 |
| `libmpi.so.X may conflict` | 本机 MPI 冲突（warning）| §3 |
| `collect2: error: ld returned` | 链接失败汇总 | 看 ld 之前的错 |
| `No rule to make target X` | Makefile 坏 | 重 setup |
| `SetupError: ...` | setup 阶段错（make 前） | `setup_guide.md §5` |
