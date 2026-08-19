---
title: restart 续跑不设 plotFileNumber → 新 plotfile 从 0 重新编号并覆盖旧文件
category: restart
severity: 数据丢失（旧 plotfile 被静默覆盖）
first_seen: 2026-08-10
last_verified: 2026-08-10
verifier: claude
status: stable
tags:
  - restart
  - plotFileNumber
  - checkpointFileNumber
  - IO
  - 数据覆盖
related:
  - agent/pitfalls/restart-incompatibility.md
  - agent/pitfalls/mpi-romio-null-comm-allreduce.md
---

# restart 续跑不设 plotFileNumber → 覆盖旧 plotfile

## 现象

restart 续跑后，新写的 plotfile 编号**从 0 附近重新开始**（如 `plt_cnt_0014`），
而不是接着原序列（如 1630+）——**静默覆盖**原算例的早期 plotfile，且被覆盖文件
内容是续跑时段（晚时间）的状态，编号却是早期编号，时间序列错乱。

## 原因

FLASH 4.8 restart 时：
- `checkpointFileNumber = N` 决定**读**哪个 chk（正确续接）
- 但 parfile 里的 `plotFileNumber = 0`（原算例初跑时的值）**覆盖** checkpoint 中
  保存的 plotfile 计数器 → 写出编号从 ~0 重新计

即：chk 里存了 IO 计数器，但 parfile 显式值的优先级更高。

## 修复（restart parfile 三件套，缺一不可）

```fortran
restart              = .true.
checkpointFileNumber = 8        ! 读哪个 chk（最新一个的编号）
plotFileNumber       = 1630     ! 写 plt 从几号继续 = 原序列最后一个编号 + 1
```

查原序列最后一个编号：
```bash
ls cases/<case>/01-data/*_hdf5_plt_cnt_* | sed 's/.*plt_cnt_//' | sort -n | tail -1
# plotFileNumber = 该值 + 1
```

## 实证（2026-08-10，Sunliang_Xray）

- 首次 restart 未设 plotFileNumber：新 plt 从 0 重编号，发现后杀掉时
  原 plt 0000-0069（**70 个**，t≈0~0.7 ns 早期段）已被覆盖
- 设 `plotFileNumber = 1630` 后重启：plt 1630→1886 连续编号，无覆盖，
  跑到 tmax=20 ns 正常结束
- 被覆盖的早期段部分可救：chk_0000 保存 t=0 完整状态
- ⚠️ 连带发现：restart 后写出的定时 plotfile 全部是空壳（无物理场数据）——
  见 `restart-skeleton-plotfiles.md`

## 预防

- flash-case-runner skill 的 restart 流程（run_guide.md §5）已加入 plotFileNumber 步骤
- 续跑前永远先 `ls 01-data/*plt_cnt* | tail -1` 确认续接编号
