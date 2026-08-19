---
title: 结果分析总览——plotfile/checkpoint/.dat 结构 + 物理量检查清单
skill: flash-result-analyzer
category: overview
source_anchors:
  - source/IO/IOMain/IO_writePlotfile.F90
  - source/IO/IOMain/IO_writeCheckpoint.F90
  - source/IO/IOMain/IO_writeIntegralQuantities.F90:L140-L254
  - cases/LaserSlab/01-data/lasslab.dat
  - cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat
manual_ref: "FLASH 4.8 User Guide §16-17 (IO), §8 (Simulation Monitoring)"
created: 2026-08-02
last_verified: 2026-08-02
verifier: claude
status: beta
tags:
  - overview
  - plotfile
  - checkpoint
  - dat-file
  - energy-balance
---

# 结果分析总览

> **TL;DR**：FLASH 跑完后会写一堆文件——`*_plt_*`（plotfile，可视化用）、`*_chk_*`（checkpoint，续跑用）、`*.dat`（积分量时间序列）、`*.log`（日志）、`LaserEnergyProfile.dat`（激光算例特有）。本文讲这些文件**长什么样、各有什么用、怎么读**。
>
> **按 L-015 先讲完整故事线**：先讲"分析结果"端到端流程，再讲每种文件细节。
>
> **按 L-014 解释术语**：plotfile/checkpoint/yt/UNK 变量/stats 文件第一次出现都有定义。

---

## 1. 结果分析的完整故事线

### 1.1 "分析结果"是什么

跑完一个 FLASH 算例后，硬 盘上会有一堆输出文件。"分析结果" = **从这些文件提取信息，回答四个问题**：

1. **跑完了吗**（plotfile 序列是否完整到目标时间）
2. **物理量对不对**（dens/tele/tion/erad 各自的范围合不合理）
3. **能量守恒吗**（总能演化是否符合物理）
4. **形态对不对**（密度/温度切片看着像不像物理）

### 1.2 分析流程（端到端旅程）

> **输出在哪（约定）**：所有运行输出在 `cases/<case>/01-data/`——这是 `flash-case-runner` 的硬约束
> （flash4 在 01-data/ 下启动，CWD 决定输出落点）。如果 objdir 根目录散落了 plt/chk/dat/log，
> 说明有人违反约束在 objdir 根目录跑了 flash4。

```
1. 先看日志（cat flash.log | tail）
   → 确认算例完整结束（"Simulation completed successfully"）
   → 看 simTime / nstep 推进是否正常

2. 列出 plotfile / checkpoint / .dat
   ls cases/<case>/01-data/
   → 确认 plt 序列完整（cnt_0000 到 cnt_NNNN）
   → 确认 .dat 文件存在（积分量时间序列）

3. 快速看 .dat（无需 Python）
   awk 'NR>2 {print $1, $6}' cases/<case>/01-data/<basenm>.dat
   → 看总能演化是否单调（激光算例）或恒定（封闭算例）

4. 用 yt 看 plotfile（深度分析）
   yt load → slice plot → save PNG
   → 看密度/温度切片，物理形态对不对

5. 算激光吸收率（仅激光算例）
   awk 'NR>2 {...}' LaserEnergyProfile.dat
   → (Energy_in - Energy_out) / Energy_in

6. 写 markdown 报告（汇总）
   → 守恒量、物理量范围、吸收率、形态描述
```

### 1.3 为什么是这个顺序（L-011 讲为什么）

- **日志先行**：如果日志显示 abort，后面分析都没意义
- **.dat 先于 plotfile**：.dat 是一行一时刻，看趋势极快；plotfile 要 Python 才能读
- **形态最后**：形态判断需要"看图说话"，前面量化指标过完才进入这步

### 1.4 不这么做会怎样

- **跳过日志直接看 plotfile**：可能 plotfile 是 t=0 状态（算例没跑就 abort）
- **跳过 .dat 直接 plotfile**：用 Python 算 100 次积分，慢 100 倍
- **跳过物理量范围直接看形态**：以为"挺好看的"，实际数值已经 NaN

---

## 2. plotfile vs checkpoint（重要术语解释）

### 2.1 plotfile 是什么

**plotfile**（按 L-014 解释术语）= FLASH 写出的可视化用 HDF5 文件，**只含主流物理量**（dens/tele/tion/erad/velx/...）。

**命名**：
```
<basenm>_hdf5_plt_cnt_<NNNN>     # 目录或单文件
```

例：`lasslab_hdf5_plt_cnt_0050`

**写入时机**：由 parfile `plot_plotFileIntervalStep` / `IntervalTime` 控制（如每 10 步或每 1e-12 秒）。

**特点**：
- **小**（只含 plot 变量子集）
- **缺 AMR 树结构**（不能 restart）
- **可被 yt 直接 load**
- **缺内部计数器**（simTime 写在 dataset attribute 里）

### 2.2 checkpoint 是什么

**checkpoint**（按 L-014 解释术语）= FLASH 写出的续跑用 HDF5 文件，**含全部状态**（所有 unk 变量 + AMR 树 + 计数器 + scalar）。

**命名**：
```
<basenm>_hdf5_chk_<NNNN>     # 目录或单文件
```

例：`lasslab_hdf5_chk_0050`

**写入时机**：由 parfile `chk_checkpointFileIntervalStep` / `IntervalTime` 控制。

**特点**：
- **大**（含所有 unk + 树）
- **能 restart**（续跑起点）
- **可被 yt load**（但比 plotfile 大）
- **含 AMR 树**（结构完整）

### 2.3 plotfile vs checkpoint 速查

| 属性 | plotfile | checkpoint |
|---|---|---|
| 命名 | `_plt_cnt_` | `_chk_` |
| 用途 | 可视化、后处理 | restart 续跑 |
| 含变量 | plot 变量子集 | 所有 unk |
| 含 AMR 树 | 否 | 是 |
| yt 加载 | ✓ 推荐 | ✓（但慢） |
| restart 续跑 | ✗ | ✓ |
| 文件大小 | 小 | 大 |

### 2.4 分析时用哪个

**默认用 plotfile**：
- 小、快
- 含主流变量（dens/tele/tion/erad）

**用 checkpoint 当**：
- plotfile 没写出（如算例 abort）
- 需要看 plotfile 没含的变量（如某些诊断变量）

```bash
# 看 plotfile 有哪些变量
h5dump -H cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050 | grep -i "dataset"

# 看 checkpoint 有哪些变量（会多很多）
h5dump -H cases/<case>/01-data/<basenm>_hdf5_chk_0050 | grep -i "dataset"
```

---

## 3. FLASH 输出文件族（按 L-014 解释术语）

### 3.1 .dat 文件族（最重要）

| 文件名 | 内容 | 何时有 |
|---|---|---|
| `<basenm>.dat` | 总能量积分（mass/E_total/E_kinetic/E_internal）| 总有 |
| `<basenm>_LaserEnergyProfile.dat` | 激光入射/沉积能量 | 仅 `+laser` 算例 |
| `<basenm>_LaserPositions.txt` | 激光束位置（若用 file-driven beams） | 仅 file-driven 激光 |
| `<basenm>.grav_profile` | 引力势剖面 | 仅 `+gravity` |
| `<basenm>.scal_profile` | scalar 剖面 | 仅含 scalar transport |
| `<basenm>.log` | 完整运行日志 | 总有 |

### 3.2 .dat 列结构详解（按 L-011 讲为什么）

源码：`source/IO/IOMain/IO_writeIntegralQuantities.F90:L223-L254`

```
#time                     mass                      x-momentum                y-momentum                z-momentum                E_total                   E_kinetic                 E_internal                MagEnergy
  1.234567890123456789E-10  1.000000000000000000E+00  ...
```

**每列含义**（按 L-014 解释术语）：

| 列号 | 名字 | 含义 | 单位（cgs）| 计算式 |
|---|---|---|---|---|
| 1 | time | 当前模拟时间 | s | simTime |
| 2 | mass | 总质量 | g | ∫ρ dV |
| 3 | x-momentum | x 方向总动量 | g·cm/s | ∫ρ·vx dV |
| 4 | y-momentum | y 方向总动量 | g·cm/s | ∫ρ·vy dV |
| 5 | z-momentum | z 方向总动量 | g·cm/s | ∫ρ·vz dV |
| 6 | **E_total** | 总能 | erg | ∫ρE dV |
| 7 | **E_kinetic** | 动能 | erg | ∫½ρv² dV |
| 8 | **E_internal** | 内能 | erg | ∫ρe dV |
| 9 | MagEnergy | 磁能 | erg | ∫B²/(2μ₀) dV（仅 MHD） |

**为什么是这些列**（L-011 讲为什么）：
- **质量 / 动量 / 能量**是流体力学三大守恒量，写出来一眼能看是否守恒
- **总能 = 动能 + 内能（+ 磁能 + 辐射能）**，写出来能验算
- **没有辐射能、激光沉积**：这些是 source term 的能量，不写在 E_total 里

**重要陷阱**：**E_total 在 3T 算例不含 ERAD**。3T 的 ERAD（辐射能量）由 RadTrans 单元管理，需要单独从 plotfile 重算。详见 `energy_balance.md §4`。

### 3.3 LaserEnergyProfile.dat（激光算例专用）

源码：`source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/EnergyDeposition_init.F90:L431`

**文件结构**：
```
#Step     Time (s)     dt (s)      Energy in (erg)    Energy out (erg)       dE in (erg)        dE out (erg)
#
    1   1.0000E-15  1.0000E-15    1.5000000000E-04    1.4999855098E-04    1.5000000000E-04    1.4999855098E-04
    2   2.1000E-15  1.1000E-15    4.4150000000E-04    4.4149419685E-04    2.9150000000E-04    2.9149564587E-04
```

**列含义**：
| 列号 | 名字 | 含义 |
|---|---|---|
| 1 | Step | 时间步号 |
| 2 | Time | 当前模拟时间（s）|
| 3 | dt | 本步时间步长（s）|
| 4 | **Energy in** | 累计入射能量（从 t=0 到当前）（erg）|
| 5 | **Energy out** | 累计透射能量（从对面边界出去的）（erg）|
| 6 | dE in | 本步入射增量 |
| 7 | dE out | 本步透射增量 |

**关键关系**：
```
吸收率 = (Energy_in - Energy_out) / Energy_in
沉积能量 = Energy_in - Energy_out（每个时刻）
```

**重要陷阱**：
- **第 2 行是注释行（#）**，第 3 行才是数据开始
- **单位 erg 不是 J**（cgs 制，1 erg = 1e-7 J）

### 3.4 .log 文件结构

见 `flash-case-runner/knowledge/run_guide.md §4`（运行日志结构）。本文不重复，引用即可。

---

## 4. 物理量合理范围（HEDP / Sedov）

### 4.1 LaserSlab HEDP 典型值

| 量 | 单位 | 合理范围 | 越界含义 |
|---|---|---|---|
| **dens** | g/cm³ | 0.001 - 10 | < 0.001：物质膨胀过头；> 50：激波压缩过头 |
| **tele** | K（注意！cgs） | 1e5 - 1e8 | > 5e8：激光过强或 EOS 错；< 1e4：未加热 |
| **tion** | K | 1e5 - 5e7 | 应 < tele（电子先热）|
| **terad** | K | 1e4 - 1e7 | 黑体等效温度，应 < tele |
| **pres** | Pa（cgs 是 dyne/cm²） | 1e8 - 1e13 | HEDP 典型 |
| **velx/vely** | cm/s | 1e5 - 1e8 | 等离子体膨胀速度 |

**温度换算**（重要！）：
- 1 eV = 11604 K
- 1 keV = 1.16e7 K
- 因此 tele = 1 keV ≈ 1.16e7 K

### 4.2 Sedov 爆炸典型值

| 量 | 单位 | 合理范围 | 备注 |
|---|---|---|---|
| **dens** | g/cm³ | 0.001 - 1 | 周围介质密度 ± 激波压缩 |
| **pres** | Pa | 1e5 - 1e12 | 激波后压力暴涨 |
| **tele = tion** | K | 1e3 - 1e8 | 1T 假设（Sedov 通常 1T）|
| **velx** | cm/s | 1e4 - 1e8 | 激波径向速度 |

### 4.3 怎么提取物理量范围（一行命令）

```bash
# 从最新 plotfile 提取 dens 的 min/max（用 h5dump）
h5dump -m "%.3e" -H cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050/DENS | head -5

# 或用 yt（更友好）
python -c "
import yt
ds = yt.load('cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050')
ad = ds.all_data()
for f in ['dens', 'tele', 'tion', 'trad']:
    try:
        v = ad[f]
        print(f, v.min(), v.max())
    except: pass
"
```

### 4.4 NaN/Inf 检测

```bash
# 日志里找 NaN
grep -i "nan\|inf\|below floor" cases/<case>/01-data/*.log | head -20

# 从 plotfile 检测（用 Python）
python -c "
import yt, numpy as np
ds = yt.load('cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050')
ad = ds.all_data()
for f in ['dens', 'tele', 'tion', 'trad', 'pres']:
    try:
        v = np.array(ad[f])
        n_nan = np.isnan(v).sum()
        n_inf = np.isinf(v).sum()
        if n_nan or n_inf:
            print(f'{f}: {n_nan} NaN, {n_inf} Inf')
    except: pass
"
```

---

## 5. 术语速查（按 L-014）

| 术语 | 定义 |
|---|---|
| **plotfile** | FLASH 写的可视化用 HDF5 文件，命名 `_plt_cnt_`，含主流物理量 |
| **checkpoint** | FLASH 写的续跑用 HDF5 文件，命名 `_chk_`，含全部状态 |
| **UNK 变量** | Unknown Variable，FLASH 的 grid 中心场变量（如 DENS_VAR/TELE_VAR）|
| **UNK 名** | UNK 变量在 HDF5 里的字符串名（如 "DENS"），对应 Fortran 的 DENS_VAR 整数 |
| **basenm** | 算例的基础命名前缀（如 `lasslab`），所有输出文件以它开头 |
| **.dat 文件** | FLASH 写的积分量时间序列（ASCII），列结构由 IO_writeIntegralQuantities 定 |
| **LaserEnergyProfile.dat** | 激光算例的能量追踪文件，含 Energy_in / Energy_out 累积 |
| **stats file** | 同 .dat 文件，由 `io_statsFileName` 控制 |
| **yt** | Python 的 AMR 数据分析库，能直接 load FLASH plotfile |
| **h5py** | Python 的 HDF5 读取库，比 yt 低层但更灵活 |
| **cell_volume** | yt 提供的每个 cell 的体积字段（cm³ in cgs）|
| **leaf block** | AMR 树的叶子节点（最细 refine level），物理量实际存的层 |
| **guard cell** | 边界 cell（每个 block 周围的 ghost cell），不在 plotfile 里 |
| **cgs 单位制** | FLASH 内部用 cm/g/s/erg/K，plotfile 也是 cgs |
| **EOS 表** | 物质的状态方程表（如 .imx/.ses），plotfile 不含，单独存 |

---

## 6. 分析"完整 vs 不完整"判断

### 6.1 完整跑完的标志

```bash
# 日志结尾
tail -5 cases/<case>/01-data/<basenm>.log
# 应看到：
# "Simulation completed successfully"
# 或 "Reached maximum simulation time"
# 或 "Reached maximum number of timesteps"

# plotfile 序列完整
ls cases/<case>/01-data/<basenm>_hdf5_plt_cnt_* | wc -l
# 应有合理数量（如 50+ 个）
```

### 6.2 异常结束的标志

| 标志 | 含义 |
|---|---|
| 日志结尾是 `abort` / `forrtl: error` | abort 了 |
| 日志结尾是 `SIGSEGV` | 段错误（如 libmpi 冲突）|
| plotfile 数 < 5 | 跑了很短就 abort |
| 最后 plotfile 时间 << sim_maxTime | 没跑到目标 |
| `<basenm>.dat` 行数 < 5 | 早期就 abort |

---

## 7. 延伸阅读

- **能量守恒分析方法**：`knowledge/energy_balance.md`
- **激光算例专项分析**：`knowledge/laser_analysis.md`
- **可视化模板**：`knowledge/visualization.md`
- **常见分析错误**：`knowledge/pitfalls.md`
- **Python 脚本**：`examples/check_energy.py` / `plot_quick.py` / `laser_coupling.py`
- **跑算例（前置）**：`flash-case-runner` skill 的 `knowledge/run_guide.md`
- **IO 单元（写 plotfile 机制）**：`flash-io` skill

---

## 8. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-08-02 | 初始创建（beta）：8 段总览 + plotfile vs checkpoint + .dat 文件族（含 LaserEnergyProfile）+ 物理量合理范围（HEDP/Sedov）+ 术语速查；按 L-011 讲为什么；按 L-014 解释术语；按 L-015 先讲分析故事线 | claude |
