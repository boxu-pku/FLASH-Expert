---
title: flash-setup-builder overview——setup 命令构造完整心智模型
skill: flash-setup-builder
category: overview
source_anchors:
  - bin/setup.py
  - bin/setup_shortcuts.txt
  - bin/Readme.SetupVars
  - cases/LaserSlab/setup_call
  - cases/Sunliang_laser_CH/setup_call
---

# flash-setup-builder overview
> 路径约定：`$FLASH_ROOT` = FLASH 4.8 仓库根目录（本机 `/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8`）；`$FLASH_LIBS` = 外部库根目录（本机 `/home/ubuntu/local/flash/myFLASH4.8`）。其它机器按实际路径替换。


> 本文是 setup 命令构造工具的**总览文档**。讲清楚 setup 命令的"完整故事线"+ 语法 + 术语，
> 让你接到用户需求时能拼出可运行的 `./setup` 命令。
>
> 跟 `flash-case-runner/knowledge/setup_guide.md` 的分工：那条讲"setup 阶段在算例生命周期里的位置"，
> 本条专讲"**怎么把一条 setup 命令从零拼出来**"。两边互补。

## 1. 术语速查（L-014：先解释概念本身）

下面这些词在 setup 世界里反复出现，先一句话讲清楚每一个是什么、为什么存在。

| 术语 | 一句话定义 | 为什么存在 |
|---|---|---|
| **setup-variable**（setup 变量）| `./setup` 命令行里用 `+foo` / `-foo` / `key=value` 形式传给 setup.py 的变量 | 让用户在命令行控制"要包含哪些单元 / 用哪个变体 / 多少群数"——不用改 Config |
| **shortcut**（快捷方式）| `bin/setup_shortcuts.txt` 里定义的、把一串 `--with-unit=...` 展开成单个 `+name` 的别名 | 把常用组合（如"+ laser 等价于 6 行 --with-unit"）压缩成一个词，命令行可读 |
| **unit**（单元）| source/ 下一个带 Config 文件的目录，是 FLASH 的最小代码组装单位（如 `physics/Hydro`）| 让代码模块化——同一份 FLASH 通过选不同 unit 实现物理切换 |
| **Config**（单元配置文件）| 每个 unit 根目录下的 `Config` 文件，声明 `REQUIRES / REQUESTS / DEFAULT / PARAMETER` | setup.py 通过读所有 Config 拼出 unit DAG，决定哪些代码进 objdir |
| **REQUIRES**（强制依赖）| Config 里的指令，声明"我必须依赖 X 单元才能编译运行" | 让 setup 自动包含必备单元，不用用户手写 `--with-unit=` |
| **REQUESTS**（可选请求）| Config 里的指令，类似 REQUIRES 但可被 setup 关掉 | 区分"硬依赖"和"软依赖"，给 setup 灵活性 |
| **DEFAULT**（默认变体）| Config 里的指令，多变体并存时声明默认选哪个 | 解决"physics/Hydro 下有 split/unsplit/usm/... 八个变体，setup 时默认选谁"|
| **SimulationMain**（算例）| source/Simulation/SimulationMain/ 下的一个目录，代表一个完整可运行问题 | 用户工作目录——每个算例有独立 Config + Simulation_initBlock + parfile |
| **objdir**（构建目录）| `./setup -objdir=<path>` 指定的目录，所有 .F90 软链接 / Makefile / parfile 都在这里 | 让一个源码树支持多个并行 build（debug 版 / opt 版 / 不同物理变体）|
| **parfile**（参数文件）| `<name>.par` 文件，运行时读的 namelist 配置 | setup 阶段把模拟参数从代码里抽出来，改参数不用重 make |
| **site**（机器配置）| `sites/<hostname>/Makefile.h`，含编译器/MPI/HDF5/HYPRE 路径 | 让同一份源码在不同超算上编译，只换 site 不改源码 |
| **setup_flags**（展开后选项）| objdir 里 setup 生成的文件，记录 setup 实际用的 `--with-unit=` 完整列表 | 让用户回看"我的 `+laser` 到底展开了什么" |
| **setup_defines**（编译宏）| objdir 里 setup 生成的文件，含 `-DNXB=16 -DFLASH_3T` 等编译宏 | 让 Fortran 代码用 `#ifdef FLASH_3T` 区分不同 setup |

## 2. setup 命令的完整故事线（L-015：先讲旅程再讲细节）

按 L-015，一条 setup 命令从被你拼出来到生成 objdir，要走完下面这条旅程。

### 2.1 一条 setup 命令的生命周期

```
1. 用户终端
   ↓ ./setup LaserSlab -2d +cylindrical +laser ... -objdir=cases/LaserSlab
2. bin/setup（薄 wrapper）
   ↓ exec bin/setup.py "$@"
3. bin/setup.py:main()
   ↓ 1) 解析命令行：识别 -2d / +laser / species=cham,targ / -objdir=... 等
   ↓ 2) 应用 bin/setup_shortcuts.txt：把 +laser 展开成 --with-unit=...Laser
   ↓ 3) 加 default shortcut（--with-library=mpi +io +grid -gridinterpolation=monotonic）
4. unitCfg.py 读所有 Config 文件
   ↓ 构建 unit DAG：从 SimulationMain/LaserSlab/Config 开始
   ↓ 递归 REQUIRES：拉 physics/Hydro、physics/Eos、IO、Grid 等
   ↓ 遇到多变体时按 DEFAULT 选；setup-variable 优先（如 +uhd3t 强制 unsplit）
5. genFiles.py 自动生成代码
   ↓ Flash.h（unk 索引：DENS_VAR/PRES_VAR/TELE_VAR/...）
   ↓ 物质相关代码（species=cham,targ → SPECIES_VAR、CHAM_SPEC、TARG_SPEC）
   ↓ 参数族代码（RuntimeParameters_get 支持 ed_wavelength、sim_xmin 等）
6. linkFiles.py 链接源码
   ↓ 把选中的 .F90 软链接/复制到 objdir
7. 复制 Makefile 模板 + site 配置
   ↓ sites/<hostname>/Makefile.h → objdir/Makefile.h
8. 复制 parfile（如果 -parfile=foo）
   ↓ source/Simulation/SimulationMain/<算例>/foo.par → objdir/flash.par
9. 写 setup_call / setup_flags / setup_defines / setup_units
   ↓ 这些是 objdir 里的"setup 档案"，下次想重 setup 直接看
```

### 2.2 这条旅程里你（构造 setup 命令的人）的关键决策点

| 决策 | 影响 | 怎么决定 |
|---|---|---|
| 选哪个 SimulationMain | 决定基础物理集（Hydro-only vs LaserHEDP）| 看用户物理目标，参考 §3 决策树 |
| 维度（-1d/-2d/-3d）| 决定 NXB/NYB/NZB + N_DIM | 看物理对称性（球对称可 1D、轴对称可 2D、其他 3D）|
| 几何（+cartesian/+cylindrical/+spherical）| 决定坐标定义 + 方程形式 | 看物理（平面/轴对称/球对称）|
| 物理模块（+laser/+mgd/+uhd3t/+mtmmmt）| 决定 unit 集 | HEDP 主流四件套：laser+mgd+uhd3t+mtmmmt |
| Grid backend（+pm4dev / +ug）| 决定 Grid 实现 | 99% AMR 算例用 +pm4dev；PIC/FFT-Poisson 用 +ug |
| 物质列表（species=）| 决定 NSPECIES + 物质参数族 | 看靶设计（cham 单层 / cham,targ1,targ2 多层）|
| 辐射群数（mgd_meshgroups=）| 决定频率分辨率 + 内存 | 调试 6，生产 70 |
| block 大小（-nxb=16 -nyb=16）| 决定 AMR 性能 | 16 是主流；太小边界损耗大，太大加密粒度粗 |
| 输入 parfile（-parfile=）| 决定运行时配置 | 用户 parfile 在 source/.../<算例>/，setup 复制到 objdir/flash.par |

## 3. 选 SimulationMain 的决策树（L-011：讲为什么）

### 3.1 决策流程

```
用户想做什么？
│
├─ 入门 / 验证环境（最小 hydro）
│  └─→ Sedov（球面爆炸）
│       或 Sod（激波管）
│
├─ HEDP 激光打靶（主流）
│  ├─ 平面靶 cham+targ         → LaserSlab
│  ├─ 多层靶 cham,targ1,targ2.. → Sunliang_laser_CH（自定义）
│  ├─ 球壳 ICF 直接驱动         → LaserCylShell / CapLaserBAMPS
│  └─ 加热箔片                  → HeatedFoil
│
├─ MHD
│  └─→ magnetoHD / OrszagTang / BrioWu / Rotor
│
├─ 辐射流体（不带激光）
│  └─→ RadSlab / RadBlastWave / GrayDiffRadShock
│
├─ 重力 / 自重力
│  └─→ SedovSelfGravity / DustCollapse / CCSN
│
├─ 燃烧 / 火焰
│  └─→ FlameChannel / RTFlame / Flame1StageNoise
│
└─ 自定义（用户自己的算例）
   └─→ source/Simulation/SimulationMain/<MyProblem>
```

### 3.2 为什么 HEDP 用户首选 LaserSlab（L-011）

**LaserSlab 是 HEDP 标准**，原因有 5 个：

1. **物理完整**：含激光沉积（EnergyDeposition）+ MGD 多群扩散辐射 + 3T 三温 EOS + Heatexchange + 多物质——HEDP 所有核心物理一站式齐备
2. **几何合理**：2D 圆柱 (r, z)，平面靶轴对称——比 3D 省 CPU 一个量级，又保留物理本质
3. **数据齐全**：自带 IONMIX4 EOS 表（`.cn4`）+ 不透明度表（`.imx`）+ SESAME 表（`.ses`）——开箱即用
4. **parfile 模板齐全**：example.par、coldstart_*.par、3Din2D.par、restart.par——覆盖典型场景
5. **社区主流**：CLAUDE.md 写"LaserSlab 是 HEDP 推荐起点"——大多数 FLASH HEDP 用户从它上手

**替代方案的差异**：

| 算例 | 与 LaserSlab 的差异 | 何时选 |
|---|---|---|
| `CapLaserBAMPS` | 圆柱 cap 几何，不同激光入射方式 | 激光打 cap（柱腔内壁）|
| `LaserCylShell` | 球壳 + 多束激光直接驱动 | ICF 直接驱动研究 |
| `HeatedFoil` | 简化为加热薄箔（无激光路径追踪）| 验证 EOS+辐射，不验证激光 |
| `Sunliang_laser_CH` | 4 物质多层靶（用户自定义）| CH/CHBr 多层平面靶 |

### 3.3 怎么浏览所有算例确认选哪个

```bash
# 列所有算例
ls $FLASH_ROOT/source/Simulation/SimulationMain/

# 看某算例 Config 顶部注释（通常说明用途）
head -30 $FLASH_ROOT/source/Simulation/SimulationMain/<算例>/Config
```

## 4. setup 命令完整语法（按 L-011 讲为什么这么设计）

### 4.1 基本骨架

```
./setup <SimulationMain/problem> [选项] -auto -objdir=<PATH>
```

**第一个位置参数**：`SimulationMain/<算例名>`，可大小写不敏感前缀匹配（`sedov` / `Sedov` / `SEDOV` 都行）。
**`-auto`**：跳过交互式提示，用 Config 里的 DEFAULT。99% 场景必加。
**`-objdir=`**：构建目录。本机约定 `cases/<算例名>/`；默认是 `object/`。

### 4.2 选项五大类（按 L-013：聚焦主流，每类只详讲主流）

| 类别 | 代表选项 | 什么时候用 |
|---|---|---|
| **维度/几何** | `-2d` / `+cylindrical` | 决定模拟空间结构 |
| **物理求解器** | `+laser` / `+mgd` / `+uhd3t` / `+mtmmmt` | 决定包含哪些物理单元 |
| **物质列表** | `species=cham,targ` | 决定模拟哪些材料 |
| **数值参数** | `-nxb=16` / `mgd_meshgroups=6` | 决定网格/频率分辨率 |
| **流程控制** | `-auto` / `-objdir=` / `-parfile=` / `-debug` | 决定 setup 行为 |

**详细每个选项的含义、展开后是什么、典型值依据**——见 `option_reference.md`。
**所有 shortcut（`+laser`、`+mgd` 等）的展开表**——见 `shortcut_table.md`。

### 4.3 setup-variable 三种写法（为什么用 + / - 而不是 --foo）

FLASH 自创的语法，**故意避开** Python argparse 风格的 `--foo`：

| 写法 | 含义 | 例子 |
|---|---|---|
| `+foo` | 把 setup-variable `foo` 设为 True | `+laser` → `Laser=True` |
| `-foo` | 把 setup-variable `foo` 设为 False | `-laser` → `Laser=False`（少见）|
| `key=value` | 把 setup-variable `key` 设为 value（字符串/数字）| `species=cham,targ`、`mgd_meshgroups=6` |

**为什么不用 `--foo`**：
- setup.py 不用 argparse，自己解析，`+`/`-` 单字符开关更紧凑
- `+` 直观（加上），`-` 直观（去掉）
- 和 Python 库的 `--foo` 视觉上分开，避免混淆

### 4.4 +foo 的展开机制（shortcut 是怎么工作的）

`bin/setup_shortcuts.txt` 是一张"shortcut 展开表"，每行格式：
```
shortcut名:展开1:展开2:...
```

setup.py 看到 `+laser` 时，去这张表查 `laser`，找到：
```
laser:-unit=physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser:-without-unit=Particles
```

把它替换成 `--unit=physics/.../Laser --without-unit=Particles`。shortcut 可以**互相引用**（如 `usm3t` 引用 `+3t +usm`）。

**所以 `+laser` 不是简单地设 `Laser=True`**，它是"展开成一组 `--unit=` 和 `--without-unit=`"。这是 shortcut 的真正威力。

完整展开表见 `shortcut_table.md`。

## 5. setup 命令生成的 objdir 里有什么

setup 跑完后，objdir（如 `cases/LaserSlab/`）含：

### 5.1 setup 档案文件（最重要）

| 文件 | 内容 | 你什么时候看 |
|---|---|---|
| `setup_call` | **原始 setup 命令**（含 `+laser` 等未展开形式）+ Expanded Command line + Defined Setup Variables | 想知道"这次 setup 怎么跑的"——重 setup 时直接复制 |
| `setup_flags` | 展开后的 `--with-unit=...` 完整列表 | 想知道"`+laser` 实际拉了哪些 unit" |
| `setup_defines` | 编译宏 `-DNXB=16 -DFLASH_3T` 等 | 想知道"编译时 -D 了什么" |
| `setup_units` | 选中的所有 unit 完整路径列表 | 想知道"代码集有哪些" |
| `setup_vars` | setup-variables 当前值 | 调试 setup 行为 |

### 5.2 构建/运行文件

| 文件 | 内容 |
|---|---|
| `Makefile` + `Makefile.h` | 主 Makefile + site 配置（编译器/库路径）|
| `flash.par` | 运行时参数（`-parfile=` 复制来的）|
| `*.F90` | 软链接过来的源码（不是真文件，是 source/ 的链接）|

### 5.3 验证 setup 正确性的三条命令

```bash
# 1. setup 是否成功（看 setup_call 完整内容）
cat cases/<case>/setup_call

# 2. setup-variables 是否生效（看 ThreeT / Laser / Mgd 等是否 True）
grep -E "ThreeT|Laser|Mgd|Mtmmmt" cases/<case>/setup_call

# 3. 编译宏是否正确（FLASH_3T / NXB=16）
cat cases/<case>/setup_defines
```

## 6. 与其他 skill 的协作（L-006：明确归属）

### 6.1 与 flash-case-runner 的分工

| 场景 | 谁答 | 怎么协作 |
|---|---|---|
| "怎么 setup LaserSlab" | **setup-builder**（本 skill）| 详讲每选项为什么、可换什么 |
| "怎么跑 Sedov 完整流程" | case-runner | 端到端讲 setup → make → run → 看结果 |
| "setup 报错 Unit not found" | pitfall-finder | 报错诊断是 pitfall-finder 的活 |
| "LaserSlab 用什么 EOS" | flash-eos + flash-laser | 物理背景是知识层 skill 的活 |
| "ed_wavelength 参数" | flash-param-query | 字典型查询是 param-query 的活 |

### 6.2 典型协作链

```
用户："我想跑一个 2D 激光算例怎么 setup"
  ↓
flash-setup-builder 生成 setup 命令 + 解释每选项
  ↓
用户：跑 setup，遇到报错
  ↓
flash-pitfall-finder 诊断
  ↓
用户：setup 过了，要 make
  ↓
flash-case-runner（make_guide.md / run_guide.md）
```

## 7. 怎么用本 skill

接到 setup 构造请求时按下面流程：

1. **问关键决策**（如果用户没给）：维度、几何、物理模块、算例
2. **参考相似 case 的 setup_call**（在 `cases/*/setup_call` 找模板）
3. **输出**：
   - 完整 setup 命令（带 `\` 换行 + 注释）
   - **每个选项的"为什么用"**（L-011）
   - **预检查清单**（site 配置、libmpi 冲突、species 数量等）
4. **提醒坑**（如 libmpi.so.40 冲突——见 `pitfalls.md`）

详细行为协议见 SKILL.md §2。

## 8. 速查：3 条典型 setup 命令

```bash
# 1. 入门（最小 hydro，无 MPI 冲突）
./setup Sedov -auto -objdir=cases/Sedov

# 2. HEDP 主流（LaserSlab）
./setup LaserSlab -2d -auto +cylindrical \
  -nxb=16 -nyb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 \
  -objdir=cases/LaserSlab -parfile=example.par

# 3. 多物质 HEDP（Sunliang 自定义）
./setup Sunliang_laser_CH -2d -auto +pm4dev \
  -geometry=cylindrical -nxb=16 -nyb=16 \
  +mtmmmt +laser +mgd +uhd3t \
  species=cham,targ1,targ2,targ3 mgd_meshgroups=6 \
  -parfile=example_xubo.par \
  -objdir=cases/Sunliang_laser_CH
```

更完整的配方（5-8 个场景）见 `recipes.md`。
