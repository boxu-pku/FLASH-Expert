---
title: Diffuse 内部实现 — Diffuse_solveScalar → Grid_advanceDiffusion → HYPRE 全流程
skill: flash-diffuse
category: internals
source_anchors:
  - source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L87-L200
  - source/physics/Diffuse/DiffuseMain/Unsplit/diff_advanceTherm.F90:L64-L488
  - source/physics/Diffuse/DiffuseMain/Diffuse_fluxLimiter.F90:L57-L261
  - source/physics/Diffuse/DiffuseMain/Diffuse_computeFluxLimiter.F90:L63-L250
  - source/physics/Diffuse/DiffuseMain/Diffuse_computeDt.F90:L61-L423
  - source/physics/Diffuse/DiffuseMain/Diffuse_init.F90:L55-L212
  - source/Grid/GridSolvers/HYPRE/Grid_advanceDiffusion.F90:L84-L120
  - source/Grid/GridSolvers/HYPRE/gr_hypreSetupSolver.F90:L51-L431
  - source/Grid/GridSolvers/HYPRE/gr_hypreSolve.F90:L27-L420
manual_ref: "FLASH 4.8 User Guide §20, §23"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: beta
tags:
  - diffuse
  - internals
  - hypre
  - call-graph
  - matrix-assembly
  - flux-limiter
---

# Diffuse 内部实现（Unsplit + HYPRE 聚焦）

> **TL;DR**：Diffuse 公共 API ~15 个。核心是 `Diffuse_solveScalar`（标量）、`Diffuse_solveScalarAniso`（各向异性）、`Diffuse_solveScalarMag`（磁）—— 都是 thin wrapper，调 `Grid_advanceDiffusion`（Grid 层 HYPRE 实现）。**本文件讲**：① API 总览；② `diff_advanceTherm` 主流程（10 步）；③ `Diffuse_solveScalar` 内部；④ HYPRE 矩阵组装（7 点模板）；⑤ 通量限制器实现（4 模式公式 + 代码）；⑥ AMR 处理；⑦ `Diffuse_computeDt` 显式 dt 公式；⑧ `Diffuse_init` 启动流程；⑨ 完整调用图。

### 术语速查（按 L-014，先解释再讲机制）

- **HYPRE**：LLNL 开发的解大稀疏线性方程组 `Ax=b` 的数学库。**为什么需要**：扩散方程隐式离散后变百万级稀疏系统，普通方法不可行。
- **Diffuse_solveScalar**：FLASH 的标量扩散方程求解接口（thin wrapper）。**为什么是 wrapper**：抽象 Grid 层，物理单元不必管 HYPRE API。
- **Grid_advanceDiffusion**：Grid 层的扩散求解实现（真正调 HYPRE）。**为什么在 Grid 层**：Grid 知道数据布局（block / AMR），物理单元不知道。
- **θ-加权（theta-weighted）**：时间离散的隐式度参数。θ=1 全隐式（无条件稳定）；θ=0.5 CN（2 阶）；θ=0 显式（不稳定）。
- **flux limiter**：限制扩散通量不超过自由流极限 `F_fs = n·k_B·T·v_th` 的数学函数。**为什么需要**：低密度区纯扩散会超光速。
- **operator-split**：把多物理拆成"一次解一个"。Diffuse 在 Driver 第 3 位独立调用。
- **BoomerAMG**：HYPRE 库里 AMG 的具体实现（LLNL 经典 AMG）。**为什么默认它**：稳健，HYPRE 推荐默认。
- **多重网格（Multigrid）**：粗-细网格层次循环，长波长误差在粗网格快速消除。**为什么需要**：单网格迭代 O(N) 步，多重网格 O(1) 步。
- **预条件子（preconditioner）**：把 `Ax=b` 变成 `M⁻¹Ax = M⁻¹b`，M 是近似 A 但易求逆。**为什么需要**：CG / GMRES 收敛慢，预条件后快几个数量级。
- **7 点模板（7-point stencil）**：3D 离散拉普拉斯算子的格式——中心 cell + 6 邻居（±x, ±y, ±z）共 7 个非零。**为什么 7 点**：标准 2 阶中心差分，简洁。
- **UNK / cell-centered**：FLASH 把物理量存在 cell 中心（如 TELE_VAR），不是 cell 角或 face。
- **guard cell**：每个 block 边界外的"虚拟单元"，存邻居数据。**为什么需要**：扩散算梯度需要邻居值。

---

## 1. 公共 API 总览

源码：`source/physics/Diffuse/Diffuse_interface.F90`（~480 行）

### 1.1 API 分类

| 类别 | 函数 | 数量 |
|---|---|---|
| **生命周期** | `Diffuse`（主入口）、`Diffuse_init`、`Diffuse_finalize` | 3 |
| **求解器** | `Diffuse_solveScalar`、`Diffuse_solveScalarAniso`、`Diffuse_solveScalarMag`、`Diffuse_solveCoupledScalar`、`Diffuse_solve`（generalized）、`Diffuse_advance1D` | 6 |
| **通量限制器** | `Diffuse_fluxLimiter`、`Diffuse_computeFluxLimiter`、`Diffuse_applyGenericFluxLimiter` | 3 |
| **物理分发** | `Diffuse_therm`、`Diffuse_visc`、`Diffuse_species`、`Diffuse_doEnergyFluxes` | 4 |
| **辅助** | `Diffuse_computeDt`、`Diffuse_getQVisc`、`Diffuse_getQOhm`、`Diffuse_setContextInfo` | 4 |

### 1.2 关键 API 详解

#### `Diffuse`（主入口，dispatcher）

源码：`source/physics/Diffuse/DiffuseMain/Diffuse.F90:L36-L72`（30 行）

```fortran
subroutine Diffuse(blockCount, blockList, dt, pass)
   if (useDiffuse) then
      call diff_advanceMag(blockCount, blockList, dt, pass)         ! 磁扩散
      if (useDiffuseTherm) call diff_advanceTherm(blockCount, blockList, dt, pass)
      if (useDiffuseVisc)  call diff_advanceVisc(blockCount, blockList, dt, pass)
   end if
end subroutine
```

Driver_evolveFlash 第 3 位调（Hydro 后，sourceTerms 前）。

#### `Diffuse_solveScalar`（thin wrapper）

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L87-L127`（40 行）

```fortran
subroutine Diffuse_solveScalar(iVar, iFactorB, iFactorA, bcTypes, bcValues, &
     dt, scaleFact, chi, theta, pass, blockCount, blockList, iFactorC, iFactorD)
   if (iFactorB >= 0) then
      call Grid_advanceDiffusion(iVar, iSrc, iFactorB, iFactorA, bcTypes, bcValues, &
           dt, chi, scaleFact, theta, solnIsDelta, iFactorC, iFactorD, pass)
   else
      call Grid_advanceDiffusionFcB(...)  ! face-centered B 系数
   end if
end subroutine
```

**为什么这么薄**：所有求解逻辑在 Grid 层。Diffuse_solveScalar 只是参数转发 + context 设置（`Grid_setSolverDbgContextInfo`，调试用）。

#### `Diffuse_solveScalarAniso`（各向异性）

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L129-L164`

```fortran
subroutine Diffuse_solveScalarAniso(iVar, iFactorsB(GRID_PDE_DIFFCOEF_NCOMP), iFactorA, ...)
   call Grid_advanceAnisoDiffusion(iVar, iSrc, iFactorsB, iFactorA, bcTypes, bcValues, ...)
end subroutine
```

`iFactorsB` 是 3 元素数组（CND1 / CND2 / CND3 = 平行 / 垂直 / 交叉）。MHD 算例用。

#### `Diffuse_solveScalarMag`（磁扩散）

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L166-L200`

```fortran
subroutine Diffuse_solveScalarMag(iVar, iFactorsB(2), iFactorA, bcTypes(6,3), bcValues(2,6,3), ...)
   call Grid_advanceMagDiffusion(iVar, iSrc, iFactorsB, iFactorA, bcTypes, bcValues, ...)
end subroutine
```

3 个分量（MAGX/Y/Z）独立求解，每个有自己的 BC。

#### `Diffuse_computeDt`（显式 dt）

源码：`source/physics/Diffuse/DiffuseMain/Diffuse_computeDt.F90:L61-L423`

公式（按维度）：
```
dt_diffuse = 0.5 · dx² / D_max        # 1D
dt_diffuse = 0.5 · min(dx², dy²) / D_max   # 2D Cartesian
dt_diffuse = 0.5 · min(dx², dy², dz²) / D_max  # 3D Cartesian
```

D_max = max(thermal_diffusivity, viscous, mass_diff, mag_resist)。

`dt_diff_factor`（默认 0.8）缩放最终结果。

### 1.3 不存在的 API（避免混淆）

- **`Diffuse_solveScalarTherm` 不存在**：用 `Diffuse_solveScalar(iVar=TELE_VAR, ...)` 即可。
- **`Diffuse_setFluxLimiter` 不存在**：通量限制器通过 `Diffuse_fluxLimiter` 修改 COND_VAR。

---

## 2. diff_advanceTherm 主流程（10 步）

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/diff_advanceTherm.F90:L64-L488`（424 行）

这是 **Driver 调用 Diffuse 时实际跑的代码**（每 hydro 步调一次）。完整流程：

```
diff_advanceTherm(blockCount, blockList, dt, pass)
│
├── Step 0: 前置检查（行 157-159）
│   ├── if (.not. useDiffuse) return
│   └── if (.not. useDiffuseTherm) return
│
├── Step 1: 决定解的变量 + EOS 模式（行 167-187）
│   ├── if 3T (TELE_VAR defined):
│   │   ├── firstComponent = EOSCOMP_ELE
│   │   ├── Temptodiffuse = TELE_VAR
│   │   ├── cvToUse = EOS_CVELE
│   │   └── EosMode = MODE_DENS_TEMP_GATHER
│   └── else (1T):
│       ├── Temptodiffuse = TEMP_VAR
│       ├── cvToUse = EOS_CV
│       └── EosMode = MODE_DENS_TEMP
│
├── Step 2: 电子热传导（if diff_useEleCond or 1T）（行 191-348）
│   │
│   ├── Step 2a: 转换 BC 字符串 → 整数常量（行 196-207）
│   │   ├── where PERIODIC: bcTypes = GRID_PDE_BND_PERIODIC
│   │   ├── where DIRICHLET: bcTypes = GRID_PDE_BND_DIRICHLET, bcValues = diff_elebcValues
│   │   └── where OUTFLOW: bcTypes = GRID_PDE_BND_NEUMANN
│   │
│   ├── Step 2b: Grid_fillGuardCells (gcmask 仅 Temptodiffuse)（行 218）
│   │   └── 让 TELE_VAR 在 guard cell 自洽（flux limiter 计算梯度需要）
│   │
│   ├── Step 2c: 每 cell 算 COND_VAR / DFCF_VAR / FLLM_VAR（行 221-278）
│   │   do lb = 1, blockCount
│   │     do i,j,k:
│   │       ├── xtemp = solnVec(Temptodiffuse,i,j,k)
│   │       ├── xdens = solnVec(DENS_VAR,i,j,k)
│   │       │
│   │       ├── if (xdens < diffusion_cutoff_density):
│   │       │   cond_zone = 0.0          # 真空区不扩散
│   │       │
│   │       ├── else:
│   │       │   call Conductivity(solnVec(:,i,j,k), cond_zone, component=EOSCOMP_ELE)
│   │       │   # cond_zone 是 3 元素（平行 / 垂直 / 交叉）电导率
│   │       │
│   │       ├── if (diff_anisoCondForEle):
│   │       │   ├── solnVec(CND1_VAR) = cond_zone(1)  # parallel
│   │       │   ├── solnVec(CND2_VAR) = cond_zone(2)  # perpendicular
│   │       │   └── if (diff_useCrossCond) solnVec(CND3_VAR) = cond_zone(3)
│   │       │
│   │       ├── else:  # 各向同性
│   │       │   solnVec(COND_VAR) = cond_zone(2)  # 用 perpendicular 作 isotropic
│   │       │
│   │       ├── call Eos(mode, ...) → eos_arr(EOS_CVELE)
│   │       ├── solnVec(DFCF_VAR) = xdens * eos_arr(cvToUse)
│   │       │   # DFCF_VAR = ρ · cv（A 系数，左端）
│   │       │
│   │       └── call Eos_getAbarZbar → Ye
│   │           solnVec(FLLM_VAR) = diff_eleFlCoef *
│   │                                sqrt(diff_boltz * xtemp / diff_mele) *
│   │                                diff_boltz * xtemp *
│   │                                (Ye * diff_avo * xdens)
│   │           # FLLM_VAR = coef · v_th · k_B·T · n_e = 自由流通量
│   │   │
│   ├── Step 2d: Grid_fillGuardCells（全变量，让 COND/DFCF/FLLM 在 guard cell）（行 280）
│   │
│   ├── Step 2e: Diffuse_setContextInfo(component=firstComponent)（行 282）
│   │   └── 调试用，告诉 HYPRE 当前解的是电子还是离子
│   │
│   ├── Step 2f: 应用 flux limiter（行 284-298 各向异性 / 行 310-311 各向同性）
│   │   ├── call Diffuse_fluxLimiter(COND_VAR, Temptodiffuse, FLLM_VAR,
│   │   │                            diff_eleFlMode, blockCount, blockList)
│   │   │   └── 修改 COND_VAR = λ·κ（λ 由 mode 决定）
│   │   │
│   │   └── if (diff_anisoCondForEle):
│   │       solnVec(CND1_VAR) *= solnVec(FLLM_VAR)   # 平行也按 λ 缩放
│   │       if (diff_useCrossCond) solnVec(CND3_VAR) *= solnVec(FLLM_VAR)
│   │
│   ├── Step 2g: diff_getFaceFluxes（if diff_updEint）（行 300-303, 313-316）
│   │   └── 算 (1-θ)·显式通量（用于 EINT_VAR 更新）
│   │
│   └── Step 2h: ★ Diffuse_solveScalar（行 305-307 各向异性 / 行 318-320 各向同性）
│       ├── call Diffuse_solveScalarAniso(Temptodiffuse, cvarsCond, DFCF_VAR, bcTypes,
│       │                                bcValues, dt, 1.0, 1.0, diff_thetaImplct, pass, ...)
│       │   └── Grid_advanceAnisoDiffusion → HYPRE 解 → 更新 TELE_VAR
│       │
│       └── or call Diffuse_solveScalar(Temptodiffuse, COND_VAR, DFCF_VAR, bcTypes,
│                                       bcValues, dt, 1.0, 1.0, diff_thetaImplct, pass, ...)
│           └── Grid_advanceDiffusion → HYPRE 解 → 更新 TELE_VAR
│   │
│   └── Step 2i: diff_updEint 时算 θ·隐式通量 + diff_updateEnergy（行 323-347）
│       └── 更新 EINT_VAR（严格能量守恒）
│
├── Step 3: 离子热传导（if diff_useIonCond and 3T）（行 355-465）
│   └── 同 Step 2 但针对 TION_VAR，bcTypes 用 diff_ionDomainBC，theta 用 diff_ionThetaImplct
│
└── Step 4: EOS 调和（行 472-478）
    └── call Eos_wrapped(EosMode, blkLimits, blockList(lb))
        └── 从更新后的 TELE/TION 重算 EINT/PRES（自洽）
```

### 2.1 为什么是这个流程

| 步骤 | 为什么必须在这位置 |
|---|---|
| Step 0 检查 | 关掉时早返回避免无谓计算 |
| Step 1 决定变量 | 1T vs 3T 分流，影响后续 EOS 模式 |
| Step 2b fillGuardCells | Step 2c 算梯度需要邻居 TELE |
| Step 2c 算 COND/DFCF/FLLM | 必须在 HYPRE 求解前算好（HYPRE 用这些）|
| Step 2d fillGuardCells（COND/DFCF/FLLM）| HYPRE 组装矩阵需要 guard cell 的系数 |
| Step 2f flux limiter | 必须在求解前应用（修改 COND_VAR = λ·κ）|
| Step 2h Diffuse_solveScalar | 核心，HYPRE 解 7 点扩散方程 |
| Step 2i EINT 更新 | diff_updEint=true 时做能量守恒 |
| Step 4 EOS 调和 | 让 TELE/EINT 自洽（HYPRE 只更新 TELE，EOS 重算 EINT）|

---

## 3. Diffuse_solveScalar 内部细节

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L87-L127`

### 3.1 调用签名（标准形式）

```fortran
call Diffuse_solveScalar( &
    iVar       = TELE_VAR,           ! ★ 求解的 UNK 索引
    iFactorB   = COND_VAR,           ! 扩散系数 B（电导率 κ）
    iFactorA   = DFCF_VAR,           ! 左端系数 A（ρ·cv）
    bcTypes,                          ! 6 面 BC 类型（整数常量）
    bcValues,                         ! 6 面 BC 值（Dirichlet T 或 0）
    dt,                               ! 时间步
    scaleFact  = 1.0,                 ! 系数倍数（不用）
    chi        = 1.0,                 ! 常数扩散（不用）
    theta      = diff_thetaImplct,    ! ★ 隐式度（默认 0.5，LaserSlab 1.0）
    pass,                             ! pass 标志（unsplit 忽略）
    blockCount, blockList,            ! block 列表（unsplit 忽略，Grid 层用）
    iFactorC   = -,                   ! 耦合项 C（MGD 用，热传导不用）
    iFactorD   = -)                   ! 源项 D（MGD 用）
```

### 3.2 解什么方程

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L27-L37`

```
A · (∂f/∂t) + C · f = div(B · grad f) + D
```

展开（热传导特化，A=ρ·cv，B=κ，C=0，D=0）：

```
ρ·cv · (∂T/∂t) = ∇·(κ·∇T)
```

θ-加权离散：
```
ρ·cv · (T^{n+1} - T^n) / dt = ∇·[κ · ∇(θ·T^{n+1} + (1-θ)·T^n)]
```

整理成线性方程组 `A·T^{n+1} = b`：

```
[ρ·cv/dt · I - θ·L(κ)] · T^{n+1} = [ρ·cv/dt · I + (1-θ)·L(κ)] · T^n
```

其中 `L(κ)` 是离散拉普拉斯算子（带系数 κ）。

### 3.3 分支：cell-centered B vs face-centered B

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L117-L123`

```fortran
if (iFactorB >= 0) then
   call Grid_advanceDiffusion(iVar, iSrc, iFactorB, ...)        ! cell-centered B（在 UNK）
else
   call Grid_advanceDiffusionFcB(iVar, iSrc, iFactorA, ...)     ! face-centered B（在 FACEX/Y/Z）
end if
```

**为什么有分支**：
- **cell-centered**（默认，iFactorB >= 0）：扩散系数存在 UNK（如 COND_VAR），求解器在 face 上做算术平均。
- **face-centered**（iFactorB = -1 时）：扩散系数直接存在 face-center（如磁扩散的电导率，更精确）。

LaserSlab 用 cell-centered（iFactorB = COND_VAR）。

---

## 4. HYPRE 矩阵组装（Grid 层）

源码：`source/Grid/GridSolvers/HYPRE/Grid_advanceDiffusion.F90:L84-L120+`（~600 行）

### 4.1 7 点模板（3D）

```
对 cell (i,j,k)，矩阵 A 的行 (i,j,k) 有 7 个非零：

中心：
  A[(i,j,k), (i,j,k)] = (ρcv)_ijk / dt + θ · Σ_faces (κ_face / dx²)

6 邻居：
  A[(i,j,k), (i-1,j,k)] = -θ · κ_{i-1/2} / dx²
  A[(i,j,k), (i+1,j,k)] = -θ · κ_{i+1/2} / dx²
  A[(i,j,k), (i,j-1,k)] = -θ · κ_{j-1/2} / dy²
  A[(i,j,k), (i,j+1,k)] = -θ · κ_{j+1/2} / dy²
  A[(i,j,k), (i,j,k-1)] = -θ · κ_{k-1/2} / dz²
  A[(i,j,k), (i,j,k+1)] = -θ · κ_{k+1/2} / dz²
```

其中 `κ_{i±1/2}` 是 face 上的电导率（由 cell-centered κ 算术平均：`(κ_i + κ_{i±1}) / 2`）。

### 4.2 RHS b 组装

```
b_ijk = (ρcv)_ijk / dt · T^n_ijk
      + (1-θ) · Σ_faces [κ_face · (T^n_neighbor - T^n_ijk) / dx²]
      + D_ijk     # 源项（热传导为 0）
      - C_ijk · T^n_ijk  # 耦合（热传导为 0）
```

### 4.3 边界条件应用

源码：`source/Grid/GridSolvers/HYPRE/gr_hypreApplyBcToFace.F90`

对每个面（6 面），按 bcTypes 修改 face 系数：
- **PERIODIC**：把左右边界 face 耦合（循环）。
- **NEUMANN**（∂T/∂n=0）：face 系数置 0（无通量）。
- **DIRICHLET**（T=T_bc）：face 系数置正常值，b 加上 T_bc 贡献。
- **VACUUM**：辐射边界，face 系数特殊处理（"vacuum" Marshak 边界）。

### 4.4 矩阵大小

- **未知数数**：Ncells = 所有 leaf cell 数（LaserSlab 2D 典型 10⁵）
- **矩阵大小**：Ncells × Ncells（10¹⁰ 元素，但稀疏存储 O(Ncells) 内存）
- **每行非零**：3D 7 个；2D 5 个；1D 3 个

### 4.5 AMR 处理

HYPRE 通过 FLASH Grid 提供的 composite grid 信息自动处理 coarse-fine 边界：
- **face coarsening**：粗细网格 face 上电导率用面积加权平均。
- **proxy cell**：粗网格的 guard cell 自动 fine-fill。
- **物理单元不感知**：Diffuse_solveScalar 只传 cell-centered 系数，HYPRE 内部处理 AMR。

---

## 5. 通量限制器实现

源码：`source/physics/Diffuse/DiffuseMain/Diffuse_fluxLimiter.F90:L57-L261`

### 5.1 主流程

```
Diffuse_fluxLimiter(idcoef=COND_VAR, ifunc=TELE_VAR, ifl=FLLM_VAR, mode, blkcnt, blklst)
│
├── Step 1: if (mode == FL_NONE): blkPtr(ifl) = 1.0, return   # 不限制
│
├── Step 2: 对每 block:
│   ├── Grid_getBlkPtr(blklst(lb), blkPtr)
│   ├── Grid_getBlkIndexLimits + Grid_getDeltas + Grid_getCellCoords
│   │
│   ├── Step 2a: 对每 cell (i,j,k):
│   │   │
│   │   ├── 算 |∇T|（中心差分）
│   │   │   gradi = ((T_{i+1} - T_{i-1}) / (2·dx))²
│   │   │   gradj = ((T_{j+1} - T_{j-1}) / (2·dy))²  (2D+)
│   │   │   gradk = ((T_{k+1} - T_{k-1}) / (2·dz))²  (3D)
│   │   │   maggrad = sqrt(gradi + gradj + gradk)
│   │   │
│   │   ├── dcoefOld = blkPtr(COND_VAR, i,j,k)   # 原始电导率 κ
│   │   │
│   │   ├── if (dcoefOld == 0): blkPtr(FLLM_VAR) = 1.0, CYCLE   # 真空区
│   │   │
│   │   ├── fl = blkPtr(FLLM_VAR, i,j,k)   # FLLM = coef·F_fs
│   │   │
│   │   └── select case(mode):
│   │       ├── FL_HARMONIC:
│   │       │   dcoef = 1 / (1/dcoefOld + maggrad / (fl + ε))
│   │       │
│   │       ├── FL_MINMAX:
│   │       │   dcoef = min(dcoefOld, fl / (maggrad + ε))
│   │       │
│   │       ├── FL_LARSEN:
│   │       │   dcoef = 1 / sqrt((1/dcoefOld)² + (maggrad/(fl+ε))²)
│   │       │
│   │       └── FL_LEVPOM:
│   │           R = dcoefOld · maggrad / max(TINY·dcoefOld·maggrad, fl) · 3.0
│   │           if (R > sqrtHuge): lambda3 = 3.0/R
│   │           else: lambda3 = 3·(2+R) / (6 + 3R + R²)
│   │           dcoef = lambda3 · dcoefOld / 3
│   │
│   ├── Step 2b: blkPtr(COND_VAR) = dcoef       # ★ 修改电导率为有效值
│   └── blkPtr(FLLM_VAR) = lambda3              # ★ 写回 λ·3 用于诊断
│
└── Step 3: Grid_releaseBlkPtr
```

### 5.2 4 模式公式对比（代码片段）

源码：`source/physics/Diffuse/DiffuseMain/Diffuse_fluxLimiter.F90:L173-L211`

```fortran
select case(mode)
case(FL_HARMONIC)
   dcoef = 1.0 / (1.0/dcoefOld + maggrad/(fl + 1.0e-100_r8))
   lambda3 = dcoef / dcoefOld

case(FL_MINMAX)
   dcoef = min(dcoefOld, fl/(maggrad + 1.0e-100_r8))
   lambda3 = dcoef / dcoefOld

case(FL_LARSEN)
   dcoef = 1.0 / sqrt((1.0/dcoefOld)**2 + (maggrad/(fl + 1.0e-100_r8))**2)
   lambda3 = dcoef / dcoefOld

case(FL_LEVPOM)
   if (maggrad == 0.0) then
      R = 0.0
   else if (...)
      R = dcoefOld * maggrad / max(TINY(fl)*dcoefOld*maggrad,fl) * 3.0
   end if
   if (R > sqrtHuge) then
      lambda3 = 3.0/R
   else
      lambda3 = 3.0*(2.0 + R)/(6.0+3.0*R+R**2)
   endif
   dcoef = lambda3 * dcoefOld / 3.0

case DEFAULT
   call Driver_abortFlash("Invalid Flux limiter type")    ! ★ abort
end select
```

### 5.3 关键设计

- **`1.0e-100_r8`**：避免除零（maggrad 或 fl 接近 0 时）。**为什么用 1e-100**：极小但不为零，让数值稳定。
- **`TINY(fl) * dcoefOld * maggrad > 1/HUGE(fl)`**：检查乘积是否在 double 范围内（避免 overflow / underflow）。
- **写回 FLLM = λ·3**：Levermore-Pomraning 1981 论文用 λ 的 3 倍形式，保持一致。
- **修改 COND_VAR**：直接修改 UNK 变量（不是返回新数组），后续 HYPRE 求解用修改后的 COND_VAR。

### 5.4 Diffuse_computeFluxLimiter（不修改 COND_VAR 的版本）

源码：`source/physics/Diffuse/DiffuseMain/Diffuse_computeFluxLimiter.F90:L63-L250`

和 `Diffuse_fluxLimiter` 区别：**不修改 COND_VAR，只计算 λ 写到 iflOut**。**为什么有两个版本**：
- `Diffuse_fluxLimiter`：直接应用（修改 COND_VAR）。
- `Diffuse_computeFluxLimiter`：诊断或外部应用（不修改）。

MGD 用 `Diffuse_computeFluxLimiter`（自己管理 COND_VAR）。

---

## 6. AMR 处理细节

### 6.1 Composite grid

HYPRE 通过 FLASH Grid 拿到 composite grid（粗细网格混合）：
- 每个 leaf block 是一个 cell 集合（如 16×16）
- 粗细边界（coarse-fine interface）有特殊 face
- HYPRE 的 SStruct grid 数据结构支持

### 6.2 face coarsening

源码：`source/Grid/GridSolvers/HYPRE/gr_hypreComputeB.F90` + `Grid_advanceDiffusion.F90:L84+`

粗细 face 上的电导率：
```
κ_cf = (κ_c · A_c + κ_f · A_f) / (A_c + A_f)
```
其中 A 是 face 面积（粗 face 大，fine face 小）。

### 6.3 proxy cell

粗网格 guard cell 自动 fill fine neighbor 值（不需要物理单元管理）。HYPRE 通过 `gr_hypreExchangeFacB` 等 exchange routine 处理。

---

## 7. Diffuse_computeDt（显式 dt）

源码：`source/physics/Diffuse/DiffuseMain/Diffuse_computeDt.F90:L61-L423`

### 7.1 公式

```
对每 cell：
  D_max = max(thermal_diffusivity, viscous_kinematic, mass_diff, mag_resistivity)
  dt_cell = 0.5 · dx² / D_max     # 显式稳定条件

对每 block：
  dt_block = min(dt_cell) · dt_diff_factor

对全 grid：
  dt_diff = min(dt_block)
```

### 7.2 thermal diffusivity 算法（行 172-218）

```fortran
if (useDiffuseComputeDtTherm) then
   call Conductivity(solnData(:,i,j,k), diffCoeff=diff_coeff_vec, component=2)  # 电子
   if (diff_anisoCondForEle) then
      diff_coeff = diff_coeff_vec(1) + diff_coeff_vec(2)  # parallel + perp
      if (diff_useCrossCond) diff_coeff += diff_coeff_vec(3)
   else
      diff_coeff = diff_coeff_vec(2)  # perp only
   end if
   if (diff_coeff > max_diffusivity(i,j,k) .and. xdens > diffusion_cutoff_density) then
      max_diffusivity(i,j,k) = diff_coeff
   end if
end if
```

### 7.3 abort（dt <= 0）

源码：`source/physics/Diffuse/DiffuseMain/Diffuse_computeDt.F90:L418`

```fortran
if (dt_check <= 0.0) call Driver_abortFlash("[Diffuse]: computed dt is not positive! Aborting!")
```

**为什么可能 dt <= 0**：
- D_max = 0（所有扩散系数都 0，真空算例）
- TINY 默认 1e-30 但 dx² 可能更小（极高分辨率）
- 数值问题（NaN in COND_VAR）

---

## 8. Diffuse_init 启动流程

源码：`source/physics/Diffuse/DiffuseMain/Diffuse_init.F90:L55-L212`（157 行）

```
Diffuse_init
│
├── Step 1: 读 MPI 信息（行 79-81）
│   └── diff_meshMe / diff_meshNumProcs / diff_meshComm
│
├── Step 2: 读主控参数（行 83-99）
│   ├── dt_diff_factor
│   ├── useDiffuseTherm
│   ├── useViscosity → useDiffuseVisc
│   ├── useMagneticResistivity → useDiffuseMagneticResistivity
│   ├── useDiffuseSpecies
│   ├── useDiffuseComputeDt{Therm,Visc,Species,Magnetic}
│   ├── diff_useEleCond / diff_useIonCond / diff_useCrossCond
│   ├── diffusion_cutoff_density
│   └── useDiffuse
│
├── Step 3: 读 geometry + 设方向几何（行 105-129）
│   ├── RuntimeParameters_get("geometry", str_geometry)
│   ├── RuntimeParameters_mapStrToInt(str_geometry, diff_geometry)
│   └── select case (diff_geometry):
│       ├── CARTESIAN: dirGeom = XYZ/XYZ/XYZ
│       ├── POLAR: dirGeom = RAD_CYL/PHI_CYL/XYZ
│       ├── CYLINDRICAL: dirGeom = RAD_CYL/XYZ/PHI_CYL
│       ├── SPHERICAL: dirGeom = RAD_SPH/THETA/PHI_SPH
│       └── default: call Driver_abortFlash("unsupported geometry ")   # ★ abort
│
├── Step 4: 读物理常量（行 140-146）
│   ├── diff_speedlt = c
│   ├── diff_asol = 4·σ_SB/c
│   ├── diff_mele, diff_boltz, diff_avo
│
├── Step 5: 读 flux limiter 模式 + 系数（行 153-167）
│   ├── diff_eleFlMode (mapStrToInt → 整数常量)
│   ├── diff_ionFlMode
│   ├── diff_magFlMode
│   ├── diff_eleFlCoef / diff_ionFlCoef / diff_magFlCoef
│
├── Step 6: 读磁扩散参数（if useDiffuseMagneticResistivity）（行 169-195）
│   ├── resistivitySolver, resistivityForm
│   └── 决定 diff_resVar = RES1_VAR (parallel) or RES2_VAR
│
└── Step 7: 子初始化（行 198-202）
    ├── diff_fbInit()    # flux-based 初始化
    ├── diff_viscInit()  # 粘性
    └── diff_magInit()   # 磁扩散
```

### 8.1 关键 abort

源码：`source/physics/Diffuse/DiffuseMain/Diffuse_init.F90:L128`

```fortran
else
   call Driver_abortFlash("unsupported geometry ")
end if
```

**为什么不支持的 geometry abort**：HYPRE 矩阵组装依赖几何（球坐标的 Jacobian 和笛卡尔不同），不支持的几何会产生错误矩阵。

---

## 9. 完整调用关系（文字 + 缩进）

```
Driver_evolveFlash（主循环）
│
├── (初始化) Driver_initFlash
│   └── Diffuse_init ★
│       ├── 读所有 diff_* 参数
│       ├── 读 geometry + 设 dirGeom
│       ├── 读物理常量
│       ├── 读 flux limiter 模式
│       ├── diff_saInit（读 BC + theta）
│       ├── diff_fbInit / diff_viscInit / diff_magInit
│       └── 验证（geometry 合法性）
│
├── (主循环每步)
│   ├── Step 1: Grid_fillGuardCells
│   ├── Step 2: Hydro / MHD
│   ├── Step 3: ★ Diffusive processes:
│   │   ├── RadTrans（MGD，flash-radtrans）
│   │   │   └── for 每群 g:
│   │   │       └── Diffuse_solveScalar(MGDRg, COND, DFCF, ...) → HYPRE
│   │   │
│   │   └── Diffuse(blockCount, blockList, dt) ★
│   │       ├── diff_advanceMag（if 磁扩散）
│   │       │   └── Diffuse_solveScalarMag(MAGX/Y/Z, RES_VAR, ...) → HYPRE
│   │       │
│   │       ├── diff_advanceTherm（if useDiffuseTherm）★ 主流程
│   │       │   ├── Step A: 电子热传导（if diff_useEleCond or 1T）
│   │       │   │   ├── Grid_fillGuardCells(TELE)
│   │       │   │   ├── 每 cell 算 COND_VAR/DFCF_VAR/FLLM_VAR
│   │       │   │   │   ├── Conductivity(...) → COND_VAR = κ
│   │       │   │   │   ├── Eos(mode) → cv → DFCF_VAR = ρ·cv
│   │       │   │   │   └── FLLM_VAR = coef · v_th · k_B·T · n_e
│   │       │   │   ├── Grid_fillGuardCells（全变量）
│   │       │   │   ├── Diffuse_fluxLimiter(COND, TELE, FLLM, mode)
│   │       │   │   │   └── 修改 COND_VAR = λ·κ
│   │       │   │   └── Diffuse_solveScalar(TELE, COND, DFCF, bcTypes, bcValues,
│   │       │   │                                 dt, ..., diff_thetaImplct, ...)
│   │       │   │       └── Grid_advanceDiffusion
│   │       │   │           ├── gr_hypreCreateMatrix（7 点模板组装 A）
│   │       │   │           ├── gr_hypreComputeB（组装 RHS b）
│   │       │   │           ├── gr_hypreApplyBcToFace（应用 6 面 BC）
│   │       │   │           └── gr_hypreSolve ★ 解 Ax=b
│   │       │   │               ├── gr_hypreSetupSolver（每步重建）
│   │       │   │               │   └── select case (gr_hypreSolverType)
│   │       │   │               │       ├── HYPRE_PCG → parCSRPCGCreate + PC=BoomerAMG
│   │       │   │               │       ├── HYPRE_AMG → BoomerAMGCreate
│   │       │   │               │       ├── HYPRE_BICGSTAB → parCSRBiCGSTABCreate
│   │       │   │               │       └── ...
│   │       │   │               ├── HYPRE_<Solver>Solve（实际迭代）
│   │       │   │               │   └── 检查收敛：final_res_norm <= relTol?
│   │       │   │               │       否 → blabber 警告（不 abort）
│   │       │   │               │       是 → 继续
│   │       │   │               └── gr_hypreUpdateSoln（x 写回 UNK → 更新 TELE_VAR）
│   │       │   │
│   │       │   ├── Step B: 离子热传导（if diff_useIonCond and 3T）
│   │       │   │   └── 同 A 但 TION_VAR，diff_ionThetaImplct
│   │       │   └── Step C: Eos_wrapped（让 TELE/EINT 自洽）
│   │       │
│   │       └── diff_advanceVisc（if useDiffuseVisc）
│   │
│   ├── Step 4: Driver_sourceTerms
│   │   ├── Heatexchange（电子-离子平衡）
│   │   └── EnergyDeposition（激光）
│   │
│   └── ...
│
├── Driver_computeDt（独立调）
│   └── Diffuse_computeDt（if useDiffuseComputeDt*）
│       └── dt = 0.5 · dx² / D_max · dt_diff_factor
│
└── (收尾) Driver_finalizeFlash
    └── Diffuse_finalize（空 stub）
```

---

## 10. 延伸阅读

- **Diffuse 总览 / 设计**：`knowledge/overview.md`
- **参数字典**：`knowledge/params.md`（diff_* / gr_hypre* 完整字典）
- **典型配置 / 5 求解器对比**：`knowledge/recipes.md`
- **常见错误（HYPRE 不收敛 / flux limiter 选错）**：`knowledge/pitfalls.md`
- **MGD 调 Diffuse_solveScalar**：`flash-radtrans/internals.md`（物理侧）
- **Conductivity 单元（COND_VAR 来源）**：`flash-material`（Phase 2）
- **EOS（cv 来源）**：`flash-eos` skill
- **Driver 主循环**：`flash-driver` skill
- **Grid / HYPRE 单元**：`flash-grid` skill
- **手册**：FLASH 4.8 User Guide §20, §23

---

## 11. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（beta）：11 段 internals；15 公共 API 分类；diff_advanceTherm 10 步流程含行号；Diffuse_solveScalar 内部；HYPRE 7 点矩阵组装公式；4 通量限制器模式代码片段；AMR composite grid / face coarsening；Diffuse_computeDt 公式；Diffuse_init 8 步启动流程；完整文字调用图（按 L-002 不用 mermaid）；公式用 ASCII（按 L-012）；abort 类按 L-008 贴源码（dt<=0、unsupported geometry、Invalid flux limiter）| claude |
