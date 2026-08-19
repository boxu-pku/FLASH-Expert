---
title: 结果分析常见错误——plotfile 读取失败 + 单位混淆 + 变量名错 + stats 列错位
skill: flash-result-analyzer
category: pitfalls
source_anchors:
  - cases/LaserSlab/01-data/lasslab.dat
  - cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat
  - source/IO/IOMain/IO_writeIntegralQuantities.F90:L223-L254
manual_ref: "FLASH 4.8 User Guide §17 (Troubleshooting)"
created: 2026-08-02
last_verified: 2026-08-02
verifier: claude
status: beta
tags:
  - pitfalls
  - troubleshooting
  - plotfile
  - unit-confusion
  - yt-errors
---

# 结果分析常见错误

> **TL;DR**：分析 FLASH 结果时踩的坑主要集中在 5 类——plotfile 读取失败、单位混淆、变量名错、stats 文件列错位、yt 版本不兼容。本文按 L-012 每条给"贴什么现场 + 原因 + 修复"。
>
> **按 L-012 先引导贴现场**：所有诊断类回答先引导用户贴 h5dump / yt 错误 / ls 输出。

---

## 1. plotfile 读取失败

### 1.1 yt 加载报错

**症状**：
```
yt.utilities.exceptions.YTUnidentifiedDataType
或
OSError: Unable to open file
或
IndexError: list index out of range
```

**按 L-012 引导贴现场**：

```bash
# 1. 确认 plotfile 存在 + 结构
ls -la cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050
# 应该看到目录或单文件

# 2. 看 plotfile 内部
h5dump -H cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050 | head -30

# 3. 复现 yt 错误
python -c "
import yt
ds = yt.load('cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050')
print(ds)
"

# 4. 看 yt 版本
python -c "import yt; print(yt.__version__)"
```

**贴完后能给出针对性诊断**：

| yt 报错 | 最可能原因 | 修复 |
|---|---|---|
| `YTUnidentifiedDataType` | yt 版本太老 / plotfile 损坏 | 升级 yt 到 4.0+；或重跑算例 |
| `OSError: Unable to open file` | 路径错 / 权限不足 | `ls -la` 验证；`chmod +r` |
| `IndexError: list index out of range` | 目录 vs 单文件混淆 | yt 一般要目录，看 §1.2 |
| `KeyError: 'DENS'` | 字段名错（大小写）| yt 用 lowercase `'dens'` |
| `AttributeError: 'Dataset' object has no attribute 'current_time'` | FLASH 老版本 plotfile | yt 4.0+ 或手动读 time |
| `KeyError: "object 'dens' doesn't exist"`（2026-08-10 实证） | **restart 后定时 plotfile 是空壳**——只有 AMR 元数据无物理场；文件 ~0.2MB vs 正常 ~4.7MB，日志却显示 wrote N blocks | 用 checkpoint 或 forced plotfile 替代；详见 `agent/pitfalls/restart-skeleton-plotfiles.md` |

### 1.2 plotfile 是目录还是单文件（陷阱）

**机制**：
- **目录型**（FLASH 默认）：`<basenm>_hdf5_plt_cnt_0050/` 目录含 `.dwt`/`.h5`/`.mesh` 等
- **单文件型**（一些配置）：`<basenm>_hdf5_plt_cnt_0050.h5` 单 HDF5 文件

**怎么确认**：
```bash
file cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050
# 输出 "directory" → 目录型
# 输出 "HDF5 ..." → 单文件型

ls cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050
# 目录型应看到：plotflash.dwt / plotflash.h5 / ...
```

**yt 加载**（两种都能 load）：
```python
# yt 自动识别
ds = yt.load('cases/.../lasslab_hdf5_plt_cnt_0050')  # 目录型（不带 .h5）
ds = yt.load('cases/.../lasslab_hdf5_plt_cnt_0050.h5')  # 单文件型（带 .h5）
```

### 1.3 plotfile 损坏（写盘中断了）

**症状**：算例正在写 plotfile 时被 kill，文件半成品

**验证**：
```bash
# 文件大小异常小
ls -lh cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050
# 应 > 几 MB；如 < 1 KB 则损坏

# h5dump 报错
h5dump -H cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050
# 如报 "unable to open" 或 "truncated" → 损坏

# 日志查最后写入
tail -50 cases/<case>/01-data/<basenm>.log | grep -i "writing"
# 看最后完整写的是 cnt_0049 还是 0050
```

**修复**：用前一个 plotfile（cnt_0049）。

### 1.4 plotfile 不在标准位置

**机制**：parfile `plot_plotFileIntervalStep` 决定写 plotfile，`basenm` 决定路径前缀。

**确认在哪**：
```bash
# 看日志里 "writing plotfile" 路径
grep "writing plotfile" cases/<case>/01-data/<basenm>.log | head -5

# 看 parfile 的 basenm
grep -E "^basenm|^io_plotFileDirectory" cases/<case>/flash.par
```

**典型位置**：
- `cases/<case>/01-data/`（如本机 LaserSlab 约定）
- `cases/<case>/`（默认 objdir）
- `cases/<case>/plt/`（如 parfile 配 io_plotFileDirectory）

---

## 2. 单位混淆（最常见陷阱）

### 2.1 温度单位 K vs eV

**症状**：报告里写 "TELE 峰值 1e7" 没说单位，被误读成 1e7 eV 或 1e7 K。

**事实**：FLASH 内部 cgs，plotfile **温度是 K**（不是 eV）。

**换算**：
```
1 eV = 11604 K
1 keV = 1.16e7 K
```

**修复**：分析时**明确标单位**，Python 脚本里换算：

```python
# K → eV
tele_ev = tele_K / 11604

# yt 显示
p.set_unit('tele', 'eV')  # yt 支持单位换算
# 或在 label 注明
p.set_colorbar_label('tele', 'TELE (K)')
```

### 2.2 能量单位 erg vs J

**症状**：报告里写 "沉积 1e5"，实际可能是 1e5 erg（= 1e-2 J）。

**事实**：FLASH 内部 cgs，能量是 **erg**（不是 J）。

**换算**：
```
1 erg = 1e-7 J
1 J = 1e7 erg
```

**修复**：分析时**明确标 erg**：

```python
# LaserEnergyProfile.dat 读出是 erg
total_deposited_erg = ein[-1] - eout[-1]
total_deposited_J = total_deposited_erg * 1e-7

print(f"沉积 = {total_deposited_erg:.4e} erg = {total_deposited_J:.4e} J")
```

### 2.3 密度单位 g/cm³ vs kg/m³

**事实**：FLASH 内部 cgs，密度是 **g/cm³**。

**换算**：
```
1 g/cm³ = 1000 kg/m³
```

**修复**：

```python
# yt 显示
p.set_unit('dens', 'kg/m^3')  # 或保持 g/cm^3

# 手动换算
dens_SI = dens_cgs * 1000
```

### 2.4 压力单位 dyne/cm² vs Pa

**事实**：FLASH 内部 cgs，压力是 **dyne/cm²**（= 0.1 Pa）。

**换算**：
```
1 dyne/cm² = 0.1 Pa
1 Pa = 10 dyne/cm²
1 Mbar = 1e11 dyne/cm²（HEDP 常用）
```

### 2.5 速度单位 cm/s vs m/s

**事实**：FLASH 内部 cgs，速度是 **cm/s**。

**换算**：
```
1 cm/s = 0.01 m/s
1 km/s = 1e5 cm/s
```

### 2.6 单位换算速查表

| 物理量 | cgs 单位 | SI 单位 | 换算 |
|---|---|---|---|
| 长度 | cm | m | 1 cm = 0.01 m |
| 质量 | g | kg | 1 g = 1e-3 kg |
| 时间 | s | s | 1:1 |
| 密度 | g/cm³ | kg/m³ | 1 g/cm³ = 1000 kg/m³ |
| 速度 | cm/s | m/s | 1 cm/s = 0.01 m/s |
| 力 | dyne | N | 1 dyne = 1e-5 N |
| 压力 | dyne/cm² | Pa | 1 dyne/cm² = 0.1 Pa |
| 能量 | erg | J | 1 erg = 1e-7 J |
| 功率 | erg/s | W | 1 erg/s = 1e-7 W |
| 温度 | K | K | 1:1（但 1 eV = 11604 K）|

---

## 3. 变量名错（yt vs UNK 名）

### 3.1 yt 用 lowercase，plotfile 用 uppercase

**陷阱**：

```python
# 错误（用 UNK 大写名）
ad['DENS']  # KeyError
ad['TELE']  # KeyError

# 正确（yt 小写）
ad['dens']  # ✓
ad['tele']  # ✓
```

**修复**：始终用 lowercase。

### 3.2 内能变量混乱（最大陷阱）

**问题**：FLASH 有多个"内能"变量，含义不同。

| yt 名 | UNK 名 | 含义 | 单位 |
|---|---|---|---|
| `eint` | EINT_VAR | 比内能（per mass） | erg/g |
| `Eele` | EELE_VAR | 电子内能密度（per volume） | erg/cm³ |
| `Eion` | EION_VAR | 离子内能密度（per volume） | erg/cm³ |
| `Eradt` | ERAD_* | 辐射能量密度 | erg/cm³ |

**陷阱**：算能量时**单位混了**：

```python
# 错（eint 是 per mass，需要 × ρ）
eele = ad['eint'] * ad['cell_volume']  # ← 量纲错

# 对（eint × dens = 能量密度，再 × volume）
eele = ad['eint'] * ad['dens'] * ad['cell_volume']

# 或直接用 EELE（per volume）
eele = ad['Eele'] * ad['cell_volume']
```

### 3.3 ERAD 变量名不统一

**问题**：不同 FLASH 版本 ERAD 字段名不同。

```python
# FLASH 4.6 / 4.8 主流
ad['Eradt']  # 'Eradt'（t 表示 total）

# 一些版本
ad['Erad']  # 不带 t

# 看 plotfile 实际可用
import yt
ds = yt.load(fn)
print([f for f in ds.field_list if 'rad' in str(f).lower()])
```

### 3.4 辐射温度 TERAD vs TRAD

```python
# yt 内
ad['trad']  # ✓ FLASH 标准
# 一些版本可能叫 'trad' 或 'Tradiation'

# 看 plotfile
print([f for f in ds.field_list if 't' in str(f).lower()][:30])
```

### 3.5 看 plotfile 实际可用字段（最稳）

```python
import yt
ds = yt.load(fn)

# 所有字段
print("All fields:")
for f in sorted(ds.field_list):
    print(f"  {f}")

# 推荐每次新 plotfile 都先看一眼
```

---

## 4. stats 文件（.dat）列错位

### 4.1 跳过注释行不够

**症状**：awk 从第 1 行开始，把表头当数据。

**修复**：跳过前 2 行（标题行 + 空行）：

```bash
# 错（从第 1 行）
awk '{print $6}' file.dat  # 含表头
# 输出：E_total（这是字符串）

# 对（跳过 2 行）
awk 'NR>2 {print $6}' file.dat  # 跳过 "#time ..." 和 "#"
```

### 4.2 列数变了（MHD vs 非 MHD）

**机制**：MHD 算例的 .dat 多一列（MagEnergy）。

**列号对照**：

| 列号 | 非 MHD | MHD |
|---|---|---|
| 1 | time | time |
| 2 | mass | mass |
| 3-5 | x/y/z-mom | x/y/z-mom |
| 6 | **E_total** | E_total |
| 7 | E_kinetic | E_kinetic |
| 8 | E_internal | E_internal |
| 9 | （无） | **MagEnergy** |

**怎么确认**：

```bash
# 看表头第 1 行
head -1 cases/<case>/01-data/<basenm>.dat
# 数有多少列名

# 看 1 行数据有多少列
awk 'NR==3 {print NF}' cases/<case>/01-data/<basenm>.dat
```

**修复**：用列名定位（更鲁棒）：

```bash
# 找 E_total 是第几列
head -1 cases/<case>/01-data/<basenm>.dat | awk '{for(i=1;i<=NF;i++) if($i ~ /E_total/) print i}'
# 输出 6（或 9，看版本）
```

### 4.3 LaserEnergyProfile.dat 列错位

**机制**：第 1 行是 `#Step` 表头，第 2 行是 `#`（空注释），第 3 行才是数据。

```bash
# 错（从第 1 行或第 2 行）
awk '{print $4}' file.dat  # 含表头
awk 'NR>1 {print $4}' file.dat  # 含空注释行 "#"

# 对（跳过 2 行）
awk 'NR>2 {print $4}' file.dat
```

### 4.4 .dat 文件不存在

**症状**：`No such file or directory`

**原因**：
- parfile `io_statsFileName` 改了名
- 算例没跑完（初始化阶段就 abort，没写 .dat）
- basenm 写错

**找**：
```bash
# 看 parfile 的 stats 文件名
grep -i "stats\|basenm" cases/<case>/flash.par

# 找所有 .dat
find cases/<case>/ -name "*.dat" 2>/dev/null

# 看日志里的 stats 写入
grep -i "stats\|integral" cases/<case>/01-data/*.log | head -5
```

---

## 5. yt 版本不兼容

### 5.1 yt 3.0 vs 4.0

**主要 API 变化**：
- yt 4.0 移除了 `derived_field_list`（用 `field_list`）
- yt 4.0 单位系统改了（更严格）
- yt 4.0 SlicePlot 的 `fields` 参数变成单数 `field`

**症状**：
```python
# yt 3.0 老代码
p = yt.SlicePlot(ds, 'z', ['dens', 'tele'])  # 多字段

# yt 4.0
p = yt.SlicePlot(ds, 'z', 'dens')  # 单字段（要循环）
```

**修复**：升级 yt 4.0+，或改代码用单字段循环。

### 5.2 yt 安装问题

```bash
# 检查版本
python -c "import yt; print(yt.__version__)"

# 升级
pip install --upgrade yt

# 或 conda
conda update -c conda-forge yt
```

### 5.3 yt 加载慢

**症状**：load 一个 plotfile 要 1+ 分钟。

**原因**：plotfile 大（>1 GB），yt 一次读全部 block。

**修复**：

```python
# 并行加载
ds = yt.load(fn, nprocs=8)

# 只看一部分
sp = ds.sphere((0, 0, 0), (0.01, 'cm'))

# 只读字段列表（不读数据）
ds = yt.load(fn)
print(ds.field_list)  # 快
```

---

## 6. NaN/Inf 诊断

### 6.1 日志找 NaN

```bash
# 1. 找 NaN 第一次出现
grep -n -i "nan\|inf" cases/<case>/01-data/<basenm>.log | head -5

# 2. 看 NaN 前后 5 行（找触发）
LINE=$(grep -n -i "nan" cases/<case>/01-data/<basenm>.log | head -1 | cut -d: -f1)
sed -n "$((LINE-5)),$((LINE+5))p" cases/<case>/01-data/<basenm>.log

# 3. 找 below floor（密度低于 EOS 表）
grep -i "below floor" cases/<case>/01-data/<basenm>.log | head -10
```

### 6.2 plotfile 找 NaN

```python
import yt
import numpy as np

ds = yt.load('cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050')
ad = ds.all_data()

for f in ['dens', 'tele', 'tion', 'trad', 'pres']:
    try:
        v = np.array(ad[f])
        n_nan = np.isnan(v).sum()
        n_inf = np.isinf(v).sum()
        if n_nan or n_inf:
            print(f"{f}: {n_nan} NaN / {n_inf} Inf out of {len(v)}")
            # 找 NaN 的位置
            nan_mask = np.isnan(v) | np.isinf(v)
            if nan_mask.sum() > 0:
                # 取第一个 NaN cell 的坐标
                coord_x = np.array(ad['x'])[nan_mask][:5]
                coord_y = np.array(ad['y'])[nan_mask][:5]
                print(f"  位置（前 5）: x={coord_x}, y={coord_y}")
    except Exception as e:
        print(f"{f}: SKIP ({e})")
```

### 6.3 NaN 常见原因

| 模式 | 原因 | 验证 |
|---|---|---|
| 早期就 NaN | 初值炸（密度/温度极端）| 看 cnt_0000 |
| 中期突然 NaN | CFL 太大 / 激波过强 | 看 dt 演化 |
| 边界附近 NaN | 边界条件错 | 看 bc_xxx |
| 激光区 NaN | 激光过强 / EOS 表超范围 | 看 ed_* / sim_rhoMin |
| 全域 NaN | 数值不稳定性（hydro_cfl > 1）| 降 CFL |

---

## 7. 数值异常（数值≠NaN 但不合理）

### 7.1 dens 负值

**原因**：
- Hydro 推进有数值耗散，**可能产生轻微负值**
- 通常被 `sim_rhoMin` 截断到正数

**修复**：
```fortran
# parfile 加
sim_rhoMin = 1.0e-10  # cgs
```

### 7.2 温度过高（> 1e9 K）

**原因**：
- 激光功率过大（如 `ed_power` 错）
- EOS 表超范围（如 `sim_teleMax`）
- 数值爆炸（heatexchange 耦合错）

**验证**：
```bash
# 看激光功率
grep "ed_power\|ed_crossSection" cases/<case>/flash.par

# 看 EOS 表温度上限（.imx 文件）
head -20 cases/<case>/<table>.imx | grep -i "temp"
```

### 7.3 激光沉积位置异常

**症状**：沉积不在临界密度附近，而是在入射边界或全域均匀。

**原因**：
- `ed_crossSectionFunctionType` 错（如该用 Gaussian 用了 Uniform）
- `ed_numberOfBeams` 错
- 临界密度算错（`ed_wavelength` 错）

**验证**：
```python
# 看 EELE 沉积分布
import yt
ds = yt.load('cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050')
p = yt.SlicePlot(ds, 'z', 'Eele')
p.set_log('Eele', True)
p.save('eele.png')
# 应看到亮区在临界密度附近（dens ~ 0.01 g/cm³ 对 351 nm）
```

---

## 8. 速查：诊断命令

```bash
# === plotfile 完整性 ===
ls -lh cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050
h5dump -H cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050 | head -20

# === yt 加载测试 ===
python -c "import yt; ds = yt.load('cases/.../plt_cnt_0050'); print(ds.field_list[:5])"

# === NaN 扫描 ===
grep -i "nan" cases/<case>/01-data/<basenm>.log | head -5

# === .dat 列结构 ===
head -1 cases/<case>/01-data/<basenm>.dat  # 看表头
awk 'NR==3 {print NF}' cases/<case>/01-data/<basenm>.dat  # 看列数

# === 物理量范围（Python）===
python -c "
import yt, numpy as np
ds = yt.load('cases/.../plt_cnt_0050')
ad = ds.all_data()
for f in ['dens', 'tele', 'tion', 'trad', 'pres']:
    try:
        v = np.array(ad[f])
        print(f'{f}: min={v.min():.3e} max={v.max():.3e}')
    except: pass
"

# === yt 版本 ===
python -c "import yt; print(yt.__version__)"
```

---

## 9. 延伸阅读

- **plotfile 结构**：`knowledge/overview.md §2`
- **能量守恒**：`knowledge/energy_balance.md`
- **激光算例**：`knowledge/laser_analysis.md`
- **可视化**：`knowledge/visualization.md`
- **跑算例错误**：`flash-case-runner/knowledge/pitfalls.md`（操作前半段错误）
- **已知 pitfall 数据库**：`flash-pitfall-finder` skill（按错误信息匹配）

---

## 10. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-08-02 | 初始创建（beta）：10 段踩坑汇总——plotfile 读取失败 + 单位混淆（K/eV、erg/J、cgs/SI 速查表）+ 变量名错（yt vs UNK、EELE 单位陷阱）+ .dat 列错位 + yt 版本不兼容 + NaN/Inf 诊断 + 数值异常；按 L-012 每条都给"贴什么现场 + 原因 + 修复" | claude |
