---
title: FLASH 快速入门（Quick Start）
skill: flash-setup-system
category: overview
source_anchors:
  - setup:1-12
  - bin/setup.py:39-90
  - source/Simulation/SimulationMain/Sedov/Config:5-7
  - source/Simulation/SimulationMain/Sod/Config:4-15
  - cases/Sedov/Makefile.h:1-50
  - source/Simulation/SimulationMain/Sedov/flash.par:1-25
  - cases/Sedov/flash.par:1-25
manual_ref: "FLASH 4.8 User Guide §2 (Quick Start) pp.17-25, PDF pp.43-52"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - setup
  - build
  - flash.par
  - Makefile.h
  - Docker
  - quick-start
  - Sedov
---

# FLASH 快速入门（Quick Start §2）

> **TL;DR**：§2 是用户接触 FLASH 的第一章。通过 Sedov 爆炸算例演示完整工作流：`./setup Sedov -auto` → `cd object && make` → `mpirun -np N flash4 -parfile flash.par` → IDL/VisIt 可视化输出。系统要求含 MPI、HDF5、Python 2.2+、gmake；章节还介绍了 Docker 镜像替代方案和 flash.par 基本格式。

## 1. 章节定位

§2 是 Part I（Getting Started）的实操入口。目标用户是**首次接触 FLASH 的新用户**——不需要了解 FLASH 内部架构即可在 15 分钟内跑通 Sedov。§2 与后续章节的关系：

| 章节 | 内容 | 在本章中挖的坑 |
|---|---|---|
| §3 Setting Up New Problems | Config 文件、Simulation_init*.F90 | §2.2 提到 "See §3" |
| §5 FLASH Configuration Script (setup) | setup 命令全参数 | §2.2 隐含 `-auto` 含义，详参 §5 |
| §9 IO Output | 输出文件格式 | §2.4 提到 plotfile/checkpoint，详参 §9 |
| §36 VisIt | 替代 IDL xflash3 的可视化 | §2.4 提到 "See §36" |

## 2. 系统需求（§2.1）

| 依赖 | 用途 | 替代方案 |
|---|---|---|
| F90 + C 编译器 | 编译 FLASH | gfortran/gcc, Intel, PGI, Absoft 均测试过 |
| MPI 库 | 并行通信 | MPICH（推荐），OpenMPI |
| HDF5（可选） | 输出文件格式 | 可用 `+noio` 跳过 |
| PnetCDF（可选） | 并行输出 | 替代 HDF5 |
| Chombo（可选） | AMR 网格后端 | 替代 PARAMESH |
| HYPRE（可选） | Diffuse 隐式求解器 | MGD/热传导必需 |
| Python ≥ 2.2 | 运行 setup 脚本 | 必需 |
| gmake | 构建系统 | GNU make，必需（宏拼接依赖） |
| IDL（可选） | 后处理可视化 | `xflash3` 工具；可用 VisIt 替代 |

**源码验证**：`setup` 脚本依赖 `#!/usr/bin/env python3`（`setup:1`）但文档要求 "Python 2.2 or later"（§2.1）；实际 `bin/setup.py:1` 已迁移到 Python 3。

## 3. 核心工作流

### 3.1 三步曲

```
# Step 1: 配置
./setup Sedov -auto

# Step 2: 编译
cd object && make -j4

# Step 3: 运行
mpirun -np 4 ./flash4 -parfile flash.par
```

### 3.2 各步骤说明

**Step 1 — `./setup`**：入口是根目录下的 `setup` shell 脚本（`setup:1-12`），它 `cd bin/` 后 `exec ./setup.py "$@"`。`setup.py main()`（`bin/setup.py:39-90`）的工作流：
1. 解析命令行参数（`parseCmd.parse()`）
2. 模糊匹配 `SimulationMain/<name>`（大小写不敏感）
3. 确定机器类型 → 匹配 `sites/<hostname>/Makefile.h`
4. `auto` 模式：自动生成 `Units` 文件（基于 Config 的 `REQUIRES`/`DEFAULT`）
5. `unitList.populate()`：解析 Config 依赖图，单元选择
6. 生成 `Makefile`、`Flash.h`、链接源文件到 `object/`

**Step 2 — `make`**：在 `object/` 目录下执行。FLASH 的 `Makefile` 由 `bin/genFiles.py` 基于 `bin/Makefile.tpl` 模板 + Config 信息生成。编译产出 `flash4` 可执行文件。

Makefile 结构关键点：
- `FFLAGS_OPT` / `FFLAGS_DEBUG` / `FFLAGS_TEST` 三套标志，由 setup 的 `-debug` 开关选择（confirmed in `cases/Sedov/Makefile.h:43-47`）
- OpenMP 并行通过 `OPENMP = -fopenmp` 控制（`cases/Sedov/Makefile.h:50`）
- `make clean`：删 `.o`，保留配置；`make realclean`：删全部（需重新 setup）

**Step 3 — 运行**：`./flash4 [-parfile <name>]`。默认读 `flash.par`，可选 `-parfile` 指定其他文件。

### 3.3 flash.par 格式

手册示例（§2.2, Figure 2.1）：

```fortran
basenm       = "sedov_"
lrefine_max  = 5
refine_var_1 = "dens"
refine_var_2 = "pres"
restart      = .false.
checkpointFileIntervalTime = 0.01
nend         = 10000
tmax         = 0.05
gamma        = 1.4
xl_boundary_type = "outflow"
xr_boundary_type = "outflow"
yl_boundary_type = "outflow"
yr_boundary_type = "outflow"
plot_var_1   = "dens"
plot_var_2   = "temp"
plot_var_3   = "pres"
sim_profFileName = "/dev/null"
```

格式规则：
- `#` 开头为注释
- `key = value`：字符串用双引号，布尔值用 Fortran 风格 `.true.` / `.false.`
- 完整参数列表见 `object/setup_params`（编译时生成）

**源码验证**：`source/Simulation/SimulationMain/Sedov/flash.par` 和 `cases/Sedov/flash.par` 均存在，但 `cases/Sedov/flash.par` 更完整（含 `geometry`, `xl/xr/yl/yr bounds`, `nblockx` 等）。手册示例（Figure 2.1）是简化版。

## 4. Docker 替代方案（§2.3）

手册 §2.3 提供 Docker 替代本地编译环境的方案。镜像名 `icksa/flash4-deps`，预装所有依赖。

```bash
# 拉取镜像
docker pull icksa/flash4-deps

# 启动容器（卷映射）
docker run -v /local/path:/mnt/path -it icksa/flash4-deps

# 容器内执行标准工作流
./setup Sedov -auto
cd object && make
mpirun -np 2 ./flash4 -parfile ../source/Simulation/SimulationMain/Sedov/flash.par
```

运行结果可视化建议用 VisIt（见 §36）。

## 5. 输出文件（§2.4）

运行完成后生成的输出文件：

| 文件 | 格式 | 用途 |
|---|---|---|
| `sedov.log` | 文本 | 运行日志（参数、性能摘要、警告） |
| `sedov.dat` | 文本 | 积分量随时间变化（质量、能量、动量等），可直接 gnuplot |
| `sedov_hdf5_chk_000*` | HDF5 | 检查点文件（完整状态，用于 restart） |
| `sedov_hdf5_plt_cnt_000*` | HDF5 | 绘图文件（单精度，高频输出，用于可视化） |

Checkpoint vs Plotfile 的选择：
- Plotfile：更频繁，适合做动画和可视化，单精度
- Checkpoint：完整状态（包括双精度变量），适合 restart

## 6. 类比其他构建系统

| 概念 | FLASH | typical CMake project | Makefile-only project |
|---|---|---|---|
| 配置 | `./setup Sedov -auto` | `cmake -B build -S .` | 手动编辑 Makefile |
| 编译 | `cd object && make` | `cmake --build build` | `make` |
| 并行编译 | `make -jN` | `cmake --build build -jN` | `make -jN` |
| 清除重建 | `make realclean → re-setup` | `rm -rf build` | `make distclean` |
| 编译后配置 | 不支持（需要重新 setup） | `cmake` 重新运行 | 手动改 Makefile |

## 7. 已知问题与陷阱

### 7.1 文档 vs 源码差异

| 手册 | 实际 | 位置 |
|---|---|---|
| 要求 Python ≥ 2.2 | `setup.py` 用 Python 3 运行（`#!/usr/bin/env python3`） | `bin/setup.py:1` |
| 说 `make` 产生 `flashX` | 此版本产生 `flash4` | 运行时确认 |
| 假设默认输出 `object/` | 本仓库用 `-objdir=cases/<name>` 约定 | 本仓库规约 |

### 7.2 新手常见问题

| 症状 | 原因 | 修复 |
|---|---|---|
| `./setup: 没找到命令` | 在 FLASH 根目录外执行 | 确保 `pwd` 是 FLASH 根目录 |
| `setup.py: 语法错误` | 系统 Python 版本太旧 | 确认 `python3 --version` ≥ 3.6 |
| `make: 找不到 Makefile` | 在 `object/` 外执行 | `cd object` 或 `cd <objdir>` 再 make |
| `flash4: 找不到` | 编译失败 | 检查 `make` 输出，特别是链接错误 |
| `flash.par: 找不到` | parfile 路径不对 | 用 `-parfile <path>` 指定，或把文件放当前目录 |
| 运行时报 `libmpi.so.40` 冲突 | 本机特有（见 CLAUDE.md） | 运行时 `sudo mv` 系统 libmpi 临时避开 |

## 8. 延伸阅读

- §3 Setting Up New Problems：Config 文件完整语法
- §5 The FLASH Configuration Script：setup 命令行全参数
- §9 IO Output：HDF5 格式细节
- §39 FLASH IDL/Xflash3-based Analysis Tools
- §36 VisIt Visualization
- `cases/Sedov/`：本仓库预构建的 Sedov 算例目录（含完整 Makefile.h + flash.par）

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft，基于 FLASH 4.8 UG §2 pp.17-25 + 源码对照 v4.8） | opencode-ai |
