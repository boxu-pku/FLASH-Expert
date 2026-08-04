---
title: MPI 错误（通信/同步/abort）
category: 运行期 MPI
severity: fatal（运行时 abort）
first_seen: 2026-06-17
last_verified: 2026-07-12
verifier: claude
status: beta
tags:
  - MPI
  - 通信
  - 死锁
  - 并行
  - mpich
---

# MPI 错误（通信/同步/abort）

## 常见错误信息

### 形式 1：MPI abort（致命，全终止）
```
MPI_ABORT: invoked by rank N on tag X, communicator X
forrtl: error (78): process killed by signal X
```

### 形式 2：死锁（卡住不动）
```
（无输出，CPU 0% 占用，挂起几小时）
```

### 形式 3：通信子不匹配
```
MPI_Comm_rank: Invalid communicator
```

### 形式 4：消息大小不匹配
```
MPI_Recv: message truncated, expected N bytes, received M
```

### 形式 5：rank 0 abort 但其他 rank 不知
```
rank 0: Driver_abortFlash called
（其他 rank 继续运行，死循环或最终超时）
```

## 原因分类

### A. FLASH 自己调 MPI_ABORT

FLASH 内部 `Driver_abortFlash` 在多数实现里调 `MPI_ABORT`。这其实是**正常 abort**，只是看起来像 MPI 错。

诊断：看 abort 信息里的 `[<routine>]` 前缀，定位真正的 sourceTerm/物理单元问题。

### B. 死锁（最棘手）

典型场景：
- rank A 调 `MPI_Recv`，但 rank B 没发对应的 `MPI_Send`
- 不同 rank 走不同分支（如 `if (dr_globalMe == MASTER_PE)` 块内通信但其他 rank 没配合）
- 集合通信（`MPI_Allreduce` 等）有 rank 没参与

诊断：
```bash
# 用 gdb attach 到卡住的进程
gdb -p <flash4_pid>
(gdb) where   # 看堆栈，找 MPI_Wait / MPI_Recv 等待什么

# 或用 mpich 自带的 chkdmesg
export MPICH_CHKD_COMM=user
./flash4 ...
```

### C. 通信子 / tag 不匹配

通常源码 bug，不是用户配置问题。报告给开发者。

### D. 网络层错误

HPC 集群常见，本机（ares 单机）少见。表现为：
- `mpiexec` 启动失败
- `ssh: connection refused` 到计算节点
- `Infiniand: link down`

## 修复

### A. Driver_abortFlash 引发的 MPI_ABORT

**这不是 MPI 问题**，找到真正的 abort 原因：
```bash
grep -B 2 "Driver_abortFlash\|MPI_ABORT" 01-data/<basenm>.log | head -20
```

按 `[<routine>]:` 前缀查 `agent/pitfalls/` 或对应 skill 的 `knowledge/pitfalls.md`。

### B. 死锁

#### 临时绕过

```bash
# 加超时
timeout 60 mpirun -np 4 ./flash4 -parfile=flash.par
# 60 秒后自动 kill，看是 abort 还是卡住

# 减少进程数
mpirun -np 1 ./flash4 -parfile=flash.par   # 单进程跑，能跑过就是并行 bug
```

#### 调试

```bash
# 启动时加 mpich debug
export MPICH_CHKD_COMM=user    # 启用通信检查
export MPICH_CHK_DBG_OUTPUT=1  # 打印调试信息

# 用 gdb attach 卡住的进程
ps aux | grep flash4           # 找 pid
gdb -p <pid>
(gdb) where
(gdb) info threads
```

### C. 切换 MPI 实现

本机配置：用户自建 mpich 在 `/home/ubuntu/local/flash/myFLASH4.8/mpich/`。

```bash
# 验证 mpich 正确
${MPI_PATH}/bin/mpif90 -show
# 应输出 mpich 的库路径

# 用绝对路径启动
/home/ubuntu/local/flash/myFLASH4.8/mpich/bin/mpirun -np 4 ./flash4 ...

# 确认 LD_LIBRARY_PATH
echo $LD_LIBRARY_PATH | tr ':' '\n' | grep mpi
```

### D. 集群配置（HPC 环境）

不在本机范围。典型问题：
- `mpiexec` 不在 PATH
- 节点间 SSH 配置错
- 资源管理器（SLURM/PBS）参数错

## 常见症状与对应原因

| 症状 | 可能原因 | 修复 |
|---|---|---|
| 启动时 abort，"MPI_INIT failed" | mpich 损坏或冲突 | 重装 mpich，或见 `libmpi-conflict.md` |
| 1 进程能跑，多进程 abort | 并行 bug（消息不匹配/死锁） | 用 mpich debug 或单进程对照 |
| 随机 abort（每次不一样） | 未初始化内存 / race condition | 用 `-debug` 编译，加 valgrind |
| 卡在固定步数 | 集合通信有 rank 没到 | gdb attach 看哪个 rank 在哪 |
| abort 时只 rank 0 报告 | MPI_ABORT 设计如此 | grep 日志看 rank 0 的完整 traceback |

## 调试工具

### 1. mpich 内置

```bash
export MPICH_CHKD_COMM=user       # 通信检查
export MPICH_CHK_DBG_OUTPUT=1     # 详细输出
export MPICH_CHK_DBG_CLASS=warn   # 只警告以上
export MPICH_COLL_OPT_MDW=1       # 集合通信检查
```

### 2. Valgrind（找内存错）

```bash
mpirun -np 4 valgrind --error-exitcode=1 --leak-check=no \
    ./flash4 -parfile=flash.par 2>&1 | tee valgrind.log
```

慢但能找 race condition、未初始化变量、buffer overflow。

### 3. gdb

```bash
# 启动时 attach
mpirun -np 4 xterm -e gdb ./flash4    # 每进程一个 xterm（X11 转发）

# 或后 attach
gdb -p <pid>
```

### 4. Flash 内部日志

```bash
# parfile 加调试
ed_printMain   = .true.
ed_printBeams  = .true.
# 看哪个 rank 在哪步卡住
```

## 源码锚点

- `source/Driver/Driver_abortFlash.F90` — abort 实现
- `source/Driver/DriverMain/Driver_initParallel.F90` — MPI 初始化
- `source/multiprocessorTools/MonitorFunctions/` — MPI 工具

## 预防

- 并行代码用 `if (dr_globalMe == MASTER_PE)` 严格控制 IO/abort 调用
- 集合通信确保所有 rank 都参与（不要在 if 块内调 Allreduce 等）
- 启动时加 `MPICH_CHKD_COMM=user` 跑测试算例

## 延伸

- 本机 libmpi 冲突：`libmpi-conflict.md`
- 一般数值 abort：`ffpe-trap-and-nan.md`
- mpi 工具用法：`mpirun --help`、`mpich docs`
