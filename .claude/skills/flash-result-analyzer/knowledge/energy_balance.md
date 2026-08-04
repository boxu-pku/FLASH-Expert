---
title: 能量守恒分析方法——FLASH .dat + Python 重算 + 3T/辐射/激光源分解
skill: flash-result-analyzer
category: energy-balance
source_anchors:
  - source/IO/IOMain/IO_writeIntegralQuantities.F90:L140-L254
  - source/Driver/DriverMain/Driver_evolveFlash.F90
  - source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserRayTrace/CellAverage/ed_traceBlockRays2DCyl3D.F90:L950
  - cases/LaserSlab/01-data/lasslab.dat
manual_ref: "FLASH 4.8 User Guide §17.4 (Energy Conservation Diagnostics)"
created: 2026-08-02
last_verified: 2026-08-02
verifier: claude
status: beta
tags:
  - energy-balance
  - conservation
  - integral-quantities
  - 3t
  - laser
---

# 能量守恒分析方法

> **TL;DR**：能量守恒是判断算例"物理对不对"的第一指标。FLASH 自带 `<basenm>.dat` 文件直接给总能/动能/内能时间序列——零 Python 就能看趋势；要从 plotfile 重算（含 3T/辐射/激光源分解）用 Python。本文讲两条路径 + 各 component 怎么算 + "不守恒"怎么诊断。
>
> **按 L-015 先讲故事线**：先讲"能量守恒分析"端到端流程，再讲细节。
>
> **按 L-011 讲为什么**：每个公式都解释"为什么这么算、不这么算会怎样"。

---

## 1. 能量守恒分析的完整故事线

### 1.1 "能量守恒"是什么

在封闭物理系统里，**总能量应该守恒**（除了源项贡献和边界流）：

```
E_total(t) = E_total(0) + E_source(t) - E_boundary_loss(t)
```

对**封闭算例**（无源、无边界流）：E_total 应**恒定**，相对误差 < 1%。

对**激光算例**（有激光源）：E_total 应**单调增长**，增长量 ≈ 激光沉积能量。

对**辐射算例**（有边界辐射流）：E_total 应**单调减少**，减少量 ≈ 辐射逃逸。

### 1.2 FLASH 的能量分解（按 L-014 解释术语）

源码：`source/IO/IOMain/IO_writeIntegralQuantities.F90:L140-L172`

```
E_total    = E_kinetic + E_internal                    # 1T 算例
E_total_3T = E_kinetic + E_eion + E_eele + E_erad      # 3T 算例（理想）
```

**为什么 FLASH .dat 只有 E_kinetic + E_internal（1T 风格）**：

源码里 `E_internal` 调用的是 `EINT_VAR`（即"内能"），3T 算例下 `EINT_VAR` 通常**等于 E_ion + E_ele**（不含辐射）。

**辐射能 ERAD 不在 .dat 里**——这是 FLASH 设计选择，因为 ERAD 由 RadTrans 管理而非 Hydro。

**激光沉积能量不在 .dat 里**——它通过 source term 加到 EELE_VAR，最终进入 E_internal，但"激光源项总贡献"要单独从 `LaserEnergyProfile.dat` 看。

### 1.3 守恒检查的三条路径

```
路径 A：用 .dat 看 E_total 演化（最快）
   → awk 提取第 6 列，画时间序列
   → 适合"快速看趋势"

路径 B：从 plotfile 用 Python 重算（最全）
   → 遍历 plotfile 序列
   → 算 E_kinetic + E_eion + E_eele + E_erad
   → 适合"详细分解 + 3T"

路径 C：用 LaserEnergyProfile.dat 算激光沉积（激光算例专用）
   → Energy_in - Energy_out = 沉积
   → 适合"激光算例守恒验算"
```

### 1.4 完整守恒验算（激光算例）

```
E_total(t) - E_total(0) = (E_in - E_out)_laser + 边界流误差 + 数值误差
```

**典型容差**：
- 数值误差：< 1%（合理）
- 边界流误差：取决于 parfile `bc_xmin/xmax` 等是否真封闭
- 物理不匹配（如 > 5%）：通常意味着参数错（如 Grid 边界没设 reflecting）

---

## 2. 路径 A：从 .dat 看能量演化（最快）

### 2.1 .dat 列结构（按 L-014 速查）

```
#time  mass  x-mom  y-mom  z-mom  E_total  E_kinetic  E_internal  [MagEnergy]
```

列号：1=time, 2=mass, 3-5=mom, 6=E_total, 7=E_kinetic, 8=E_internal

### 2.2 一行 awk 看 E_total 演化

```bash
# 提取 time 和 E_total（第 1、6 列）
awk 'NR>2 {print $1, $6}' cases/LaserSlab/01-data/lasslab.dat

# 算相对变化（E_total - E_total_0） / E_total_0
awk 'NR>2 {et=$6; if(NR==3)et0=et; printf "%.3e %.6f\n", $1, (et-et0)/et0}' \
  cases/LaserSlab/01-data/lasslab.dat
```

### 2.3 验算 E_total = E_kinetic + E_internal

```bash
# 第 6 列应 = 第 7 列 + 第 8 列
awk 'NR>2 {et=$6; ek=$7; ei=$8; diff=(et-ek-ei)/et; printf "t=%.3e diff=%.2e\n", $1, diff}' \
  cases/LaserSlab/01-data/lasslab.dat | head -10
```

**含义**：
- `diff ≈ 0`（< 1e-10）：FLASH 内部自洽，没问题
- `diff > 1e-6`：异常——可能 MagEnergy 项存在（MHD 算例）或代码 bug

### 2.4 看激光算例 E_total 是否单调增长

```bash
# 算 E_total 的一阶差分（应 > 0 表示单调增长）
awk 'NR>2 {et=$6; if(NR>3)print $1, et-prev; prev=et}' \
  cases/LaserSlab/01-data/lasslab.dat | head -20
```

**期望**：
- 激光算例：每步 dE > 0（激光沉积）
- 数值噪声可能导致个别 dE < 0（极小）

---

## 3. 路径 B：Python 从 plotfile 重算（最全）

### 3.1 完整脚本（3T 算例）

```python
#!/usr/bin/env python3
# check_energy.py - 从 plotfile 序列算能量演化
# 用法：python check_energy.py cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_*

import sys
import glob
import yt
import numpy as np

# 物理量提取
def extract_energy(ds):
    ad = ds.all_data()
    # 单位都是 cgs
    vol = np.array(ad['cell_volume'])         # cm^3
    rho = np.array(ad['dens'])                # g/cm^3
    vx  = np.array(ad['velx'])
    vy  = np.array(ad['vely'])
    vz  = np.array(ad['velz'])

    # 动能
    ekin = np.sum(0.5 * rho * (vx**2 + vy**2 + vz**2) * vol)

    # 内能（1T：用 'eint'；3T：分别算 eion/eele/erad）
    try:
        eele = np.sum(ad['Eele'] * vol)  # 电子内能密度（ erg/cm^3 ）
        eion = np.sum(ad['Eion'] * vol)
        eint_total = eele + eion
    except yt.field_exceptions.MissingField:
        # 1T 算例
        eint = np.sum(rho * np.array(ad['eint']) * vol)
        eele = eion = 0.0
        eint_total = eint

    # 辐射能（如有）
    try:
        erad = np.sum(ad['Eradt'] * vol)
    except:
        erad = 0.0

    return float(ds.current_time), ekin, eint_total, eele, eion, erad

# 主流程
files = sorted(glob.glob(sys.argv[1])) if '*' in sys.argv[1] else [sys.argv[1]]
print(f"{'time(s)':>12} {'E_kin(erg)':>14} {'E_int(erg)':>14} {'E_ele':>14} {'E_ion':>14} {'E_rad':>14} {'E_tot':>14}")

t0 = None
etot0 = None
for fn in files:
    try:
        ds = yt.load(fn)
        t, ekin, eint, eele, eion, erad = extract_energy(ds)
        etot = ekin + eint + erad
        if t0 is None:
            t0, etot0 = t, etot
        rel = (etot - etot0) / etot0 if etot0 > 0 else 0
        print(f"{t:12.3e} {ekin:14.4e} {eint:14.4e} {eele:14.4e} {eion:14.4e} {erad:14.4e} {etot:14.4e} rel={rel:+.4f}")
    except Exception as e:
        print(f"SKIP {fn}: {e}")
```

**为什么用 `ad['Eele']` 不是 `ad['EELE']`**（L-011 讲为什么）：
- yt 字段名是 lowercase（yt 自动转）
- 'Eele' 是能量密度字段（erg/cm³），不是质量内能
- 不同 FLASH 版本字段名略不同：`yt.load` 后 `print(ds.field_list)` 看实际可用

### 3.2 输出格式

```
time(s)        E_kin(erg)     E_int(erg)     E_ele          E_ion          E_rad          E_tot
1.000e-15      1.234e+02      5.678e+05      3.456e+05      2.222e+05      0.000e+00      5.679e+05 rel=+0.0000
1.100e-14      1.345e+03      6.789e+06      4.567e+06      2.222e+05      1.111e+05      6.790e+06 rel=+10.95
```

**怎么解读**：
- `rel` 列：相对 t=0 的总能变化比例
- 激光算例：rel 应单调增
- 封闭算例：rel 应 ≈ 0

### 3.3 单位换算（cgs → SI）

FLASH 内部 cgs（cm/g/s/erg/K），yt 也用 cgs。**换算**：
- 1 erg = 1e-7 J
- 1 g/cm³ = 1000 kg/m³
- 1 K = 1 K（温度不变，但 1 eV = 11604 K）

---

## 4. 3T 算例的能量分解

### 4.1 3T 各 component 怎么算（按 L-014）

**3T 算例**：每个 cell 有 3 个独立内能变量。

| UNK 名 | 含义 | 单位 |
|---|---|---|
| EELE_VAR（"Eele"）| 电子内能密度 | erg/cm³ |
| EION_VAR（"Eion"）| 离子内能密度 | erg/cm³ |
| ERAD_VAR（"Eradt"）| 辐射能量密度 | erg/cm³ |
| TELE_VAR（"tele"）| 电子温度 | K |
| TEION_VAR（"tion"）| 离子温度 | K |
| TERAD_VAR（"trad"）| 辐射温度 | K |

**总能公式**（3T）：
```
E_total = ∫ ρ·(e_kinetic_per_mass) dV
        + ∫ EELE dV
        + ∫ EION dV
        + ∫ ERAD dV
```

注意 EELE/EION 是**能量密度**（per volume），不是 per mass，所以**不乘 ρ**。

### 4.2 辐射能量的物理含义

**ERAD_VAR** = 单位体积的辐射能量 = ∫ u(ν) dν （在所有频率积分）

**与 TERAD 的关系**：黑体辐射
```
ERAD = a · TERAD^4
```
其中 a = 4σ/c = 7.5657e-15 erg/(cm³·K⁴) 是辐射常数。

**Python 验算**：
```python
import numpy as np
a_rad = 7.5657e-15  # erg/(cm^3 K^4)
# yt 加载后
trad = np.array(ad['trad'])  # K
erad_calc = a_rad * trad**4  # 应该 = ad['Eradt']
```

### 4.3 激光沉积到 EELE（按 L-011 讲为什么）

**机制**：激光通过逆韧致吸收加热电子（不直接加热离子），所以源项加到 EELE_VAR。

**守恒验算**（激光算例）：
```
∫ EELE(t_final) dV - ∫ EELE(t_0) dV ≈ 激光沉积能量 × 热损失率
```

**为什么不直接相等**：
- 电子被加热后，部分能量通过 Heatexchange 转给离子
- 部分能量通过辐射（韧致）变成 ERAD
- 部分能量通过热传导散开
- 所以 EELE 增长 < 激光沉积总量

### 4.4 三温平衡时间尺度（HEDP 关键）

**Heatexchange 时间尺度**（耦合常数 λ_ie 由 Lee-More 或 Epperlein-Haines 模型算）：
```
τ_ie ~ m_i / (m_e · n_e · ν_ei)
```

典型 HEDP 等离子体 τ_ie ~ 10 ps - 1 ns。

**Python 分析**：
```python
import yt, numpy as np
import glob

tele_avg = []
tion_avg = []
times = []
for fn in sorted(glob.glob('cases/<case>/01-data/<basenm>_hdf5_plt_cnt_*')):
    ds = yt.load(fn)
    ad = ds.all_data()
    # 体积加权平均温度
    vol = np.array(ad['cell_volume'])
    tele = np.array(ad['tele'])
    tion = np.array(ad['tion'])
    tele_avg.append(np.sum(tele * vol) / np.sum(vol))
    tion_avg.append(np.sum(tion * vol) / np.sum(vol))
    times.append(float(ds.current_time))

# 找 tion 第一次接近 tele（差 < 10%）
import numpy as np
times = np.array(times)
ratio = np.array(tion_avg) / np.array(tele_avg)
# ratio 从 ~ 0 上升到 ~ 1，平衡时间 = ratio 第一次 > 0.9 对应的时间
idx = np.argmax(ratio > 0.9)
print(f"平衡时间尺度 ~ {times[idx]:.3e} s")
```

详见 `knowledge/laser_analysis.md §3`。

---

## 5. 路径 C：LaserEnergyProfile.dat 算激光源贡献

### 5.1 文件结构（同 `overview.md §3.3`）

```
#Step  Time      dt       Energy_in    Energy_out   dE_in   dE_out
```

### 5.2 算沉积能量

```bash
# 总沉积能量 = Energy_in - Energy_out（最后一行）
awk 'NR>2 {ein=$4; eout=$5} END {printf "总沉积 = %.4e erg\n", ein-eout}' \
  cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat
```

### 5.3 守恒验算（激光算例）

**期望等式**：
```
E_total(t_final) - E_total(t_0) ≈ 激光沉积 - 边界流 - 辐射逃逸
```

**Python 完整脚本**：
```python
import yt, numpy as np
import glob

# 1. 从 .dat 读 E_total
dat = np.loadtxt('cases/LaserSlab/01-data/lasslab.dat', comments='#')
t_dat = dat[:, 0]
etot_dat = dat[:, 5]  # 第 6 列

# 2. 从 LaserEnergyProfile 读沉积
prof = np.loadtxt('cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat', comments='#')
t_prof = prof[:, 1]
deposited = prof[:, 3] - prof[:, 4]  # Energy_in - Energy_out

# 3. 在最后时刻验算
final_idx = -1
print(f"E_total 变化  = {etot_dat[final_idx] - etot_dat[0]:.4e} erg")
print(f"激光沉积      = {deposited[final_idx]:.4e} erg")
print(f"差异          = {(etot_dat[final_idx] - etot_dat[0]) - deposited[final_idx]:.4e} erg")
print(f"相对差异      = {abs(etot_dat[final_idx] - etot_dat[0] - deposited[final_idx]) / deposited[final_idx] * 100:.2f}%")
```

**容差**：
- < 5%：很好
- 5-15%：边界流可解释
- > 30%：参数错或数值问题（可能 parfile 边界条件没设对）

---

## 6. "能量不守恒"怎么诊断（按 L-012 引导贴现场）

### 6.1 引导贴什么

```
请贴以下信息以便诊断"能量不守恒"：

1. .dat 文件前 5 行 + 后 5 行（看 E_total 演化）：
   head -5 cases/<case>/01-data/<basenm>.dat
   tail -5 cases/<case>/01-data/<basenm>.dat

2. parfile 边界条件段（看是否真封闭）：
   grep -E "bc_x|bc_y|bc_z" cases/<case>/flash.par

3. 算例是否含源项（看 setup_call）：
   grep -E "\+laser|\+mgd|\+cool|\+heat" cases/<case>/setup_call

4. 相对误差（具体多少）：
   awk 'NR>2 {et=$6; if(NR==3)et0=et} END {printf "rel diff = %.4f%%\n", (et-et0)/et0*100}' \
     cases/<case>/01-data/<basenm>.dat
```

### 6.2 常见原因（按概率排序）

| 原因 | 标志 | 修复 |
|---|---|---|
| **边界流**（最常见） | parfile `bc_xmin = "outflow"` 等开放 | 改 `"reflect"` 或 `"zero-gradient"` 验算 |
| **激光算例**（正常） | setup_call 含 `+laser` | 不是 bug，沉积是预期的（见 §5） |
| **辐射逃逸** | setup_call 含 `+mgd`，diff > 0 但 < 激光沉积 | 由 ERAD 逃逸，正常 |
| **EOS 表超范围** | 同时日志有 `below floor` | 调 parfile `sim_rhoMin` |
| **数值耗散**（少见）| 相对误差 < 1% | 通常可忽略 |
| **CFL 太大** | 同时日志有 NaN | 降 `hydro_cfl` 重跑 |
| **源项时间分裂错**（极少） | 误差 > 5% 且无源 | 检查 sourceTerms 顺序 |

### 6.3 验算示例

**贴现场**：
```
.dat tail:
  1.000e-10  1.000e+00  ... 5.678e+05
  1.100e-10  1.000e+00  ... 5.682e+05

parfile: bc_xmin="outflow" bc_xmax="outflow"

setup_call: ./setup Sedov ...
```

**诊断**：Sedov 是封闭算例（爆炸在内部），E_total 应**严格守恒**。
- 相对变化 = (5.682e+05 - 5.678e+05) / 5.678e+05 ≈ 0.07%（< 1%）→ **正常数值误差**

如果相对变化 = 50%：
- bc_xmin/outflow 让能量流出（ Sedov 激波传到边界就漏能）→ 改 bc 为 reflecting 或扩大 domain

---

## 7. 完整分析模板（一键脚本）

`examples/check_energy.py` 完整功能：
1. 读 .dat 看 E_total 演化
2. 从 plotfile 重算 3T 分量
3. 从 LaserEnergyProfile 算激光沉积
4. 三者交叉验算
5. 输出 markdown 报告

**用法**：
```bash
python check_energy.py cases/LaserSlab/01-data/
# 输出：
# === .dat 摘要 ===
# 总能变化: +X% (期望: 单调增长)
# === 3T 分解 ===
# E_kinetic / E_ele / E_ion / E_erad
# === 激光验算 ===
# 沉积: X erg
# 边界流: Y erg（占 Z%）
# === 结论 ===
# 守恒 ✓ / 异常（具体原因）
```

---

## 8. 速查：守恒量分析命令

```bash
# 1. 看 E_total 演化（一行 awk）
awk 'NR>2 {print $1, $6}' cases/<case>/01-data/<basenm>.dat

# 2. 算相对变化
awk 'NR>2 {et=$6; if(NR==3)et0=et; printf "%.3e %.6f\n", $1, (et-et0)/et0}' \
  cases/<case>/01-data/<basenm>.dat

# 3. 验算 E_total = E_kin + E_int
awk 'NR>2 {printf "%.3e diff=%.2e\n", $1, ($6-$7-$8)/$6}' cases/<case>/01-data/<basenm>.dat

# 4. 算激光沉积（最后一行）
awk 'NR>2 {ein=$4; eout=$5} END {printf "沉积=%.4e\n", ein-eout}' \
  cases/<case>/01-data/<basenm>_LaserEnergyProfile.dat

# 5. 从 plotfile 算（Python）
python check_energy.py cases/<case>/01-data/
```

---

## 9. 延伸阅读

- **激光算例专项分析**：`knowledge/laser_analysis.md`（更详细的吸收率 + 三温演化）
- **可视化**：`knowledge/visualization.md`（怎么把能量演化画出来）
- **常见错误**：`knowledge/pitfalls.md`（.dat 列错位、单位混淆等）
- **跑算例**：`flash-case-runner/knowledge/run_guide.md`（前置——先跑出来）
- **Hydro 守恒律**：`flash-hydro` 知识层
- **3T EOS 模式**：`flash-eos/knowledge/overview.md §3.5`（_ION/_ELE/_RAD 模式）

---

## 10. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-08-02 | 初始创建（beta）：10 段能量守恒分析——3 路径（.dat / Python / LaserProfile）+ 3T 分解 + 激光源贡献 + 守恒验算 + 不守恒诊断；按 L-011 讲为什么；按 L-014 解释术语；按 L-015 先讲守恒分析故事线；按 L-012 不守恒时先引导贴现场 | claude |
