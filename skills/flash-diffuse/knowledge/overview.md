---
title: Diffuse 总览 — 角色 + Unsplit/Split + HYPRE 接口 + 通量限制器
skill: flash-diffuse
category: overview
source_anchors:
  - source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L87-L127
  - source/physics/Diffuse/DiffuseMain/Unsplit/diff_advanceTherm.F90:L64-L488
  - source/physics/Diffuse/DiffuseMain/Diffuse_fluxLimiter.F90:L57-L261
  - source/physics/Diffuse/DiffuseMain/Diffuse_computeFluxLimiter.F90:L63-L250
  - source/physics/Diffuse/DiffuseMain/Diffuse_computeDt.F90:L61-L423
  - source/Grid/GridSolvers/HYPRE/gr_hypreSetupSolver.F90:L51-L431
  - source/Grid/GridSolvers/HYPRE/Config:L31-L145
manual_ref: "FLASH 4.8 User Guide §20 Diffusion, §23 Heat Conduction"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: beta
tags:
  - diffuse
  - overview
  - hypre
  - flux-limiter
  - theta-implicit
  - thermal-conduction
---

# Diffuse 总览（Unsplit + HYPRE 聚焦）

> **TL;DR**：Diffuse 单元负责所有隐式扩散方程的求解——热传导（电子 / 离子）、磁扩散、粘性、质量扩散。**核心 API** 是 `Diffuse_solveScalar`（标量）、`Diffuse_solveScalarAniso`（各向异性）、`Diffuse_solveScalarMag`（磁）。**核心机制**：把扩散方程 `A·∂f/∂t + C·f = div(B·∇f) + D` 隐式离散（θ-加权）后调用 HYPRE 库解稀疏线性系统 `Ax=b`。LaserSlab 用 Unsplit + HYPRE_AMG（BoomerAMG）+ fl_larsen 通量限制器，是 HEDP 标准配置。

---

## 术语速查（按 L-014，先解释再讲机制）

第一次出现的术语先一句话定义，再讲机制。

### 物理概念

- **扩散方程（diffusion equation）**：描述物理量（温度、磁场、动量）随时间在空间中"散开"的偏微分方程。一般形式 `∂f/∂t = ∇·(D·∇f)`，其中 D 是扩散系数（如热传导的 D = κ/(ρcv)）。**为什么需要**：很多物理过程（热传导、磁扩散、粘性、辐射扩散）都是这种形式，统一求解避免代码重复。
- **热传导（thermal conduction / heat conduction）**：温度从高温区流向低温区。Fick 定律：热通量 `F = -κ∇T`，κ 是电导率（W/(cm·K)）。**为什么需要**：HEDP 算例激光沉积到电子后，热通过电子传导扩散到周围物质。
- **磁扩散（magnetic diffusion）**：磁场在电阻等离子体中"扩散衰减"。方程 `∂B/∂t = ∇×(η∇×B)`，η 是电阻率。**为什么需要**：MHD 算例里磁场和流体演化耦合，磁扩散用隐式求解避免刚性。
- **各向异性扩散（anisotropic diffusion）**：扩散系数随方向不同（平行 vs 垂直磁场）。强磁场等离子体里电子沿磁力线运动远比垂直快。**为什么需要**：MHD 算例磁场强时，普通各向同性扩散会严重高估垂直热传导。

### 数值 / 算法概念

- **隐式求解（implicit）vs 显式（explicit）**：时间离散方式。显式 `f^{n+1} = f^n + dt·D·∇²f^n`（用旧值算新值，简单但稳定条件苛刻 `dt < 0.5·dx²/D`）；隐式 `f^{n+1} = f^n + dt·D·∇²f^{n+1}`（用新值算新值，需要解线性方程组，但无条件稳定）。**为什么用隐式**：HEDP 算例热传导系数极大（高温等离子体），显式 dt 会小到 1e-20 s 不可用，必须隐式。
- **θ-加权（theta-weighted）**：时间离散的隐式度参数。一般形式 `f^{n+1} - f^n = dt·[θ·D·∇²f^{n+1} + (1-θ)·D·∇²f^n]`。`θ=0` 全显式；`θ=1` 全隐式 / 后向 Euler（无条件稳定，1 阶精度）；`θ=0.5` Crank-Nicolson（2 阶精度，可能震荡）。**为什么默认 0.5**：精度优先；**为什么 LaserSlab 用 1.0**：稳定性优先（陡梯度 CN 会震荡）。
- **多重网格（Multigrid）**：加速迭代法收敛的算法。在粗-细网格层次间循环，长波长误差在粗网格快速消除，短波长在细网格处理。**为什么需要**：单网格迭代法收敛慢（O(N) 步），多重网格 O(1) 步收敛。
- **预条件子（preconditioner, PC）**：把 `Ax=b` 变成更容易解的形式 `M⁻¹Ax = M⁻¹b`，其中 M 是近似 A 但容易求逆的矩阵。**为什么需要**：CG / GMRES 等迭代法对原始矩阵收敛慢，预条件后快几个数量级。FLASH 常用 AMG（多重网格）作为 PC。
- **AMG（Algebraic MultiGrid）**：基于矩阵代数性质自动构造粗-细层次的多重网格，不需要几何信息。**为什么需要**：AMR 网格的几何复杂，AMG 自动适应。
- **BoomerAMG**：HYPRE 库里 AMG 的具体实现，是 LLNL 开发的"经典 AMG"。**为什么默认它**：稳健，对各种问题都表现不错，是 HYPRE 推荐默认。
- **PFMG（Piecewise constant Multigrid）**：HYPRE 里另一种多重网格，适用于结构化网格（如 PARAMESH 的 block 结构）。比 AMG 简单快，但对非结构化问题弱。
- **PCG（Preconditioned Conjugate Gradient）**：预条件共轭梯度法。**为什么需要**：扩散方程离散后是对称正定矩阵，CG 是这类问题的最优迭代法，加 AMG 预条件几步就收敛。
- **BiCGSTAB**：双共轭梯度稳定法。**为什么需要**：非对称矩阵（flux limiter 让系数 cell-face 依赖）CG 不适用，BiCGSTAB 适用。
- **GMRES**：广义最小残差法。**为什么需要**：最难收敛的问题用，存储 O(k)（k 是迭代数），需要重启。
- **operator-split**：把复杂多物理过程拆成"一次解一个"的策略。Diffuse 在 Driver 第 3 位（Hydro 后）独立调用，不和 Hydro 耦合。**为什么用**：每个物理过程用各自最优的算法（Hydro 用 Godunov，Diffuse 用 HYPRE 隐式）。
- **flux limiter（通量限制器）**：限制扩散通量不超过物理上限（如自由流极限 `F_max = n·k_B·T·v_thermal`）的数学函数。**为什么需要**：低密度 / 光学薄区纯扩散会让通量超光速（物理不可能），flux limiter 把有效扩散系数降低。
- **自由流极限（free-streaming limit）**：粒子以热速度 `v_th = sqrt(k_B·T/m)` 直线运动的通量上限。`F_fs = n·k_B·T·v_th`。**为什么需要**：扩散方程在平均自由程 >> 网格尺度时不适用，需要让通量饱和到这个上限。

### 工程 / 代码概念

- **HYPRE**：美国 Lawrence Livermore National Laboratory (LLNL) 开发的解大稀疏线性方程组 `Ax=b` 的数学库（C 写的，Fortran 接口）。提供 BoomerAMG / PFMG / PCG / BiCGSTAB / GMRES / Hybrid 等求解器，支持 MPI 分布式并行。**为什么用它**：FLASH 把扩散方程离散后变成百万级稀疏线性系统，普通高斯消元 O(N³) = 10¹⁸ 次运算不可行，HYPRE 用迭代法 + 多重网格几秒解完。**不是 FLASH 内部组件**——外部依赖，需先编译安装（见 `Makefile.h` 的 `HYPRE_PATH`）。
- **Diffuse_solveScalar**：FLASH 的标量扩散方程求解接口（在 `physics/Diffuse/` 单元）。**真正的求解在 Grid 层**（`Grid_advanceDiffusion` 调 HYPRE）。**为什么设计成 thin wrapper**：抽象层让物理单元（RadTrans / Diffuse_therm）不必管 HYPRE API 细节，且支持换 Grid 求解器（HYPRE / 其他）。
- **Grid_advanceDiffusion**：Grid 层的扩散求解实现（在 `Grid/GridSolvers/HYPRE/`）。这是 FLASH 真正调 HYPRE 的地方。
- **unk / UNK**：FLASH 的 cell-centered 网格变量存储（Unknowns）。如 `TEMP_VAR`、`TELE_VAR`、`COND_VAR`、`DFCF_VAR`。
- **guard cell**：每个 block 边界外的"虚拟单元"，存邻居 block 的数据。扩散算梯度需要邻居值，guard cell 提供数据。每次扩散前先 `Grid_fillGuardCells`。

---

## 1. Diffuse 是什么 / 做什么

### 1.1 角色：所有"扩散类"物理的统一求解器

源码：`source/physics/Diffuse/`（顶层）+ `source/physics/Diffuse/DiffuseMain/`（实现）

**Diffuse 单元**是 FLASH 处理所有扩散型偏微分方程的统一接口。覆盖的物理：

| 物理类型 | 方程 | 变量 | API |
|---|---|---|---|
| 电子热传导 | `ρ·cv_ele·∂T_ele/∂t = ∇·(κ_ele·∇T_ele)` | `TELE_VAR` | `diff_advanceTherm` |
| 离子热传导 | `ρ·cv_ion·∂T_ion/∂t = ∇·(κ_ion·∇T_ion)` | `TION_VAR` | `diff_advanceTherm`（3T 专属）|
| 磁扩散 | `∂B/∂t = ∇×(η·∇×B)` | `MAGX/Y/Z_VAR` | `diff_advanceMag` |
| 粘性扩散 | Navier-Stokes 粘性项 | 速度 | `diff_advanceVisc` |
| 质量扩散 | Fick 扩散（未完全实现）| 物种分数 | `Diffuse_species`（stub）|
| MGD 辐射扩散 | `1/c·∂E_g/∂t = ∇·(D_g·∇E_g) + 源` | `MGDRg_VAR` | `RadTrans` → `Diffuse_solveScalar` |

### 1.2 一般形式

所有扩散方程可以写成统一形式（`source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solve.F90:L1-L12`）：

```
A_i · (∂U_i/∂t) = C_ij·U_j + ∂_k(B_ijkl · ∂_l U_j) + D_i
```

其中：
- `U_i`：要解的变量（如 TELE、B）
- `A_i`：左端系数（如 `ρ·cv`）
- `B_ijkl`：扩散系数张量（电导率 / 电阻率）
- `C_ij`：耦合矩阵（如辐射-物质能量交换）
- `D_i`：源项

**对应到代码变量**（`source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L87-L109`）：
- `iVar`：U 的 UNK 索引（如 `TELE_VAR`）
- `iFactorA`：A 的 UNK 索引（如 `DFCF_VAR = ρ·cv`）
- `iFactorB`：B 的 UNK 索引（如 `COND_VAR = κ`）
- `iFactorC`：C 的 UNK 索引（可选，MGD 吸收项用）
- `iFactorD`：D 的 UNK 索引（可选，MGD 发射项用）

### 1.3 为什么要单独建一个单元

- **代码复用**：5+ 种扩散物理共享同一求解器
- **算法统一**：所有扩散都用隐式 + HYPRE（避免每个物理单独实现）
- **可扩展性**：加新扩散物理只需写 setup / 调用 `Diffuse_solveScalar`，求解器不用动

---

## 2. 主流路径：Unsplit + HYPRE（LaserSlab 用的）

### 2.1 Unsplit vs Split 对比（按 L-013 聚焦 Unsplit）

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/` vs `source/physics/Diffuse/DiffuseMain/Split/`

| 维度 | **Unsplit**（主流，详讲） | Split（边缘，简要） |
|---|---|---|
| 求解策略 | 多维联合求解（一次解整个 2D/3D 矩阵） | 维度分裂（1D X → 1D Y → 1D Z 串行） |
| 调用 HYPRE | 是，每步调一次（多维联合矩阵）| 是，每步调 NDIM 次（每维一次）|
| 精度 | 2 阶（全隐式 + θ=0.5 时）| 1 阶（分裂误差）|
| 时间步 | 无限制（θ=1 时）| 受限于分裂格式 |
| 边界处理 | 完整 6 面 BC | 每维分别 BC |
| LaserSlab 用？ | **是**（HEDP 标准配置）| 否 |
| AMR 兼容 | 是（HYPRE 处理 coarse-fine 边界）| 是 |
| 何时选 Split | 调试、教学、极简单问题 | 默认 |
| 实现位置 | `DiffuseMain/Unsplit/` | `DiffuseMain/Split/` |
| 关键 API | `Diffuse_solveScalar` → `Grid_advanceDiffusion` | `Diffuse_advance1D` → 1D Thomas 算法 |

**LaserSlab 用 Unsplit 的原因**：
- 多维联合精度高（2 阶 vs 1 阶分裂）
- HEDP 物理需要全耦合求解（温度场和辐射场强耦合）
- AMR 兼容好（HYPRE 自动处理 coarse-fine）
- 不用 Strang splitting（避免分裂误差）

**Unsplit 实现关键文件**：

| 文件 | 行数 | 角色 |
|---|---|---|
| `Diffuse_solveScalar.F90` | 200 | thin wrapper，调 `Grid_advanceDiffusion` |
| `diff_advanceTherm.F90` | 488 | **热传导每步调**（电子+离子）|
| `diff_advanceVisc.F90` | ~330 | 粘性扩散（简要）|
| `diff_getFaceFluxes.F90` | 21K | face fluxes 计算（diff_updEint=true 时）|
| `diff_updateEnergy.F90` | ~100 | 更新 EINT_VAR（能量守恒）|
| `diff_saInit.F90` | 177 | 读 BC + theta 参数 |
| `diff_saData.F90` | 57 | Unsplit 状态模块 |

### 2.2 DiffuseMain 三变体（按 L-013）

```
DiffuseMain/（Config 在 DiffuseMain/Config）
├── Unsplit/    ★ LaserSlab 用，HEDP 主流
├── Split/      1D 分裂，教学用
├── CG/         共轭梯度（旧版，不用 HYPRE）
└── ... (Diffuse_computeDt / Diffuse_fluxLimiter 等共享文件)
```

**选择规则**（`source/physics/Diffuse/DiffuseMain/Config`）：
```
EXCLUSIVE Unsplit Split CG    # 三选一
```

setup 时通过 `REQUESTS physics/Diffuse/DiffuseMain/Unsplit`（或 Split/CG）选。LaserSlab 用 Unsplit（见 `source/Simulation/SimulationMain/LaserSlab/Config`）。

---

## 3. HYPRE 接口

### 3.1 调用层次（按 L-002 文字 + 缩进）

```
物理单元（每步调）
├── Diffuse_therm / Diffuse_visc / RadTrans
│   └── diff_advanceTherm（Per-block 设 COND_VAR、DFCF_VAR、FLLM_VAR）
│       │
│       ├── Diffuse_fluxLimiter（修改 COND_VAR = λ·κ）
│       │
│       └── Diffuse_solveScalar(iVar, iFactorB, iFactorA, ...) ★
│           │   thin wrapper（source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L87）
│           │
│           └── Grid_advanceDiffusion(iVar, iSrc, iFactorB, iFactorA, ...) ★
│               │   Grid 层（source/Grid/GridSolvers/HYPRE/Grid_advanceDiffusion.F90:L84）
│               │
│               ├── gr_hypreCreateMatrix（组装稀疏矩阵 A）
│               │   └── 7 点模板（3D）：每 cell 中心系数 + 6 邻居系数
│               │       中心：(ρcv)/dt + θ·Σ_faces (κ_face / dx²)
│               │       邻居：-θ·(κ_face / dx²)
│               │
│               ├── gr_hypreComputeB（组装 RHS b）
│               │   └── b = (1-θ)·Σ_faces (κ·∇²T_old) + (ρcv)/dt·T_old + source
│               │
│               ├── gr_hypreApplyBcToFace（应用边界条件）
│               │
│               └── gr_hypreSolve ★ 解 Ax=b
│                   │
│                   ├── gr_hypreSetupSolver（每步重设，按 HYPRE 团队建议）
│                   │   ├── select case (gr_hypreSolverType)
│                   │   │   ├── HYPRE_PCG     → parCSRPCGCreate
│                   │   │   ├── HYPRE_AMG     → BoomerAMGCreate
│                   │   │   ├── HYPRE_BICGSTAB → parCSRBiCGSTABCreate
│                   │   │   ├── HYPRE_GMRES   → parCSRGMRESCreate
│                   │   │   └── HYPRE_HYBRID  → ParCSRHybridCreate
│                   │   │
│                   │   └── select case (gr_hyprePCType)
│                   │       ├── HYPRE_AMG      → BoomerAMG 作 PC（默认）
│                   │       ├── HYPRE_ILU      → Euclid ILU 作 PC
│                   │       └── HYPRE_PARASAILS → ParaSails 作 PC
│                   │
│                   └── HYPRE_<Solver>Solve（实际迭代解）
│                       └── 输出 num_iterations、final_res_norm
│                           └── 检查收敛：final_res_norm <= gr_hypreRelTol？
│                               否 → blabber 警告 + 继续（不 abort）
│                               是 → gr_hypreUpdateSoln 把 x 写回 UNK
```

### 3.2 为什么是这个层次

| 层次 | 为什么这样设计 |
|---|---|
| 物理单元 → diff_advanceTherm | 物理 setup（算 COND_VAR、应用 flux limiter）|
| Diffuse_solveScalar 是 wrapper | 抽象 Grid 层，未来可换非 HYPRE 求解器 |
| Grid_advanceDiffusion 在 Grid 层 | Grid 知道数据布局（block / AMR），物理单元不知道 |
| HYPRE 求解器对象每步重建 | HYPRE 团队建议（2013-01-09 Rob Falgout 推荐），避免 communicator 泄漏 |
| 不直接 abort | HYPRE 不收敛只警告，让物理继续（可能下一步收敛）|

### 3.3 HYPRE 矩阵结构

**每 cell 一个未知数**（cell-centered，存 UNK），3D 7 点模板：

```
对 cell (i,j,k)：
  中心系数：A[(i,j,k),(i,j,k)] = (ρcv)/dt + θ·Σ_faces (κ_face / dx²)
  6 邻居：A[(i,j,k),(i±1,j,k)] = -θ·(κ_face / dx²)
       A[(i,j,k),(i,j±1,k)] = -θ·(κ_face / dy²)
       A[(i,j,k),(i,j,k±1)] = -θ·(κ_face / dz²)
```

**矩阵大小**：Ncells × Ncells（Ncells = 所有 leaf cell 数）。LaserSlab 2D 典型 ~10⁵ cells，矩阵 10¹⁰ 元素但每行仅 5 个非零，稀疏存储 O(Ncells) 内存。

**对称性**：常数系数时对称；flux limiter 让系数 cell-face 依赖 → 一般非对称（这是为什么需要 BiCGSTAB 而不只是 PCG）。

**AMR 处理**：HYPRE 通过 FLASH Grid 的 composite grid 信息自动处理 coarse-fine 边界（face-coarsened），不需要物理单元操心。

---

## 4. 通量限制器（flux limiter）

### 4.1 为什么需要 flux limiter

**问题**：纯扩散方程 `F = -κ∇T` 在低密度 / 陡梯度区会让通量超物理上限。

例子：HEDP 激光沉积，电子温度梯度极大，纯扩散计算 `F = -κ∇T` 可能超过自由流极限：
```
F_fs = n_e · k_B · T · v_th        # 自由流极限（粒子以热速度直线运动）
v_th = sqrt(k_B · T / m_e)
```

如果不限制，扩散通量会超光速（物理不可能）。

### 4.2 数学形式

引入"有效扩散系数" `D_eff`，让 `F = -D_eff·∇T` 在大梯度时饱和到 `F_fs`。定义：
```
R = D_old · |∇T| / F_fs           # 比值（梯度大小的无量纲化）
λ(R) = D_eff / D_old              # 通量限制因子（0 < λ ≤ 1）
```

FLASH 把 `λ·3` 存到 `FLLM_VAR`（注意：是 λ 的 3 倍，因为 Levermore-Pomraning 1981 论文形式）。

### 4.3 4 种模式（按 L-013 主流详讲）

源码：`source/physics/Diffuse/DiffuseMain/Diffuse_fluxLimiter.F90:L173-L211`

| 模式 | 公式 | 特点 | 何时用 |
|---|---|---|---|
| `fl_none` | 不限制（λ=1） | 危险，超光速 | **默认但不推荐**——纯扩散问题用 |
| `fl_harmonic` | `1/D_eff = 1/D_old + |∇T|/F_fs`（调和平均） | 保守，平滑过渡 | MGD 辐射扩散（常用）|
| `fl_minmax` | `D_eff = min(D_old, F_fs/|∇T|)`（最小者） | 最保守，会突然饱和 | 极端强梯度 |
| **`fl_larsen`** | `1/D_eff² = 1/D_old² + (|∇T|/F_fs)²`（平方和根） | 平滑，HEDP 标准 | **LaserSlab 用**（电子热传导 coef=0.06）|
| `fl_levermorepomraning1981` | `λ = 3·(2+R)/(6+3R+R²)` | 理论严格，复杂 | 精确研究（少见）|

### 4.4 LaserSlab 标准配置

```
diff_eleFlMode  = "fl_larsen"   # 平滑过渡
diff_eleFlCoef  = 0.06          # 让有效热传导为自由流的 6%（HEDP 经验值）
```

源码：`source/Simulation/SimulationMain/LaserSlab/flash.par`

**为什么 0.06**：HEDP 实验经验值，让 Spitzer 算出的高电导率在低密度区被限制到 6% 自由流。这个值在 LaserSlab / Flash 大量文献中作为推荐初值。

### 4.5 FLLM_VAR 是什么

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/Config:L106-L110`

```
VARIABLE FLLM     # flux limit (input/output)
```

- **输入**（每 cell 算好）：FLLM_VAR = `diff_eleFlCoef · sqrt(k_B·T/m_e) · k_B·T · (Ye·avo·ρ)` = `coef · F_fs / |∇T|`（自由流通量除以梯度量级，使 R 量级合理）
- **输出**（flux limiter 算后）：被覆盖为 `3·λ`（用于诊断，可看出哪些区被限制了）

---

## 5. 与其他单元的耦合

### 5.1 调用关系

```
Driver_evolveFlash（主循环每步）
│
├── (Step 1) Grid_fillGuardCells
├── (Step 2) Hydro / MHD
├── (Step 3) ★ Diffusive processes:
│   ├── RadTrans（MGD 多群扩散，flash-radtrans）
│   │   └── 内部循环每群调 Diffuse_solveScalar → HYPRE
│   │
│   └── Diffuse(blockCount, blockList, dt) ★
│       ├── diff_advanceMag（磁扩散，可选）
│       ├── diff_advanceTherm（热传导，主流）
│       │   ├── 算 COND_VAR = Conductivity(...)（flash-material）
│       │   ├── 算 DFCF_VAR = ρ·cv（EOS）
│       │   ├── 算 FLLM_VAR = 自由流通量
│       │   ├── Diffuse_fluxLimiter(COND_VAR, ..., FLLM_VAR, ...)
│       │   │   └── 修改 COND_VAR = λ·κ
│       │   └── Diffuse_solveScalar(TELE_VAR, COND_VAR, DFCF_VAR, ...)
│       │       └── Grid_advanceDiffusion → HYPRE 解 → 更新 TELE_VAR
│       │
│       └── diff_advanceVisc（粘性扩散，可选）
│
├── (Step 4) Driver_sourceTerms（Heatexchange 等）
└── ...
```

源码：`source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90:L302-L311`（默认）/ `:L326-L335`（DRIVER_DIFFULAST 模式）

### 5.2 DRIVER_DIFFULAST 是什么

源码：`source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90:L302-L335`

`#define DRIVER_DIFFULAST` 编译期宏，让 Diffuse 调用顺序从"Hydro 后"（默认）变到"sourceTerms 后"。**为什么需要**：某些算例希望 Heatexchange 在 Diffuse 前算（让 TELE/TEION 先平衡再做热传导），这需要 `setup -debug` 或修改 setup_defines 加这个宏。

### 5.3 上游 / 下游

| 方向 | 单元 | 关系 |
|---|---|---|
| 上游 | Conductivity | 提供 κ（电导率）→ 写到 COND_VAR |
| 上游 | EOS | 提供 cv（比热）→ 写到 DFCF_VAR；Diffuse 后调 `Eos_wrapped` 让 TELE/EINT 自洽 |
| 上游 | Hydro | 提供流体状态（密度、温度）|
| 下游 | TELE_VAR / TION_VAR | 直接更新（diff_advanceTherm）|
| 下游 | EINT_VAR / ENER_VAR | diff_updEint=true 时更新（能量守恒）|
| 下游 | MAGX/Y/Z_VAR | diff_advanceMag 更新 |
| 互补 | RadTrans | MGD 通过 Diffuse_solveScalar 调用同一 HYPRE 求解器 |

---

## 6. 边缘变体简要（按 L-013）

### 6.1 Split（1D 分裂）

源码：`source/physics/Diffuse/DiffuseMain/Split/`

按 X → Y → Z 顺序，每维独立 1D 求解（Thomas 算法或类似）。**优点**：简单，不依赖 HYPRE。**缺点**：1 阶精度（分裂误差），多维耦合差。**何时用**：教学、简单测试、HYPRE 不可用。LaserSlab 不用。

### 6.2 CG（共轭梯度，旧）

源码：`source/physics/Diffuse/DiffuseMain/CG/`

FLASH 自己实现的 CG，不依赖 HYPRE。**为什么不推荐**：性能不如 HYPRE（没多重网格），维护少。**何时用**：HYPRE 不可用时。

### 6.3 DiffuseFluxBased

源码：`source/physics/Diffuse/DiffuseFluxBased/`

不独立求解扩散方程，而是修改 Hydro 的能量通量（加 `F = -κ∇T` 项）。**优点**：和 Hydro 耦合自然（不分裂）。**缺点**：显式（受 CFL 限制 `dt < 0.5·dx²/D`）。**何时用**：粘性、磁扩散等小扩散系数物理（diffusion_CFL 不是瓶颈）。**LaserSlab 不用**（电子热传导系数太大，显式 dt 不可接受）。

### 6.4 Polar（柱坐标）

几何变体（不是独立求解器），r-θ 网格的扩散。在 Unsplit / Split 内通过 `diff_geometry == POLAR` 分支处理。

---

## 7. 延伸阅读

- **Diffuse 内部实现**：`knowledge/internals.md`（Diffuse_solveScalar 流程 + HYPRE 矩阵组装 + 通量限制器实现）
- **参数字典**：`knowledge/params.md`（diff_* / gr_hypre* 完整字典）
- **典型配置**：`knowledge/recipes.md`（LaserSlab 配置 + 5 求解器对比 + parfile）
- **常见错误**：`knowledge/pitfalls.md`（HYPRE 不收敛、flux limiter 选错等 + 诊断引导）
- **MGD 物理**：`flash-radtrans` skill（MGD 调 Diffuse_solveScalar 的物理侧）
- **电导率计算**：`flash-material` skill（Phase 2，Conductivity 单元）
- **EOS 三温耦合**：`flash-eos` skill
- **Driver 主循环**：`flash-driver` skill
- **手册**：FLASH 4.8 User Guide §20 Diffusion, §23 Heat Conduction

---

## 8. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（beta）：8 段 overview；术语速查段（按 L-014 解释 HYPRE / BoomerAMG / θ-加权 / flux limiter / 多重网格 / 自由流极限等）；按 L-013 聚焦 Unsplit+HYPRE 主流；Split/CG/DiffuseFluxBased/Polar 简要带过；4 通量限制器模式详讲 + LaserSlab 配置；调用关系用文字+缩进（按 L-002 不用 mermaid）；公式用 ASCII（按 L-012）；按 L-011 讲为什么默认值/为什么这么设计 | claude |
