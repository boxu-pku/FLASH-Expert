---
title: setup 选项详查——每个选项的"是什么 + 为什么 + 何时用 + 可换什么"
skill: flash-setup-builder
category: reference
source_anchors:
  - bin/setup.py
  - bin/setup_shortcuts.txt
  - cases/LaserSlab/setup_call
  - cases/Sunliang_laser_CH/setup_call
  - cases/Sedov/setup_call
---

# setup 选项详查

> 每个选项按 L-011 五要素展开：**是什么 / 为什么有它 / 为什么这么设计 / 何时用 / 有什么坑**。
> 按 L-013 聚焦 HEDP 主流选项详讲，边缘选项简表。

## 目录

1. [位置参数：SimulationMain](#1-位置参数simulationmain)
2. [维度选项：-1d / -2d / -3d](#2-维度选项-1d--2d--3d)
3. [几何选项：+cartesian / +cylindrical / +spherical](#3-几何选项)
4. [Block 大小：-nxb / -nyb / -nzb](#4-block-大小-nxb--nyb--nzb)
5. [Grid backend：+pm4dev / +ug](#5-grid-backend)
6. [物理求解器（HEDP 主流四件套）](#6-物理求解器hedp-主流四件套)
7. [物质列表：species=](#7-物质列表species)
8. [辐射群数：mgd_meshgroups=](#8-辐射群数mgd_meshgroups)
9. [IO 后端：+hdf5typeio](#9-io-后端hdf5typeio)
10. [流程控制：-auto / -objdir= / -parfile=](#10-流程控制)
11. [调试：-debug](#11-调试-debug)
12. [边缘选项速查](#12-边缘选项速查)

---

## 1. 位置参数：SimulationMain

### 是什么
setup 命令**第一个位置参数**（不是 `-key=val` 形式），指定要 setup 的算例。

### 为什么有它
FLASH 有 59+ 个算例（`source/Simulation/SimulationMain/` 下每个目录都是一个），必须告诉 setup 你要哪个。

### 为什么这么设计
- 位置参数（不是 `-problem=LaserSlab`）因为它**必填**——必填项用位置参数更紧凑
- 大小写不敏感前缀匹配：`sedov` / `Sedov` / `SEDOV` 都行；甚至 `sed` 都能匹配（如果唯一）
- setup.py 找不到唯一匹配时报 `SetupError: Ambiguous unit 'X' matches: [...]`

### 何时用
**永远第一个**。例：
```bash
./setup LaserSlab -2d -auto -objdir=cases/LaserSlab
         ^^^^^^^^^ 位置参数
```

### 有什么坑
- **大小写不敏感但拼写要对**：`laserslab` 不行（FLASH 算例名是 `LaserSlab`，驼峰）
- **前缀匹配可能歧义**：`S` 能匹配 Sod / Sedov / SedovSelfGravity / SedovSolidWall / SedovChamber，setup 会报 ambiguous

### 怎么查所有可用算例
```bash
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/
```

---

## 2. 维度选项：-1d / -2d / -3d

### 是什么
告诉 setup 模拟的**空间维度数**。

### 为什么有它
不同维度下：
- NXB/NYB/NZB 编译期宏不同（1D 时 NZB=NYB=1）
- N_DIM 宏不同（影响 Grid 数组维度、guard cell 数量）
- 调用的坐标几何不同（1D 通常 spherical、2D 通常 cylindrical、3D cartesian）

### 为什么这么设计
- 维度是**编译期决策**（不是运行时）——1D 和 3D 的数组形状根本不同，必须编译时就定
- `-2d` 比 `-d=2` 紧凑，且和其他 setup 选项视觉一致（都是 `-xxx`）
- 维度影响 NXB 默认值（1D 默认 NZB=NYB=1，3D 默认 NXB=NYB=NZB=8）

### 何时用（按物理判断）

| 物理目标 | 维度 | 理由 |
|---|---|---|
| 球对称（点爆炸、ICF 内爆球壳）| `-1d` + `+spherical` | 球对称下 1D 等价于 3D，省 CPU 几千倍 |
| 轴对称（平面靶、Z 箍缩）| `-2d` + `+cylindrical` | 轴对称下 2D 等价于 3D，省 CPU 几百倍 |
| 平面 + 各向同性（激波管测试）| `-1d` 或 `-2d` + `+cartesian` | 1D 验证；2D 验证横向稳定性 |
| 任意 3D 结构（湍流、3D RT）| `-3d` + `+cartesian` | 真实 3D 物理 |

### 有什么坑
- **不写维度**：setup.py 用 Config 默认，可能默认 2D 但你要 3D——**始终显式写**
- **维度和几何不匹配**：`-3d` + `+spherical` 通常无意义（球对称 3D 浪费 CPU）
- **Hydro 求解器限制**：有些 Hydro 变体只支持 1D/2D（如某些 split hydro 不支持 3D）

---

## 3. 几何选项

### 是什么
告诉 setup 用哪种坐标系。三种主流：

| 选项 | 坐标系 | 等价写法 |
|---|---|---|
| `+cartesian` | (x, y, z) 直角坐标 | `-geometry=cartesian` |
| `+cylindrical` | (r, z) 或 (r, θ, z) 圆柱坐标 | `-geometry=cylindrical` |
| `+spherical` | (r, θ, φ) 或 (r) 球坐标 | `-geometry=spherical` |

### 为什么有它
不同几何下：
- 控制方程不同（球坐标有 1/r² 项，圆柱有 1/r 项）
- 网格度量（cell 体积、面积）计算不同
- 物理量梯度算子不同

### 为什么这么设计
- **两种写法等价**（`+cylindrical` 和 `-geometry=cylindrical`）——shortcut 风格 vs 显式风格，前者紧凑，后者语义明确
- 几何是 setup-variable，可以和 Config 里的 DEFAULT 配合（Config 默认 cartesian，setup 命令行覆盖）

### 何时用（按物理判断）

| 物理 | 几何 | 典型算例 |
|---|---|---|
| 平面问题（无对称轴）| cartesian | Sod 激波管、WindTunnel |
| 轴对称（旋转对称）| cylindrical | LaserSlab 平面靶、Z 箍缩 |
| 球对称（点源）| spherical | Sedov 球爆炸、ICF 直接驱动 |
| 平面 + 球边界（少见）| spherical + 特殊网格 | SedovSelfGravity |

### 有什么坑
- **几何和维度不匹配**：`+spherical -2d` 通常无意义（球对称要 1D，3D 球不用对称）
- **几何影响激光路径**：cylindrical 下激光沿 z 轴，spherical 下沿 r——选错几何激光行为完全错
- **AMR 在曲线坐标下要小心**：cylindrical/spherical 下 AMR 加密时 r=0 附近有奇点，需 Config 处理

---

## 4. Block 大小：-nxb / -nyb / -nzb

### 是什么
告诉 setup 每个 AMR **block** 在 x/y/z 方向的 cell 数。

### 为什么有它
Paramesh 的 AMR 用固定大小 block（编译期定）：
- `-nxb=16 -nyb=16 -nzb=1` 表示每个 block 是 16×16×1 cells（2D 时 NZB=1）
- AMR 加密时 block 分裂成 4 个（2D）或 8 个（3D）子 block

### 为什么这么设计
- **编译期固定**让数组形状静态，编译器优化好（缓存、向量化）
- **block 大小固定**让 AMR 树结构简单（每个 block 同样大小）
- 默认 8（小），但**实际算例 16 是主流**（见下面"何时用"）

### 何时用（按经验）

| Block 大小 | 何时用 | 为什么 |
|---|---|---|
| `-nxb=8 -nyb=8`（默认）| **几乎不用** | 太小，边界损耗（guard cell 占比大）|
| `-nxb=16 -nyb=16` | **主流**（HEDP 99%）| 边界损耗可接受，AMR 灵活 |
| `-nxb=32 -nyb=32` | 大块算例 | 单块计算更高效，但 AMR 加密粒度粗 |
| `-nxb=64 -nyb=64` | 极少 | AMR 几乎没用，不如 UG |

**为什么 16 是主流**：
- 8 太小：guard cell 通常 4，block 8×8 时 guard 占 (16×16-8×8)/(16×16) = 75%（边界损耗极大）
- 16 适中：block 16×16 时 guard 占 (24×24-16×16)/(24×24) ≈ 55%（可接受）
- 32 偏大：加密 1 块需要 4 块（2D），32×32 → 4 个 16×16 还是太大
- 64 极大：基本等于不加密

### 有什么坑
- **维度和 nzb 关系**：2D 时 `nzb` 默认为 1（**不用写 `-nzb=1`**）；3D 必须显式
- **shortcut cube16/cube32/cube64**：`+cube16` = `-nxb=16 -nyb=16 -nzb=16`（3D 用）
- **nxb 必须 ≥ 2×GUARDCELLS**：当用 PPM 等高阶格式时 GUARDCELLS=4，nxb 必须 ≥ 8

---

## 5. Grid backend

### 是什么
告诉 setup 用哪个 Grid 实现。FLASH 有 4 个 Grid backend：

| 选项 | backend | 用途 |
|---|---|---|
| `+pm4dev`（默认）| Paramesh 4 dev | AMR 算例（HEDP 99%）|
| `+pm2` | Paramesh 2 | 老版本 Paramesh（少用）|
| `+ug` | Uniform Grid | PIC、FFT-Poisson、不需要 AMR 的算例 |
| `+chombo_amr` | Chombo AMR | 嵌入式边界（半成熟）|

### 为什么有它
不同物理问题对网格需求**根本不同**（L-011：讲为什么）：
- 激波算例需要**局部加密**（AMR）→ Paramesh
- PIC 算例粒子权重依赖**均匀网格** → UG
- FFT-Poisson 数学上要 uniform → UG
- 嵌入式边界（如复杂几何）→ Chombo

### 为什么默认 pm4dev
- 99% 的 FLASH 算例是 AMR 类
- pm4dev 是修改过的 Paramesh 4，比 sourceforge 原版更 scalable（surr_blks 数组填法更高效）
- UG 用户**知道自己要 UG**会主动写 `+ug`

### 何时用

| 场景 | 选什么 |
|---|---|
| HEDP / 激波 / 普通流体 | `+pm4dev`（或不写，默认）|
| PIC / PIC-like | `+ug` |
| FFT-Poisson 求解（如 incompFlow）| `+ug` |
| 嵌入式边界（少见）| `+chombo_amr` |

### 有什么坑
- **LaserSlab 不用 +pm4dev**：因为 Paramesh 是默认（`default` shortcut 已含），所以 LaserSlab 命令里没写
- **Sunliang 显式写 +pm4dev**：用户为了明确（不依赖默认），两种都行
- **UG 和 AMR 物理不同**：UG 不能局部加密，AMR 算例换 UG 物理就错了

---

## 6. 物理求解器（HEDP 主流四件套）

HEDP 激光打靶算例的标准物理组合：`+laser +mgd +uhd3t +mtmmmt`。逐个讲。

### 6.1 +laser

#### 是什么
包含激光能量沉积单元（EnergyDeposition/Laser）。

#### 为什么有它
HEDP 激光打靶的核心物理——激光在等离子体里通过逆韧致吸收沉积能量。

#### 为什么这么设计
- 是个 shortcut（见 shortcut_table.md）：展开成 `-unit=physics/sourceTerms/.../Laser -without-unit=Particles`
- 默认用 Kaiser 算法（ray tracing + 几何光学）；变体 `+laserCubicInterpolation` 用立方插值
- `+asyncLaser` 是实验性的异步通信优化（少用）

#### 何时用
HEDP 激光算例**必加**。无激光的辐射流体算例（如 RadSlab）不加。

#### 有什么坑
- **必须配 `ed_maxBeams` / `ed_maxPulses` 等参数**：setup 不报错，运行时才报——见 pitfalls.md
- **激光路径依赖几何**：cylindrical 下沿 z 轴，spherical 下沿 r
- **+laser 自动 -without-unit=Particles**：因为 Laser 单元和 Particles 共用一些 slot，互斥

### 6.2 +mgd

#### 是什么
包含多群扩散辐射单元（RadTrans/RadTransMain/MGD）+ Opacity 单元。

#### 为什么有它
HEDP 的辐射输运**主流方法**是 MGD（多群扩散），vs flux-limited diffusion（灰体）更简单但精度低。

#### 为什么这么设计
- MGD 把辐射谱分成 N 群（典型 6 调试 / 70 生产），每群解扩散方程
- 比 Monte Carlo 输运便宜 1000 倍，比灰体扩散准 10 倍
- shortcut 展开成 `-unit=physics/materialProperties/Opacity -unit=physics/RadTrans/RadTransMain/MGD`

#### 何时用
HEDP 算例**必加**。注意：
- **`+mgd` 自动开 Opacity 单元**——不用单独写
- **配 `mgd_meshgroups=N`**：决定频率分辨率（6 调试 / 70 生产）
- **配 HYPRE 库**：MGD 调 HYPRE 解大稀疏矩阵（Makefile.h 必须有 `HYPRE_PATH`）

#### 有什么坑
- **没配 mgd_meshgroups**：用默认值（可能很大，浪费内存）
- **HYPRE 库没装**：编译失败，看 Makefile.h 的 `HYPRE_PATH`
- **MGD 和 USM 冲突**（旧版本）：现在已修，但旧算例要小心

### 6.3 +uhd3t

#### 是什么
"unsplit Hydro + 3T" 组合。

#### 为什么有它
- **3T**：三温模型（Tele 电子温度 + Tion 离子温度 + Trad 辐射温度独立演化）
- **unsplit Hydro**：守恒律无分裂求解（vs 老的 split Hydro，不能直接处理 3T）

#### 为什么这么设计
shortcut `uhd3t` 展开为 `+3t +uhd`，其中：
- `+3t` = `ThreeT=1 -defines=FLASH_3T`（开启 3T 编译宏）
- `+uhd` = `--with-unit=physics/Hydro/HydroMain/unsplit/Hydro_Unsplit --without-unit=physics/Hydro/HydroMain/split`

HEDP 必须用 3T（激光主要加热电子，离子靠碰撞传能，辐射独立演化），且 unsplit Hydro 才支持 3T 模式。

#### 何时用
HEDP 算例**必加**。无 3T 的灰体/单温算例不加。

#### 有什么坑
- **+uhd3t 不能配 split hydro**：shortcut 已经 `--without-unit=.../split` 强制 unsplit
- **3T 内存翻 3 倍**：Tele/Tion/Trad 各一份，比单温 PRES 多 3 倍 unk 数组
- **+uhd3t 自动 +3t +uhd**：不要重复写

### 6.4 +mtmmmt

#### 是什么
"multi-temp EOS multi-type"，开启 multiTemp + Multitype EOS 单元。

#### 为什么有它
3T 算例需要**分别查 3 种 EOS**（电子 EOS / 离子 EOS / 辐射 EOS），mtmmmt 提供这个能力。

#### 为什么这么设计
- shortcut 展开为 `-unit=physics/Eos/EosMain/multiTemp/Multitype -unit=physics/Eos/EosMain/Tabulated`
- Multitype 让每种物质可以有不同 EOS 类型（如 cham 用 IONMIX4 表，targ 用 SESAME 表）
- Tabulated 提供表查找（与解析 EOS 并存）

#### 何时用
3T 算例**必加**。和 `+uhd3t` 一起出现。

#### 有什么坑
- **没加 +mtmmmt 但加了 +uhd3t**：编译可能过但运行时 EOS 查询错
- **+mtmmmt 必须配 species=**：每个 species 要有 EOS 类型（参数族 `eos_<spec>EosType`）

---

## 7. 物质列表：species=

### 是什么
告诉 setup 模拟哪些物质。例：`species=cham,targ`（2 物质）或 `species=cham,targ1,targ2,targ3`（4 物质）。

### 为什么有它
FLASH 用 Multispecies 单元管理物质参数（每种物质的 EOS 类型、原子序数、不透明度表等）。setup 看到 `species=` 后通过 Python genFiles 自动生成：
- 编译宏 `FLASH_MULTISPECIES` + `NSPECIES=N`
- `Flash.h` 里的 unk 索引（`CHAM_SPEC=1`、`TARG_SPEC=2`）
- UNK 数组 `SPECIES_VAR`（每种物质的质量分数）
- 参数族 `ms_<spec>A`、`ms_<spec>Z`、`eos_<spec>EosType`、`op_<spec>AbsorbKind` 等

### 为什么这么设计
- **setup 阶段决策**：species 列表影响编译宏 + unk 数组大小，必须编译期定
- **用 Python genFiles 自动生成**：避免用户手写 60+ 行 Config
- **逗号分隔**：简单直观，setup.py 拆分即可

### 何时用（按靶设计）

| 物理目标 | species | 例子 |
|---|---|---|
| 单物质（最简）| `species=targ` | 单层平面靶 |
| 标准 HEDP 平面靶 | `species=cham,targ` | LaserSlab 默认（腔体 + 靶）|
| 多层平面靶 | `species=cham,targ1,targ2,targ3` | CH + CHBr + CH 多层靶 |
| 不同 cham 材料 | `species=helium,targ` | 氦腔体 |

### 有什么坑
- **species 数量必须匹配 Config**：LaserSlab Config 期望 2 种，给 4 种会失败（除非改 Config）
- **Sunliang_laser_CH 是改过 Config 的版本**：支持 4 species
- **species 名字影响参数族**：`species=cham` → 参数 `ms_chamA`；改名要改 parfile 全套

### 详细机制
species 的完整故事线见 `flash-multispecies` skill。

---

## 8. 辐射群数：mgd_meshgroups=

### 是什么
MGD（多群扩散）的**频率群数**。把辐射谱分成 N 个群，每群解一个扩散方程。

### 为什么有它
辐射谱是连续的（不同频率光子行为不同），但数值上必须离散。N 越大频率分辨率越高，但内存和时间越多。

### 为什么这么设计
- **setup 阶段决策**：影响编译期数组大小（`RAD_RAY_BANDS` 宏）
- **典型范围**：调试 6，生产 70，最高 ~200（受内存限制）
- **群间隔不均匀**：MGD 在低频（红外）密集，高频稀疏（Planck 谱权重）

### 何时用

| 场景 | mgd_meshgroups | 理由 |
|---|---|---|
| 调试 / 验证 setup | 6 | 内存小，跑通为主 |
| 生产（HEDP 主流）| 70 | 频率分辨率够用，内存可接受 |
| 高精度辐射（少）| 100-200 | Planck 谱需要精细分辨率 |

### 有什么坑
- **没写 mgd_meshgroups**：用默认（可能很大或很小，看 Config）
- **改群数要重新 setup**：因为影响编译宏——只改 parfile 不行
- **群数和 EOS/Opacity 表的群数一致**：IONMIX4 表自带群数，必须匹配

---

## 9. IO 后端：+hdf5typeio

### 是什么
告诉 setup 用 HDF5 格式做 plotfile / checkpoint 输出。

### 为什么有它
FLASH 支持多种 IO 后端：
- 默认（非 HDF5）：老式二进制
- HDF5：现代主流，跨平台、可并行、工具链支持（Visit / Python h5py）
- pnetcdf：另一种并行格式（少用）

### 为什么这么设计
- shortcut `hdf5TypeIO` 展开为 `+io +parallelIO +hdf5 typeIO=True`
- HDF5 是科学计算事实标准，Visit / Paraview / h5py 都支持
- 默认非 HDF5 是历史遗留（早期 HDF5 慢）

### 何时用
HEDP 主流**必加**。除非：
- 极简测试（Sedov 调试环境，不用 HDF5）
- 老脚本依赖非 HDF5 格式

### 有什么坑
- **没装 HDF5 库**：编译失败，看 Makefile.h 的 `HDF5_PATH`
- **HDF5 并行版本不匹配**：MPI 是 mpich，HDF5 必须用支持 mpich 的版本
- **typeIO=True**：表示用类型化 IO（每变量单独 HDF5 dataset），更灵活

---

## 10. 流程控制

### 10.1 -auto

#### 是什么
跳过交互式提示，用 Config 里的 DEFAULT 自动选变体。

#### 为什么有它
不带 `-auto` 时，setup 遇到多变体选择会进交互式菜单，用户得手动选。`-auto` 让 setup 全自动。

#### 为什么这么设计
- 命令行 setup 时交互式菜单不便（脚本化困难）
- Config 里通常有 DEFAULT，用户信任 DEFAULT 就用 `-auto`
- 99% 的算例 `-auto` 都能正常 setup

#### 何时用
**几乎必加**。除非：
- 想看交互式菜单的所有选项（学习用）
- 算例 Config 没设 DEFAULT（罕见）

#### 有什么坑
- **`-auto` 选错变体**：如默认 Hydro 是 split，但你要 unsplit——必须显式 `+uhd3t`
- **`-auto` 不警告缺失**：如缺 species= 但 Config 期望——运行时才报错

### 10.2 -objdir=PATH

#### 是什么
指定构建目录。

#### 为什么有它
让一个源码树支持多个并行 build（debug 版 / opt 版 / 不同物理变体）。

#### 为什么这么设计
- objdir 隔离 build——不同 setup 不冲突
- 默认 `object/` 太通用，本机约定 `cases/<算例名>/`（让 cases 集中管理）
- objdir 内全是软链接 + 生成文件，删了重 setup 就行

#### 何时用
**必加**。本机约定 `cases/<算例名>/`。

#### 有什么坑
- **缺 -objdir=**：默认 `object/`——多个算例 setup 会覆盖
- **objdir 已存在**：setup 默认追加（不删旧文件）——重新 setup 前要 `-clean` 或手动 `rm -rf`
- **objdir 路径含空格**：少见但会出问题，避免

### 10.3 -parfile=NAME

#### 是什么
复制 `<NAME>.par` 到 objdir 作 `flash.par`。

#### 为什么有它
FLASH 运行时读 `flash.par`，但用户 parfile 模板在 `source/Simulation/SimulationMain/<算例>/`。setup 阶段复制让用户不用手动 cp。

#### 为什么这么设计
- 让 setup 命令一行搞定"build + 配置"
- 不同 parfile 模板对应不同场景（example.par / coldstart.par / 3Din2D.par）

#### 何时用
**几乎必加**。否则要手动 `cp <name>.par cases/<case>/flash.par`。

#### 有什么坑
- **parfile 必须在 source/.../<算例>/ 下**：找不到报 `SetupError: parfile 'X.par' not found`
- **parfile 名不带 `.par` 后缀**：`-parfile=example` 找 `example.par`
- **parfile 顶部 setup 注释可能不可信**（L-009）：以 `setup_call` 为准

### 10.4 -clean

#### 是什么
setup 前清 objdir（删旧文件）。

#### 何时用
重新 setup 一个 case 时（如改了 setup-variables）。否则旧文件可能残留导致编译错。

---

## 11. 调试：-debug

### 是什么
用 debug 编译选项（`FFLAGS_DEBUG` 替换 `FFLAGS_OPT`）。

### 为什么有它
HEDP 算例常见 NaN / 越界 / 浮点异常，debug 模式开 `-O0 -g -ffpe-trap=... -fbounds-check` 让问题立刻暴露。

### 为什么这么设计
- **不开 -debug 时用 -O3**：编译器优化可能掩盖 NaN（如 NaN 被 vectorize 跳过）
- **debug 模式慢 5-10 倍**：默认不开，调问题时开

### 何时用
- 算例跑出 NaN——立刻重 setup 加 `-debug`
- 验证 parfile 改动正确——`-debug` 跑几步看初始化对不对
- 调 guard cell 越界——`-fbounds-check` 立刻报

### 有什么坑
- **`-debug` 必须重新 setup + make**：不是只 make——`-debug` 影响 Makefile.h 的 FFLAGS 选择
- **`-debug` 跑得极慢**：调试完记得去掉重 setup
- **建议 objdir 分开**：`-objdir=cases/<case>_debug`，不污染生产版

---

## 12. 边缘选项速查

按 L-013，这些不是主流，简要列：

| 选项 | 作用 | 何时用 |
|---|---|---|
| `-maxBlocks=N` | 设每个 MPI 进程的最大 block 数 | 大算例（10000+ blocks）|
| `-verbose` / `-v` | 详细 setup 输出 | 调试 setup 过程 |
| `-no-server` | 不启动 setup.py IPC 服务器 | 罕见（老版本机制）|
| `-nodef` | 不应用 default shortcut | 极少（想完全控制）|
| `+npg` | NO_PERMANENT_GUARDCELLS 模式 | 节省内存但限制多 |
| `+cube16` / `+cube32` / `+cube64` | 3D block 大小快捷方式 | 3D 算例 |
| `+mpi3` | 用 MPI-3 标准 | 新功能（如 shared memory）|
| `+threadBL` / `+threadwB` | OpenMP 多线程 | 优化算例 |
| `+usm` / `+usm3t` | unsplit MHD | MHD 算例 |
| `+8wave` | 8-wave MHD 求解器 | 老版本 MHD |
| `+spark` | 激光打火 | 燃烧算例 |
| `+noio` | 不包含 IO 单元 | 极少（测试用）|
| `+nofbs` | no fixed block size | UG 算例 |
| `+mpole` | multipole 重力求解器 | 自重力算例 |
