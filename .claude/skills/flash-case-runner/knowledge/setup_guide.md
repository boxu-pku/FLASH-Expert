---
title: setup 阶段完整指南——命令语法 + 选 SimulationMain + site 配置
skill: flash-case-runner
category: setup
source_anchors:
  - bin/setup.py
  - bin/genFiles.py
  - bin/linkFiles.py
  - bin/unitCfg.py
  - source/Simulation/SimulationMain/Sedov/Config
  - source/Simulation/SimulationMain/LaserSlab/Config
  - cases/LaserSlab/setup_call
  - cases/LaserSlab/Makefile.h
---

# setup 阶段完整指南

> 本文讲 FLASH 算例生命周期的**第一阶段**：setup。
>
> 按 L-015，先讲 setup 的完整故事线，再讲细节。

## 1. setup 的完整故事线

### 1.1 setup 是什么

`./setup` 是 FLASH 项目的**配置脚本**——一条命令，把"算例所需的源码 + Makefile + parfile"组装到一个独立目录（objdir）。

`./setup` 实际上是 `bin/setup.py` 的薄 wrapper：
```bash
#!/bin/bash
exec /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/bin/setup.py "$@"
```

### 1.2 setup 的端到端旅程（L-015）

setup 命令从用户终端出发，经过这些步骤：

```
1. 用户终端
   ↓ ./setup LaserSlab -2d -auto ...
2. bin/setup.py:main()
   ↓ 解析命令行参数
3. unitCfg.py
   ↓ 读所有 unit 的 Config 文件（声明单元依赖关系）
4. 解析 setup-variables（+laser, species=, mgd_meshgroups=, ...）
   ↓ 根据 setup-variables 决定哪些 unit 被包含
5. genFiles.py
   ↓ 自动生成代码（Flash.h、UNK 声明、参数族、Multispecies 数据等）
   ↓ 这些生成的代码取决于 setup-variables（如 species=cham,targ 生成 SPECIES_VAR）
6. linkFiles.py
   ↓ 把选中的源码 .F90 软链接/拷贝到 objdir
7. 复制 Makefile 模板 + site 配置（Makefile.h）
   ↓ site 来自 sites/<hostname>/Makefile.h；本机无 sites/ares/，从已有 case 复制
8. 复制 parfile（如果指定了 -parfile=）
   ↓ cases/LaserSlab/flash.par
9. 写 setup_call、setup_flags、setup_defines、setup_units
   ↓ 这些文件记录"这次 setup 用了什么"
```

### 1.3 为什么需要 setup（不是直接 make）

FLASH 有**几百个单元**（Driver/Grid/Hydro/Eos/RadTrans/Diffuse/sourceTerms/Material/IO/...），每个单元又有多个变体（如 Hydro 有 split / unsplit / usm / mhd 八种变体）。

一个算例只用其中几十个单元。如果直接 `make`，编译器不知道要编译哪些。setup 负责"按需组装"——根据：
- 算例的 Config（声明 `REQUIRES physics/Hydro` 等）
- 用户的 setup-variables（`+laser` 决定要不要激光单元）
- 各单元的 DEFAULT 声明（多变体时默认选哪个）

挑出**精确需要的单元集**，生成 Makefile + 链接源码。

**为什么这样设计**：
- 不同物理问题代码集差异大（Hydro-only vs LaserHEDP），共用一个 Makefile 不现实
- 同一算例不同变体（+laser vs 不加），代码集也不同
- setup 把"选哪些单元"这件事**显式化**（每次 setup 记录在 setup_call/setup_flags）

## 2. setup 命令完整语法

### 2.1 基本格式

```
./setup <SimulationMain/problem> [选项] -auto -objdir=<PATH>
```

- **第一个位置参数** = `SimulationMain/<算例名>`，可以大小写不敏感前缀匹配（如 `sedov` 也行）
- 选项可任意顺序
- `-auto` 几乎必加（否则会进交互式菜单，本 skill 不展开交互式）
- `-objdir=` 几乎必加（默认 `object/`，但本机约定 `cases/<算例名>/`）

### 2.2 维度与几何选项（按 L-011 讲为什么）

| 选项 | 作用 | 为什么这么用 |
|---|---|---|
| `-1d` / `-2d` / `-3d` | 设维度，影响 NXB/NYB/NZB + N_DIM | 决定模拟维度 |
| `-nxb=N` / `-nyb=N` / `-nzb=N` | 设每个 block 在 x/y/z 方向的 cell 数 | Paramesh 的 block 是固定大小（编译期）|
| `-geometry=xxx` | 设几何类型 | 影响坐标定义和方程形式 |
| `+cartesian` / `+cylindrical` / `+spherical` | 几何快捷方式（等价 -geometry） | 同上 |

**几何选项**：
| 几何 | 坐标 | 适用场景 |
|---|---|---|
| `cartesian` (默认) | (x, y, z) | 平面问题、各向同性 |
| `cylindrical` | (r, z) 或 (r, θ, z) | 轴对称（如 LaserSlab 平面靶）|
| `spherical` | (r, θ, φ) 或 (r) | 球对称（如 Sedov 球面爆炸、ICF 内爆）|
| `-zr` / `-zt` | 圆柱的 (z, r) 或 (z, θ) 顺序 | 高级用法，少用 |

**block 大小说明**：
- Paramesh 的 AMR 用"块"（block）作为最小单元
- 每个 block 大小固定（`-nxb=16 -nyb=16` = 16×16 cells）
- AMR 加密时分裂块（一个块拆 4 个/8 个子块）
- 默认 8 cells 太小（边界损耗大），16 是主流；64+ 浪费（每块大但加密少）

### 2.3 物理/求解器选项（+foo / -foo）

`+foo` 把 setup-variable `foo` 设为 True，`-foo` 设为 False。**主要选项**：

| 选项 | 作用 | 何时用 |
|---|---|---|
| `+laser` | 包含激光沉积（EnergyDeposition）单元 | HEDP 激光打靶 |
| `+mgd` | 多群扩散辐射（RadTrans/RadTransMain/MGD）| HEDP（vs flux-limited diffusion）|
| `+uhd3t` | unsplit Hydro + 3T（Hydro_Unsplit）| HEDP（默认 Hydro 是 split，不适用 3T）|
| `+mtmmmt` | multi-temp EOS（multiTemp + Multitype）| 3T 算例（Tele/Tion/Trad 分开）|
| `+hdf5typeio` | HDF5 IO 后端（vs 默认 non-HDF5）| 后处理要 HDF5 时（HEDP 主流）|
| `+pm4dev` | Paramesh 4 dev Grid backend | AMR 算例（vs UG/Chombo/Samrai）|
| `+ug` | Uniform Grid backend | PIC、FFT-Poisson |
| `+usm` / `+usm3t` | unsplit MHD | MHD 算例 |
| `+spark` | 包含激光打火（Ignition）| 燃烧算例 |

**为什么用 +foo 而不是 -foo / --foo**：
- `+`/`-` 是 FLASH 自创的 setup-variable 开关语法
- `--foo` 容易和 Python argparse 风格混淆
- `+laser` 直观（加激光），`-laser` 直观（去激光）

### 2.4 键值选项（key=value）

| 选项 | 作用 | 典型值 |
|---|---|---|
| `species=name1,name2,...` | 设物质列表 | `species=cham,targ`（HEDP）/ `species=cham,targ1,targ2,targ3`（多物质）|
| `mgd_meshgroups=N` | MGD 辐射群数 | `mgd_meshgroups=6`（调试）/ `70`（生产）|
| `EPSILON=...` | 配置 setup 内部变量 | 极少用 |
| `maxBlocks=N` | 最大 block 数 | 大算例用 10000+ |

**`species=` 触发什么**（L-014：先解释）：
- species 是 setup 阶段的"物质列表"——告诉 FLASH 模拟哪些物质（cham=腔体、targ=靶、deuterium=氘等）
- setup 看到 `species=cham,targ` 后，调用 Multispecies/Config Python 自动生成：
  - 编译宏 `FLASH_MULTISPECIES` + `NSPECIES=2`
  - `Flash.h` 里 `CHAM_SPEC=1`、`TARG_SPEC=2`（unk 索引）
  - UNK 数组 `SPECIES_VAR`（每种物质的质量分数）
  - 参数族 `ms_*` / `eos_*EosType` / `op_*AbsorbKind` 等
- 详见 `flash-multispecies` skill

### 2.5 输出/控制选项

| 选项 | 作用 | 何时用 |
|---|---|---|
| `-auto` | 跳过交互式提示，用 Config DEFAULT | 几乎必加 |
| `-objdir=PATH` | 设构建目录 | 本机约定 `cases/<name>/` |
| `-parfile=NAME` | 复制 `<NAME>.par` 到 objdir 作 `flash.par` | 否则要手动 cp parfile |
| `-debug` | 用 debug 编译选项（`-O0 -ffpe-trap -fbounds-check`）| 调 NaN/越界 |
| `-verbose` / `-v` | 详细输出 | 调试 setup 过程 |
| `-no-server` | 不启动 setup.py 的 IPC 服务器（旧版机制）| 罕见 |
| `-clean` | setup 前清 objdir | 重 setup 时用 |

### 2.6 实证 setup 命令（从 setup_call 提取）

```bash
# Sedov（最小 Hydro，无 MPI 冲突涉及）
cat cases/Sedov/setup_call
# → ./setup Sedov -auto -objdir=cases/Sedov

# LaserSlab（HEDP 主流）
cat cases/LaserSlab/setup_call
# → ./setup LaserSlab -2d -auto +cylindrical \
#      -nxb=16 -nyb=16 +hdf5typeio \
#      species=cham,targ +mtmmmt +laser +uhd3t +mgd \
#      mgd_meshgroups=6 \
#      -objdir=cases/LaserSlab -parfile=example.par

# Sunliang（多物质自定义）
cat cases/Sunliang_laser_CH/setup_call
# → ./setup Sunliang_laser_CH -2d -auto +pm4dev \
#      -geometry=cylindrical -nxb=16 -nyb=16 \
#      +mtmmmt +laser +mgd +uhd3t \
#      species=cham,targ1,targ2,targ3 mgd_meshgroups=6 \
#      -parfile=example_xubo.par \
#      -objdir=cases/Sunliang_laser_CH
```

**注意**：LaserSlab 用 `+cylindrical`，Sunliang 用 `-geometry=cylindrical`——两者**完全等价**，是 setup 语法的两种表达方式。

### 2.7 setup 输出产物（objdir 里有什么）

setup 完成后，objdir 含：

| 文件 | 内容 | 用途 |
|---|---|---|
| `Makefile` | 主 Makefile（编译规则）| make 用 |
| `Makefile.h` | site 配置（编译器/库路径）| Makefile include |
| `setup_call` | **原始 setup 命令**（含展开前的）| 重 setup / debug 用 ⭐ |
| `setup_flags` | 展开后的 setup 选项 | 看 setup 实际用了什么 |
| `setup_defines` | 编译宏（F90 preprocessor defines）| 如 `-DFLASH_3T`、`-DNXB=16` |
| `setup_units` | 选中的单元列表 | 看代码集 |
| `setup_vars` | setup-variables 当前值 | 调试用 |
| `setup_libraries` | 链接的外部库（mpi/hdf5/hypre）| Makefile 用 |
| `setup_datafiles` | 算例需要的 datafile（EOS/opacity 表）| 链接/拷贝到 objdir |
| `setup_params` | runtime parameter 列表（每个 unit 声明的 PARAMETER）| 用于生成 parfile 默认值 |
| `flash.par` | parfile（如指定 -parfile=）| 运行时读 |
| `*.F90` | 链接过来的源码 | 编译 |
| `Simulation_units` 和其他 build_*.py | setup 工具链生成的 Python 脚本 | 内部用 |

**最重要的三个文件**：
- `setup_call` — 想知道"这次 setup 怎么跑的"
- `setup_flags` — 想知道"setup 实际选了哪些选项"
- `setup_defines` — 想知道"编译期 -D 了什么宏"

## 3. 怎么选 SimulationMain（决策树）

### 3.1 决策流程

按"用户的物理目标"选：

```
用户想做什么？
│
├─ 纯 Hydro 测试 / 验证环境
│  └─→ Sedov（最简单）
│
├─ HEDP（激光打靶）
│  ├─ 标准平面靶（cham + targ）→ LaserSlab
│  ├─ 多物质平面靶（多 targ）→ Sunliang_laser_CH（参考）
│  ├─ 球形靶（ICF 直接驱动）→ LaserCylShell（如有）/ CapLaserBAMPS
│  └─ 特殊物理 → 自定义算例
│
├─ MHD
│  └─→ magnetoHD / BrioWu / Rotor / OrszagTang
│
├─ 辐射输运验证
│  └─→ RadBlastWave / RotatingBeam / SuOlson
│
├─ 等离子体物理（PIC，FLASH 较少）
│  └─→ （需特殊 backend，少见）
│
└─ 其他（核燃烧 / 重力 / 等等）
   └─→ 看 source/Simulation/SimulationMain/ 全列表
```

### 3.2 HEDP 选 LaserSlab 的理由

**为什么 LaserSlab 是 HEDP 标准**（L-011 讲为什么）：

1. **物理完整**：含激光 + MGD + 3T + Heatexchange + 多物质——HEDP 所有核心物理
2. **几何合理**：2D 圆柱 (r, z)，平面靶轴对称，省 CPU
3. **数据全**：自带 EOS 表（`.cn4`）+ 不透明度表（`.imx`）+ SESAME 表
4. **parfile 模板齐全**：example.par、coldstart_*.par、3Din2D.par 等
5. **CLAUDE.md 说"用户从 LaserSlab 上手"**——社区主流

**替代方案**：
- `CapLaserBAMPS` — 用激光打 cap（不同几何）
- `LaserCylShell` — 球壳内爆（ICF 直接驱动）
- 自定义算例（如 Sunliang_laser_CH）

### 3.3 怎么浏览所有算例

```bash
# 列所有算例
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/

# 看某算例的 Config（第一段注释通常说明用途）
cat source/Simulation/SimulationMain/<算例>/Config | head -30
```

### 3.4 怎么选 LaserSlab 的变体（species）

LaserSlab Config 注释明确：**用户必须用 setup 变量指定 species**。常见组合：

| species 组合 | 用途 |
|---|---|
| `species=cham,targ` | 标准（腔体 + 靶）|
| `species=cham,targ1,targ2,targ3` | 多层靶（如 CH + CHBr + CH）|
| `species=helium,targ` | 氦腔体（不同 cham 材料）|

**Sunliang_laser_CH 用 4 个 species**（cham, targ1, targ2, targ3）——这是用户实际研究的"CH/CHBr 多层靶"配置。

## 4. site 配置（本机 ares 特殊）

### 4.1 site 是什么（L-014）

**site** = 一台机器的编译器/库路径配置，存为 `Makefile.h`。FLASH 编译时需要知道：
- 用哪个 Fortran 编译器（gfortran / ifort）
- MPI 库在哪（mpich / openmpi / slurm）
- HDF5 库在哪
- HYPRE 库在哪（如用 MGD）
- 编译选项（-O2 / -fopenmp 等）

**为什么需要 site**：不同机器配置差异大；同一份 FLASH 源码要能在不同机器编译。

### 4.2 正常 FLASH 的 site 机制

```
sites/
├── ares/Makefile.h       # 本机（如存在）
├── theta/Makefile.h      # ALCF Theta
├── summit/Makefile.h     # OLCF Summit
└── ...
```

`./setup` 时，根据 `$(hostname)` 找 `sites/<hostname>/Makefile.h`，复制到 objdir 作 Makefile.h。

### 4.3 本机 ares 的特殊性

**本机没有 `sites/ares/`**：
```bash
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/sites/
# （可能不存在或不含 ares）
```

**site 配置已 baked in 各 `cases/<case>/Makefile.h`**：
```bash
cat cases/LaserSlab/Makefile.h | head -20
# → MPI_PATH   = /home/ubuntu/local/flash/myFLASH4.8/mpich
# → HDF5_PATH  = /home/ubuntu/local/flash/myFLASH4.8/hdf5
# → HYPRE_PATH = /home/ubuntu/local/flash/myFLASH4.8/hypre
# → FCOMP   = ${MPI_PATH}/bin/mpif90
# → ...
```

**为什么这样**：用户从其他机器拷贝 cases 过来时，Makefile.h 跟着过来。新 setup 时如果 `sites/ares/` 不存在，setup.py 会找默认模板（可能失败）或用 `cases/` 里已有的。

### 4.4 新 setup 时怎么处理 site

**场景 A：新建一个 case（setup 新算例）**

如果 `sites/ares/` 不存在，setup.py 可能报错 `site not found`。**解决方案**（按优先级）：

1. **创建 `sites/ares/Makefile.h`**（一劳永逸）：
   ```bash
   mkdir -p sites/ares
   cp cases/LaserSlab/Makefile.h sites/ares/Makefile.h
   # 以后所有 setup 都自动用这个 site
   ```

2. **从已有 case 复制**（每次手动）：
   ```bash
   ./setup <NewCase> -auto -objdir=cases/<NewCase>
   # 失败后：
   cp cases/LaserSlab/Makefile.h cases/<NewCase>/Makefile.h
   # 重 setup
   ./setup <NewCase> -auto -objdir=cases/<NewCase>
   ```

3. **使用 setup 的 -no-server 模式**（高级，本 skill 不展开）

**场景 B：重新 setup 一个已有 case**（如改 setup-variables 重 setup）

Makefile.h 已存在 objdir 里，setup 一般会保留。但保险起见：
```bash
# 备份 Makefile.h
cp cases/<case>/Makefile.h /tmp/Makefile.h.bak
# 重 setup
./setup <case> -auto -objdir=cases/<case> [新选项]
# 如果 Makefile.h 被覆盖，恢复
cp /tmp/Makefile.h.bak cases/<case>/Makefile.h
```

### 4.5 Makefile.h 关键字段速查

| 字段 | 含义 | 本机典型值 |
|---|---|---|
| `MPI_PATH` | MPI 库根路径 | `/home/ubuntu/local/flash/myFLASH4.8/mpich` |
| `HDF5_PATH` | HDF5 库根路径 | `/home/ubuntu/local/flash/myFLASH4.8/hdf5` |
| `HYPRE_PATH` | HYPRE 库根路径（MGD 用）| `/home/ubuntu/local/flash/myFLASH4.8/hypre` |
| `FCOMP` | Fortran 编译器 | `${MPI_PATH}/bin/mpif90` |
| `CCOMP` | C 编译器 | `${MPI_PATH}/bin/mpicc` |
| `LINK` | 链接器（通常 = FCOMP）| `${MPI_PATH}/bin/mpif90` |
| `FFLAGS_OPT` | 优化编译选项 | `-O3 -fdefault-real-8 ...` |
| `FFLAGS_DEBUG` | 调试编译选项（`-debug` 时用）| `-O0 -g -ffpe-trap=... -fbounds-check` |
| `OPENMP` | 是否 OpenMP（编译宏）| `-fopenmp` 或留空 |

## 5. setup 阶段常见错误（按 L-012 引导贴现场）

### 5.1 SetupError: Unit not found

**完整错误**：
```
SetupError: Could not find Unit 'X' requested by 'Y'
```

**贴什么现场**（按 L-012）：
```bash
# 1. 完整错误信息
./setup <算例> [选项] -auto -objdir=<PATH> 2>&1 | tee setup_error.log

# 2. setup-variables 你指定的
cat setup_error.log | grep "Setup Variables\|Defined Setup"
```

**最可能原因**：

| 原因 | 怎么验证 | 怎么修 |
|---|---|---|
| 单元名拼错 | `find source/ -name Config \| xargs grep -l "REQUIRES"` 找正确名 | 改 setup 命令 |
| setup-variable 没开（如要 laser 但没 +laser）| 看 setup_flags | 加 `+laser` |
| Config 路径错（少见）| 看 `source/Simulation/SimulationMain/<算例>/Config` | 改 Config |

**详细**：见 `agent/pitfalls/setup-unit-not-found.md`。

### 5.2 site not found

**完整错误**：
```
SetupError: Site '<hostname>' not found in sites/ directory
```

**贴什么现场**：
```bash
echo "Hostname: $(hostname)"
ls sites/ 2>/dev/null || echo "sites/ 不存在"
```

**修复**：见本文 §4.4——从 cases/LaserSlab 复制 Makefile.h 到 `sites/<hostname>/`。

**详细**：见 `agent/pitfalls/site-not-found.md`。

### 5.3 species 数量错

**错误**：
```
SetupError: Number of species in 'species=' variable does not match ...
```

**原因**：算例 Config 期望 N 种物质，但 species= 给的数量不对。

**例**：LaserSlab 期望 2 种（cham + targ），给 `species=cham,targ1,targ2,targ3` 会失败（如果 Config 没扩展）。

**修**：看 Config 里 `USESETUPVARS` 段，确认算例期望几个 species。Sunliang_laser_CH 是修改过 Config 支持多 targ 的版本。

### 5.4 parfile 找不到

**错误**：
```
SetupError: parfile 'X.par' not found
```

**修复**：确认 `<X>.par` 在 `source/Simulation/SimulationMain/<算例>/` 下。`-parfile=example_xubo` 找 `example_xubo.par`。

### 5.5 setup 后看 setup_flags 不对

**症状**：setup 完了，但 `setup_flags` 里没看到期望的 `-DFLASH_3T` 等。

**原因**：setup-variables 没生效（可能 setup 顺序问题、或变量名错）。

**贴什么现场**：
```bash
cat cases/<case>/setup_flags
cat cases/<case>/setup_vars  # 看 setup-variables 实际值
```

**修**：对照算例 Config 的 `USESETUPVARS` 段，确认变量名。

## 6. 新建自定义算例（简版流程）

参见 `CLAUDE.md` §"Adding a new problem (short version)"。

```bash
# 1. 拷贝模板
cp -r source/Simulation/SimulationMain/Sedov source/Simulation/SimulationMain/<MyProblem>
# HEDP 算例应该 cp LaserSlab

# 2. 改 Config（声明 REQUIRES / REQUESTS / PARAMETER）
vi source/Simulation/SimulationMain/<MyProblem>/Config

# 3. 改初始化代码
vi source/Simulation/SimulationMain/<MyProblem>/Simulation_initBlock.F90
vi source/Simulation/SimulationMain/<MyProblem>/Simulation_init.F90

# 4. 加 parfile 模板
cp source/Simulation/SimulationMain/LaserSlab/flash.par \
   source/Simulation/SimulationMain/<MyProblem>/example.par

# 5. setup + make + run（run 在 01-data/ 里，硬约束）
./setup <MyProblem> [选项] -auto -objdir=cases/<MyProblem>
cd cases/<MyProblem> && make -j4
mkdir -p 01-data && cd 01-data && mpirun -np 2 ../flash4 -par_file ../flash.par
```

**详细**：见 `flash-setup-builder` skill（构造辅助）+ CLAUDE.md（项目根的"Adding a new problem"）。

## 7. 速查：setup 命令模板

```bash
# 入门（Sedov）
./setup Sedov -auto -objdir=cases/Sedov

# HEDP 主流（LaserSlab）
./setup LaserSlab -2d -auto +cylindrical \
  -nxb=16 -nyb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 \
  -objdir=cases/LaserSlab -parfile=example.par

# 多物质 HEDP（Sunliang）
./setup Sunliang_laser_CH -2d -auto +pm4dev \
  -geometry=cylindrical -nxb=16 -nyb=16 \
  +mtmmmt +laser +mgd +uhd3t \
  species=cham,targ1,targ2,targ3 mgd_meshgroups=6 \
  -parfile=example_xubo.par \
  -objdir=cases/Sunliang_laser_CH

# Debug 模式（调 NaN/越界）
./setup LaserSlab -2d -auto -debug +cylindrical ... -objdir=cases/LaserSlab_debug
```
