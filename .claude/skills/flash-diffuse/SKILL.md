---
name: flash-diffuse
description: |
  FLASH 4.8 Diffuse 单元专家（隐式扩散求解 + HYPRE 接口）。
  按 L-013 聚焦主流量径——Unsplit + HYPRE（LaserSlab 用的主流，热传导 / 磁扩散 / 各向异性扩散都用它）；
  覆盖：Diffuse 公共 API（Diffuse_solveScalar / Diffuse_solveScalarAniso / Diffuse_solveScalarMag /
  Diffuse_fluxLimiter / Diffuse_computeFluxLimiter / Diffuse_advance1D / Diffuse_computeDt / Diffuse_init）、
  扩散方程 A·(df/dt) + C·f = div(B·grad f) + D 的 θ-加权隐式离散（diff_thetaImplct）、
  HYPRE 求解器选择（HYPRE_AMG / HYPRE_PCG / HYPRE_BICGSTAB / HYPRE_GMRES / HYPRE_HYBRID + PC：BoomerAMG / ParaSails / Euclid ILU）、
  通量限制器（flux limiter）4 种模式（fl_none / fl_harmonic / fl_minmax / fl_larsen / fl_levermorepomraning1981，LaserSlab 用 fl_larsen coef=0.06）、
  各向异性电子热传导（diff_anisoCondForEle，CND1/CND2/CND3 平行/垂直/交叉系数，需要 MHD）、
  电子热传导（diff_useEleCond，Spitzer 物理自由流通量限）、离子热传导（diff_useIonCond，3T 专属）、
  磁扩散（diff_doMagDiff）、粘性扩散（useDiffuseVisc）、质量扩散（useDiffuseSpecies，未实现）、
  Driver_evolveFlash 调用顺序（第 3 位 RadTrans → Diffuse，可 DRIVER_DIFFULAST 移到 sourceTerms 之后）、
  扩散时间步（Diffuse_computeDt 显式 dt = 0.5·dx²/D，dt_diff_factor=0.8 缩放，LaserSlab 设 1e100 禁用）、
  与 Grid/GridSolvers/HYPRE 的耦合（Grid_advanceDiffusion 是真正实现，Diffuse_solveScalar 仅是 thin wrapper）；
  Split / CG / DiffuseFluxBased / Polar 等边缘变体简要带过（按 L-013）。
  触发词：diffuse, Diffuse, Diffuse_, diff_, 扩散, 扩散方程, 热传导, 热扩散,
        电子热传导, 离子热传导, 各向异性扩散, 磁扩散, 电阻率扩散,
        thermal conduction, heat conduction, electron heat conduction, ion heat conduction,
        anisotropic conduction, magnetic diffusion, viscous diffusion,
        HYPRE, hypre, BoomerAMG, PFMG, PCG, BiCGSTAB, GMRES, ParaSails, Euclid,
        多重网格, multigrid, AMG, 预条件子, preconditioner, 隐式求解, 隐式扩散,
        θ-加权, theta, theta-implicit, Crank-Nicolson, 后向 Euler, backward Euler,
        diff_thetaImplct, diff_ionThetaImplct, diff_eleFlMode, diff_ionFlMode, diff_magFlMode,
        diff_eleFlCoef, diff_ionFlCoef, diff_magFlCoef,
        fl_none, fl_harmonic, fl_minmax, fl_larsen, fl_levermorepomraning1981,
        flux limiter, flux-limiter, 通量限制器, 自由流极限, free-streaming,
        diff_useEleCond, diff_useIonCond, diff_anisoCondForEle, diff_anisoCondForIon,
        diff_useCrossCond, diff_doMagDiff, diff_doAnisoMagDiff,
        diff_eleXlBoundaryType, diff_ionXlBoundaryType, diff_magxXlBoundaryType,
        useDiffuse, useDiffuseTherm, useDiffuseVisc, useDiffuseSpecies,
        useDiffuseComputeDtTherm, dt_diff_factor, diffusion_cutoff_density,
        diff_scaleFactThermSaTempDiff, diff_scaleFactThermSaTime, diff_updEint,
        gr_hypreSolverType, gr_hyprePcType, gr_hypreRelTol, gr_hypreMaxIter,
        gr_hypreFloor, gr_hypreUseFloor, gr_hyprePrintSolveInfo, gr_hypreInfoLevel,
        Diffuse_solveScalar, Diffuse_solveScalarAniso, Diffuse_solveScalarMag,
        Diffuse_advance1D, Diffuse_computeFluxLimiter, Diffuse_fluxLimiter,
        Diffuse_computeDt, Diffuse_init, Diffuse_finalize, Diffuse_therm,
        Grid_advanceDiffusion, Grid_advanceDiffusionFcB, Grid_advanceAnisoDiffusion,
        Grid_advanceMagDiffusion, Grid_solvePoisson,
        COND_VAR, DFCF_VAR, FLLM_VAR, DFLX_VAR, CND1_VAR, CND2_VAR, CND3_VAR, RES1_VAR, RES2_VAR,
        HYPRE/Unified, parabolic problem, parabolic PDE, 椭圆方程, Poisson,
        operator-split diffusion, DRIVER_DIFFULAST,
        Split, Unsplit, CG, DiffuseFluxBased, 各向异性电导率
triggers:
  # 中文
  - 扩散
  - 扩散方程
  - 热传导
  - 热扩散
  - 电子热传导
  - 离子热传导
  - 各向异性扩散
  - 各向异性热传导
  - 磁扩散
  - 电阻率扩散
  - 粘性扩散
  - 质量扩散
  - 隐式扩散
  - 隐式求解
  - θ-加权
  - 通量限制器
  - 自由流极限
  - 多重网格
  - 预条件子
  - 椭圆方程
  # 英文通用
  - Diffuse
  - diffuse
  - Diffuse_
  - diff_
  - thermal conduction
  - heat conduction
  - heat diffusion
  - electron heat conduction
  - ion heat conduction
  - anisotropic conduction
  - anisotropic diffusion
  - magnetic diffusion
  - viscous diffusion
  - mass diffusion
  - species diffusion
  - flux limiter
  - flux-limiter
  - free-streaming
  - operator-split diffusion
  - parabolic problem
  - parabolic PDE
  # HYPRE
  - HYPRE
  - hypre
  - BoomerAMG
  - PFMG
  - PCG
  - BiCGSTAB
  - GMRES
  - ParaSails
  - Euclid
  - multigrid
  - AMG
  - preconditioner
  - theta-implicit
  - Crank-Nicolson
  - backward Euler
  - Poisson
  # Diffuse 参数（diff_*）
  - diff_thetaImplct
  - diff_ionThetaImplct
  - diff_eleFlMode
  - diff_ionFlMode
  - diff_magFlMode
  - diff_eleFlCoef
  - diff_ionFlCoef
  - diff_magFlCoef
  - diff_useEleCond
  - diff_useIonCond
  - diff_anisoCondForEle
  - diff_anisoCondForIon
  - diff_useCrossCond
  - diff_doMagDiff
  - diff_doAnisoMagDiff
  - diff_eleXlBoundaryType
  - diff_eleXrBoundaryType
  - diff_eleYlBoundaryType
  - diff_eleYrBoundaryType
  - diff_eleZlBoundaryType
  - diff_eleZrBoundaryType
  - diff_ionXlBoundaryType
  - diff_ionXrBoundaryType
  - diff_ionYlBoundaryType
  - diff_ionYrBoundaryType
  - diff_ionZlBoundaryType
  - diff_ionZrBoundaryType
  - diff_magxXlBoundaryType
  - diff_magyXlBoundaryType
  - diff_magzXlBoundaryType
  - diff_scaleFactThermSaTempDiff
  - diff_scaleFactThermSaTime
  - diff_updEint
  - useDiffuse
  - useDiffuseTherm
  - useDiffuseVisc
  - useDiffuseSpecies
  - useDiffuseComputeDtTherm
  - useDiffuseComputeDtVisc
  - useDiffuseComputeDtSpecies
  - useDiffuseComputeDtmagnetic
  - dt_diff_factor
  - diffusion_cutoff_density
  # HYPRE 参数（gr_hypre*）
  - gr_hypreSolverType
  - gr_hyprePcType
  - gr_hyprePCType
  - gr_hypreRelTol
  - gr_hypreRelTolMag
  - gr_hypreAbsTol
  - gr_hypreMaxIter
  - gr_hypreMaxIterMag
  - gr_hypreMinIter
  - gr_hypreFloor
  - gr_hypreUseFloor
  - gr_hypreMagFloor
  - gr_hypreUseMagFloor
  - gr_hyprePrintSolveInfo
  - gr_hypreInfoLevel
  - gr_hypreUse2Norm
  - gr_hypreCfTol
  - gr_hypreRecomputeResidual
  - gr_hypreRecomputeResidualP
  - gr_hypreRelChange
  - gr_hypreSolverAutoAbsTolFact
  - gr_hypreSlopeLimType
  - useMagHarmonicAvg
  - useViscHarmonicAvg
  # 求解器值
  - HYPRE_PCG
  - HYPRE_AMG
  - HYPRE_GMRES
  - HYPRE_BICGSTAB
  - HYPRE_SPLIT
  - HYPRE_HYBRID
  - HYPRE_NONE
  - HYPRE_ILU
  - HYPRE_PARASAILS
  - HYPRESL_MC
  - HYPRESL_MINMOD
  - HYPRESL_VANLEER
  - HYPRESL_NONE
  # 通量限制器模式
  - fl_none
  - fl_harmonic
  - fl_minmax
  - fl_larsen
  - fl_levermorepomraning1981
  # API
  - Diffuse_solveScalar
  - Diffuse_solveScalarAniso
  - Diffuse_solveScalarMag
  - Diffuse_solveCoupledScalar
  - Diffuse_advance1D
  - Diffuse_computeFluxLimiter
  - Diffuse_fluxLimiter
  - Diffuse_applyGenericFluxLimiter
  - Diffuse_computeDt
  - Diffuse_init
  - Diffuse_finalize
  - Diffuse_therm
  - Diffuse_visc
  - Diffuse_species
  - Diffuse_doEnergyFluxes
  - Diffuse_setContextInfo
  - Grid_advanceDiffusion
  - Grid_advanceDiffusionFcB
  - Grid_advanceAnisoDiffusion
  - Grid_advanceMagDiffusion
  - Grid_advanceImplicit
  - Grid_solvePoisson
  - Grid_setSolverDbgContextInfo
  - diff_advanceTherm
  - diff_advanceVisc
  - diff_advanceMag
  - diff_saInit
  - diff_viscInit
  - diff_magInit
  - diff_fbInit
  - diff_updateEnergy
  - diff_getFaceFluxes
  # 变量
  - COND_VAR
  - DFCF_VAR
  - FLLM_VAR
  - DFLX_VAR
  - DFLY_VAR
  - DFLZ_VAR
  - CND1_VAR
  - CND2_VAR
  - CND3_VAR
  - RES1_VAR
  - RES2_VAR
  # 单元 / 路径
  - DiffuseMain/Unsplit
  - DiffuseMain/Split
  - DiffuseMain/CG
  - DiffuseFluxBased
  - GridSolvers/HYPRE
  - GridSolvers/HYPRE/Unified
  - GridSolvers/HYPRE/paramesh
  - GridSolvers/HYPRE/UG
  - DRIVER_DIFFULAST
when_to_use: |
  调用本 skill 的场景：
  1. 用户问 Diffuse 角色 / 设计（"Diffuse 单元干什么"、"为什么需要隐式"）
  2. 用户问 HYPRE 是什么 / 怎么选求解器（"BoomerAMG vs PCG"、"gr_hypreSolverType 默认"）
  3. 用户问 diff_thetaImplct（"θ 是什么"、"为什么默认 0.5"、"隐式度怎么选"）
  4. 用户问通量限制器（"fl_larsen 是什么"、"fl_harmonic vs fl_minmax"、"为什么 LaserSlab 用 0.06"）
  5. 用户问各向异性扩散（"diff_anisoCondForEle 什么时候开"、"CND1/CND2/CND3 是什么"）
  6. 用户问 Diffuse_solveScalar 调用 / Grid_advanceDiffusion 流程
  7. 用户问扩散时间步（"dt_diff_factor 默认"、"为什么 LaserSlab 设 1e100"）
  8. 用户问 Diffuse 在 Driver 的调用顺序（"为什么在 Hydro 后"、"DRIVER_DIFFULAST 是什么"）
  9. 用户调试 HYPRE 不收敛 / NaN / 慢
  10. 用户问 LaserSlab 配置 Diffuse 的典型 parfile（diff_useEleCond / fl_larsen / thetaImplct=1.0）
  11. 用户问 MGD 通过 Diffuse_solveScalar 调 HYPRE 的机制（指向 flash-radtrans，本 skill 给 HYPRE 侧补充）
  12. 用户问磁扩散 / 粘性扩散（简要，按 L-013）
when_not_to_use: |
  **不调用本 skill 的场景**：
  - MGD 多群辐射扩散的物理 / 群结构 / rt_mgd* 参数 → `flash-radtrans`（互补：MGD 调 Diffuse_solveScalar 的 HYPRE 侧由本 skill 补充）
  - 电导率 / 不透明度 / 粘性系数怎么算 → `flash-material`（Phase 2）
  - EOS 三温耦合 / TELE/EION 怎么自洽 → `flash-eos`
  - Driver 主循环 → `flash-driver`
  - Grid / AMR / leaf block → `flash-grid`
  - 找 Diffuse_* / Grid_advanceDiffusion 源码位置 → `flash-source-reader`
  - 错误信息匹配 → `flash-pitfall-finder`
  - 参数基本属性（类型 / 默认） → `flash-param-query`
  - 跑算例 → `flash-case-runner`（Phase 3）
layer: knowledge
phase: 2
status: stable
created: 2026-06-17
last_updated: 2026-07-31
owner: user
---

# flash-diffuse — Diffuse 扩散求解器专家（隐式 + HYPRE）

> **状态**：beta（Phase 2 stable 知识层 skill，2026-07-30；Phase 2 第九个知识层 skill）
>
> **按 L-013 聚焦主流**：本 skill 主讲 **DiffuseMain/Unsplit + Grid/GridSolvers/HYPRE**（LaserSlab 用的主流）。Split / CG / DiffuseFluxBased / Polar 等边缘变体简要带过。
>
> **互补声明（按 L-006）**：MGD（多群辐射扩散）的物理、群结构、rt_mgd* 参数在 `flash-radtrans` 已详讲。本 skill 重点讲 HYPRE 侧（Diffuse_solveScalar → Grid_advanceDiffusion → HYPRE 的接口细节），MGD 怎么调它只引用不重复。

## 1. 角色与边界

### 1.1 我是做什么的

回答 FLASH **Diffuse 单元**相关问题——所有隐式扩散方程的求解：

| 范畴 | 详见 |
|---|---|
| 物理原理 + 设计 | `knowledge/overview.md` — Diffuse 角色 + Unsplit/Split 对比 + HYPRE 接口 + 通量限制器 + 术语速查（L-014）|
| 参数字典 | `knowledge/params.md` — diff_* / gr_hypre* / 通量限制器参数完整字典 |
| 内部实现 | `knowledge/internals.md` — Diffuse_solveScalar 流程 + HYPRE 矩阵组装 + 通量限制器实现 + AMR 处理 |
| 典型配置 | `knowledge/recipes.md` — Unsplit+HYPRE 配置 + 通量限制器选择 + 典型 parfile |
| 踩坑排查 | `knowledge/pitfalls.md` — HYPRE 不收敛、flux limiter 选错、diff_* 参数错等 + 诊断引导（L-012）|

### 1.2 我不做什么

| 用户问题类型 | 归属 skill |
|---|---|
| MGD 多群辐射扩散的物理 | `flash-radtrans` |
| 电导率 / 不透明率 / 粘性系数数值 | `flash-material`（Phase 2） |
| EOS 三温耦合 | `flash-eos` |
| Driver 主循环 / 调用顺序 | `flash-driver` |
| Grid / AMR 数据结构 | `flash-grid` |
| 找源码位置 | `flash-source-reader` |
| 错误匹配 | `flash-pitfall-finder` |
| 参数基本属性 | `flash-param-query` |

## 2. 行为协议

按 `agent/TEMPLATES/skill-template.md §2` 通用协议。核心要点（按 L-001~L-014）：

- **讲逻辑**（L-001）：不只是列 HYPRE 求解器，讲清楚每个的物理意义、何时选
- **不用 mermaid**（L-002）：调用关系用文字+缩进
- **贴源码相关代码**（L-008）：abort 类查询贴 `Driver_abortFlash` 所在 if（如 `[Diffuse]: computed dt is not positive`、`Invalid Flux limiter type`）
- **核心 4 段 + 引导项**（L-010）：核心段必给详细，引导项按需展开
- **讲为什么**（L-011）：选择/配置/概念类问题必给"为什么这么设计/为什么默认这个值"
- **诊断类先引导贴现场**（L-012）：HYPRE 不收敛 / NaN 等先要用户贴日志/setup/parfile/HYPRE 输出
- **公式 CLI 友好**（L-012）：用 ASCII / 代码块，不用 `$...$`
- **聚焦主流路径**（L-013）：Unsplit + HYPRE 是主流，详讲；Split / CG / DiffuseFluxBased 简要
- **专业术语先解释**（L-014）：HYPRE / BoomerAMG / 多重网格 / θ-加权 / flux limiter / operator-split / PC（preconditioner）等先定义再讲机制
- **面向新手**：解释每个术语（"implicit"、"guard cell"、"unk"、"leaf block"）

## 3. knowledge/ 子目录

| 文件 | 内容 |
|---|---|
| `knowledge/overview.md` | Diffuse 角色 + Unsplit/Split 对比 + HYPRE 接口 + 通量限制器 + 术语速查（L-014）|
| `knowledge/params.md` | diff_* + gr_hypre* + 通量限制器参数完整字典（主流参数详细 + 边缘简表，按 L-013）|
| `knowledge/internals.md` | Diffuse_solveScalar → Grid_advanceDiffusion → HYPRE 完整流程 + 矩阵组装 + 通量限制器实现 + AMR 处理 |
| `knowledge/recipes.md` | Unsplit+HYPRE 配置 + 通量限制器选择 + LaserSlab 标准 parfile + 5 求解器对比 |
| `knowledge/pitfalls.md` | 常见错误（HYPRE 不收敛、flux limiter 选错、diff_* 参数错、thetaImplct 选错等）+ 诊断引导（L-012）|

## 4. examples/

| 文件 | 内容 |
|---|---|
| `examples/setup-diffuse-unsplit.sh` | LaserSlab Unsplit+HYPRE setup 命令（HEDP 标准） |
| `examples/parfile-diffuse-therm.txt` | 热传导完整 parfile 片段（含 diff_thetaImplct / fl_larsen / dt_diff_factor） |
| `examples/parfile-hypre-solvers.txt` | 5 种 HYPRE 求解器配置对比（PCG / BiCGSTAB / GMRES / AMG / Hybrid） |
| `examples/README.md` | examples 索引 + 6 大陷阱提醒（按 L-011） |

## 5. 示例问答（验收基准）

### Q1: HYPRE 是什么？为什么 FLASH 用它解扩散？
**A**: 见 `knowledge/overview.md §术语速查` + `§3 HYPRE 接口`。**HYPRE = LLNL 开发的解大稀疏线性方程组 `Ax=b` 的数学库**（不是 FLASH 内部组件）。FLASH 把扩散方程（如热传导 `ρ·cv·∂T/∂t = ∇·(κ∇T)`）隐式离散后变成百万级稀疏线性系统（每行 ~7 个非零，3D 7 点模板）。普通高斯消元 O(N³) 不可行，HYPRE 用迭代法 + 多重网格几秒解完。FLASH 通过 Grid/GridSolvers/HYPRE 单元封装它，物理单元（Diffuse / RadTrans）只调 `Diffuse_solveScalar` 不直接接触 HYPRE API。

### Q2: diff_thetaImplct 是什么？为什么 LaserSlab 设 1.0 不是 0.5？
**A**: 见 `knowledge/params.md §1.1` + `knowledge/overview.md §术语速查`。**θ-加权（theta-weighted）**：时间离散的隐式度参数。`θ=0` 全显式（不稳定，需 dt < 0.5·dx²/D）；`θ=0.5` Crank-Nicolson（2 阶精度，可能震荡）；`θ=1.0` 全隐式 / 后向 Euler（无条件稳定，1 阶精度）。**默认 0.5**（精度优先），但 LaserSlab 用 `1.0`（稳定性优先——激光物理产生极陡温度梯度，Crank-Nicolson 会震荡；HEDP 物理时间步长本就大，无条件稳定重要）。

### Q3: 通量限制器是什么？LaserSlab 为什么用 fl_larsen + coef=0.06？
**A**: 见 `knowledge/overview.md §4 通量限制器` + `knowledge/recipes.md §2`。**flux limiter（通量限制器）**：限制热通量不超过物理上限（自由流极限 `F_max = n_e·k_B·T·v_th`）的数学函数。光学薄 / 低密度区纯扩散会让通量超物理上限（"超光速"）。LaserSlab 用 **fl_larsen**（`1/sqrt((1/D)²+(R/F_max)²)`，平滑过渡）+ coef=0.06（经验值，让有效热传导为自由流的 6%）。其他选项：fl_harmonic（最小者，保守）、fl_minmax（min，最保守）、fl_levermorepomraning1981（理论严格但复杂）。**默认 fl_none 危险**——纯扩散会超光速。

### Q4: HYPRE 5 种求解器怎么选？默认是哪个？
**A**: 见 `knowledge/params.md §3` + `knowledge/recipes.md §4`。**默认 gr_hypreSolverType = "HYPRE_PCG"** + PC = "HYPRE_AMG"（BoomerAMG 预条件共轭梯度）。LaserSlab 用 `"HYPRE_AMG"`（直接 BoomerAMG，对大网格扩散方程更稳定）。选择原则：(1) PCG+AMG：扩散方程标准选择，对称正定矩阵收敛快；(2) BiCGSTAB：非对称矩阵（如 flux limiter 让系数 cell-face 依赖）；(3) GMRES：最难收敛，存储大；(4) AMG 独立：超大问题避免 PCG 内部存储；(5) Hybrid：旧版 HYPRE 推荐，新版本用 PCG+AMG 取代。

### Q5: HYPRE 不收敛 / 输出 "Nonconv./failure" 怎么办？
**A**: 见 `knowledge/pitfalls.md §A`。**先贴现场**（按 L-012）：HYPRE 输出（`grep "Nonconv\|final_res_norm\|num_iterations"` 日志）、setup_call、parfile 的 gr_hypre* 段、物理参数（COND_VAR 范围）。常见原因：(1) `gr_hypreMaxIter=500` 太小（大网格要 1000+）；(2) `gr_hypreRelTol=1e-8` 太严（物理精度 1e-6 够）；(3) `diff_thetaImplct<1.0` 引起震荡；(4) flux limiter 选错让系数 cell-face 跳变；(5) COND_VAR=0（`diffusion_cutoff_density` 触发，真空区扩散为 0 让矩阵奇异）；(6) 边界条件全 NEUMANN（解不唯一，需要至少一个 DIRICHLET 或 VACUUM）。

## 6. 关键源码入口

| 想理解 | 看哪个文件 |
|---|---|
| Diffuse 公共接口（17 函数） | `source/physics/Diffuse/Diffuse_interface.F90` |
| Diffuse 主入口（每步调） | `source/physics/Diffuse/DiffuseMain/Diffuse.F90`（仅 30 行 dispatcher）|
| **Unsplit 实现（LaserSlab 用）** | `source/physics/Diffuse/DiffuseMain/Unsplit/` |
| Diffuse_solveScalar（thin wrapper） | `source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L87-L127` |
| Diffuse_solveScalarAniso（各向异性） | `source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L129-L164` |
| Diffuse_solveScalarMag（磁扩散） | `source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L166-L200` |
| **diff_advanceTherm**（热传导每步调） | `source/physics/Diffuse/DiffuseMain/Unsplit/diff_advanceTherm.F90:L64-L488` |
| Diffuse_solve（generalized） | `source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solve.F90` |
| **Diffuse_computeFluxLimiter**（通用） | `source/physics/Diffuse/DiffuseMain/Diffuse_computeFluxLimiter.F90:L63-L250` |
| Diffuse_fluxLimiter（修改 COND_VAR） | `source/physics/Diffuse/DiffuseMain/Diffuse_fluxLimiter.F90:L57-L261` |
| Diffuse_applyGenericFluxLimiter | `source/physics/Diffuse/DiffuseMain/Diffuse_applyGenericFluxLimiter.F90` |
| Diffuse_computeDt（显式 dt 限制） | `source/physics/Diffuse/DiffuseMain/Diffuse_computeDt.F90:L61-L423` |
| Diffuse_init（读所有参数） | `source/physics/Diffuse/DiffuseMain/Diffuse_init.F90:L55-L212` |
| diff_saInit（读 BC + theta） | `source/physics/Diffuse/DiffuseMain/Unsplit/diff_saInit.F90:L31-L177` |
| Diffuse_data（模块变量） | `source/physics/Diffuse/DiffuseMain/Diffuse_data.F90` |
| diff_saData（Unsplit 状态） | `source/physics/Diffuse/DiffuseMain/Unsplit/diff_saData.F90` |
| Diffuse 顶层 Config（PARAMETER 声明） | `source/physics/Diffuse/DiffuseMain/Unsplit/Config` |
| **HYPRE 真正实现（Grid 层）** | `source/Grid/GridSolvers/HYPRE/` |
| Grid_advanceDiffusion（main） | `source/Grid/GridSolvers/HYPRE/Grid_advanceDiffusion.F90:L84-L120+` |
| Grid_advanceAnisoDiffusion | `source/Grid/GridSolvers/HYPRE/Grid_advanceAnisoDiffusion.F90` |
| Grid_advanceDiffusionFcB（face-centered B） | `source/Grid/GridSolvers/HYPRE/Grid_advanceDiffusionFcB.F90` |
| Grid_advanceMagDiffusion | `source/Grid/GridSolvers/HYPRE/Grid_advanceMagDiffusion.F90.fv` |
| **gr_hypreSetupSolver**（5 求解器分支） | `source/Grid/GridSolvers/HYPRE/gr_hypreSetupSolver.F90:L51-L431` |
| gr_hypreSolve（实际解 Ax=b） | `source/Grid/GridSolvers/HYPRE/gr_hypreSolve.F90:L27-L420` |
| gr_hypreInit（读 gr_hypre* 参数） | `source/Grid/GridSolvers/HYPRE/gr_hypreInit.F90` |
| HYPRE Config（所有 gr_hypre* PARAMETER） | `source/Grid/GridSolvers/HYPRE/Config` |
| HYPRE/Unified（MHD 联合矩阵） | `source/Grid/GridSolvers/HYPRE/Unified/` |
| Split / CG / DiffuseFluxBased（边缘） | `source/physics/Diffuse/DiffuseMain/Split/`、`.../CG/`、`.../DiffuseFluxBased/` |
| Diffuse_advance1D（Split 1D） | `source/physics/Diffuse/DiffuseMain/Split/Diffuse_advance1D.F90` |
| Driver 调用 Diffuse | `source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90:L306`（Hydro 后）/ `:L330`（DRIVER_DIFFULAST 时） |
| Driver_computeDt（Diffuse 注册） | `source/Driver/DriverMain/Driver_computeDt.F90:L410` |
| LaserSlab Config（REQUESTS Unsplit） | `source/Simulation/SimulationMain/LaserSlab/Config` |
| LaserSlab flash.par（diff_thetaImplct=1.0） | `source/Simulation/SimulationMain/LaserSlab/flash.par` |
| Diffuse abort（dt <= 0） | `source/physics/Diffuse/DiffuseMain/Diffuse_computeDt.F90:L418` |
| Diffuse abort（Invalid flux limiter） | `source/physics/Diffuse/DiffuseMain/Diffuse_fluxLimiter.F90:L210` |
| Diffuse abort（unsupported geometry） | `source/physics/Diffuse/DiffuseMain/Diffuse_init.F90:L128` |

## 7. 待办

- [ ] 跑 5 道验收考题，全部通过则升级 stable
- [ ] 持续累积踩坑（用户实战 HEDP 算例遇到 Diffuse / HYPRE 问题时）
- [ ] Phase 2+ 后续 skill 协作验证（如 flash-material 解释 Conductivity 系数如何进 COND_VAR）

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-07-30 | **升级 draft → beta**（Phase 2 第九个知识层 skill）：按 flash-laser/driver/grid/hydro/eos/radtrans/sourceterms 模板 + L-001~L-014 全部经验（特别强化 L-013 聚焦 Unsplit+HYPRE 主流 + L-014 解释 HYPRE/BoomerAMG/多重网格/θ-加权/flux limiter 等术语 + L-011 讲为什么默认这个值）；扩展 triggers（180+ 关键词含全部 diff_* / gr_hypre* / 5 HYPRE 求解器 / 5 flux limiter 模式 / API / 变量 / Config 路径）；5 knowledge 文件齐 + 4 examples（1 setup 脚本 + 2 parfile 片段 + README）；含完整 Diffuse 单元讲解（θ-加权隐式 / HYPRE 5 求解器对比 / 通量限制器 4 模式 / 各向异性 CND1/2/3 / Driver 调用顺序 / 与 Grid/GridSolvers/HYPRE 的耦合）；按 L-013 主讲 Unsplit+HYPRE（HEDP 主流）+ 简要带过 Split/CG/DiffuseFluxBased（边缘）；MGD HYPRE 侧补充但不重复 flash-radtrans；Phase 2 stable 知识层 skill | claude |
