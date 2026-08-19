---
title: libmpi.so.40 vs libmpi.so.12 冲突（本机特定）
category: 编译/链接期
machine: ares (本机)
severity: warning（可忽略）→ fatal（运行时如果 libmpi.so.40 在 loader path）
first_seen: 2025-11-12
last_verified: 2026-08-14
verifier: claude
status: stable
tags:
  - 编译
  - MPI
  - libmpi
  - 链接
  - 本机特定
  - hypre
---

# libmpi.so.40 vs libmpi.so.12 冲突

## 错误信息

```
/usr/bin/ld: warning: libmpi.so.12, needed by /home/ubuntu/local/flash/myFLASH4.8/hypre/lib/libHYPRE.so,
may conflict with libmpi.so.40
```

出现在 `make` 链接阶段的最后一行（产生 `flash4` 可执行文件时）。

## 原因

本机（hostname=`ares`）系统提供 `libmpi.so.40`（Ubuntu 默认 OpenMPI 库），但 FLASH 使用的 HYPRE 库（`/home/ubuntu/local/flash/myFLASH4.8/hypre/lib/libHYPRE.so`）链接的是用户自建的 mpich 库（提供 `libmpi.so.12`）。

两个 MPI 实现的 ABI 不兼容：
- 系统 OpenMPI（libmpi.so.40）→ Ubuntu apt 安装
- 用户 mpich（libmpi.so.12）→ `/home/ubuntu/local/flash/myFLASH4.8/mpich/`

`libHYPRE.so` 内部记录了它依赖 `libmpi.so.12`，但系统默认 loader 路径优先找到 `libmpi.so.40`，导致潜在符号冲突。

## 影响等级

| 阶段 | 影响 |
|---|---|
| **make 链接** | 只是 warning，可忽略 |
| **flash4 启动** | 通常 OK，因为运行时 LD_LIBRARY_PATH 指向 mpich |
| **运行中 abort** | 如果 PATH/LD_LIBRARY_PATH 配错，可能 MPI_COMM_WORLD 等基础调用失败 |

## 修复

### 方案 1：临时 workaround（推荐，每次 make 前后做）

```bash
# 备份系统 MPI 库（需要 sudo）
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak

# 重新编译
make -j4

# 编译完成后恢复（避免影响其他程序）
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40
```

### 方案 2：LD_PRELOAD（推荐，不需要 sudo）

2026-08-02 实战验证。不需要 sudo 权限，比方案 1 更安全（不影响其他程序）：

```bash
env LD_PRELOAD=/home/ubuntu/local/flash/myFLASH4.8/mpich/lib/libmpi.so \
    mpirun -np 2 ./flash4 -parfile=flash.par
```

**为什么有效**：`LD_PRELOAD` 让 mpich 的 `libmpi.so.12` 在程序启动时**最先**加载，覆盖系统的 `libmpi.so.40`（OpenMPI），避免两个 MPI 实现冲突。

**适用场景**：
- 没有 sudo 权限的环境（如 HPC 共享节点）
- 不想反复 `sudo mv` / 恢复（避免忘记恢复导致其他程序坏掉）
- 只需要跑 flash4（不影响系统其他 MPI 程序）

**验证结果**（2026-08-02 LaserSlab 4.8 实战）：
- mpirun -np 2 正常启动（之前不用 LD_PRELOAD 会 SIGSEGV in Driver_initParallel.F90:92）
- 66 步跑完，checkpoint + plotfile 正常写入
- 零 MPI 错误

**⚠️ 2026-08-14 系统恶化观察（ICF1D_CH 实战）**：
- 系统 `libmpi.so.40` 升级后，**连之前能跑的 ICF3D_CH flash4 也 SIGSEGV**（同样 Driver_initParallel.F90:92，
  MPI_Comm_Rank）。即历史可执行文件在系统库更新后失效——环境是活的，重跑旧 case 也可能中招。
- 诊断特征：`readelf -d flash4 | grep NEEDED` 显示同时有 `libmpi.so.40`（系统 OpenMPI）和 mpich 库；
  `ldd flash4` 看到两个 libmpi。
- 本次运行时用 `export LD_PRELOAD=/home/ubuntu/local/flash/myFLASH4.8/mpich/lib/libmpi.so.12`
  （注意指向具体 .so.12）+ `LD_LIBRARY_PATH` 含 hypre/hdf5/mpich 三个 lib，mpirun -np 1 正常跑完。
- 本机 sudo 需要密码，方案 1（sudo mv）无法自动执行，**运行时优先用 LD_PRELOAD**。

**注意**：
- 编译期（make）仍需方案 1（sudo mv），因为 ld 不支持 LD_PRELOAD
- LD_PRELOAD 只解决**运行时** loader 冲突

### 方案 3：永久修复（改 site 配置）

在 `sites/ares/Makefile.h`（如果存在）或 `cases/<your_case>/Makefile.h` 加：

```makefile
LIB_MPI = -L${MPI_PATH}/lib -lmpi -Wl,-rpath,${MPI_PATH}/lib
LFLAGS_OPT = -ggdb -o -Wl,-rpath,${MPI_PATH}/lib
```

`-Wl,-rpath` 告诉链接器把 mpich 路径写进可执行文件的 RPATH，运行时优先用这个。

### 方案 2b：写进 bashrc（推荐，固化 LD_PRELOAD）

2026-08-14 验证：把 LD_PRELOAD 固化进 bashrc，运行前 source 一次即可，无需每次手动 export、无需 sudo。
本机专用 bashrc：`/home/ubuntu/local/flash/myFLASH4.8/bashrc_myflash48`（含 mpich/hdf5/hypre 的
LD_LIBRARY_PATH + `export LD_PRELOAD=$MPI_HOME/lib/libmpi.so.12`）。

```bash
source /home/ubuntu/local/flash/myFLASH4.8/bashrc_myflash48
mpirun -np N ./flash4 -par_file flash.par   # 正常启动, 无 SIGSEGV
```

> ⚠️ 注意：旧的 `FLASH4.6.2/bashrc_mpich4112` 只设 LD_LIBRARY_PATH、**没有 LD_PRELOAD**，且路径
> 是 FLASH4.6.2/（与 myFLASH4.8 库不匹配）。LD_LIBRARY_PATH 只能让 loader 找到 mpich 库，**无法阻止**
> libmpi.so.40（若 flash4 编译时已把它链接进 NEEDED）被加载 → 仍会段错误。必须 LD_PRELOAD。
> 之前 bashrc 能跑是因为当时 flash4 编译时移走过 libmpi.so.40（方案1），NEEDED 干净；一旦重新编译
> 没移走（sudo 需密码），bashrc 就不够，需要 LD_PRELOAD 兜底。

### 方案 4：环境变量（每次会话做）

```bash
export LD_LIBRARY_PATH=/home/ubuntu/local/flash/myFLASH4.8/mpich/lib:$LD_LIBRARY_PATH
./flash4 -parfile=flash.par
```

不够稳健（每次会话都要 export）。

## 源码/配置锚点

- `note.txt` — 本机说明（中文）
- `cases/NOTE.txt` — cases 目录的说明（英文）
- `cases/LaserSlab/Makefile.h` — 含 `MPI_PATH = /home/ubuntu/local/flash/myFLASH4.8/mpich`
- 系统库位置：`/lib/x86_64-linux-gnu/libmpi.so.40`

## 预防

- 每次在新 case 上做 `make` 前先做方案 1
- 长期方案：写个 wrapper 脚本 `safe_make.sh`：
  ```bash
  #!/bin/bash
  sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak
  make "$@"
  sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40
  ```

## 延伸

- 类似库冲突：libhdf5、libHYPRE 等也可能有同样问题
- 本机其他特有配置：见 `agent/PROJECT_PLAN.md §site 配置`
- 与 MPI 调用相关的运行时错误：见 `mpi-errors.md`
