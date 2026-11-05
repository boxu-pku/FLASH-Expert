---
title: Grid 网格单元
skill: flash-grid
category: overview
source_anchors:
  - source/Grid/Config:1-5
  - source/Grid/GridMain/Grid_getBlkPtr.F90:1-10
  - source/Grid/GridMain/paramesh/Config:1-15
  - source/Grid/GridMain/UG/Grid_getBlkPtr.F90:1
  - source/Grid/GridBoundaryConditions/Grid_applyBC.F90:1-5
  - source/Grid/GridSolvers/Multigrid/Grid_solvePoisson.F90:1-10
  - source/Grid/GridSolvers/HYPRE/gr_hypreSolve.F90:1-5
  - source/Grid/GridMain/paramesh/paramesh4/Paramesh4dev/Config:1-5
manual_ref: "FLASH 4.8 User Guide §8 (Grid Unit) pp.107-170, PDF pp.125-188"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - grid
  - paramesh
  - UG
  - chombo
  - AMR
  - boundary-condition
  - geometry
  - particles
  - poisson-solver
  - hypre
---

# Grid 网格单元（§8）

> **TL;DR**：Grid 是 FLASH 最大最复杂的基础设施单元。4 个子单元（GridMain、GridParticles、GridBoundaryConditions、GridSolvers）；3 个互斥后端（PARAMESH4dev AMR 默认、UG 均匀网格、Chombo 补丁 AMR）；核心数据结构 `unk(NUNK_VARS, nxb, nyb, nzb, blocks)` 和 `facevarx/y/z`；Löhner 二阶导数细化判据；6 种 Poisson 求解器。

> **互补性声明**：本条目补充 `skills/flash-grid/knowledge/`，侧重手册 §8 的整体结构和 API 参照，而非内部实现细节。

## 1. 子单元结构

```
Grid/
├── GridMain/                    ← 网格数据结构和核心管理
│   ├── UG/                      ← Uniform Grid（均匀网格）
│   └── paramesh/                ← PARAMESH AMR（自适应网格）
│       ├── paramesh2/           ── 旧版，仅兼容
│       ├── paramesh4/
│       │   ├── Paramesh4.0/     ── PM4 稳定版
│       │   └── Paramesh4dev/    ── PM4dev 默认版（+pm4dev）
│       └── interpolation/       ── 插值方法
├── GridBoundaryConditions/      ← 边界条件处理
│   └── Flash2HSE/              ── 静水压平衡 BC
├── GridParticles/               ← 粒子管理
│   ├── GridParticlesMove/       ── 粒子运动
│   └── GridParticlesMapFromToMesh/ ── 粒子↔网格映射
└── GridSolvers/                 ← PDE 求解器
    ├── Multipole/               ── 多极 Poisson
    ├── Multipole_new/           ── 改进型多极
    ├── BHTree/                  ── Barnes-Hut 树码
    ├── Multigrid/               ── 多重网格 Poisson
    ├── HYPRE/                   ── HYPRE 接口（用于 MGD/热传导）
    └── Pfft/                    ── FFT Poisson
```

**源码验证**：`source/Grid/Config:1-5` 设置 `DEFAULT GridMain` 和 `CHILDORDER localAPI unitTest`。`source/Grid/GridMain/paramesh/Config:1-15` 通过 `USESETUPVARS Grid` 和条件检查选择 PM4dev 为 `DEFAULT`。

## 2. 数据模型

### 2.1 数据数组

| 数组 | 维度 | 说明 |
|---|---|---|
| `unk` | `(NUNK_VARS, nxb, nyb, nzb, blocks)` | 体心变量（"unknowns"） |
| `facevarx` | `(NFACE_VARS, nxb+1, nyb, nzb, blocks)` | x 方向面心变量 |
| `facevary` | `(NFACE_VARS, nxb, nyb+1, nzb, blocks)` | y 方向面心变量 |
| `facevarz` | `(NFACE_VARS, nxb, nyb, nzb+1, blocks)` | z 方向面心变量 |
| `scratch` | `(NSCRATCH_GRID_VARS, nxb+1, nyb+1, nzb+1, blocks)` | 临时工作空间（已弃用） |
| `scratchCenterVar` | 同 `unk` 形状 | 体心临时变量（推荐替代 scratch） |
| `scratchFaceVarX/Y/Z` | 同对应 `facevar` | 面心临时变量 |

`NUNK_VARS`、`NFACE_VARS`、`nxb`/`nyb`/`nzb`、`MAXBLOCKS` 由 `setup` 编译为 `Flash.h` 常量。

### 2.2 使用模式

客户端单元通过 `Grid_getBlkPtr` 获取 block 数据指针，通过 `Grid_releaseBlkPtr` 释放：

```fortran
call Grid_getBlkPtr(blockID, solnData, CENTER)
! 读/写 solnData(DENS_VAR, :, :, :)
call Grid_releaseBlkPtr(blockID, solnData, CENTER)
```

**源码验证**：`source/Grid/GridMain/Grid_getBlkPtr.F90:1-10` 是 PM4dev、PM4、UG 和 Chombo 共享的顶层 API 接口文件。

### 2.3 Guard Cell 机制

每个 block 周围有一圈 guard cell（默认 4 层，对应 PPM 模板宽度）。通过 `Grid_fillGuardCells` 从相邻 block 填充或从边界条件赋值，使每个 block 可独立计算。

## 3. 计算域与边界条件

### 3.1 域设置

运行时参数 `xmin`/`xmax`、`ymin`/`ymax`、`zmin`/`zmax` 定义物理域范围。角度坐标用度输入，内部转为弧度。

### 3.2 边界条件类型

| BC 类型 | 说明 | 适用范围 |
|---|---|---|
| `outflow` | 零梯度（Neumann） | 最常用 |
| `reflect` | 反射（对称） | 对称面 |
| `periodic` | 周期（wrap-around） | 全周期问题 |
| `diode` | 单向通量 | 入口/出口 |
| `user` | 自定义（`Simulation/` 目录实现） | 任意 |
| `absorb` | 吸收层（damping） | 波吸 |
| `vacuum` | 真空（流入 = 0） | 边界无入流 |

**小节**：8.4.2 障碍物边界条件（`obstacle`）；8.4.3 `Grid_bcApplyToRegionSpecialized` 接口。PM4dev 用户见 8.4.3.1 关于 `forceConsistency` 参数的注意事项。

## 4. 三种网格后端

### 4.1 Uniform Grid（UG，§8.5）

- 每 processor 仅 1 个 block
- **FIXEDBLOCKSIZE** 模式：`nxb`/`nyb`/`nzb` 编译时确定
- **NONFIXEDBLOCKSIZE** 模式：block 大小运行时确定（setup 加 `+nofbs`）
- 适合：无 AMR 需求的小规模计算、调试

### 4.2 PARAMESH AMR（§8.6）

- FLASH 的主干 AMR 包，默认选择
- 初始化：`gr_createDomain`（并行 Morton 排序）→ `gr_expandDomain`（细化至满意分辨率）
- **Morton 曲线**负载均衡：interleave bits 计算 block 编号 → 按 Morton 顺序分配
- Block 权重分配：预估计算负载；`lrefine_min`/`lrefine_max` 控制精化深度

### 4.3 Chombo（§8.7）

- C++ 实现的补丁 AMR，通过 FLASH 封装层接入
- 需手动下载和构建 Chombo ≥ 3.0
- FLASH 内提供单元测试辅助验证兼容性
- 尚未用于 Flash Center 生产计算

## 5. AMR 细化机制

### 5.1 Löhner 误差估计器

FLASH 使用 Löhner (1987) 修正二阶导数估计器。1D 简化形式：

$$E_i = \frac{|u_{i+2} - 2u_i + u_{i-2}|}{|u_{i+2} - u_i| + |u_i - u_{i-2}| + \epsilon[|u_{i+2}| + 2|u_i| + |u_{i-2}|]}$$

多维推广（式 8.4）：考虑所有交叉导数项。默认 $\epsilon = 10^{-2}$（`refine_filter_#` 参数可调）。

Block 标记条件：
- `E_i` > `refine_cutoff_#` → refine
- 所有 cell 的 `E_i` < `derefine_cutoff_#` → derefine

### 5.2 细化处理流程

```
每个 processor 对本 block 计算 Löhner 估计器
  → 标记 refine/derefine
  → refine: 创建 2^d 个子 block
  → derefine: 删除全部子 block
  → Morton 曲线重分布负载均衡
```

细化变量通过 `refine_var_#`（# = 1-4）在 flash.par 中设置。**FLASH4 默认无细化变量**，需用户明确指定，否则产生警告。

## 6. GridSolvers

### 6.1 Poisson 求解器

| 求解器 | setup 方式 | 适用场景 | 备注 |
|---|---|---|---|
| Multipole（原版） | 默认 | 引力/静电 | 渐近展开 + P^M 求和 |
| Multipole（改进版） | `+newMP` | 引力（2D 柱/3D Cartesian） | 线程安全，支持 OpenMP |
| BHTree | `+bhtree` | 大粒子数引力 | Barnes-Hut 树码 O(N log N) |
| Multigrid | `+multigrid` | Poisson 方程标准解 | V-cycle |
| HYPRE | `+hypre` | MGD/热传导/扩散 | PFMG/BoomerAMG/Krylov 求解器 |
| Pfft（预处理） | `+pfft` | 大域 Poisson | FFT 加速 |
| Hybrid (Pfft+MG) | 组合 | 大域 + 局部 | 顶级 + 校正步 |

### 6.2 HYPRE 接口（§8.10.4）

HYPRE 是 MGD 辐射扩散和隐式热传导的必需求解器。支持：
- 结构化求解器：PFMG（默认）、SMG
- 代数求解器：BoomerAMG、PCG、GMRES
- 预处理：`gr_hypreSetPreconditioner`
- 曲线坐标支持（§8.10.4.3）

**源码验证**：`source/Grid/GridSolvers/HYPRE/gr_hypreSolve.F90:1-5` 为 HYPRE 求解器入口。`source/Grid/GridSolvers/Multigrid/Grid_solvePoisson.F90:1-10` 为 Multigrid 入口。

## 7. 网格几何

| 几何 | setup 参数 | 轴处理 |
|---|---|---|
| Cartesian | `-geometry=cartesian` | x/y/z 均为直线坐标 |
| Cylindrical | `-geometry=cylindrical` | r-z（2D）或 r-z-φ（3D）；$\delta V = r\;\delta r\delta z\delta\phi$ |
| Spherical | `-geometry=spherical` | r-θ-φ；$\delta V = r^2\sin\theta\;\delta r\delta\theta\delta\phi$ |
| Polar | `-geometry=polar` | r-θ（2D）；$\delta V = r\;\delta r\delta\theta$ |

代码内通过 `Grid_getGeometry` 获取几何类型。曲线坐标下的 conservative prolongation/restriction（§8.11.5）确保标量/密度在 refine/derefine 时守恒。

## 8. 关键 API 函数

| 函数 | 用途 |
|---|---|
| `Grid_getBlkPtr` / `Grid_releaseBlkPtr` | block 数据指针获取/释放 |
| `Grid_getBlkIndexLimits` | 获取 block 索引边界（含/不含 guard cell） |
| `Grid_getCellCoords` | 获取 cell 坐标数组 |
| `Grid_getBlkBoundBox` | 获取 block 包围盒 |
| `Grid_getDeltas` | 获取 cell 步长 |
| `Grid_fillGuardCells` | 填充 guard cell |
| `Grid_getListOfBlocks` | 获取指定类型 block 列表 |
| `Grid_markRefineDerefine` | 标记细化/粗化 |
| `Grid_updateRefinement` | 执行细化/粗化调度 |
| `Grid_solvePoisson` | 求解 Poisson 方程 |
| `Grid_computeUserVars` | 用户自定义变量计算 |

## 9. 已知陷阱

| 问题 | 说明 | 解决 |
|---|---|---|
| AMR 无细化变量 | FLASH4 不设默认细化变量 | 在 flash.par 设置 `refine_var_#` |
| `maxblocks` 不足 | AMR 运行中创建 > `maxblocks` | 增大 `-maxblocks=` 后重新 setup |
| UG FIXED vs NONFIXED | 两种模式 block 大小策略不同 | 默认 FIXED，NONFIXED 需 `+nofbs` |
| Chombo 库未安装 | 需手动下载构建 Chombo | `./setup` 配合单元测试验证 |
| PM4dev `forceConsistency` | 影响 restart 精度 | 见手册 §8.4.3.1 |
| 曲线坐标角度单位 | 输入用度，内部弧度 | 不需担心，自动转换 |
| HYPRE 与 MPI 冲突 | 本机 `libmpi.so.40` 冲突 | 见 CLAUDE.md 工作区 |

## 10. 延伸阅读

- 本技能知识：`skills/flash-grid/knowledge/` 含 backend 差异、AMR 策略、guard cell 策略等技术细节
- §6 Flash.h File：变量索引如何生成
- §9 IO Unit：plotfile/checkpoint 中网格数据输出
- §14 3T HEDP Capabilities：MGD + HYPRE 耦合
- §25 RadTrans/MGD：多群辐射扩散与 HYPRE 的协作
- `source/Grid/GridMain/paramesh/paramesh4/Paramesh4dev/`：当前默认 AMR 实现

## 11. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft，基于 FLASH 4.8 UG §8 pp.107-170 + 源码对照 v4.8） | opencode-ai |
