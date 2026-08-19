---
title: h5py 直接读 FLASH plotfile 时 cell 索引错位（径向轮廓假边界、coord-data 错配）
category: 后处理 / 可视化
severity: warning（不 abort，但结果误导）
first_seen: 2026-08-05
last_verified: 2026-08-05
verifier: claude
status: stable
tags:
  - h5py
  - yt
  - plotfile
  - 后处理
  - 可视化
  - fortran-order
  - radial-profile
  - 球对称性
---

# h5py 直接读 FLASH plotfile 时 cell 索引错位

## 错误现象

用 `h5py.File(...)` 直接读 FLASH plotfile 的 cell 数据（`dens`, `tele`, `tion` 等）做后处理（径向轮廓、空间平均、cell-by-cell 分析）时，**coord 与 dens 数据错配**——cell 中心坐标算的对，但配的 dens 值是另一个 cell 的。

典型表现：
- 2D 切片图（yt 画）显示球边界在正确的 100 μm
- 用 h5py 自算的径向轮廓显示球边界在 ~120 μm（**偏大 ~20 μm**）
- 球内出现非物理的 "密度 = 0" 区域（实际是球外 cham cell 的值被错配到球内 coord）

## 原因

**FLASH HDF5 plotfile 用 Fortran order 存储cell数组，但 h5py 默认按 C order 解释**。

具体：
- FLASH 是 Fortran 代码，`unk(UNK_VAR, i, j, k, block)` 在内存中按 Fortran order（k 最快变）
- 写入 HDF5 时维度顺序按 Fortran 习惯：文件里实际维度顺序对应 `(k, j, i, block)`
- 但 HDF5 metadata 标记的 `dims = (MAXBLOCKS, NXB, NYB, NZB)`（看起来是 C order）
- h5py 读时返回 shape = `(MAXBLOCKS, NXB, NYB, NZB)` 的 numpy 数组，**按 C order 索引**

结果：`dens_arr[block, i, j, k]` 在 numpy 中是 C-order 索引位置，但实际数据是按 Fortran order 排列的，所以**取到的值不是 cell (i, j, k) 的值**，而是某个被索引错位后的 cell 的值。

### 验证方法

```python
import h5py, yt, numpy as np

# h5py 读
with h5py.File('plt_cnt_0000', 'r') as f:
    dens_h5py = np.array(f['dens'])   # shape (1920, 16, 16, 16)

# yt 读
ds = yt.load('plt_cnt_0000')
ad = ds.all_data()
dens_yt = np.array(ad['flash', 'dens'])

# 总 cells 一样、dens 值分布一样，但 coord 配对错
print(f"h5py: dens > 0.5 的 max r = {h5py_max_r:.1f} μm")  # 错的，可能 ~120 μm
print(f"yt:   dens > 0.5 的 max r = {yt_max_r:.1f} μm")    # 对的，应该 ~100 μm
```

同一 block 同一 cell 索引：
```
h5py:   dens_arr[52, 11, 15, 9] = 1.05   # 配 coord (x=-42.773, y=-38.086, z=-82.617) → r=100.5 μm
yt:     同 coord 的 cell dens = 1e-6      # 球外 cham
yt:     dens=1.05 的实际 coord 是 (x=-42.773, y=-38.086, z=-81.445) → r=99.4 μm（球内）
```

差了**整整 1 个 cell**（1.172 μm）。

## 修复

### ✅ 方法 A：用 yt 读（推荐）

```python
import yt
ds = yt.load(plotfile)
ad = ds.all_data()
x = np.array(ad['index', 'x'])     # 自动正确
y = np.array(ad['index', 'y'])
z = np.array(ad['index', 'z'])
dens = np.array(ad['flash', 'dens'])
# coord 与 dens 自动正确配对
```

yt 的 FLASH frontend 内部处理了 Fortran/C order 问题，所有 coord 与数据自动对齐。

### ⚠️ 方法 B：h5py + transpose

如果一定要用 h5py（比如 yt 太慢），需要 transpose cell 维度：

```python
import h5py
with h5py.File(plotfile, 'r') as f:
    dens = np.array(f['dens'])
# dens shape (n_blocks, NXB, NYB, NZB) but stored as Fortran
# Transpose cell axes (1, 2, 3) → reverse order
dens_fixed = dens.transpose(0, 3, 2, 1)   # (n_blocks, NZB, NYB, NXB) → 反向
# 现在 dens_fixed[b, i, j, k] 是 cell (i, j, k) 的正确值
```

但要小心：bbox、coordinates、bounding box 等"per-block"数据集本身**没有这个问题**（它们不涉及 cell 维度），不需要 transpose。

### ❌ 错误做法（踩过的坑）

直接用 h5py 读 + 用 bbox 算 cell 中心 + 配 dens：
```python
# 错的！
dens_leaf = dens_all[leaf_mask]
bbox_leaf = bbox[leaf_mask]
xc = bbox_leaf[:, 0, 0] + (i + 0.5) * dx   # 这个 coord 是对的
dens_at_xc = dens_leaf[b, i, j, k]          # 这个 dens 是错位后的！
```

coord 算对，但配的 dens 是错的。

## 源码锚点

- `yt/frontends/flash/io.py` — yt FLASH frontend 的 IO 处理（正确处理 Fortran order）
- `yt/frontends/flash/definitions.py` — FLASH 文件格式定义
- HDF5 文件 dens dataset metadata：`DATASPACE SIMPLE { (1920, 16, 16, 16) / (1920, 16, 16, 16) }` —— shape 看起来是 C order 但实际数据是 Fortran order

## 预防

后处理 FLASH plotfile 时，**优先用 yt，不要用 h5py 直接读 cell 数据**。yt 的优势：

1. 自动处理索引顺序（这个坑）
2. 自动处理单位（yt 用 cm、g、K 等 CGS，自动转换）
3. 自动处理 AMR 树（leaf blocks 自动展开）
4. 提供 SlicePlot / ProjectionPlot 等高级 API

只有以下场景才需要 h5py：
- 读 `integer scalars` / `real scalars` / `runtime parameters`（yt 不暴露）
- 读 `bounding box` / `coordinates` / `node type` 等 per-block 元数据（yt 也不直接暴露）
- 极端性能需求（yt 遍历 AMR 树有 overhead）

即使这些场景，**cell 数据本身也要用 yt 读**。

## 延伸

- 相关：[[negative-3t-internal-energy]]（同样是 ICF3D_CH 算例调试过程中发现）
- 相关工具：`yt.frontends.flash` — FLASH 文件读取的权威实现
- 同类问题：FLASH checkpoint 文件也是 Fortran order，同样适用本规则

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-08-05 | 初始创建，来自 ICF3D_CH 算例可视化调试（径向轮廓边界偏移 20 μm 的诡异现象）| claude |
