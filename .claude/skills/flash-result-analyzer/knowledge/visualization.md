---
title: 可视化——yt + h5py + matplotlib 快速画图模板
skill: flash-result-analyzer
category: visualization
source_anchors:
  - cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0000
  - source/IO/IOMain/IO_writePlotfile.F90
manual_ref: "yt docs: https://yt-project.org/doc/examining/loading_data.html#flash-data"
created: 2026-08-02
last_verified: 2026-08-02
verifier: claude
status: beta
tags:
  - visualization
  - yt
  - h5py
  - matplotlib
  - slice-plot
  - profile
---

# 可视化模板

> **TL;DR**：FLASH plotfile 用 **yt** 最方便（自动识别 AMR + 物理单位），用 **h5py + matplotlib** 最灵活（完全控制）。本文给主流场景的模板——切片、1D 剖面、时间演化、相图——每个都给最小可运行脚本 + 关键陷阱。
>
> **按 L-013 聚焦主流**：主讲 yt（用户首选），h5py 仅在 yt 不支持时用。
>
> **按 L-011 讲为什么**：每个画图选择都解释"为什么这么画、不这么画会怎样"。

---

## 1. yt vs h5py vs matplotlib（按 L-014 解释术语）

### 1.1 三个工具的分工

| 工具 | 是什么 | 干什么 | 何时用 |
|---|---|---|---|
| **yt** | Python AMR 数据分析库 | 直接 load FLASH plotfile，自动处理 AMR + 单位 | **默认**——任何 AMR 数据分析 |
| **h5py** | Python HDF5 读取库 | 直接读 plotfile 的 .h5，绕过 yt | yt 不支持的字段 / 高级自定义 |
| **matplotlib** | Python 画图库 | 画线图、散点、contour | 配合 yt 或 h5py 出图 |

### 1.2 为什么默认用 yt（L-011 讲为什么）

- **自动识别 AMR**：yt 知道 FLASH 用块结构 AMR，自动合并不同 refine level
- **自动单位**：yt 知道 cgs，自动转换（如 cell_volume → cm³）
- **内置字段**：yt 知道 'dens'/'tele'/'velocity_magnitude' 等，自动 map
- **派生字段**：yt 能算 KE = 0.5·ρ·v² 不用自己写

**不这么用会怎样**：
- 直接 h5py 要手写 AMR 树遍历（~50 行）
- 直接 h5py 要自己算 cell 体积（r·dr·dz 圆柱 vs dx·dy·dz 笛卡尔）
- 直接 h5py 单位要自己换算

### 1.3 安装

```bash
# yt（推荐 conda）
conda install -c conda-forge yt

# 或 pip
pip install yt

# h5py（一般已装）
pip install h5py

# matplotlib（一般已装）
pip install matplotlib
```

---

## 2. yt 快速画图模板

### 2.1 SlicePlot（2D/3D 切片）——最常用

**最小脚本**（10 行）：

```python
import yt

ds = yt.load('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050')

# 2D 算例：投影轴 'z'（FLASH 2D 是 x-y 平面，z 是法向）
# 3D 算例：投影轴可选 'x'/'y'/'z'
p = yt.SlicePlot(ds, 'z', 'dens')
p.set_log('dens', True)
p.set_cmap('dens', 'viridis')
p.set_colorbar_label('dens', 'Density (g/cm^3)')
p.save('density_slice.png')
```

**为什么用 SlicePlot**（L-011 讲为什么）：
- SlicePlot 给的是**单层切片**（cell 中心值），适合看内部结构
- 替代 ProjectionPlot 给的是**积分**（沿轴累积），适合看柱密度
- HEDP 通常用 SlicePlot（看密度/温度分布）

### 2.2 多变量切片（一次性画多个量）

```python
import yt

ds = yt.load('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050')

# 一次性画 dens/tele/tion/erad 4 个量
fields = ['dens', 'tele', 'tion', 'trad']
for f in fields:
    p = yt.SlicePlot(ds, 'z', f)
    p.set_log(f, True)
    p.set_cmap(f, 'viridis' if f == 'dens' else 'hot')
    p.set_colorbar_label(f, f)
    p.save(f'{f}_slice.png')
```

### 2.3 叠加速度矢量

```python
import yt

ds = yt.load('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050')
p = yt.SlicePlot(ds, 'z', 'dens')
p.set_log('dens', True)
p.annotate_velocity(factor=20)  # 速度矢量，factor 控制密度
p.annotate_grids()  # 可选：画 AMR 网格线
p.save('density_with_velocity.png')
```

### 2.4 设置坐标范围（zoom in）

```python
import yt

ds = yt.load('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050')

# zoom 到激光沉积区
p = yt.SlicePlot(ds, 'z', 'dens', width=(0.01, 'cm'))  # 0.01 cm 宽
# 或
p.zoom(4)  # 放大 4 倍

# 自定义中心
p = yt.SlicePlot(ds, 'z', 'dens', center=(0.005, 0.005, 0), width=(0.01, 'cm'))
p.save('density_zoom.png')
```

### 2.5 1D 剖面（ProfilePlot）

适合**沿某个方向看物理量分布**（如沿激光方向看 TELE 剖面）。

```python
import yt

ds = yt.load('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050')

# 沿 y 轴的 TELE 剖面（每个 y 一个平均值）
plot = yt.ProfilePlot(
    ds,
    'y',                # x 轴：y 坐标
    ['tele', 'tion'],   # y 轴：温度
    weight_field='cell_volume'  # 体积加权
)
plot.save('tele_tion_profile_y.png')

# 沿 x 轴的密度剖面
plot = yt.ProfilePlot(
    ds,
    'x',
    ['dens'],
    weight_field='cell_volume'
)
plot.save('dens_profile_x.png')
```

### 2.6 时间演化图（PhasePlot）

适合**看物理量的散点分布**（如 dens-tele 相图）。

```python
import yt

ds = yt.load('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050')

# dens vs tele 相图（每个 cell 一点）
plot = yt.PhasePlot(
    ds.all_data(),
    'dens',      # x 轴
    'tele',      # y 轴
    'cell_volume',  # 颜色（按 cell 体积加权）
    weight_field='cell_volume'
)
plot.set_log('dens', True)
plot.set_log('tele', True)
plot.save('dens_tele_phase.png')
```

---

## 3. yt 多 plotfile 序列分析

### 3.1 遍历 plotfile 画时间演化

```python
import yt
import glob

files = sorted(glob.glob('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_*'))
print(f"找到 {len(files)} 个 plotfile")

for fn in files:
    ds = yt.load(fn)
    t = float(ds.current_time)
    print(f"画 {fn} (t={t:.3e}s)")
    
    p = yt.SlicePlot(ds, 'z', 'dens')
    p.set_log('dens', True)
    p.save(f'frames/dens_{t:.3e}.png')
```

### 3.2 做 GIF 动画

```bash
# 用 ffmpeg / imageio
pip install imageio

python -c "
import imageio.v2 as imageio
import glob, os

files = sorted(glob.glob('frames/dens_*.png'))
with imageio.get_writer('dens_evolution.gif', mode='I', duration=0.2) as w:
    for fn in files:
        w.append_data(imageio.imread(fn))
print(f'GIF 已生成，{len(files)} 帧')
"
```

---

## 4. h5py 低层访问（特殊场景）

### 4.1 何时用 h5py 而不是 yt

| 场景 | 用什么 |
|---|---|
| yt 不支持的字段（如某些内部诊断）| h5py |
| 想绕过 AMR 树（直接看 cell）| h5py |
| 大批量提取数值（性能优）| h5py |
| 看 HDF5 元数据（dataset 列表）| h5py |

### 4.2 看 plotfile 结构

```python
import h5py

fn = 'cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050'
# plotfile 可能是目录或单文件，先 ls
import os
if os.path.isdir(fn):
    # 目录型 plotfile
    print(os.listdir(fn))
    # 通常有：plotflash.dwt / plotflash.h5 等
    h5fn = os.path.join(fn, [s for s in os.listdir(fn) if s.endswith('.h5')][0])
else:
    h5fn = fn

f = h5py.File(h5fn, 'r')

# 顶级 dataset
print("datasets:", list(f.keys()))

# 每个 dataset 的 shape
for k in list(f.keys())[:10]:
    print(f"  {k}: {f[k].shape} dtype={f[k].dtype}")

# 元数据（attributes）
print("attrs:", dict(f.attrs))
```

### 4.3 读 DENS 字段

```python
import h5py
import numpy as np

f = h5py.File(fn, 'r')

# DENS 通常是 4D：[block, i, j, k]
dens = np.array(f['DENS'])
print(f"dens shape: {dens.shape}")  # e.g., (nblocks, NXB, NYB, NZB)
print(f"dens range: {dens.min()} - {dens.max()}")

# 读坐标轴（如果有）
coordx = np.array(f['coordinates'])  # block 中心坐标
```

### 4.4 h5py + matplotlib 画图（绕过 yt）

```python
import h5py
import numpy as np
import matplotlib.pyplot as plt

f = h5py.File(fn, 'r')
dens = np.array(f['DENS'])  # shape: (nblocks, NXB, NYB, 1) for 2D
# 简化：所有 block 的密度 histogram
plt.figure(figsize=(8, 6))
plt.hist(dens.flatten(), bins=100, log=True)
plt.xlabel('Density (g/cm^3)')
plt.ylabel('Cell count')
plt.xscale('log')
plt.title('Density distribution')
plt.savefig('dens_hist.png', dpi=150, bbox_inches='tight')
plt.close()
```

---

## 5. matplotlib 模板（出报告图）

### 5.1 时间演化曲线（标准报告图）

```python
import numpy as np
import matplotlib.pyplot as plt

# 从 .dat 读
data = np.loadtxt('cases/LaserSlab/01-data/lasslab.dat', comments='#')
t = data[:, 0]
etot = data[:, 5]  # E_total
ekin = data[:, 6]  # E_kinetic
eint = data[:, 7]  # E_internal

# 归一化
etot_rel = (etot - etot[0]) / etot[0] * 100

# 画
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))

ax1.semilogx(t, etot, 'r-', label='E_total', linewidth=2)
ax1.semilogx(t, ekin, 'b--', label='E_kinetic', linewidth=1.5)
ax1.semilogx(t, eint, 'g-.', label='E_internal', linewidth=1.5)
ax1.set_xlabel('Time (s)')
ax1.set_ylabel('Energy (erg)')
ax1.legend()
ax1.grid(True, which='both', alpha=0.3)
ax1.set_title('Energy components evolution')

ax2.semilogx(t, etot_rel, 'k-', linewidth=2)
ax2.axhline(0, color='gray', linestyle='--')
ax2.set_xlabel('Time (s)')
ax2.set_ylabel('Relative E_total change (%)')
ax2.grid(True, which='both', alpha=0.3)
ax2.set_title('Conservation check')

plt.tight_layout()
plt.savefig('energy_evolution.png', dpi=150, bbox_inches='tight')
plt.close()
```

### 5.2 激光吸收率时间演化

```python
import numpy as np
import matplotlib.pyplot as plt

data = np.loadtxt('cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat', comments='#')
t = data[:, 1]
ein = data[:, 3]
eout = data[:, 4]

coupling = (ein - eout) / ein * 100

plt.figure(figsize=(10, 6))
plt.semilogx(t, coupling, 'b-', linewidth=2)
plt.axhline(coupling[-1], color='r', linestyle='--', 
            label=f'Final: {coupling[-1]:.2f}%')
plt.xlabel('Time (s)')
plt.ylabel('Laser coupling efficiency (%)')
plt.title('Laser absorption evolution')
plt.legend()
plt.grid(True, which='both', alpha=0.3)
plt.ylim(0, 100)
plt.savefig('coupling_evolution.png', dpi=150, bbox_inches='tight')
plt.close()
```

### 5.3 三温演化

```python
import yt, numpy as np
import glob
import matplotlib.pyplot as plt

# 提取（见 laser_analysis.md §3.2）
times, tele_avg, tion_avg, trad_avg = [], [], [], []
for fn in sorted(glob.glob('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_*'))[:20]:
    ds = yt.load(fn)
    ad = ds.all_data()
    vol = np.array(ad['cell_volume'])
    times.append(float(ds.current_time))
    tele_avg.append(np.sum(np.array(ad['tele'])*vol)/np.sum(vol)/11604)  # eV
    tion_avg.append(np.sum(np.array(ad['tion'])*vol)/np.sum(vol)/11604)
    trad_avg.append(np.sum(np.array(ad['trad'])*vol)/np.sum(vol)/11604)

# 画
plt.figure(figsize=(10, 6))
plt.semilogx(times, tele_avg, 'r-', label='TELE', linewidth=2)
plt.semilogx(times, tion_avg, 'b-', label='TION', linewidth=2)
plt.semilogx(times, trad_avg, 'g-', label='TRAD', linewidth=2)
plt.xlabel('Time (s)')
plt.ylabel('Volume-averaged T (eV)')
plt.title('Three-temperature evolution')
plt.legend()
plt.grid(True, which='both', alpha=0.3)
plt.savefig('three_T_evolution.png', dpi=150, bbox_inches='tight')
plt.close()
```

---

## 6. yt 字段名速查

### 6.1 常用字段（按 L-014 速查）

**yt 用 lowercase，plotfile 是 uppercase**：

| yt 字段 | plotfile UNK | 含义 | 单位 |
|---|---|---|---|
| `dens` | DENS | 密度 | g/cm³ |
| `tele` | TELE | 电子温度 | K |
| `tion` | TION | 离子温度 | K |
| `trad` | TRAD | 辐射温度 | K |
| `pres` | PRES | 总压力 | dyne/cm² |
| `velx` | VELX | x 方向速度 | cm/s |
| `vely` | VELY | y 方向速度 | cm/s |
| `velz` | VELZ | z 方向速度 | cm/s |
| `eint` | EINT | 比内能 | erg/g |
| `Eele` | EELE | 电子内能密度 | erg/cm³ |
| `Eion` | EION | 离子内能密度 | erg/cm³ |
| `Eradt` | ERAD_RADIATION_VARIABLE | 辐射能量密度 | erg/cm³ |
| `cell_volume` | (yt 派生) | cell 体积 | cm³ |
| `velocity_magnitude` | (yt 派生) | 速度模 | cm/s |

### 6.2 看 plotfile 实际可用字段

```python
import yt
ds = yt.load('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050')

# 所有字段
print("All fields:")
for f in sorted(ds.field_list):
    print(f"  {f}")

# 仅 FLASH 输出字段（'flash' 类型）
print("\nFLASH fields:")
for f in sorted(ds.fields.flash):
    print(f"  {f}")
```

---

## 7. 常见可视化问题

### 7.1 字段不存在

```python
# yt 报错
yt.utilities.exceptions.YTFieldNotFound: Could not find field ...
```

**原因**：算例没启用对应单元（如没用 `+mgd` 就没 'trad'）

**修复**：先 `print(ds.field_list)` 看实际可用，再选字段。

### 7.2 单位异常

```python
# yt 自动 cgs，但有时显示 Jy/cm²/s 等怪单位
p = yt.SlicePlot(ds, 'z', 'dens')
# 强制单位
p.set_unit('dens', 'g/cm^3')  # 或 'kg/m^3'
```

### 7.3 plotfile 是目录还是文件

```bash
# FLASH 默认写目录型 plotfile（一个目录含多个 .h5 + 元数据）
ls cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050/
# 应有：plotflash.dwt、plotflash.h5、...

# yt 直接 load 目录
python -c "import yt; ds = yt.load('cases/.../lasslab_hdf5_plt_cnt_0050'); print(ds)"

# 如果是单 .h5 文件（一些自定义配置）
python -c "import yt; ds = yt.load('cases/.../single.h5'); print(ds)"
```

### 7.4 2D 算例投影轴选错

```python
# 2D 算例（x-y 平面），SlicePlot 投影轴只能是 'z'
p = yt.SlicePlot(ds, 'z', 'dens')  # ✓
p = yt.SlicePlot(ds, 'x', 'dens')  # ✗ 报错
```

### 7.5 大 plotfile 加载慢

```python
# yt.load 默认读全部 block
# 对超大 plotfile，用 'nprocs' 并行
ds = yt.load(fn, nprocs=8)  # 8 个并行进程

# 或只读一部分（按 bounding box）
import yt
ds = yt.load(fn)
sp = ds.sphere((0, 0, 0), (0.01, 'cm'))  # 只看中心 0.01 cm 球
```

---

## 8. 完整可视化脚本（`examples/plot_quick.py`）

```python
#!/usr/bin/env python3
# plot_quick.py - 快速画图（密度/温度切片）
# 用法：python plot_quick.py cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050

import sys
import yt
import os

fn = sys.argv[1]
output_dir = 'figures'
os.makedirs(output_dir, exist_ok=True)

print(f"Loading {fn}...")
ds = yt.load(fn)
print(f"Time: {float(ds.current_time):.3e} s")
print(f"Available fields: {len(ds.field_list)}")

# 主流量切片
fields = [
    ('dens', 'viridis', True, 'Density (g/cm^3)'),
    ('tele', 'hot', True, 'TELE (K)'),
    ('tion', 'hot', True, 'TION (K)'),
    ('trad', 'hot', True, 'TRAD (K)'),
    ('pres', 'plasma', True, 'Pressure (dyne/cm^2)'),
]

for field, cmap, log, label in fields:
    try:
        p = yt.SlicePlot(ds, 'z', field)
        p.set_log(field, log)
        p.set_cmap(field, cmap)
        p.set_colorbar_label(field, label)
        out = os.path.join(output_dir, f'{field}_t{float(ds.current_time):.3e}.png')
        p.save(out)
        print(f"  Saved {out}")
    except Exception as e:
        print(f"  SKIP {field}: {e}")

# 速度矢量叠加
try:
    p = yt.SlicePlot(ds, 'z', 'dens')
    p.set_log('dens', True)
    p.annotate_velocity(factor=16)
    out = os.path.join(output_dir, f'dens_velocity_t{float(ds.current_time):.3e}.png')
    p.save(out)
    print(f"  Saved {out}")
except Exception as e:
    print(f"  SKIP velocity overlay: {e}")

print(f"\nDone. Output: {output_dir}/")
```

---

## 9. 速查：可视化命令

```python
# 1. SlicePlot（最常用）
import yt
ds = yt.load('plotfile.h5')
yt.SlicePlot(ds, 'z', 'dens').save('out.png')

# 2. 多变量
for f in ['dens', 'tele', 'tion']:
    yt.SlicePlot(ds, 'z', f).save(f'{f}.png')

# 3. 1D 剖面
yt.ProfilePlot(ds, 'y', ['tele', 'tion']).save('profile.png')

# 4. 相图
yt.PhasePlot(ds.all_data(), 'dens', 'tele', 'cell_volume').save('phase.png')

# 5. 看字段
print(ds.field_list)
```

```bash
# 6. 批量画图
python plot_quick.py cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050

# 7. 做 GIF
python -c "import imageio.v2 as iio; import glob; \
  with iio.get_writer('movie.gif', mode='I', duration=0.2) as w: \
    [w.append_data(iio.imread(f)) for f in sorted(glob.glob('frames/*.png'))]"
```

---

## 10. 延伸阅读

- **yt 官方文档**：https://yt-project.org/doc/
- **FLASH 数据加载**：https://yt-project.org/doc/examining/loading_data.html#flash-data
- **能量守恒分析**：`knowledge/energy_balance.md`
- **激光算例专项**：`knowledge/laser_analysis.md`
- **常见错误**：`knowledge/pitfalls.md`
- **完整脚本**：`examples/plot_quick.py`
- **plotfile 结构**：`knowledge/overview.md §2`

---

## 11. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-08-02 | 初始创建（beta）：11 段可视化——yt vs h5py vs matplotlib + SlicePlot/ProfilePlot/PhasePlot 模板 + 多 plotfile 序列 + h5py 低层 + matplotlib 报告图 + 字段速查 + 常见问题；按 L-011 讲为什么；按 L-013 聚焦 yt；按 L-014 字段名速查 | claude |
