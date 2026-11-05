---
title: Diffuse 参数完整字典 — diff_* + gr_hypre* + flux limiter
skill: flash-diffuse
category: params
source_anchors:
  - source/physics/Diffuse/DiffuseMain/Unsplit/Config:L1-L128
  - source/physics/Diffuse/DiffuseMain/Config:L1-L45
  - source/Grid/GridSolvers/HYPRE/Config:L31-L155
  - source/physics/Diffuse/DiffuseMain/Diffuse_computeDt.F90:L406-L418
manual_ref: "FLASH 4.8 User Guide §20 Diffusion"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: beta
tags:
  - diffuse
  - params
  - runtime-parameters
  - hypre
  - flux-limiter
---

# Diffuse 参数字典（diff_* + gr_hypre* + flux limiter）

> **TL;DR**：~45 个 RuntimeParameters 分 4 类：(1) 主控（useDiffuse / useDiffuseTherm / dt_diff_factor 等）；(2) θ + flux limiter（diff_thetaImplct / diff_eleFlMode / Coef）；(3) 边界条件（diff_eleXlBoundaryType 等）；(4) HYPRE 求解器（gr_hypreSolverType / PCType / RelTol / MaxIter）。**主流路径**（LaserSlab 用的）详讲，边缘参数简表（按 L-013）。

---

## 1. Diffuse 主控参数

源码：`source/physics/Diffuse/DiffuseMain/Config:L11-L40` + `source/physics/Diffuse/Config:L5-L15`

### 1.1 总开关

| 参数 | 类型 | 默认 | 含义 / 为什么这么设 | 声明位置 |
|---|---|---|---|---|
| `useDiffuse` | BOOLEAN | TRUE | Diffuse 单元总开关。**为什么默认开**：即使不用热传导，Diffuse 也提供 stub 接口让 Driver 调用，避免编译错。LaserSlab 显式设 `.true.`。| `DiffuseMain/Config:L14` |
| `useDiffuseTherm` | BOOLEAN | TRUE | 热传导开关（电子+离子）。**为什么默认开**：3T EOS 算例几乎都用。| `DiffuseMain/Config:L18` |
| `useDiffuseVisc` | BOOLEAN | FALSE（视 useViscosity） | 粘性扩散开关。**为什么这样**：从 `useViscosity .and. .not. useExplicitViscosity` 算出（见 `Diffuse_init.F90:L87`），显式粘性由 Hydro 处理。| `DiffuseMain/Config:L19` + init |
| `useDiffuseSpecies` | BOOLEAN | TRUE | 质量扩散开关。**为什么默认开但实际不工作**：接口存在但实现是 stub（`Diffuse_species.F90`），FLASH 4.8 未完成。| `DiffuseMain/Config:L20` |
| `useDiffuseMagneticResistivity` | BOOLEAN | FALSE | 磁扩散开关。**为什么默认关**：只有 MHD 算例需要。从 `useMagneticResistivity` 读入。| init:L88 |
| `dt_diff_factor` | REAL | 0.8 | Diffuse_computeDt 返回的 dt 乘以这个系数。**为什么默认 0.8**：保守系数，避免边界 dt 太大。**为什么 LaserSlab 设 1e100**：禁用显式 dt 限制（隐式不需要，见 `pitfalls.md §C`）。| `DiffuseMain/Config:L16` |
| `diffusion_cutoff_density` | REAL | 1.e-30 | 密度低于此值时关掉扩散（COND_VAR=0）。**为什么默认 1e-30**：避免真空区产生奇异矩阵。HEDP 算例通常调到 1e-5（g/cm³）让低密度区不扩散。| `DiffuseMain/Config:L22` |

### 1.2 各向同性 vs 各向异性

| 参数 | 类型 | 默认 | 含义 / 为什么 | 声明位置 |
|---|---|---|---|---|
| `diff_useEleCond` | BOOLEAN | FALSE | 电子热传导开关。**为什么默认关**：需要 3T EOS（TELE_VAR）。LaserSlab 显式设 `.true.`。| `DiffuseMain/Config:L37` |
| `diff_useIonCond` | BOOLEAN | FALSE | 离子热传导开关。**为什么默认关**：3T 专属，1T 算例用 TEMP_VAR。| `DiffuseMain/Config:L38` |
| `diff_anisoCondForEle` | BOOLEAN | CONSTANT FALSE | 电子各向异性扩散开关。**为什么是 CONSTANT**：需要 setup 期 `SupportAnisoCond` 变量（MHD），运行时不能改。| `DiffuseMain/Config:L46-L50` |
| `diff_anisoCondForIon` | BOOLEAN | FALSE | 离子各向异性扩散。同上规则。| `DiffuseMain/Config:L48` |
| `diff_useCrossCond` | BOOLEAN | CONSTANT FALSE | 各向异性扩散的交叉项（CND3_VAR）。**为什么默认关**：复杂物理，少见用。| `DiffuseMain/Config:L47` |
| `diff_doMagDiff` | BOOLEAN | FALSE | 磁扩散（独立 vs flux-based）。**为什么默认关**：MHD 专属。| `DiffuseMain/Config:L40` |
| `diff_doAnisoMagDiff` | BOOLEAN | FALSE | 各向异性磁扩散。| `DiffuseMain/Config:L41` |

### 1.3 时间步 / computeDt 开关

| 参数 | 类型 | 默认 | 含义 | 声明位置 |
|---|---|---|---|---|
| `useDiffuseComputeDtTherm` | BOOLEAN | TRUE | Diffuse_computeDt 是否考虑热传导。**为什么默认开**：热传导系数大，dt 限制重要。**为什么 LaserSlab 关（隐式）**：隐式不需要。| `DiffuseMain/Config:L32` |
| `useDiffuseComputeDtVisc` | BOOLEAN | TRUE | 同上，粘性。| `DiffuseMain/Config:L33` |
| `useDiffuseComputeDtSpecies` | BOOLEAN | TRUE | 同上，质量扩散。| `DiffuseMain/Config:L34` |
| `useDiffuseComputeDtmagnetic` | BOOLEAN | TRUE | 同上，磁扩散。| `DiffuseMain/Config:L35` |

### 1.4 standalone 缩放参数

| 参数 | 类型 | 默认 | 含义 / 为什么 | 声明位置 |
|---|---|---|---|---|
| `diff_scaleFactThermSaTempDiff` | REAL | 1.0 | 热传导 standalone 实现的温度差缩放。**为什么默认 1.0**：不缩放。调试时可设 0.5 让每步温度变化减半（提高稳定性，损失精度）。| `DiffuseMain/Config:L61` |
| `diff_scaleFactThermSaTime` | REAL | 1.0 | 热传导 standalone 时间步缩放。设 2.0 让 Diffuse 用 2·dt 推进（精度损失）。| `DiffuseMain/Config:L62` |
| `diff_updEint` | BOOLEAN | FALSE | 是否更新 EINT_VAR（能量守恒）。**为什么默认关**：默认只更新 TEMP_VAR，EOS 调和后再算 EINT。设 `.true.` 时直接更新 EINT_VAR（用于严格能量守恒）。| `Unsplit/Config:L42` |

---

## 2. θ + flux limiter（核心物理参数）

### 2.1 隐式度 θ（最关键）

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/Config:L25-L29`

| 参数 | 类型 | 默认 | 范围 | 含义 / 为什么 | 声明位置 |
|---|---|---|---|---|---|
| `diff_thetaImplct` | REAL | 0.5 | [0.0, 1.0] | 电子热传导隐式度。θ=1 后向 Euler（无条件稳定）；θ=0.5 Crank-Nicolson（2 阶）；θ=0 全显式（不稳定）。**为什么默认 0.5**：精度优先（2 阶）。**为什么 LaserSlab 设 1.0**：稳定性优先（HEDP 陡梯度 CN 震荡）。| `Unsplit/Config:L26` |
| `diff_ionThetaImplct` | REAL | 0.5 | [0.0, 1.0] | 离子热传导隐式度。**为什么独立**：电子和离子扩散系数差几个数量级，可能需要不同 θ。| `Unsplit/Config:L29` |

**典型值选择**（按 L-011）：

| 场景 | θ 值 | 为什么 |
|---|---|---|
| 教学简单扩散 | 0.5 | 2 阶精度，温和条件稳定 |
| LaserSlab HEDP（陡梯度）| 1.0 | 后向 Euler 无条件稳定，避免 CN 震荡 |
| MGD 辐射扩散 | 1.0 | 同上（rt_mgdthetaImplct）|
| 极强非线性 | 0.7~1.0 | 折中，逐步稳定 |
| Debug / 测试 | 0.5 + 小 dt | 精度优先，dt 控制稳定 |

### 2.2 flux limiter 模式

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/Config:L112-L120`

| 参数 | 类型 | 默认 | 允许值 | 含义 |
|---|---|---|---|---|
| `diff_eleFlMode` | STRING | "fl_none" | fl_none / fl_harmonic / fl_minmax / fl_larsen / fl_levermorepomraning1981 | 电子热传导 flux limiter 模式 |
| `diff_ionFlMode` | STRING | "fl_none" | fl_none / fl_harmonic / fl_minmax / fl_larsen | 离子热传导 flux limiter 模式（没 lev-pom）|
| `diff_magFlMode` | STRING | "fl_none" | 同 ele + lev-pom | 磁扩散 flux limiter |

**为什么默认 fl_none 危险**：纯扩散会超光速（物理不可能）。HEDP 算例必须显式设 `fl_larsen`（LaserSlab）或 `fl_harmonic`（MGD）。

**模式对比**（详见 `overview.md §4`）：

| 模式 | 公式 | 平滑度 | 保守性 | 何时用 |
|---|---|---|---|---|
| `fl_none` | 不限制 | - | 危险 | 纯扩散问题（不存在超光速）|
| `fl_harmonic` | `1/D_eff = 1/D_old + |∇T|/F_fs` | 平滑 | 中等 | MGD 辐射扩散（推荐）|
| `fl_minmax` | `D_eff = min(D_old, F_fs/|∇T|)` | 突变 | 最保守 | 极端梯度 |
| `fl_larsen` | `1/D_eff² = ...`（平方和根） | 最平滑 | 中等 | **HEDP 电子热传导（LaserSlab 标准）**|
| `fl_levermorepomraning1981` | `λ = 3·(2+R)/(6+3R+R²)` | 平滑 | 理论 | 精确研究 |

### 2.3 flux limiter 系数

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/Config:L121-L128`

| 参数 | 类型 | 默认 | 含义 / 为什么 | 声明位置 |
|---|---|---|---|---|
| `diff_eleFlCoef` | REAL | 1.0 | 电子 flux limiter 系数。**为什么默认 1.0**：保守上界，让自由流通量满限。**为什么 LaserSlab 设 0.06**：HEDP 经验值，让有效热传导为自由流的 6%（Spitzer 算出的电导率在低密度区高估）。| `Unsplit/Config:L123` |
| `diff_ionFlCoef` | REAL | 1.0 | 离子 flux limiter 系数。| `Unsplit/Config:L125` |
| `diff_magFlCoef` | REAL | 1.0 | 磁 flux limiter 系数。| `Unsplit/Config:L128` |

---

## 3. 边界条件（diff_*BoundaryType）

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/Config:L64-L103`

每物理（ele/ion/mag[xyz]）有 6 个边界（Xl/Xr/Yl/Yr/Zl/Zr）= 共 24 个 BC 参数。所有默认 `"neumann"`。

### 3.1 允许的 BC 值

| BC 字符串 | 整数常量 | 含义 / 何时用 |
|---|---|---|
| `"periodic"` | PERIODIC / GRID_PDE_BND_PERIODIC | 周期边界（左右互通）。**何时用**：1D/2D/3D 周期算例 |
| `"outflow"` / `"neumann"` | OUTFLOW / GRID_PDE_BND_NEUMANN | 零梯度（∂T/∂n=0）。**何时用**：开放边界，物理量自由流出（LaserSlab 默认）|
| `"dirichlet"` | DIRICHLET / GRID_PDE_BND_DIRICHLET | 固定值。需要 `diff_*bcValues(2,6)` 设值。**何时用**：边界固定温度 |
| `"vacuum"` | VACUUM | 真空边界（辐射专用，零进入）。**何时用**：辐射 / 等离子体外部边界 |

### 3.2 LaserSlab 标准配置

源码：`source/Simulation/SimulationMain/LaserSlab/flash.par`

```
diff_eleXlBoundaryType = "neumann"    # 左（r=0 轴）零梯度
diff_eleXrBoundaryType = "neumann"    # 右（出靶面）
diff_eleYlBoundaryType = "vacuum"     # 底（真空，辐射可逃）
diff_eleYrBoundaryType = "neumann"    # 顶（出靶面）
diff_eleZlBoundaryType = "neumann"    # 3D 用
diff_eleZrBoundaryType = "neumann"
```

**为什么 Yl 用 vacuum**：LaserSlab 是 2D R-Z 网格，Yl（底部）是激光进入方向，模拟真空让热可逃。

### 3.3 Dirichlet BC 值（如用）

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/diff_saInit.F90:L204-L207`

`diff_elebcValues(2,6)` 存 6 边的 Dirichlet 值。init 时默认 -1（不使用），parfile 通过 `diff_eleXlBoundaryType = "dirichlet"` + `diff_eleXlBoundaryValue = 100.0` 设。

---

## 4. HYPRE 求解器参数（gr_hypre*）

源码：`source/Grid/GridSolvers/HYPRE/Config:L31-L155`

### 4.1 求解器选择（最关键）

| 参数 | 类型 | 默认 | 允许值 | 含义 / 为什么 | 声明位置 |
|---|---|---|---|---|---|
| `gr_hypreSolverType` | STRING | "HYPRE_PCG" | HYPRE_PCG / HYPRE_AMG / HYPRE_GMRES / HYPRE_BICGSTAB / HYPRE_SPLIT / HYPRE_HYBRID | HYPRE 求解器类型。**为什么默认 PCG**：扩散方程是对称正定矩阵，CG 最快收敛。**为什么 LaserSlab 用 AMG**：超大问题（>1M cells）时 BoomerAMG 独立解，避免 PCG 双重存储。| `HYPRE/Config:L32` |
| `gr_hyprePCType` | STRING | "HYPRE_AMG" | HYPRE_NONE / HYPRE_ILU / HYPRE_AMG / HYPRE_PARASAILS | 预条件子类型。**为什么默认 AMG**：BoomerAMG 对扩散方程最优（多重网格近似 A⁻¹）。| `HYPRE/Config:L35` |

**5 求解器对比**（按 L-011 讲为什么）：

| 求解器 | 适用矩阵 | 收敛速度 | 存储 | 何时选 |
|---|---|---|---|---|
| **HYPRE_PCG** | 对称正定 | 快（O(sqrt(κ))）| 中 | **默认**，扩散方程标准 |
| HYPRE_AMG | 任意 | 慢但稳 | 大 | LaserSlab 用，超大问题 |
| HYPRE_BICGSTAB | 非对称 | 中 | 中 | flux limiter 让矩阵非对称时 |
| HYPRE_GMRES | 任意 | 慢但稳 | 大（k 维 Krylov）| 最难收敛问题 |
| HYPRE_HYBRID | 任意 | 自适应 | 中 | 旧 HYPRE 推荐，新版用 PCG+AMG |
| HYPRE_SPLIT | 特殊 | - | 小 | 结构化网格特殊算法，少见 |

### 4.2 收敛 / 迭代参数

| 参数 | 类型 | 默认 | 含义 / 为什么 | 声明位置 |
|---|---|---|---|---|
| `gr_hypreRelTol` | REAL | 1.0e-8 | 相对收敛容差 `||r||/||b|| < relTol`。**为什么默认 1e-8**：物理精度足够，迭代不过多。**为什么不能太小（<1e-12）**：double 精度极限，无意义。| `HYPRE/Config:L38` |
| `gr_hypreRelTolMag` | REAL | 1.0e-8 | 磁扩散专属相对容差。**为什么独立**：磁扩散矩阵条件数不同。| `HYPRE/Config:L41` |
| `gr_hypreAbsTol` | REAL | 0.0 | 绝对容差 `||r|| < absTol`。**为什么默认 0**：用相对容差就够。**为什么大网格时设**：b 范数很大时相对容差不灵敏。| `HYPRE/Config:L50` |
| `gr_hypreMaxIter` | INTEGER | 500 | 最大迭代数。**为什么默认 500**：足够大部分问题收敛。**为什么不收敛时调到 1000+**：大网格或多物理需要更多迭代。| `HYPRE/Config:L75` |
| `gr_hypreMaxIterMag` | INTEGER | 500 | 磁扩散最大迭代。| `HYPRE/Config:L78` |
| `gr_hypreMinIter` | INTEGER | 0 | GMRES 最小迭代数（强制至少这么多）。| `HYPRE/Config:L72` |

### 4.3 数值保护 / 诊断

| 参数 | 类型 | 默认 | 含义 / 为什么 | 声明位置 |
|---|---|---|---|---|
| `gr_hypreUseFloor` | BOOLEAN | TRUE | 是否对 HYPRE 输出做下限 floor。**为什么默认开**：避免负温度（HYPRE 迭代残差可能产生小负值，被 floor 到 1e-12）。**为什么 Poisson 关**：Poisson 解不需要 floor。| `HYPRE/Config:L92` |
| `gr_hypreFloor` | REAL | 1.0e-12 | floor 值。| `HYPRE/Config:L95` |
| `gr_hypreUseMagFloor` | BOOLEAN | FALSE | 磁扩散 floor。**为什么默认关**：磁场可正可负（不-floor）。| `HYPRE/Config:L98` |
| `gr_hypreMagFloor` | REAL | 0.0 | 磁场 floor 值。| `HYPRE/Config:L101` |
| `gr_hyprePrintSolveInfo` | BOOLEAN | FALSE | 是否打印 HYPRE 求解信息（迭代数、残差）。**为什么默认关**：每步打印太多日志。**为什么 LaserSlab 设 `.true.`**：调试用，看收敛情况。| `HYPRE/Config:L82` |
| `gr_hypreInfoLevel` | INTEGER | 1 | 信息详细级别（1=summary, 2=每次迭代）。| `HYPRE/Config:L86` |

### 4.4 PCG 专属（高级）

源码：`source/Grid/GridSolvers/HYPRE/Config:L109-L141`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `gr_hypreUse2Norm` | BOOLEAN | FALSE | 用 L2 范数（默认 L1）。**为什么用 2 范数**：更严格，但收敛慢。|
| `gr_hypreCfTol` | REAL | 0.0 | 收敛因子容差。>0 时启用"是否充分进展"检查（0.5/0.8/0.9/0.95/0.99）。|
| `gr_hypreRecomputeResidual` | BOOLEAN | FALSE | 重新计算残差检查收敛。**为什么用**：迭代多时残差估计可能错。|
| `gr_hypreRecomputeResidualP` | INTEGER | -1 | 每多少步重新算残差。-1 = 不用。|
| `gr_hypreRelChange` | BOOLEAN | FALSE | 收敛测试加"解变化不大"条件。|
| `gr_hypreSolverAutoAbsTolFact` | REAL | 0.0 | 自动设 absTol 的因子。|

### 4.5 BoomerAMG 内部参数（最常用）

源码：`source/Grid/GridSolvers/HYPRE/gr_hypreSetupSolver.F90:L133-L178`

这些是 HYPRE 库直接调用，**不通过 RuntimeParameters 暴露**——代码硬编码：

| 参数 | 硬编码值 | 含义 | 为什么 |
|---|---|---|---|
| CoarsenType | 10 | CLJP-coarsening | 并行 coarsening 算法 |
| InterpType | 6 | 经典插值 | 稳健 |
| RelaxType | 6 | l1-Jacobi | 并行友好 |
| NumSweeps | 1 | 每层 smoothing 次数 | 标准 |
| TruncFactor | 0.0 | 插值截断 | 默认 |
| PMaxElmts | 4 | 每行最大非零 | 控制内存 |
| CycleRelaxType(3) | 6 | 粗层 smoothing | 稳健 |
| CycleNumSweeps(3) | 3 | 粗层 sweeps | 多做 |

**为什么硬编码**：HYPRE 文档说"这些值对标准扩散问题表现好"，暴露太多参数让用户困惑。需要调时改源码（不推荐）。

### 4.6 通量限制器斜率限制器（HYPRE 用）

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `gr_hypreSlopeLimType` | STRING | "HYPRESL_MC" | 横向温度梯度的斜率限制器（HYPRE 矩阵组装用）。**为什么默认 MC**：minmod 与 vanleer 折中。| `HYPRE/Config:L144` |

值：`HYPRESL_MC`（monotonized central, 推荐）/ `HYPRESL_MINMOD`（最保守）/ `HYPRESL_VANLEER`（最不保守）/ `HYPRESL_NONE`（不限制，可能有震荡）。

---

## 5. 简表：边缘参数（按 L-013）

### 5.1 粘性相关（MHD 算例用）

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/diff_viscInit.F90`

| 参数 | 默认 | 含义 |
|---|---|---|
| `thetaVisc` | 1.0 | 粘性隐式度（硬编码，不可改）|
| `useViscHarmonicAvg` | FALSE | 粘性系数用调和平均（vs 算术平均）|
| `diff_viscUseAngularMomentum` | FALSE | 是否保留角动量（轴对称）|

### 5.2 磁扩散相关（MHD 算例用）

源码：`source/physics/Diffuse/DiffuseMain/Diffuse_init.F90:L169-L195`

| 参数 | 默认 | 含义 |
|---|---|---|
| `resistivitySolver` | IMPLCT | 电阻率求解器（IMPLCT / EXPLCT / RES_HYBRID）|
| `resistivityForm` | PARALLEL | 电阻率形式（PARALLEL / PERPENDICULAR / FULLANISO）|
| `useMagHarmonicAvg` | FALSE | 电阻率用调和平均 |

### 5.3 物理 / 数学常量（Diffuse 内部）

源码：`source/physics/Diffuse/DiffuseMain/Diffuse_init.F90:L140-L146`

Diffuse 启动时从 `PhysicalConstants` 模块读：
- `diff_speedlt` = 光速 c
- `diff_asol` = 4·σ_SB/c（辐射常数 a）
- `diff_mele` = 电子质量
- `diff_boltz` = Boltzmann 常数 k_B
- `diff_avo` = Avogadro 数

这些不是 RuntimeParameters，是 FLASH 内置物理常量。

---

## 6. 典型 parfile 速查

### 6.1 LaserSlab 标准（HEDP 默认）

```
# 主控
useDiffuse      = .true.
useDiffuseTherm = .true.
diff_useEleCond = .true.

# θ + flux limiter
diff_thetaImplct = 1.0          # 后向 Euler，无条件稳定
diff_eleFlMode   = "fl_larsen"  # 平滑过渡
diff_eleFlCoef   = 0.06         # HEDP 经验值

# 边界
diff_eleXlBoundaryType = "neumann"
diff_eleXrBoundaryType = "neumann"
diff_eleYlBoundaryType = "vacuum"   # 真空让热逃
diff_eleYrBoundaryType = "neumann"
diff_eleZlBoundaryType = "neumann"
diff_eleZrBoundaryType = "neumann"

# 时间步（隐式不需要 dt 限制）
dt_diff_factor = 1.0e+100

# HYPRE
gr_hypreSolverType    = "HYPRE_AMG"      # 直接 BoomerAMG
gr_hyprePrintSolveInfo = .true.           # 调试用
```

### 6.2 调试 / 教学（简单 1T 扩散）

```
useDiffuse       = .true.
diff_thetaImplct = 0.5                    # Crank-Nicolson 2 阶
diff_eleFlMode   = "fl_none"              # 不限制（教学无超光速问题）
dt_diff_factor   = 0.5                    # 保守 dt
gr_hypreSolverType = "HYPRE_PCG"          # 默认 PCG
gr_hyprePCType     = "HYPRE_AMG"          # BoomerAMG 预条件
gr_hypreMaxIter    = 100                  # 教学用，小问题
```

### 6.3 大规模生产（>1M cells）

```
gr_hypreSolverType = "HYPRE_AMG"          # 直接 AMG，避免 PCG 双重存储
gr_hypreMaxIter    = 1000                 # 大网格要更多迭代
gr_hypreRelTol     = 1.0e-6               # 物理精度 1e-6 够
gr_hyprePrintSolveInfo = .true.           # 监控收敛
```

---

## 7. 延伸阅读

- **Diffuse 角色总览**：`knowledge/overview.md`
- **内部实现**：`knowledge/internals.md`（HYPRE 矩阵组装 + 通量限制器实现）
- **典型配置 + 5 求解器对比**：`knowledge/recipes.md`
- **常见错误（参数错配）**：`knowledge/pitfalls.md`
- **MGD 参数（rt_mgd*）**：`flash-radtrans` skill
- **手册**：FLASH 4.8 User Guide §20

---

## 8. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（beta）：~45 参数分 6 段；主流路径详讲（按 L-013）+ 边缘简表；每个参数给"为什么默认这个值"（按 L-011）；HYPRE BoomerAMG 内部硬编码值列出；3 个典型 parfile（LaserSlab / 教学 / 大规模）| claude |
