---
title: 激光算例专项分析——吸收率 + TELE/TION 演化 + ERAD 分布
skill: flash-result-analyzer
category: laser-analysis
source_anchors:
  - source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/EnergyDeposition_init.F90:L431
  - source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserRayTrace/CellAverage/ed_traceBlockRays2DCyl3D.F90:L950
  - cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat
manual_ref: "FLASH 4.8 User Guide §9.4 (Laser Diagnostics)"
created: 2026-08-02
last_verified: 2026-08-02
verifier: claude
status: beta
tags:
  - laser
  - coupling-efficiency
  - absorption
  - tele
  - tion
  - erad
  - 3t-evolution
---

# 激光算例专项分析

> **TL;DR**：激光算例（如 LaserSlab HEDP）有三个关键诊断量——**激光吸收率**（沉积了多少）、**TELE/TION 演化**（电子先热、离子后热）、**ERAD 空间分布**（辐射在哪里产生）。本文讲每个量怎么算、典型值、不正常时怎么诊断。
>
> **按 L-015 先讲故事线**：激光算例的物理时序——激光进域 → 电子吸热 → 离子被耦合加热 → 辐射产生 → 各 component 在空间上分布。
>
> **按 L-013 聚焦主流**：主讲 LaserSlab（用户实际场景），不展开激光聚变复杂场景。

---

## 1. 激光算例的物理时序（按 L-015 讲故事线）

### 1.1 激光算例的能量旅程

```
1. 激光从边界入射（ed_xwall / ed_ymin 等）
   └── Energy_in 累加（在 LaserEnergyProfile.dat 第 4 列）

2. 激光在等离子体中通过逆韧致吸收加热电子
   └── EELE_VAR 局部增加
   └── 部分激光穿出域（Energy_out，第 5 列）

3. 电子被加热后：
   ├── 部分能量通过 Heatexchange 转给离子（τ_ie ~ ps）
   │   └── EION_VAR 局部增加
   ├── 部分能量通过韧致辐射产生光子
   │   └── ERAD_VAR 局部增加
   ├── 部分能量通过热传导散开
   │   └── Diffuse 单元处理
   └── 部分能量通过流体膨胀变动能
       └── Hydro 处理

4. 辐射在域内扩散（MGD）并最终逃逸
   └── 边界流（从 .dat 看不出，要从 RadTrans 内部诊断）

5. 等离子体膨胀 → 动能增加
   └── E_kinetic 局部增加
```

### 1.2 各 component 的时间尺度（重要）

| 物理过程 | 时间尺度 | HEDP 典型 |
|---|---|---|
| 激光逆韧致吸收 | fs | ~10 fs |
| 电子-离子平衡（Heatexchange）| ps | 1-100 ps |
| 韧致辐射发射 | ps - ns | 1-100 ps |
| MGD 辐射扩散 | ns | 0.1-1 ns |
| 流体膨胀 | ns | 1-10 ns |

**含义**：
- 在 fs 时间尺度：电子被加热，离子冷（**TELE >> TION**）
- 在 ps 时间尺度：离子被耦合加热（TELE → TION 接近）
- 在 ns 时间尺度：流体膨胀（velx/vely 起来）

### 1.3 分析时看什么

| 量 | 来源 | 典型期望 |
|---|---|---|
| **激光吸收率** | LaserEnergyProfile.dat | 60-90%（HEDP） |
| **TELE 峰值** | plotfile | 1-10 keV |
| **TELE/TION 比** | plotfile | 早期 >> 1，后期 → 1 |
| **TERAD 峰值** | plotfile | 10 eV - 1 keV（黑体等效）|
| **沉积区位置** | plotfile slice | 临界密度附近 |
| **辐射产生区** | plotfile ERAD slice | 高 TELE 区 |

---

## 2. 激光吸收率分析

### 2.1 文件位置

```
cases/<case>/01-data/<basenm>_LaserEnergyProfile.dat
```

源码：`source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/EnergyDeposition_init.F90:L431`
```fortran
ed_energyProfileFileName = trim (ed_baseName) // "LaserEnergyProfile.dat"
```

### 2.2 文件结构（按 L-014 速查）

```
#Step  Time(s)    dt(s)      Energy_in(erg)  Energy_out(erg)  dE_in(erg)  dE_out(erg)
    1  1.00E-15    1.00E-15   1.50E-04        1.50E-04         1.50E-04    1.50E-04
    2  2.10E-15    1.10E-15   4.42E-04        4.41E-04         2.92E-04    2.91E-04
```

| 列号 | 名字 | 含义 |
|---|---|---|
| 1 | Step | 时间步号 |
| 2 | Time | 当前模拟时间（s）|
| 3 | dt | 本步时间步长（s）|
| 4 | Energy_in | 累计入射能量（从 t=0 到当前）（erg）|
| 5 | Energy_out | 累计透射能量（从对面边界出去的）（erg）|
| 6 | dE_in | 本步入射增量 |
| 7 | dE_out | 本步透射增量 |

**重要陷阱**：
- 第 2 行是 `#`（注释行），第 3 行才是数据开始
- 单位是 **erg**（cgs），不是 J（1 erg = 1e-7 J）

### 2.3 吸收率公式

```
吸收率 = (Energy_in - Energy_out) / Energy_in
沉积能量 = Energy_in - Energy_out
```

### 2.4 一行 awk 算总吸收率

```bash
# 总吸收率（最后一行）
awk 'NR>2 {ein=$4; eout=$5} END {printf "总吸收率 = %.2f%%\n", (ein-eout)/ein*100}' \
  cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat
```

### 2.5 时间演化（看吸收率何时稳定）

```bash
# 每一行的瞬时吸收率
awk 'NR>2 {printf "t=%.3e abs=%.2f%%\n", $2, ($4-$5)/$4*100}' \
  cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat | head -20
```

**期望趋势**：
- 早期（密度均匀）：吸收率低（激光直接穿）
- 中期（等离子体膨胀，临界密度形成）：吸收率上升
- 后期（达到稳态）：吸收率稳定

### 2.6 Python 完整脚本（`examples/laser_coupling.py`）

```python
#!/usr/bin/env python3
# laser_coupling.py - 算激光吸收率
# 用法：python laser_coupling.py cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat

import sys
import numpy as np

fn = sys.argv[1]
data = np.loadtxt(fn, comments='#')

# 列：Step, Time, dt, Energy_in, Energy_out, dE_in, dE_out
step   = data[:, 0]
time   = data[:, 1]
dt     = data[:, 2]
ein    = data[:, 3]
eout   = data[:, 4]

# 累积吸收率
cumul_abs = (ein - eout) / ein * 100

# 瞬时吸收率（本步 dE_in - dE_out）/ dE_in
dein  = data[:, 5]
deout = data[:, 6]
inst_abs = np.where(dein > 0, (dein - deout) / dein * 100, 0)

# 总沉积能量
total_deposited = ein[-1] - eout[-1]
total_coupling  = total_deposited / ein[-1] * 100

print(f"=== 激光吸收率分析 ===")
print(f"总入射能量:     {ein[-1]:.4e} erg = {ein[-1]*1e-7:.4e} J")
print(f"总透射能量:     {eout[-1]:.4e} erg")
print(f"总沉积能量:     {total_deposited:.4e} erg")
print(f"累积吸收率:     {total_coupling:.2f}%")
print()
print(f"=== 时间演化（前 5 + 后 5）===")
print(f"{'Step':>6} {'Time(s)':>12} {'瞬时%':>8} {'累积%':>8}")
for i in list(range(min(5, len(data)))) + list(range(max(0, len(data)-5), len(data))):
    print(f"{int(step[i]):6d} {time[i]:12.3e} {inst_abs[i]:8.2f} {cumul_abs[i]:8.2f}")

# 期望范围判断
if total_coupling < 30:
    print(f"\n警告：吸收率偏低（< 30%），可能：")
    print(f"  - 激光波长过短（穿透太深）")
    print(f"  - 临界密度过低（等离子体太稀）")
    print(f"  - 不透明度表错")
elif total_coupling > 95:
    print(f"\n警告：吸收率过高（> 95%），可能：")
    print(f"  - 域太小（激光没机会出去）")
    print(f"  - 不透明度表过大")
else:
    print(f"\n吸收率正常范围（30-95%）")
```

### 2.7 吸收率异常的常见原因

| 异常 | 可能原因 | 验证 |
|---|---|---|
| < 30% | 激光波长过短（如 351 nm vs 527 nm） | 看 parfile `ed_wavelength` |
| < 30% | 临界密度过低（密度太小） | 看 plotfile dens 是否 < 0.01 g/cm³ |
| < 30% | 不透明度表错（吸收系数太小） | 看 .imx 表，cross-section 是否合理 |
| > 95% | 域太小 | 看 domain 范围（应该 > 激光吸收长度）|
| 起步就 0% | 激光没启动 | 看 parfile `useLaser = .true.` |

---

## 3. TELE/TION 三温演化分析

### 3.1 为什么看三温（L-011 讲为什么）

**3T 算例的核心特征**：电子被激光直接加热，离子是被电子通过碰撞间接加热的，所以**TELE 上升早、TION 上升晚**。

```
TELE ^                        TION ^
     |                              |
     |  ____                        |       ____
     | /    \___                    |  ____/
     |/         \____               | /    \____
     +---------------> t            +--------------> t
     fs    ps    ns                 fs    ps    ns
     激光加热              耦合加热
```

**TION 接近 TELE 的时间** = 电子-离子平衡时间尺度 τ_ie。

**为什么 τ_ie 重要**：
- τ_ie < 模拟时间：达到平衡，物理接近 1T
- τ_ie > 模拟时间：永远达不到平衡，必须用 3T（用 1T 会错）
- τ_ie ~ 模拟时间：转换期，物理最复杂

### 3.2 平均温度演化（体积加权）

```python
import yt, numpy as np
import glob

times = []
tele_avg = []
tion_avg = []
trad_avg = []

files = sorted(glob.glob('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_*'))
for fn in files:
    ds = yt.load(fn)
    ad = ds.all_data()
    vol  = np.array(ad['cell_volume'])
    tele = np.array(ad['tele'])
    tion = np.array(ad['tion'])
    trad = np.array(ad['trad'])
    
    times.append(float(ds.current_time))
    tele_avg.append(np.sum(tele * vol) / np.sum(vol))
    tion_avg.append(np.sum(tion * vol) / np.sum(vol))
    trad_avg.append(np.sum(trad * vol) / np.sum(vol))

# 单位换算：K → eV（1 eV = 11604 K）
times = np.array(times)
tele_avg = np.array(tele_avg) / 11604  # eV
tion_avg = np.array(tion_avg) / 11604
trad_avg = np.array(trad_avg) / 11604

print(f"{'time(s)':>12} {'TELE(eV)':>10} {'TION(eV)':>10} {'TRAD(eV)':>10} {'TION/TELE':>10}")
for i in range(len(times)):
    ratio = tion_avg[i] / max(tele_avg[i], 1e-10)
    print(f"{times[i]:12.3e} {tele_avg[i]:10.2f} {tion_avg[i]:10.2f} {trad_avg[i]:10.2f} {ratio:10.4f}")
```

### 3.3 画三温演化图

```python
import matplotlib.pyplot as plt

plt.figure(figsize=(10, 6))
plt.semilogx(times, tele_avg, 'r-', label='TELE', linewidth=2)
plt.semilogx(times, tion_avg, 'b-', label='TION', linewidth=2)
plt.semilogx(times, trad_avg, 'g-', label='TRAD', linewidth=2)
plt.xlabel('Time (s)')
plt.ylabel('Volume-averaged T (eV)')
plt.title('Three-temperature evolution')
plt.legend()
plt.grid(True, which='both', alpha=0.3)
plt.savefig('tele_tion_trad_evolution.png', dpi=150, bbox_inches='tight')
plt.close()
```

### 3.4 找平衡时间尺度

```python
# 找 TION/TELE 第一次 > 0.9 的时间
ratio = tion_avg / np.maximum(tele_avg, 1e-10)
idx = np.argmax(ratio > 0.9)
if ratio[idx] > 0.9:
    print(f"电子-离子平衡时间 ~ {times[idx]:.3e} s")
else:
    print(f"模拟时间内未达到平衡（TION/TELE 最大 = {ratio.max():.3f}）")
```

### 3.5 三温异常的诊断

| 异常 | 可能原因 |
|---|---|
| **TELE 一直 = TION** | Heatexchange 太强（hx_ieCoef 过大）或初始化假设 1T |
| **TELE/TION 一直不收敛** | Heatexchange 太弱（耦合系数计算错）|
| **TION > TELE** | 物理错（激光只加热电子）或代码 bug |
| **TERAD > TELE** | 物理错（辐射温度不可能超过电子）|

---

## 4. ERAD 辐射能量空间分布

### 4.1 辐射能量密度的物理意义

**ERAD_VAR** = 单位体积的辐射能量 = ∫ u(ν) dν

**与 TERAD 的关系**（黑体辐射）：
```
ERAD = a_rad · TERAD^4
其中 a_rad = 7.5657e-15 erg/(cm³·K⁴)
```

### 4.2 ERAD 分布的典型形态（HEDP）

```
入射激光方向
   ↓
─────────────────  ← 入射边界
│░░░░░░░░░░░░░░░░│  临界密度附近：激光沉积区
│░░░░░░▓▓▓▓▓▓░░░░│  ERAD 高（韧致辐射产生）
│░░░░░▓▓▓▓▓▓▓▓░░░│  
│░░░░░░▓▓▓▓▓▓░░░░│  
│░░░░░░░░░░░░░░░░│  远离沉积区：ERAD 低
─────────────────  ← 出口边界
```

**特征**：
- ERAD 在激光沉积区附近最强
- ERAD 向外扩散（黑体辐射）
- 域边界 ERAD 可能高（如果辐射被反射）或低（如果流出）

### 4.3 Python 画 ERAD 切片

```python
import yt

ds = yt.load('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050')
p = yt.SlicePlot(ds, 'z', 'Eradt')  # 辐射能量密度
p.set_log('Eradt', True)
p.set_cmap('Eradt', 'hot')
p.set_colorbar_label('Eradt', 'ERAD (erg/cm^3)')
p.save('erad_slice.png')

# 也可以画 TERAD
p2 = yt.SlicePlot(ds, 'z', 'trad')
p2.set_log('trad', True)
p2.set_cmap('trad', 'hot')
p2.set_colorbar_label('trad', 'TRAD (K)')
p2.save('trad_slice.png')
```

### 4.4 ERAD 与 TELE 的相关性

```python
import yt, numpy as np
import matplotlib.pyplot as plt

ds = yt.load('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050')
ad = ds.all_data()
tele = np.array(ad['tele'])
erad = np.array(ad['Eradt'])

# 散点图（每个 cell 一点）
plt.figure(figsize=(8, 6))
plt.loglog(tele, erad, '.', markersize=1, alpha=0.3)
plt.xlabel('TELE (K)')
plt.ylabel('ERAD (erg/cm^3)')
plt.title('ERAD vs TELE correlation')
plt.grid(True, which='both', alpha=0.3)
plt.savefig('erad_vs_tele.png', dpi=150, bbox_inches='tight')
plt.close()
```

**期望**：ERAD ∝ TELE^4（韧致辐射 ~ T^(1/2) · exp(-hν/kT) 但积分后接近 T^4）

### 4.5 多群辐射分析（MGD）

MGD（MultiGroup Diffusion）算例中 ERAD 是频率积分后的总量，但每个群（mesh group）的能量分布在内部数组里。

**Python 提取单群辐射**（高级）：

```python
import h5py

# 直接读 plotfile 的 HDF5（绕过 yt）
f = h5py.File('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050', 'r')
# 看所有 dataset 名
print(list(f.keys()))

# MGD 群能量（如有 MGDN_RAD_VAR 等）
# 群数 = parfile mgd_meshgroups
```

详细见 `flash-radtrans` skill。

---

## 5. 完整激光算例分析模板

### 5.1 一键分析

```bash
#!/bin/bash
# analyze_laser.sh - 激光算例一键分析

CASE_DIR=$1
DAT=$CASE_DIR/$(ls $CASE_DIR | grep "\.dat$" | head -1)
PROF=$CASE_DIR/$(ls $CASE_DIR | grep "LaserEnergyProfile" | head -1)

echo "=== 激光算例分析: $CASE_DIR ==="

# 1. 吸收率
echo ""
echo "--- 激光吸收率 ---"
awk 'NR>2 {ein=$4; eout=$5} END {printf "累积吸收率 = %.2f%%\n沉积 = %.4e erg\n", (ein-eout)/ein*100, ein-eout}' $PROF

# 2. 总能演化
echo ""
echo "--- 总能演化（.dat 前 3 + 后 3 行）---"
head -5 $DAT
echo "..."
tail -3 $DAT

# 3. 算例时长
echo ""
echo "--- 算例时长 ---"
awk 'NR>2 {t=$1} END {printf "总模拟时间 = %.3e s\n", t}' $DAT

# 4. 相对总能变化
echo ""
echo "--- 相对总能变化 ---"
awk 'NR>2 {et=$6; if(NR==3)et0=et} END {printf "E_total 变化 = %.4f%%\n", (et-et0)/et0*100}' $DAT
```

### 5.2 输出示例

```
=== 激光算例分析: cases/LaserSlab/01-data ===

--- 激光吸收率 ---
累积吸收率 = 78.34%
沉积 = 1.234e+05 erg

--- 总能演化 ---
  1.000e-15  ...
  ...
  1.000e-09  ...

--- 算例时长 ---
总模拟时间 = 1.000e-09 s

--- 相对总能变化 ---
E_total 变化 = 76.21%
```

**判断**：
- 吸收率 78%：正常范围（60-90%）
- E_total 变化 76%：低于吸收率（76% < 78%）—— 部分能量通过辐射逃逸或边界流出（合理）

---

## 6. 速查：激光分析命令

```bash
# 1. 总吸收率
awk 'NR>2 {ein=$4; eout=$5} END {printf "%.2f%%\n", (ein-eout)/ein*100}' \
  cases/<case>/01-data/<basenm>_LaserEnergyProfile.dat

# 2. 吸收率时间演化
awk 'NR>2 {printf "t=%.3e abs=%.2f%%\n", $2, ($4-$5)/$4*100}' \
  cases/<case>/01-data/<basenm>_LaserEnergyProfile.dat

# 3. 三温演化（Python）
python -c "
import yt, numpy as np
import glob
for fn in sorted(glob.glob('cases/<case>/01-data/<basenm>_hdf5_plt_cnt_*'))[:5]:
    ds = yt.load(fn); ad = ds.all_data()
    vol = np.array(ad['cell_volume'])
    tele = np.sum(np.array(ad['tele'])*vol)/np.sum(vol)
    tion = np.sum(np.array(ad['tion'])*vol)/np.sum(vol)
    print(f't={float(ds.current_time):.3e} TELE={tele/11604:.1f}eV TION={tion/11604:.1f}eV')
"

# 4. ERAD 切片
python -c "
import yt
ds = yt.load('cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050')
p = yt.SlicePlot(ds, 'z', 'Eradt')
p.set_log('Eradt', True)
p.save('erad.png')
"

# 5. 完整激光分析
python laser_coupling.py cases/<case>/01-data/<basenm>_LaserEnergyProfile.dat
```

---

## 7. 延伸阅读

- **能量守恒验算**：`knowledge/energy_balance.md`（路径 C 详细）
- **plotfile 结构**：`knowledge/overview.md §2-3`
- **可视化模板**：`knowledge/visualization.md`
- **激光物理原理**：`flash-laser` skill（逆韧致吸收、临界密度等）
- **3T EOS 机制**：`flash-eos` skill
- **Heatexchange**：`flash-sourceterms` skill
- **MGD 辐射扩散**：`flash-radtrans` skill

---

## 8. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-08-02 | 初始创建（beta）：8 段激光算例专项分析——吸收率（LaserEnergyProfile 解析 + 一行 awk + Python）+ TELE/TION 演化（三温时间尺度 + 平衡时间找法）+ ERAD 分布（切片 + TELE 相关性）+ 完整模板；按 L-011 讲为什么；按 L-013 聚焦 LaserSlab；按 L-014 解释术语；按 L-015 先讲激光能量旅程 | claude |
