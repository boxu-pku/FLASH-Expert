# flash-result-analyzer examples

本目录提供 3 个 Python 脚本，覆盖 FLASH 结果分析的主流场景。

## 脚本一览

| 脚本 | 用途 | 输入 | 输出 |
|---|---|---|---|
| `check_energy.py` | 能量守恒检查（.dat + plotfile + LaserProfile 交叉验算）| case 目录 | ASCII 报告 |
| `plot_quick.py` | yt 快速画图（dens/tele/tion 切片 + 速度矢量）| plotfile 或目录 | PNG 图片 |
| `laser_coupling.py` | 激光吸收率分析（LaserEnergyProfile 解析）| LaserEnergyProfile.dat | ASCII 报告 + 可选 PNG |

## 依赖

```bash
# 必装
pip install numpy

# 画图用
pip install matplotlib

# yt（plot_quick.py 和 check_energy.py 重算用）
pip install yt
# 或
conda install -c conda-forge yt
```

## 快速用法

### 1. 能量守恒检查（最常用）

```bash
# 在 FLASH 项目根目录
python skills/flash-result-analyzer/examples/check_energy.py cases/LaserSlab/01-data
```

输出示例：
```
=== FLASH 算例能量守恒分析 ===
目录: cases/LaserSlab/01-data

--- 1. .dat 文件分析 ---
文件: lasslab.dat
  数据点: 1024
  时间范围: 1.000e-15 - 1.000e-09 s
  E_total(0)    = 5.6789e+05 erg
  E_total(end)  = 6.1234e+05 erg
  相对变化      = +7.8234%

--- 2. 激光能量分析 ---
  累计入射:   1.5000e+05 erg
  累计透射:   3.2546e+04 erg
  累计沉积:   1.1745e+05 erg
  吸收率:     78.30%
  ...
```

### 2. 快速画图

```bash
# 单 plotfile
python skills/flash-result-analyzer/examples/plot_quick.py \
  cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050

# plotfile 序列（画时间演化）
python skills/flash-result-analyzer/examples/plot_quick.py \
  cases/LaserSlab/01-data -seq
```

输出：PNG 文件保存在 `figures/` 或 `frames/` 目录。

### 3. 激光吸收率

```bash
python skills/flash-result-analyzer/examples/laser_coupling.py \
  cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat --plot
```

输出：ASCII 报告 + `coupling.png` 时间演化图。

## 完整分析工作流（推荐）

```bash
# Step 1: 跑完算例后先看能量守恒
python skills/flash-result-analyzer/examples/check_energy.py cases/LaserSlab/01-data

# Step 2: 看激光吸收率（仅激光算例）
python skills/flash-result-analyzer/examples/laser_coupling.py \
  cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat --plot

# Step 3: 画图看物理形态
python skills/flash-result-analyzer/examples/plot_quick.py \
  cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050

# Step 4: 序列画图做 GIF
python skills/flash-result-analyzer/examples/plot_quick.py \
  cases/LaserSlab/01-data -seq

# 用 imageio 做 GIF
python -c "
import imageio.v2 as iio
import glob
with iio.get_writer('dens_movie.gif', mode='I', duration=0.2) as w:
    for fn in sorted(glob.glob('frames/dens_*.png')):
        w.append_data(iio.imread(fn))
print('GIF done')
"
```

## 设计原则

- **L-012 公式 CLI 友好**：所有输出纯 ASCII，能在终端直接看
- **L-012 诊断引导**：脚本失败时给具体诊断提示（如"ls -la 确认 plotfile 存在"）
- **L-013 聚焦主流**：3 个脚本覆盖 90% 的分析需求，不强求"全功能"
- **L-014 解释术语**：脚本里的注释解释了每个字段含义（如"Energy_in = 累计入射"）

## 与 knowledge/ 的对应

| 脚本 | 对应 knowledge |
|---|---|
| `check_energy.py` | `knowledge/energy_balance.md` |
| `plot_quick.py` | `knowledge/visualization.md` |
| `laser_coupling.py` | `knowledge/laser_analysis.md` |

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-08-02 | 初始版本（beta）：3 个核心脚本 + 工作流文档 | claude |
