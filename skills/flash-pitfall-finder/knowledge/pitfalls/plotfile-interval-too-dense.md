---
title: plotFileIntervalTime 小于 dt → 每步一个 plotfile（磁盘暴涨 + ROMIO 稳定性风险）
category: IO 配置
severity: 中（磁盘浪费；极端时触发 MPI-IO 层崩溃）
first_seen: 2026-08-03
last_verified: 2026-08-10
verifier: claude
status: stable
tags:
  - IO
  - plotfile
  - plotFileIntervalTime
  - 磁盘
  - ROMIO
related:
  - skills/flash-pitfall-finder/knowledge/pitfalls/mpi-romio-null-comm-allreduce.md
---

# plotFileIntervalTime < dt → 每步一个 plotfile

## 现象

- plotfile 数量 ≈ 步数（如 8041 步产出 1630 个 plotfile）
- 磁盘占用远超预期（单算例 6.7 GB，其中 plt 占绝大部分）
- 长跑后期 IO 占比显著升高，步速变慢

## 原因

`plotFileIntervalTime` 的语义是"模拟时间间隔"（不是 wall time）。
当 `plotFileIntervalTime < dt`（如 0.01e-9 s 而 dt≈1.35e-11 s）时，
**每一步都满足写出条件** → 每步一个集合 HDF5 写。

两个危害：
1. **磁盘**：plt 文件数量爆炸（Sunliang_Xray 实证：1630 个 × 4.7 MB）
2. **稳定性**：每次写都是 ROMIO two-phase 集合 I/O，高频调用给 MPI-IO
   层持续施压——2026-08-03 该算例在 step 8041 触发 ROMIO consensus
   Allreduce on MPI_COMM_NULL 崩溃（见 `mpi-romio-null-comm-allreduce.md`）

## 修复

按物理时间分辨率需求设间隔，而不是按步：

```fortran
plotFileIntervalTime = 0.1e-09    # 每 0.1 ns 一个（20 ns 算例 ≈ 200 个文件，足够）
# 或按步数：
plotFileIntervalStep = 50
```

**经验法则**：整个算例的 plotfile 总量控制在 100~500 个；
`plotFileIntervalTime` 至少大于 5×dt。

## 已落地（2026-08-10）

- `source/Simulation/SimulationMain/Sunliang_Xray/example_xray.par`（模板）
- `cases/Sunliang_Xray/flash.par`（objdir 工作副本）
均已从 0.01e-09 改为 0.1e-09。

## 检查命令

```bash
# 看间隔设置 vs 实际 dt
grep -E "plotFileInterval" cases/<case>/flash.par
grep -oE "dt=[0-9.E+-]+" cases/<case>/01-data/<basenm>.log | tail -3

# 看 plt 数量是否失控
ls cases/<case>/01-data/*_hdf5_plt_cnt_* | wc -l
```
