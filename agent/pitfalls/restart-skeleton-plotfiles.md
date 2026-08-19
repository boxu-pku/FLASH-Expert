---
title: restart 后定时 plotfile 是空壳（只有 AMR 元数据，无物理场数据集）
category: 运行期 IO / restart
severity: 高（该时段的可视化帧全废，但日志无报错、有迷惑性）
first_seen: 2026-08-10
last_verified: 2026-08-10
verifier: claude
status: beta
tags:
  - restart
  - plotfile
  - HDF5
  - IO
  - yt
  - 空壳文件
related:
  - agent/pitfalls/restart-plotfilenumber-overwrite.md
  - agent/pitfalls/mpi-romio-null-comm-allreduce.md
---

# restart 后定时 plotfile 是空壳

## 现象

restart 续跑后，**定时写出的 plotfile 只有 ~0.2 MB**（正常 ~4.7 MB），
h5py/yt 打开报：

```
KeyError: "Unable to synchronously open object (object 'dens' doesn't exist)"
```

递归检查文件内容：只有 AMR 树元数据（`bounding box` / `coordinates` /
`refine level` / `node type` / `* scalars` / `* runtime parameters` /
`unknown names` …），**全部物理场数据集（/dens /tele /depo …）缺失**。

## 迷惑性（为什么难发现）

- 运行日志**正常**：每个 plotfile 都打印 `*** Wrote plotfile to ... ***`，
  且有 `[io_writeData]: wrote 240 blocks`——FLASH 认为数据写了，但数据集没落盘
- 文件名、编号、时间戳（real scalars 里的 time）全都正常

## 范围（2026-08-10 Sunliang_Xray 实证，两次 restart 均复现）

| 文件类型 | restart 后写出 | 状态 |
|---|---|---|
| **定时 plotfile**（plotFileIntervalTime/Step 触发） | 空壳 ❌ |
| **forced plotfile**（算例正常结束时收尾写出） | 正常 ✓（14 场全） |
| **checkpoint** | 正常 ✓（含全部场数据） |
| 全新算例（非 restart）的定时 plotfile | 正常 ✓ |

与 `plotFileNumber` 设不设无关（两次 restart 一次设了一次没设，都空壳）。
**触发条件锁定在 restart 代码路径本身**（FLASH 4.8 + pm4dev + hdf5typeio），
源码根因未定位（io_writeData 报告写了 240 blocks 但数据集未创建——
疑似 restart 后首个定时写路径的 collective 创建环节静默失败，待查）。

## 检查命令

```bash
python3 - <<'EOF'
import h5py, glob
for fn in sorted(glob.glob('cases/<case>/01-data/*_hdf5_plt_cnt_*'))[:5]:
    with h5py.File(fn,'r') as f:
        print(fn, 'OK' if 'dens' in f else '空壳')
EOF
```

## 规避

1. **restart 时段的可视化/分析用 checkpoint 文件**（含全部场数据，
   yt 可以直接 load chk），或算例收尾的 forced plotfile
2. 需要 restart 时段连续帧序列时：宁可从最近 chk 重新**分段 fresh 跑**
   （改 basenm 避免覆盖），也不要依赖 restart 的定时 plt
3. 续跑前先小跑 3-5 步验证产出文件含 dens，再放开长跑

## 延伸

- 续跑另一个坑（编号覆盖）：`restart-plotfilenumber-overwrite.md`
- 本机 ROMIO 集合写崩溃：`mpi-romio-null-comm-allreduce.md`
