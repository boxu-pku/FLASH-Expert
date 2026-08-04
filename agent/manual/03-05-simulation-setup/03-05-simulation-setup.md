---
title: 算例设置、FLASH 架构与 setup 配置脚本
skill: flash-setup-system
category: overview
source_anchors:
  - bin/setup.py:39-90
  - bin/parseCmd.py:1-50
  - bin/unitCfg.py:1200-1268
  - bin/genFiles.py:1-50
  - source/Simulation/SimulationMain/Sod/Config:4-15
  - source/Simulation/SimulationMain/Sedov/Config:5-7
  - cases/Sedov/Makefile.h:1-50
  - source/Simulation/SimulationMain/Sod/Simulation_initBlock.F90:1-30
manual_ref: "FLASH 4.8 User Guide §3 (Setting Up New Problems) pp.27-39, §4 (FLASH Architecture) pp.41-47, §5 (setup Script) pp.49-87"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - setup
  - Config
  - unit-architecture
  - inheritance
  - Makefile.h
  - unit-dependency
  - GenLines
  - flash.par
  - stub
  - subunits
---

# 算例设置、FLASH 架构与 setup 配置脚本（§3-5）

> **TL;DR**：§3-5 构成 FLASH 的自定义算例开发三部曲：§3 教用户创建新算例（Config + Simulation_init*.F90 文件），§4 解释 FLASH 单元架构（继承、API、stub、subunit），§5 是 setup 脚本完整参考（命令行参数、Config 文件语法、Makefile.h 创建、生成文件清单）。

## 1. 三章内容概览

| 章 | 标题 | 印刷页 | PDF页 | 核心主题 |
|---|---|---|---|---|
| §3 | Setting Up New Problems | 27-39 | 53-65 | 创建新算例的 8 步模板（Sod 例） |
| §4 | Overview of FLASH Architecture | 41-47 | 67-73 | 单元概念、继承层级、API/stub/subunit |
| §5 | The FLASH Configuration Script (setup) | 49-87 | 75-113 | setup 完整参考（参数、Config 语法、生成文件） |

§4 是联系 §3（实操）和 §5（reference）的桥梁：理解 FLASH 的单元架构才能正确编写 Config 文件和使用 setup 参数。

## 2. §3 设置新算例

### 2.1 创建算例目录

在 `source/Simulation/SimulationMain/` 下新建目录：

```bash
mkdir source/Simulation/SimulationMain/MyProblem
```

典型算例包含的文件：

| 文件 | 必需 | 用途 |
|---|---|---|
| `Config` | 是 | 声明依赖、运行时参数、变量 |
| `Makefile` | 是 | 算例单元 Makefile 片段 |
| `Simulation_data.F90` | 是 | 数据模块，存储问题参数 |
| `Simulation_init.F90` | 是 | 读取运行时参数，初始化 |
| `Simulation_initBlock.F90` | 是 | 设置单个 block 的初始条件 |
| `Simulation_initSpecies.F90` | 否 | 多物种时初始化物种属性 |
| `flash.par` | 推荐 | 运行时参数文件模板 |

**源码验证**：`source/Simulation/SimulationMain/Sod/` 包含所有上述文件，其中 `Simulation_initBlock.F90:1-30` 演示了标准的 block 循环模式：`Grid_getBlkIndexLimits` → `Grid_getCellCoords` → 遍历 `blkLimits` 循环。

### 2.2 Config 文件（§3.1）

Config 文件是算例的"蓝图"：
- **功能 1**：声明所需单元（`REQUIRES`/`REQUESTS`）
- **功能 2**：注册运行时参数（`PARAMETER`）
- **功能 3**：声明网格变量（`VARIABLE`）

Sod 例的 Config（简化）：

```fortran
REQUIRES Driver
REQUIRES physics/Hydro
REQUIRES physics/Eos/EosMain/Gamma

PARAMETER sim_rhoLeft   REAL   1.      [0 to ]
PARAMETER sim_rhoRight  REAL   0.125   [0 to ]
PARAMETER sim_pLeft     REAL   1.      [0 to ]
PARAMETER sim_pRight    REAL   0.1     [0 to ]
```

参数命名约定以 `sim_` 前缀标识算例专属参数，避免与其他单元冲突。取值范围用方括号 `[min to max]` 指定。

### 2.3 Simulation_init*.F90 文件（§3.3-3.5）

- `Simulation_data.F90`：Fortran module，含 `sim_*` 变量声明和 `save` 属性。使用 `Simulation_data` module 可在 `Simulation_init.F90`、`Simulation_initBlock.F90` 和 `Simulation_freeUserArrays.F90` 之间共享数据。
- `Simulation_init.F90`：调用 `RuntimeParameters_get` 读取 flash.par 中的 `sim_*` 参数值备用。
- `Simulation_initBlock.F90`：核心初始化逻辑。标准模式：
  1. `Grid_getBlkIndexLimits(blockId, blkLimits, blkLimitsGC)` 获取 block 边界
  2. `Grid_getCellCoords(...)` 获取坐标数组
  3. 三层嵌套循环（k, j, i）计算每个 cell 的初始变量值
  4. `Grid_putPl...d` 存入数据

### 2.4 覆盖 FLASH 默认函数

在 `SimulationMain/MyProblem/` 下放置与核心 FLASH 文件同名的 `.F90` 文件即可覆盖默认实现。例如自定义 `Grid_markRefineDerefine.F90` 实现特定细化判据，搭配 `LINKIF` 指令选择适用网格后端。

## 3. §4 FLASH 架构

### 3.1 单元分类

FLASH 代码组织为"单元"（unit），按 5 类功能划分：

| 类别 | 示例 | 路径前缀 |
|---|---|---|
| Infrastructure（基础设施） | Grid, IO, RuntimeParameters | `source/` |
| Physics（物理） | Hydro, Eos, Gravity, Burn | `source/physics/` |
| Monitor（监控） | Logfile, Profiler, Timers | `source/monitors/` |
| Driver（驱动） | Driver_evolveFlash | `source/Driver/` |
| Simulation（算例） | Simulation_main | `source/Simulation/` |

**源码验证**：`source/physics/` 下按领域分组，`source/Grid/` 为单独顶级目录，体现了命名规则与目录组织规则。

### 3.2 继承层级

FLASH 利用 Unix 目录结构而非 OOP 实现继承：

- **子目录继承**：子目录源代码 + Config + Makefile 累积继承父目录
- **文件名覆盖**：子目录与父目录同名文件 → 子目录版本优先
- **命名规则**：大写开头 = 单元目录（命名空间），小写开头 = 组织目录（分类用）
  - 例：`source/physics/Hydro/` — `physics` 组织目录，`Hydro` 单元目录
  - 例：`source/Grid/` — `Grid` 既是组织目录也是单元目录

### 3.3 API、Stub 与 Subunit

| 概念 | 描述 | 源码位置 |
|---|---|---|
| API（Public Interface） | 单元对外暴露的公共过程和函数 | `Unit_interface.F90`（如 `Grid_interface.F90`） |
| Stub（空实现） | 等同函数原型，做最小操作（如返回 0） | 单元顶级目录（如 `Grid/Grid_getListOfBlocks stub`） |
| Subunit（子单元） | 实现变体，按 `DEFAULT` 选择 | `UnitMain/<variant>/` （如 `Hydro/HydroMain/unsplit/`） |

Stub 的作用：允许未包含某单元的仿真安全编译。例如 Uniform Grid 不需要 `Grid_updateRefinement`，但其在 `Driver_evolveFlash` 中被调用——存在 `Grid_updateRefinement` 的 stub 使得 Driver 无需条件编译。

### 3.4 Unit Test Framework（§4.3）

单元测试框架分为两部分：

```
# 算例专用 Driver_evolveFlash + 初始条件
source/Simulation/SimulationMain/unitTest/<UnitName>/

# 被测试单元的内部数据访问代码
source/<unit-path>/unitTest/
```

这种拆分在满足算例封装（Simulation 目录可覆盖任意 FLASH 函数）和内部数据访问需求间取得平衡。

## 4. §5 setup 配置脚本参考

### 4.1 核心工作流

```
setup 入口（`./setup Sedov -auto`）
  └→ setup shell 脚本（根目录）
       └→ exec bin/setup.py "$@"
            ├── parseCmd.parse()        ← 解析命令行
            ├── GVars.init(flashHome)   ← 确定根目录
            ├── determineMachine()      ← 匹配 sites/<hostname>/Makefile.h
            ├── unitList.populate()     ← 解析 Config 依赖图
            ├── unitList.adjustOpts()   ← 命令选项基于单元组合调整
            └── genFiles / linkFiles    ← 生成 Makefile/Flash.h/链接源文件
```

**源码验证**：
- `bin/setup.py:39-90`（main 函数核心逻辑）
- `bin/parseCmd.py:1-50`（命令行参数定义，`WITH_ARGS` 和 `WITHOUT_ARGS` 列表）
- `bin/unitCfg.py:1200-1268`（`varInfo` / `configInfo` 聚合逻辑）

### 4.2 命令行参数表

setup 参数分 3 类：

**Setup Options**（`-` 前缀）：

| 参数 | 作用 |
|---|---|
| `-auto` | 自动生成 Units 文件（几乎必用） |
| `-2d` / `-3d` / `-1d` | 维度选择（默认 2D） |
| `-debug` / `-opt` / `-test` | 编译标志集切换 |
| `-nxb=N` / `-nyb=N` / `-nzb=N` | block 每边 cell 数（默认 8） |
| `-maxblocks=N` | 每 processor 最大 block 数 |
| `-objdir=<dir>` | 输出目录（默认 `object/`） |
| `-site=<site>` / `-ostype=<ostype>` | 覆盖机器检测 |
| `-with-unit=<path>` / `-unit=<path>` | 添加指定单元 |
| `-without-unit=<path>` | 排除指定单元 |
| `-verbose=<level>` | 详细程度（`ERROR`,`IMPINFO`,`WARN`,`INFO`,`DEBUG`） |
| `-noclobber` | 重用已编译代码 |
| `-defines=<defines>` | 额外 `-D` 预处理器定义 |
| `-gridinterpolation=<method>` | 网格插值方法 |
| `-geometry=<type>` | 几何类型（`cartesian`/`cylindrical`/`spherical`/`polar`） |

**Setup Variables**（`key=value` 形式）：

由各单元在 Config 文件中用 `USESETUPVARS` 声明。例如：
- `species=cham,targ`（定义物种列表）
- `mgd_meshgroups=6`（辐射群组数）
- `threadBlockList=True`（启用 OpenMP block 级并行）

**Setup Shortcuts**（`+` 前缀）：

预定义的宏，会自动展开为一组 setup options 和 setup variables。例如：
- `+laser` → 展开为 `useEnergyDeposition=True` 等
- `+pm4dev` → 选择 PARAMESH 4-dev Grid 后端
- `+uhd3t` → 展开为 `+unsplitHydro3T`
- `+hdf5typeio` → 选择 HDF5 类型化 IO

### 4.3 机器配置与 Makefile.h

setup 通过 `sites/<hostname>/Makefile.h` 获取本机编译器和库路径：

```makefile
# 本机配置示例（cases/Sedov/Makefile.h:1-50）
MPI_PATH   = /home/ubuntu/local/flash/myFLASH4.8/mpich
HDF5_PATH  = /home/ubuntu/local/flash/myFLASH4.8/hdf5
HYPRE_PATH = /home/ubuntu/local/flash/myFLASH4.8/hypre
FCOMP   = ${MPI_PATH}/bin/mpif90
CCOMP   = ${MPI_PATH}/bin/mpicc
OPENMP = -fopenmp
```

创建步骤（§5.6）：
1. `mkdir sites/$(hostname)`
2. 从 `os/$(uname)/Makefile.h` 复制模板
3. 运行 `bin/suggestMakefile.sh` 扫描库位置
4. 编辑路径指向本机 MPI/HDF5/HYPRE 位置

### 4.4 Config 文件语法

Config 文件有两种模式：

**静态模式**（默认，最常用）：纯文本，指令逐行解析

**Python 模式**（`##python:genLines` 首行触发）：整个文件作为 Python 代码执行，须定义 `def genLines(setupvars)` 函数返回指令字符串的可迭代对象。用于动态生成参数（如循环注册 `ed_wavelength_1`...`ed_wavelength_N`）。

静态模式支持的全部指令：

| 指令 | 用途 | 示例 |
|---|---|---|
| `REQUIRES path [OR path]` | 强制依赖其他单元 | `REQUIRES physics/Eos OR TREM` |
| `REQUESTS path` | 请求单元（可被 `-without-unit` 撤销） | `REQUESTS IO/IOMain/hdf5` |
| `SUGGEST path` | 建议单元（仅警告） | `SUGGEST monitors/Logfile` |
| `PARAMETER name TYPE default [range]` | 运行时参数 | `PARAMETER gamma REAL 1.4 [0.0 to ]` |
| `PARAMETER ... CONSTANT` | 编译时常量参数 | `PARAMETER nxb INTEGER CONSTANT 16` |
| `D name comment` | 参数文档注释 | `D gamma Ratio of specific heats` |
| `VARIABLE name [TYPE:] [EOSMAP:]` | 网格变量 | `VARIABLE eint TYPE: PER_MASS EOSMAP: EINT` |
| `MASS_SCALAR name [RENORM:]` | 随流标量 | `MASS_SCALAR sele EOSMAP: SELE` |
| `FACEVAR name` | 面心变量 | `FACEVAR magx` |
| `FLUX name` | 通量变量 | `FLUX advectiveFlux` |
| `SPECIES name [TO N]` | 物种定义 | `SPECIES cham TO 10` |
| `PARTICLETYPE name ...` | 粒子类型 | `PARTICLETYPE passive INITMETHOD lattice ...` |
| `PARTICLEPROP name type` | 粒子属性 | `PARTICLEPROP dens REAL` |
| `DATAFILES wildcard` | 数据文件 | `DATAFILES *.dat` |
| `LINKIF filename unit` | 条件链接 | `LINKIF Grid_markRefineDerefine.F90 Grid/.../paramesh` |
| `PPDEFINE sym` | 预处理器定义 | `PPDEFINE FLASH_GRID_UG` |
| `USESETUPVARS vars` | 声明使用 setup 变量 | `USESETUPVARS withParticles` |
| `DEFAULT sub-unit` | 默认子单元 | `DEFAULT Gamma` |
| `EXCLUSIVE list` | 互斥实现 | `EXCLUSIVE *` |
| `CONFLICTS path` | 冲突声明 | `CONFLICTS physics/Eos/EosMain/Helmholtz` |
| `GUARDCELLS N` | 保护层数 | `GUARDCELLS 4` |
| `KERNEL [subdir]` | 递归包含子目录 | `KERNEL` |
| `LIBRARY name` | 外部库 | `LIBRARY HDF5` |
| `CHILDORDER child1 child2` | 覆盖顺序 | `CHILDORDER unsplit split` |
| `IF/ELSEIF/ELSE/ENDIF` | 条件编译 | `IF withParticles` |
| `SETUPERROR msg` | 强制 setup 错误 | `SETUPERROR "Requires 3D"` |
| `NONREP type name localmax globalparam ioformat` | 非复制网格变量 | `NONREP MASS_SCALAR A 4 numA a???` |

### 4.5 生成的文件

setup 运行后在 object 目录生成 3 类文件：

**信息文件**（`setup_*` 前缀）：

| 文件名 | 内容 |
|---|---|
| `setup_call` | setup 原始命令 + 展开后的命令 |
| `setup_libraries` | 链接的库列表及参数 |
| `setup_units` | 包含的所有单元列表 |
| `setup_defines` | 预处理器符号（给编译器的 `-D`） |
| `setup_flags` | 编译器和链接器标志 |
| `setup_params` | 运行时参数完整列表（含注释） |
| `setup_vars` | 变量/通量/物种/粒子属性列表 |

**生成的代码**：

| 文件 | 功能 |
|---|---|
| `Flash.h` | 预处理器宏（变量索引、常量定义） |
| `setup_buildstamp.F90` | 构建时间戳和系统信息 |
| `setup_getFlashUnits.F90` | 返回单元列表 |
| `Simulation_mapIntToStr.F90` | 索引 → 字符串映射 |
| `Simulation_mapStrToInt.F90` | 字符串 → 索引映射 |

**Makefile**：主 Makefile + 每个单元的子 Makefile（`Makefile.UnitName`）。单元 Makefile 由该单元层级所有 `Makefile` 文件串联而成。

## 5. 已知陷阱与手册差异

### 5.1 PDF 页码偏移

§3 印刷页 27-39 ≈ PDF 53-65；§4 印刷页 41-47 ≈ PDF 67-73；§5 印刷页 49-87 ≈ PDF 75-113。handoff 给出的 PDF 60-100 只覆盖到 §5 的约 2/3（不完整）。

### 5.2 `CONSTANT` 参数的行为

手册 §5.5.2 说 "若用户试图通过 flash.par 设置 CONSTANT 参数将报错"（`will cause an error`），但源码 `rpUtils.py` 中对此的处理是非致命警告。用户应理解为 CONSTANT 参数在运行时不可变，但并非所有版本都会强制报错。

### 5.3 `-noclobber` 与衍生类型 IO

手册 §1.3 Known Issues 指出 `-noclobber` 与 `+hdf5typeIO` 或 `+pnetTypeIO` 不兼容：不会强制重建所需源文件。用户在切换 IO 后端时需重新 setup。

### 5.4 Units 文件的 FLASH2→FLASH4 迁移

FLASH2 的 Units 文件在 FLASH 根目录；FLASH4 改为 `object/` 下。自动生成的 Units 文件允许用户手动编辑后重跑 setup（不带 `-auto`）以覆盖默认单元选择。

### 5.5 OpenMP 线程安全

手册 §5.8 描述混合 MPI+OpenMP 模式需要 `MPI_THREAD_SERIALIZED` 级别，但默认 MPI 安装常不提供（尤其是 OpenMPI < 1.5）。编译前需确认 MPI 支持级别，否则给出 unsafe 警告。

## 6. 典型工作流

```bash
# 1. 创建新算例
mkdir -p source/Simulation/SimulationMain/MyProblem
# 从已有算例复制模板文件，修改 Config / init / initBlock

# 2. setup（初次用 -auto 生成 Units 文件）
./setup MyProblem -2d -auto -nxb=16 -nyb=16 -objdir=cases/MyProblem

# 3. 可选：编辑 Units 文件指定特定实现
# vi cases/MyProblem/Units -> 加 INCLUDE physics/Eos/EosMain/Helmholtz

# 4. 重新 setup（不带 -auto 以使用已编辑的 Units）
./setup MyProblem -2d -nxb=16 -nyb=16 -objdir=cases/MyProblem

# 5. 编译 & 运行
cd cases/MyProblem && make -j4 && ./flash4 -parfile flash.par
```

## 7. 延伸阅读

- §2 Quick Start：完整三步实战（前一篇 entry）
- §6 Mesh Data Structures：Flash.h 变量索引详解
- §9 IO Output：plotfile/checkpoint 格式
- §43 FLASH Multithreaded Application：混合 MPI+OpenMP 细节
- `bin/README.shortcuts`：内置 shortcut 说明
- `source/Simulation/SimulationMain/Sod/`：最简洁的参考算例

## 8. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft，基于 FLASH 4.8 UG §3-5 pp.27-87 + 源码对照 v4.8） | opencode-ai |
