---
name: flash-result-analyzer
description: |
  FLASH 4.8 模拟结果分析专家（Phase 4 操作层 skill）——跑完算例后看 plotfile/日志，
  判断"结果对不对、能量守不守恒、物理合不合理、激光吸收了多少"。
  按 L-013 聚焦主流路径——主讲 LaserSlab HEDP（用户实际场景：3T + MGD + 激光 + 多物质），
  Sedov 作为入门算例（有解析自相似解，最适合验证"代码对不对"）。
  覆盖：plotfile/checkpoint 结构（HDF5 + .dat 文件、变量名 UNK 速查、什么变量能用什么不能）；
  物理量范围检查（dens/pres/tele/tion/erad 的合理范围 + 越界诊断）；
  能量守恒分析（FLASH 自带 .dat 总能分解 + Python 从 plotfile 重算 + 3T/辐射/激光源各项贡献）；
  激光算例专项（吸收率计算从 LaserEnergyProfile.dat、TELE/TION 平衡时间尺度、ERAD 空间分布）；
  可视化（yt 快速画图 + h5py + matplotlib 模板，密度/温度/速度/辐射/物质分布）；
  基准对比（Sedov 自相似解、两个算例 diff）；
  常见分析错误（plotfile 读取失败/单位混淆/变量名错/stats 列错位）。
  非 tool skill——Claude 直接执行 Python/bash 分析（D-决策：knowledge + examples > 复杂 Python wrapper）。
  触发词：分析结果, 检查结果, 能量守恒, 守恒量, plotfile, 看输出, 看结果,
        物理上对吗, 结果合理吗, 验证结果, 后处理, post-process,
        可视化, 画图, yt, h5py, matplotlib, 出图,
        吸收率, 激光吸收, 沉积能量, coupling efficiency,
        TELE, TION, TERAD, 三温平衡, 电子温度, 离子温度,
        辐射能量, ERAD, 辐射场,
        总能量, 内能, 动能, E_total, E_internal, E_kinetic,
        stats 文件, .dat, integral quantities,
        NaN, Inf, 越界, 物理量范围,
        Sedov 自相似解, 基准对比,
        LaserEnergyProfile, 能量平衡
triggers:
  # 中文 - 分析类
  - 分析结果
  - 检查结果
  - 看结果
  - 看输出
  - 结果对吗
  - 结果合理吗
  - 物理上对吗
  - 验证结果
  - 后处理
  - 守恒量
  - 能量守恒
  - 能量平衡
  - 总能量
  - 内能
  - 动能
  - 三温平衡
  - 吸收率
  - 激光吸收
  - 沉积能量
  - 可视化
  - 画图
  - 出图
  - 基准对比
  # 英文 - 分析类
  - analyze results
  - check results
  - post-process
  - postprocess
  - energy balance
  - energy conservation
  - conservation
  - total energy
  - internal energy
  - kinetic energy
  - coupling efficiency
  - absorption rate
  - laser absorption
  - deposited energy
  - visualize
  - visualization
  - plot
  - yt
  - h5py
  - matplotlib
  - benchmark
  - sedov self-similar
  # 文件 / 对象
  - plotfile
  - checkpoint
  - stats file
  - .dat
  - LaserEnergyProfile
  - integral quantities
  # 物理量
  - TELE
  - TION
  - TERAD
  - ERAD
  - dens
  - pres
  - "电子温度"
  - "离子温度"
  - "辐射温度"
  - "辐射能量"
  # 异常诊断
  - NaN
  - Inf
  - "越界"
  - "物理量范围"
when_to_use: |
  调用本 skill 的场景（分析类——跑完算例后看结果）：
  1. 用户跑完算例说"看下结果对不对" / "物理上合理吗"——按 L-015 先讲完整分析流程（读 plotfile → 检查物理量 → 算守恒 → 画图）
  2. 用户说"能量守恒吗" / "总能量怎么变"——给 FLASH 自带 .dat + Python 重算两套方案
  3. 用户说"激光吸收了多少" / "coupling efficiency"——从 LaserEnergyProfile.dat 直接读 + 算吸收率
  4. 用户说"画个图" / "可视化" / "yt 怎么用"——给 yt + h5py + matplotlib 模板
  5. 用户说"TELE/TION 平衡了吗" / "三温演化"——给 3T 平衡时间尺度分析
  6. 用户说"和解析解对比" / "Sedov 自相似"——给 Sedov benchmark 脚本
  7. 用户说"plotfile 读不出来" / "变量名错"——按 L-012 引导贴 h5dump 输出 + 诊断
  8. 用户说"NaN/Inf 怎么定位"——给 grep + plotfile 扫描脚本
  9. 用户说"两个算例对比"——给 plotfile diff 流程
when_not_to_use: |
  **不调用本 skill 的场景**（属于其他 skill）：
  - 跑算例（setup/make/run/restart） → `flash-case-runner`（操作层前一个 skill）
  - 物理原理（"激光怎么沉积"、"MGD 怎么解"） → `flash-laser` / `flash-radtrans` 等知识层
  - parfile 参数含义 → `flash-param-query`
  - plotfile/checkpoint 的 IO 机制（怎么写出来的） → `flash-io`
  - 源码（IO_writeIntegralQuantities 在哪） → `flash-source-reader`
  - 已知错误信息匹配修复方案 → `flash-pitfall-finder`
  - 手册查询 → `flash-manual-search`
  - 构造新 setup 命令 → `flash-setup-builder`
layer: operations
phase: 4
status: stable
created: 2026-06-17
last_updated: 2026-08-02
owner: user
---

# flash-result-analyzer — FLASH 模拟结果分析专家（plotfile → 报告）

> **状态**：beta（Phase 4 第二个操作层 skill；操作层 2/2 全部 stable 后 Phase 4 收尾）
>
> **按 L-013 聚焦主流**：主讲 **LaserSlab HEDP**（用户实际场景：3T + MGD + 激光 + 多物质），**Sedov** 作为入门算例（有解析自相似解，最适合验证"代码本身对不对"）。
>
> **本 skill 的特殊价值**（L-001）：不只是给 Python 脚本模板——讲清楚每个分析方法"为什么这么算"、"不这么算会怎样"、单位陷阱、stats 文件结构陷阱、激光算例特有的 LaserEnergyProfile.dat 利用。

## 1. 角色与边界

### 1.1 我是做什么的

帮用户**分析跑完的 FLASH 算例结果**——从 plotfile / checkpoint / 日志 / .dat 文件提取信息，判断：
- 物理量是否在合理范围（dens/pres/tele/tion/erad）
- 能量是否守恒（总能 = 动能 + 内能 + 辐射能 + 激光沉积，等式左右差多少）
- 激光吸收了多少（沉积能量 / 入射能量）
- 三温是否平衡（TELE/TION/TERAD 演化）
- 数值有没有炸（NaN/Inf/below floor）

| 范畴 | 详见 |
|---|---|
| 结果分析总览 + plotfile 结构 + 检查清单 + 术语速查 | `knowledge/overview.md` |
| 能量守恒分析方法 | `knowledge/energy_balance.md` — FLASH 自带 .dat + Python 重算 + 3T/辐射/激光源分解 |
| 激光算例专项分析 | `knowledge/laser_analysis.md` — 吸收率 + TELE/TION 平衡 + ERAD 分布 |
| yt + h5py + matplotlib 可视化 | `knowledge/visualization.md` — 快速画图模板（密度/温度/速度/辐射/物质） |
| 结果分析常见错误 | `knowledge/pitfalls.md` — 按 L-012 每条都给"贴什么现场 + 怎么诊断 + 怎么修" |
| 一键脚本 | `examples/check_energy.py` / `examples/plot_quick.py` / `examples/laser_coupling.py` |

### 1.2 我不做什么

| 用户问题类型 | 归属 skill |
|---|---|
| 跑算例（setup/make/run/restart） | `flash-case-runner` |
| 激光沉积物理原理 | `flash-laser` |
| MGD 辐射扩散物理 | `flash-radtrans` |
| EOS 三温耦合机制 | `flash-eos` |
| Heatexchange（电子-离子平衡物理） | `flash-sourceterms` |
| Grid/AMR 机制 | `flash-grid` |
| plotfile/checkpoint 的 IO 写出机制 | `flash-io` |
| Multispecies（物质分布怎么算的） | `flash-multispecies` |
| 参数物理含义/默认值 | `flash-param-query` |
| 源码位置 | `flash-source-reader` |
| 已知错误匹配 | `flash-pitfall-finder` |
| 构造新 setup 命令 | `flash-setup-builder` |
| 手册查询 | `flash-manual-search` |

### 1.3 与 flash-case-runner 的边界（重要）

`flash-case-runner` 是**操作前半段**——把算例从 setup 跑到 plotfile 落地。

本 skill 是**操作后半段**——拿到 plotfile 之后判断"对不对、好不好"。

| 场景 | 用谁 |
|---|---|
| 用户说"算例怎么跑" / "怎么 setup" | `flash-case-runner` |
| 用户说"跑完了，看下结果" / "能量守恒吗" | 本 skill |
| 用户跑出 NaN（运行中） | `flash-case-runner`（先看是不是环境/parfile 问题）→ 本 skill（如果确认是数值问题，看分布） |
| 用户跑出 NaN（跑完了看分布） | 本 skill |

## 2. 行为协议

按 `agent/TEMPLATES/skill-template.md §2` 通用协议。核心要点：

- **讲逻辑**（L-001）：不只是给 Python 脚本，讲清楚"为什么这么算"、"不这么算会怎样"
- **不用 mermaid**（L-002）：流程图用文字+缩进
- **核心 4 段 + 引导项**（L-010）：核心段（命令/代码）必给详细，引导项（背景原理）按需展开
- **讲为什么**（L-011）：每个分析步骤必给"为什么这么算/什么场景该用"
- **诊断类先引导贴现场**（L-012）：plotfile 读失败 / 数据异常时**第一步**是引导用户贴 h5dump / ls / df.head() 输出
- **公式 CLI 友好**（L-012）：用 ASCII / 代码块
- **聚焦主流路径**（L-013）：主讲 LaserSlab（用户实际场景），Sedov 入门，简要带过其他
- **专业术语先解释**（L-014）：plotfile/checkpoint/yt/UNK 变量/stats 文件等术语第一次出现先一句话定义
- **先讲完整故事线**（L-015）：用户问"怎么分析结果"时先讲读 plotfile → 检查物理量 → 算能量 → 画图四步流程，再讲每步细节

## 3. knowledge/ + examples/ 子目录

| 文件 | 内容 |
|---|---|
| `knowledge/overview.md` | 结果分析总览 + plotfile/checkpoint 结构 + .dat 文件族 + 物理量检查清单 + 术语速查 |
| `knowledge/energy_balance.md` | 能量守恒分析方法（FLASH .dat 总能分解 + Python 重算 + 3T/辐射/激光源贡献 + 诊断"不守恒"原因） |
| `knowledge/laser_analysis.md` | 激光算例专项（LaserEnergyProfile.dat 解析 + 吸收率计算 + TELE/TION 演化 + ERAD 空间分布） |
| `knowledge/visualization.md` | yt + h5py + matplotlib 快速画图模板（密度/温度/速度/辐射/物质切片 + 1D 剖面 + 时间演化） |
| `knowledge/pitfalls.md` | 结果分析常见错误（plotfile 读取失败/单位混淆/变量名错/stats 列错位/yt 版本不兼容）+ 诊断引导 |
| `examples/check_energy.py` | Python 能量守恒检查脚本（从 plotfile 序列算总能演化 + 守恒误差） |
| `examples/plot_quick.py` | yt 快速画图脚本（密度/温度切片 + 保存 PNG） |
| `examples/laser_coupling.py` | 激光吸收率计算脚本（从 LaserEnergyProfile.dat 算 coupling efficiency） |
| `examples/README.md` | 脚本用法说明 |

## 4. 示例问答（验收基准）

### Q1: 跑完 LaserSlab，怎么知道结果对不对？

**A**: 见 `knowledge/overview.md §3` + `examples/check_energy.py`。**按 L-015 先讲完整故事线**：

```
1. 读 plotfile：用 yt 或 h5py 加载 *_hdf5_plt_cnt_*.h5
   → 拿到密度/温度/速度等场变量
2. 检查物理量范围：dens/tele/tion/erad 各自 min/max 是否在合理范围
   → 越界说明物理炸了或 EOS 表超范围
3. 算能量守恒：E_total(t) 应该 = 初始 + 激光沉积 - 边界损失
   → 误差 > 1% 说明数值出问题
4. 画图：密度/温度切片，看物理形态对不对（激波/激光沉积区/等离子体膨胀）
```

**LaserSlab 的合理范围参考**（用户实际场景）：

| 量 | 合理范围 | 越界含义 |
|---|---|---|
| dens | 0.001 - 10 g/cm³ | < 0.001 → 物质膨胀过头；> 50 → 激波压缩过头 |
| tele | 10 eV - 10 keV | > 50 keV → 激光过强或 EOS 错 |
| tion | 10 eV - 5 keV | ion 应该 < tele（电子先被加热） |
| erad | 1 eV - 1 keV | Trad 对应黑体温度，比 tele 低 |
| pres | 1e8 - 1e13 Pa | HEDP 典型范围 |

**关键陷阱**：
- **单位**：FLASH 内部 cgs（cm/g/s/erg/K），plotfile 也是 cgs。温度是 K 不是 eV（1 eV = 11604 K）
- **3T 算例**：TELE/TION/TERAD 都在 plotfile，但 TEMP（如有的话）是平均温度

### Q2: 能量守恒怎么看？

**A**: 见 `knowledge/energy_balance.md` + `examples/check_energy.py`。**两条路径**：

#### 路径 A：用 FLASH 自带的 .dat 文件（推荐，零 Python）

FLASH 运行时自动写 `<basenm>.dat`（默认 `<basenm>.dat`，可由 `io_statsFileName` 改）。
**结构**（源码 `source/IO/IOMain/IO_writeIntegralQuantities.F90:L223-L254`）：

```
#time                     mass                      x-momentum                y-momentum                z-momentum                E_total                   E_kinetic                 E_internal                MagEnergy
  1.234567890123456789E-10  1.000000000000000000E+00  ...
```

**列含义**（按 L-014 解释术语）：
- **mass**：总质量（积分 ∫ρ dV），单位 g（cgs）
- **x/y/z-momentum**：总动量（∫ρv dV），单位 g·cm/s
- **E_total**：总能（∫ρE dV，含动能 + 内能），单位 erg
- **E_kinetic**：动能（∫½ρv² dV），单位 erg
- **E_internal**：内能（∫ρe dV），单位 erg
- **MagEnergy**：磁能（仅 MHD 算例）

**守恒检查**：
- **封闭系统**（无源项、无边界流）：E_total 应**恒定**，相对误差 < 1%
- **激光算例**：E_total 应**单调增长**，增长量 ≈ 激光沉积能量

```bash
# 提取 E_total 列（第 6 列）画时间演化
awk 'NR>2 {print $1, $6}' cases/LaserSlab/01-data/lasslab.dat > etotal_vs_t.txt
# 看相对变化
awk 'NR>2 {et=$6; if(NR==3)et0=et; print $1, (et-et0)/et0}' \
  cases/LaserSlab/01-data/lasslab.dat
```

#### 路径 B：从 plotfile 用 Python 重算（适合需要分解 3T/辐射时）

见 `examples/check_energy.py`。核心：

```python
import yt
import glob

# 遍历 plotfile 序列
for fn in sorted(glob.glob('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_*')):
    ds = yt.load(fn)
    ad = ds.all_data()
    # 总能 = 动能 + 内能（1T）或 3T 分别算（3T）
    ekin = (ad['density'] * 0.5 * ad['velocity_magnitude']**2 * ad['cell_volume']).sum()
    # 3T 内能（EELE/EION/ERAD）
    eele = (ad['Eele'] * ad['cell_volume']).sum()  # 电子内能密度 × 体积
    eion = (ad['Eion'] * ad['cell_volume']).sum()
    erad = (ad['Eradt'] * ad['cell_volume']).sum()
    print(ds.current_time, ekin, eele, eion, erad)
```

### Q3: 激光吸收率怎么算？

**A**: 见 `knowledge/laser_analysis.md §2` + `examples/laser_coupling.py`。**关键发现**：FLASH 激光算例自动写一个 **LaserEnergyProfile.dat** 文件，含每步的入射能量和沉积能量——不用自己重算！

**文件位置**：
```
cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat
```

**文件结构**（源码 `EnergyDeposition_init.F90:L431`）：

```
#Step     Time (s)     dt (s)      Energy in (erg)    Energy out (erg)       dE in (erg)        dE out (erg)
    1   1.0000E-15  1.0000E-15    1.5000000000E-04    1.4999855098E-04    ...
```

**列含义**（按 L-014 解释术语）：
- **Energy in**：激光从入射边界进入域的总能量（cumulative，单位 erg）
- **Energy out**：激光从对面边界出去的能量（cumulative）
- **dE in / dE out**：本步增量
- **吸收率 = (Energy_in - Energy_out) / Energy_in**

**一行 awk 算吸收率**：

```bash
# 跳过前 2 行（注释 + 空），取最后一行算总吸收率
awk 'NR>2 {ein=$4; eout=$5} END {printf "吸收率 = %.2f%%\n", (ein-eout)/ein*100}' \
  cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat
```

**LaserSlab HEDP 典型吸收率**：
- 60-90%：正常（短波长、强吸收）
- < 30%：异常（激光过穿透 / 临界密度过低 / 不透明度错）
- > 95%：异常（可能域太小，激光还没出去就沉积完了）

### Q4: 怎么用 yt 画密度切片？

**A**: 见 `knowledge/visualization.md §2` + `examples/plot_quick.py`。**最小脚本**（10 行）：

```python
import yt
ds = yt.load('cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050')
p = yt.SlicePlot(ds, 'z', 'dens')  # 'z' 是投影轴（2D 算例也是 'z'）
p.set_log('dens', True)  # 密度用 log
p.set_cmap('dens', 'viridis')
p.annotate_velocity()  # 叠加速度矢量
p.save('density_slice.png')
```

**为什么用 yt（L-011 讲为什么）**：
- yt 自动识别 FLASH plotfile 格式（含 AMR 块结构）
- yt 自动合并不同 refine level 的 cell
- yt 自带物理量单位转换（cgs → SI）
- 替代方案 h5py + matplotlib 要手写 ~50 行才能实现同等效果

**关键陷阱**：
- **变量名**：yt 用 lowercase（`dens`/`tele`），plotfile 里是 UNK 名（`DENS`/`TELE`），yt 自动转换
- **3T 变量**：`tele`/`tion`/`trad` 都在 yt 里，但要先 `yt.load` 后 `print(ds.field_list)` 看实际可用
- **2D 算例**：投影轴只能是 'z'（FLASH 2D 是 x-y 平面）

### Q5: plotfile 用 yt 加载失败怎么办？

**A**: 见 `knowledge/pitfalls.md §2`。**按 L-012 先引导贴现场**：

```bash
# 1. 确认 plotfile 完整（应有 _hdf5_plt_cnt_NNNN 目录或单文件 .h5）
ls cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050
# 应看到：plotfile 目录或 .h5 文件 + 可能的 _chk 文件

# 2. 看 plotfile 内 HDF5 结构
h5dump -H cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050 | head -50
# 应看到 datasets: DENS, TELE, VELX, VELY, ...

# 3. 复现 yt 错误
python -c "import yt; ds = yt.load('cases/<case>/01-data/<basenm>_hdf5_plt_cnt_0050'); print(ds)"
# 看具体报错
```

**贴完后能给出针对性诊断**（按 L-012 通用原因）：

| yt 报错 | 最可能原因 | 修复 |
|---|---|---|
| `IndexError: list index out of range` | plotfile 是单文件 vs 目录混淆 | 用 `ls -la` 确认；yt 一般要目录 |
| `KeyError: 'DENS'` | UNK 名错（实际是 DENS_VAR 编号？） | `h5dump -H` 看实际 dataset 名 |
| `YTUnidentifiedDataType` | plotfile 损坏 / 写入中断 | 检查 sim 完整结束 |
| `AttributeError: 'Dataset' object has no attribute 'current_time'` | FLASH 老版本 plotfile | 用 yt 4.0+ 或手动读 time |
| `OSError: Unable to open file` | 文件权限 / 路径错 | `ls -la` + `chmod` |

## 5. 关键源码/文件入口

| 想理解 | 看哪个文件 |
|---|---|
| plotfile/checkpoint 写出实现 | `source/IO/IOMain/IO_writePlotfile.F90` / `IO_writeCheckpoint.F90` |
| 总能量积分（.dat 文件） | `source/IO/IOMain/IO_writeIntegralQuantities.F90:L140-L172`（总能/动能/内能计算） |
| .dat 文件列结构定义 | `source/IO/IOMain/IO_writeIntegralQuantities.F90:L223-L254`（write format） |
| LaserEnergyProfile.dat 写出 | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/EnergyDeposition_init.F90:L431` |
| 激光能量追踪 ed_energyOutTimeStep | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserRayTrace/CellAverage/ed_traceBlockRays2DCyl3D.F90:L950` |
| IO_output 主调度 | `source/IO/IOMain/IO_output.F90` |
| UNK 变量定义（DENS/TELE/EION 等） | `source/Simulation/SimulationMain/<problem>/Config` + setup 生成的 `Flash.h` |
| yt 加载 FLASH plotfile 文档 | https://yt-project.org/docs/dev/examining/loading_data.html#flash-data |
| h5py 文档 | https://docs.h5py.org/ |
| 本机已有 plotfile 样本（实证） | `cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0000/` |
| 本机已有 .dat 样本（实证） | `cases/LaserSlab/01-data/lasslab.dat` / `lasslab_LaserEnergyProfile.dat` |
| 物理量合理范围参考 | `knowledge/overview.md §4`（HEDP / Sedov 典型值） |

## 6. 与其他 skill 的协作链

| 场景 | 协作链 |
|---|---|
| 用户跑完算例，要看结果 | `flash-case-runner`（跑）→ 本 skill（看结果） |
| 用户跑完 LaserSlab，发现能量不守恒 | 本 skill（贴 .dat）→ `flash-pitfall-finder`（找原因）→ `flash-hydro` / `flash-sourceterms`（根因） |
| 用户跑出 NaN，已经看了日志 | `flash-case-runner`（日志诊断）→ 本 skill（plotfile 看 NaN 在哪） |
| 用户问"这个变量名 plotfile 里叫什么" | 本 skill（plotfile 结构）→ `flash-source-reader`（UNK 定义源码） |
| 用户问"为什么 Trad 比 Tele 低" | 本 skill（数据展示）→ `flash-eos` / `flash-sourceterms`（物理原因） |
| 用户问"激光吸收率为什么只有 30%" | 本 skill（计算）→ `flash-laser`（参数诊断：波长/功率/临界密度） |
| 用户问"yt 怎么用 SlicePlot" | 本 skill（yt 模板） |
| 用户问"和 Sedov 解析解对比" | 本 skill（benchmark 脚本） |

## 7. 待办

- [ ] 跑 5 道验收考题（用户评分驱动迭代 SKILL.md，按 L-007）
- [ ] 持续累积分析踩坑（用户实战 HEDP 算例遇到的分析问题）
- [ ] 扩展 visualization 模板（3D 体积渲染、相图、自定义 phase plot）
- [ ] 加 Sedov 自相似解 benchmark 脚本
- [ ] 加多算例 diff 脚本（参数敏感性分析）

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-08-02 | **升级 draft → beta**（Phase 4 第二个操作层 skill，操作层 2/2 全部 stable）：基于 LaserSlab 实战 plotfile + LaserEnergyProfile.dat 实证 + IO_writeIntegralQuantities 源码结构，按 L-001~L-015 全部经验写完 SKILL.md + 5 knowledge + 4 examples；核心设计——knowledge + examples > 复杂 Python wrapper（Claude 直接执行 Python 更灵活）；按 L-013 聚焦 LaserSlab（用户实际场景）+ Sedov（入门）；按 L-014 解释 plotfile/checkpoint/yt/UNK/stats 文件等术语；按 L-015 先讲"读 plotfile → 检查物理量 → 算能量 → 画图"四步流程；按 L-012 plotfile 读失败/数据异常先引导贴 h5dump/yt 错误 | claude |
