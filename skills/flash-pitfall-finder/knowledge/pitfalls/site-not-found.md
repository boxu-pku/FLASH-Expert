---
title: setup 找不到 sites/<hostname>/Makefile.h
category: setup 期
severity: warning → 运行时 fatal
first_seen: 2026-06-17
last_verified: 2026-07-12
verifier: claude
status: beta
tags:
  - setup
  - site
  - Makefile.h
  - hostname
  - 配置
---

# setup 找不到 sites/<hostname>/Makefile.h

## 错误信息

### 形式 1：直接报错
```
SetupError: No site file found for host '<hostname>'. Expected: sites/<hostname>/Makefile.h
```

### 形式 2：Makefile.h 为空或残缺
```
Makefile.h:1: *** missing separator. Stop.
```

### 形式 3：编译时变量未定义
```
Makefile:123: *** No rule to make target '...'. Stop.
```
（因为 `MPI_PATH` / `HDF5_PATH` 等变量没在 Makefile.h 里设）

## 原因

FLASH 的 setup 流程：
1. 读 `$(hostname)` → 如 `ares`
2. 找 `sites/ares/Makefile.h`
3. 找到 → copy 到 objdir 作为 `Makefile.h`
4. 找不到 → fallback 或 abort（看 setup.py 版本）

本机（hostname=`ares`）的情况：
- `sites/ares/` 目录**不存在**
- 已 build 的 cases 在 `cases/<name>/Makefile.h` 里**手动复制了**配置块
- 新 setup 时找不到 → 报错

源码：`bin/setup.py` 在 `genFiles.py` 的 `genMakefileHierarchy` 里处理。

## 修复

### 方案 1：建 sites/ares/Makefile.h（推荐，永久修复）

从已有 case 的 Makefile.h 复制过来：

```bash
mkdir -p sites/ares
cp cases/LaserSlab/Makefile.h sites/ares/Makefile.h
```

然后检查并修改以匹配新机环境（虽然本机就是 ares，不用改）。

下次 `./setup` 自动找到。

### 方案 2：手动 cp Makefile.h 到 objdir（临时）

setup 后，把 Makefile.h 复制到 objdir：

```bash
./setup <problem> ... -objdir=cases/<new_case>
cp cases/LaserSlab/Makefile.h cases/<new_case>/Makefile.h
cd cases/<new_case> && make -j4
```

**警告**：下次 setup 会覆盖这个 Makefile.h！

### 方案 3：用 -site 选项指定其他 site

某些 setup.py 版本支持 `-site=<other_host>`：
```bash
./setup <problem> ... -site=linux-gfortran-mpich
```

→ 用 `sites/linux-gfortran-mpich/Makefile.h`。

## 关键配置块（sites/ares/Makefile.h 必须含）

```makefile
# 路径
MPI_PATH   = /home/ubuntu/local/flash/myFLASH4.8/mpich
HDF5_PATH  = /home/ubuntu/local/flash/myFLASH4.8/hdf5
HYPRE_PATH = /home/ubuntu/local/flash/myFLASH4.8/hypre

# 编译器
FCOMP = ${MPI_PATH}/bin/mpif90
CCOMP = ${MPI_PATH}/bin/mpicc
LINK  = ${MPI_PATH}/bin/mpif90

# Flags（gfortran）
FFLAGS_OPT = -ggdb -c -O2 -fdefault-real-8 -fdefault-double-8 -Wuninitialized
FFLAGS_DEBUG = -ggdb -c -O0 -fdefault-real-8 -fdefault-double-8 \
               -pedantic -Wall -Waliasing -Wsurprising -Wconversion -Wunderflow \
               -ffpe-trap=invalid,zero,overflow -fbounds-check -fimplicit-none

# OpenMP
OPENMP = -fopenmp

# HDF5 / HYPRE / LAPACK
FFLAGS_HYPRE = -I${HYPRE_PATH}/include
CFLAGS_HDF5  = -I${HDF5_PATH}/include -DH5_USE_16_API
LIB_HYPRE = -L${HYPRE_PATH}/lib -lHYPRE
LIB_HDF5  = -L${HDF5_PATH}/lib -lhdf5 -lz
LIB_LAPACK = -L/usr/lib/x86_64-linux-gnu -llapack
```

## 源码锚点

- `bin/setup.py` — 选 site 的逻辑（按 `socket.gethostname()`）
- `bin/genFiles.py:genMakefileHierarchy` — copy Makefile.h 到 objdir
- `cases/LaserSlab/Makefile.h` — 可作模板
- `cases/Sunliang_laser_CH/Makefile.h` — 同上

## 预防

- 永久方案：建 `sites/ares/Makefile.h`（方案 1）
- 定期验证：`./setup Sedov -auto -objdir=/tmp/test_setup` 看能否生成完整 objdir

## 延伸

- 配套错误：libmpi 冲突（`libmpi-conflict.md`）
- setup 单元找不到：`setup-unit-not-found.md`
- 切换 hostname 时（如换机器）必须更新 site 文件
