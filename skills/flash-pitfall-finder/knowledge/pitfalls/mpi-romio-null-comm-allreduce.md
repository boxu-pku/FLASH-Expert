---
title: 长跑后 ROMIO(MPI-IO) Allreduce on MPI_COMM_NULL 崩溃
category: 运行期 MPI
severity: fatal（运行中断，可 restart 续跑）
first_seen: 2026-08-03
last_verified: 2026-08-10
verifier: claude
status: beta
tags:
  - MPI
  - ROMIO
  - MPI-IO
  - HDF5
  - plotfile
  - mpich
  - MPI_COMM_NULL
  - Allreduce
related:
  - skills/flash-pitfall-finder/knowledge/pitfalls/mpi-errors.md
  - skills/flash-pitfall-finder/knowledge/pitfalls/libmpi-conflict.md
---

# 长跑后 ROMIO Allreduce on MPI_COMM_NULL 崩溃

## 错误信息（指纹）

```
Abort(207690245) on node 0 (rank 0 in comm 0): Fatal error in internal_Allreduce: Invalid communicator, error stack:
internal_Allreduce(128): MPI_Allreduce(sendbuf=0x7fff..., recvbuf=0x7fff..., count=1, MPI_INT, op=0x98000000, MPI_COMM_NULL) failed
internal_Allreduce(45).: Null communicator
```

两个 rank 同时炸，错误逐字相同（除 sendbuf 地址）。

## 首次出现

2026-08-03，cases/Sunliang_Xray 长跑：step 8041 / t=17.11 ns（tmax=20 ns），
wall 2.5 h，此前已正常写 1630 个 plotfile + 9 个 checkpoint。

## 诊断结论（2026-08-10 排查，逐条实证）

### 错误指纹解码

在本机 mpich 4.1.2 上用 5 行 C 程序逐字复现了该错误，确认：

- `op=0x98000000` = **本进程第一个运行时创建的 MPI_Op**（handle 编码实证：
  MPI_OP_NULL=0x18000000，预定义 op=0x5800000x，第一个用户 op=0x98000000）
- `MPI_INT`（C 数据类型）而非 `MPI_INTEGER` → **调用者是 C 代码，不是 FLASH Fortran**
  （Fortran 侧 Allreduce 会打印 MPI_INTEGER）

### 排除过程（均在 objdir 实证）

| 候选 | 排除依据 |
|---|---|
| XrayImaging (xray_globalComm) | init 时 Driver_getComm(GLOBAL_COMM) 正常赋值；且其 Allreduce 是 MPI_LOGICAL |
| EnergyDeposition (ed_meshComm/LaserComm) | Driver_getComm(MESH_COMM) 正常赋值；MPI_LOGICAL |
| paramesh (amr_mpi_meshComm) | init 一次赋值，全程有效 |
| local_tree_build (blkCartComm) | 每次调用创建后正常 free（行 137/503） |
| HYPRE | libHYPRE.so 反汇编 **0 处** MPI_Op_create 调用点 |
| HDF5 | libhdf5.so **0 处** Op_create |
| FLASH Fortran 全部 Allreduce | dtype 均为 MPI_INTEGER/FLASH_REAL/MPI_LOGICAL，与指纹 MPI_INT 不符 |

### 唯一匹配：ROMIO（MPICH 内置 MPI-IO）

libmpi.so.12 反汇编显示 **只有 ROMIO 内部创建用户 Op**（ADIO_Init / my_consensus /
ADIOI_GEN_SetInfo，共 5 处调用点）——即 op=0x98000000 是 ROMIO 自己的共识归约 op。
崩溃调用 = ROMIO two-phase 集合 I/O 的 consensus Allreduce，且 comm 为 NULL。

### 两个关键环境事实

1. **触发条件——极端 IO 频率**：该算例 `plotFileIntervalTime = 0.01e-09` < dt，
   后期**每一步**都做一次 4.7 MB 的集合 HDF5 写（8041 步写了 1630 个 plotfile）。
2. **非确定性**：从 chk_0008（step 8001）restart 复现，**顺利越过 8041** 跑到 8162+
   无异常 → 不是 grid/物理状态触发的确定性 bug，而是长跑累积/偶发的 MPI-IO 层故障。

## 修复 / 规避

### 立即可做

1. **restart 续跑即可**：崩溃点之后的状态从 checkpoint 恢复是干净的。
   ✅ **2026-08-10 已实证闭环**：Sunliang_Xray 从 chk_0008 续跑，越过崩溃点，
   正常跑到 tmax=20 ns 完成（最终 chk_0009 + plt 续接到 1886）。
2. **降低 plotfile 频率**：`plotFileIntervalTime` 从 0.01e-09 调到 0.1e-09 或
   用 `plotFileIntervalStep = 50`——既省 6.7 GB 磁盘又大幅降低触发概率。
   ✅ 已落入 `example_xray.par` 模板 + objdir flash.par
   （见 `plotfile-interval-too-dense.md`）。

### 若复发

3. **关闭 ROMIO 集合缓冲**（绕过 two-phase consensus 代码路径）：
   ```bash
   export ROMIO_CB_WRITE=disable   # 或 ROMIO hints via H5Pset
   ```
   代价：IO 变慢，但 2 rank 小算例几乎无感。
4. 进一步深挖：重跑时长开 `gdb -batch -ex run -ex bt` 抓栈（需完整 2.5h 复现）。

### 长期建议

5. 长算例分段跑：利用已有的 `wall_clock_checkpoint`，让单次连续运行
   控制在几千步以内，从工程上规避此类累积型故障。

## 贴什么现场（下次遇到）

```bash
# 1. 错误指纹（确认是同一问题）
grep -B5 "Null communicator" cases/<case>/01-data/*.log

# 2. 崩溃步号 / 时间
grep -oE "^ +[0-9]+ +[0-9.]+E-?[0-9]+" cases/<case>/01-data/run_long.log | tail -3

# 3. IO 频率（是否每步都写）
grep -E "plotFileInterval|checkpointFileInterval" cases/<case>/flash.par

# 4. 最新可用 checkpoint（restart 用）
ls cases/<case>/01-data/*_hdf5_chk_* | tail -3
```
