---
title: Diffuse 踩坑排查 — HYPRE 不收敛 / flux limiter / 参数错配
skill: flash-diffuse
category: pitfalls
source_anchors:
  - source/physics/Diffuse/DiffuseMain/Diffuse_computeDt.F90:L418
  - source/physics/Diffuse/DiffuseMain/Diffuse_init.F90:L128
  - source/physics/Diffuse/DiffuseMain/Diffuse_fluxLimiter.F90:L210
  - source/Grid/GridSolvers/HYPRE/gr_hypreSolve.F90:L256-L350
  - source/Grid/GridSolvers/HYPRE/gr_hypreSetupSolver.F90:L51-L431
manual_ref: "FLASH 4.8 User Guide §20"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: beta
tags:
  - diffuse
  - pitfalls
  - hypre
  - diagnostics
  - flux-limiter
---

# Diffuse 踩坑排查（按 L-012 诊断引导 + L-008 贴源码）

> **TL;DR**：~15 类常见错误，分 5 组：A. HYPRE 不收敛（最高频）；B. flux limiter 选错；C. dt 限制问题；D. 边界条件错；E. 启动 abort。**按 L-012**：所有诊断先引导贴现场（HYPRE 输出 + parfile + setup_call），再展开通用原因。**按 L-008**：abort 类贴触发代码。**按 L-013**：聚焦主流问题（HYPRE / flux limiter）。

### 术语速查（按 L-014）

- **HYPRE 不收敛**：迭代解 `Ax=b` 没在 `gr_hypreMaxIter` 步内达到 `gr_hypreRelTol` 容差。
- **flux limiter**：限制扩散通量不超过自由流极限的函数。选错会让物理失真（超光速）或过度限制（热传不动）。
- **θ-加权**：时间离散隐式度参数。LaserSlab 用 1.0（无条件稳定），CN 0.5 在陡梯度会震荡。
- **operator-split**：Diffuse 在 Driver 第 3 位独立调用，不耦合 Hydro。
- **boomerAMG**：HYPRE 默认预条件子（多重网格），稳健但有时收敛慢。

---

## A. HYPRE 不收敛（最高频）

### A.0 诊断引导（必给，按 L-012）

**先贴现场**——HYPRE 不收敛原因可能 10+ 种，直接列通用原因会误导：

```bash
# 1. HYPRE 输出（关键！）
grep -E "Nonconv|final_res_norm|num_iterations|ierr|converged" \
    cases/<case>/01-data/<basenm>.log | head -50

# 2. parfile HYPRE 段
grep -E "gr_hypre|diff_theta" cases/<case>/flash.par

# 3. setup 命令
cat cases/<case>/setup_call

# 4. 物理参数（COND_VAR 范围）
# 跑一个 checkpoint，看 COND_VAR min/max（用 visit / python）
```

**为什么需要这些**：
- **HYPRE 输出**：看 `num_iterations`（接近 maxIter？）和 `final_res_norm`（多大？停滞？震荡？）
- **parfile HYPRE 段**：确认 gr_hypreMaxIter / RelTol / SolverType 真的生效
- **setup_call**：确认 +mgd / +uhd3t 等编译期选项
- **COND_VAR 范围**：如果 COND_VAR=0 或 NaN，矩阵奇异 / 不收敛

贴完后能给出针对性诊断。如果用户只想看通用原因，继续读 A.1-A.7。

### A.1 gr_hypreMaxIter 太小（500 不够）

**症状**：`num_iterations = 500`（= maxIter），`final_res_norm > relTol`。

**原因**：扩散方程条件数随网格细化二次增长（κ(A) ~ O(N²)）。默认 500 步对 100×100 网格够，对 500×500 不够。

**修复**：
```
gr_hypreMaxIter = 2000   # 调到 2000 或 5000
```

**为什么默认 500**：FLASH 文档说"对标准扩散问题够"，但 HEDP 大网格 / 多物理耦合不够。

### A.2 gr_hypreRelTol 太严（1e-8 不必要）

**症状**：HYPRE 跑 1000+ 步才收敛，浪费时间。

**原因**：物理精度（温度误差 1e-4 K）远低于数学精度（1e-8 相对容差）。**用户过度追求精度**。

**修复**：
```
gr_hypreRelTol = 1.0e-6   # 放宽到 1e-6（仍比物理精度严）
```

**为什么默认 1e-8**：保守，保证任何问题都"数学收敛"。但 HEDP 物理精度 1% 就够，1e-6 完全够用。

### A.3 COND_VAR = 0 或 NaN（矩阵奇异）

**症状**：HYPRE 报错 `ierr != 0` 或 final_res_norm = NaN。

**原因 1**：`diffusion_cutoff_density` 默认 1e-30 太松，真空区 COND_VAR = 0 → 矩阵行全 0 → 奇异。

**原因 2**：Conductivity 单元返回 NaN（如温度低于表范围）。

**诊断**：
```bash
# 跑一个 checkpoint，用 visit / python 看 COND_VAR：
python3 -c "
import h5py
f = h5py.File('cases/<case>/01-data/FLASH2_0000', 'r')
print('COND_VAR min/max:', f['/COND_VAR'].min(), f['/COND_VAR'].max())
print('COND_VAR NaN count:', np.isnan(f['/COND_VAR']).sum())
"
```

**修复**：
- 真空区：`diffusion_cutoff_density = 1.0e-5`（HEDP 典型，避免完全 0）
- Conductivity NaN：检查温度范围，确保 EOS 表覆盖

### A.4 矩阵非对称（PCG 不适用）

**症状**：PCG 不收敛，但 BiCGSTAB 收敛。

**原因**：flux limiter 让扩散系数 cell-face 依赖（每 face 不同），矩阵不再对称。

**修复**：
```
gr_hypreSolverType = "HYPRE_BICGSTAB"   # 非对称矩阵
gr_hyprePCType     = "HYPRE_AMG"
```

**为什么 PCG 假设对称**：CG 算法基于最优化二次型 `1/2 x^T A x - b^T x`，要求 A 对称正定。

### A.5 边界全 NEUMANN（解不唯一）

**症状**：HYPRE 不收敛或收敛到错值（平均温度漂移）。

**原因**：全 NEUMANN（∂T/∂n=0）边界让矩阵有零特征值（解不唯一——加任意常数解不变）。

**修复**：至少一个边界改成 DIRICHLET 或 VACUUM：
```
diff_eleYlBoundaryType = "vacuum"   # 或 "dirichlet" + value
```

**为什么 LaserSlab Yl 用 vacuum**：既避免奇异，又物理合理（激光进入方向是真空）。

### A.6 flux limiter 让系数跳变

**症状**：HYPRE 收敛慢，迭代震荡。

**原因**：`fl_minmax` 让系数突变（`min(D_old, F_fs/|∇T|)`），HYPRE 难以处理。

**修复**：换平滑 flux limiter：
```
diff_eleFlMode = "fl_larsen"   # 平滑过渡
```

### A.7 HYPRE 库链接问题

**症状**：编译时报 `undefined reference to HYPRE_*`。

**原因**：HYPRE 库未正确链接（Makefile.h 的 `HYPRE_PATH` 错）。

**修复**：
```bash
# 检查 Makefile.h
grep HYPRE_PATH cases/<case>/Makefile.h
# 应看到：HYPRE_PATH = /home/ubuntu/local/flash/myFLASH4.8/hypre

# 验证库存在
ls -la $HYPRE_PATH/lib/libHYPRE.a
```

**为什么不算源码错**：链接器错（L-008），不贴 FLASH 源码，讲 ld 机制。

---

## B. flux limiter 选错

### B.1 默认 fl_none 导致超光速

**症状**：温度场出现非物理震荡 / 辐射能量爆炸。

**原因**：`diff_eleFlMode` 默认 `fl_none`，纯扩散在低密度区让通量超自由流极限（物理不可能）。

**触发代码**（源码：`source/physics/Diffuse/DiffuseMain/Unsplit/Config:L112-L113`）：
```
PARAMETER diff_eleFlMode STRING "fl_none" [...]
```

**修复**：
```
diff_eleFlMode = "fl_larsen"   # HEDP 标准
diff_eleFlCoef = 0.06          # 6% 自由流
```

**为什么默认 fl_none 危险**：纯扩散问题（如教学）不需要限制，但 HEDP 必须显式设。**这是 LaserSlab 最常踩的坑**。

### B.2 Invalid Flux limiter type（启动 abort）

**症状**：运行时 abort `Invalid Flux limiter type`。

**触发代码**（源码：`source/physics/Diffuse/DiffuseMain/Diffuse_fluxLimiter.F90:L210`）：
```fortran
case DEFAULT
   call Driver_abortFlash("Invalid Flux limiter type")
end select
```

**完整 select case 段**（L173-L211）：
```fortran
select case(mode)
case(FL_HARMONIC)
   dcoef = 1.0 / (1.0/dcoefOld + maggrad/(fl + 1.0e-100_r8))
   ...
case(FL_MINMAX)
   dcoef = min(dcoefOld, fl/(maggrad + 1.0e-100_r8))
   ...
case(FL_LARSEN)
   dcoef = 1.0 / sqrt((1.0/dcoefOld)**2 + (maggrad/(fl + 1.0e-100_r8))**2)
   ...
case(FL_LEVPOM)
   ...
case DEFAULT
   call Driver_abortFlash("Invalid Flux limiter type")
end select
```

**原因**：parfile 写错模式名（如 `"fl_lasen"` 拼错）。

**修复**：用允许值之一：
```
diff_eleFlMode = "fl_none" | "fl_harmonic" | "fl_minmax" | "fl_larsen" | "fl_levermorepomraning1981"
```

**为什么 abort 而非警告**：错误模式让 dcoef 未定义，后续计算无意义。

### B.3 coef 选错（0.06 vs 1.0）

**症状**：温度场过度扩散（热传得太快）或欠扩散（热传不动）。

**原因**：`diff_eleFlCoef` 默认 1.0（满自由流），LaserSlab 用 0.06（HEDP 经验）。

| coef | 效果 | 何时用 |
|---|---|---|
| 1.0（默认） | 满自由流（最限制）| 保守上界，安全但可能欠扩散 |
| 0.06 | 6% 自由流 | **LaserSlab HEDP 标准** |
| 0.10 | 10% 自由流 | 离子热传导（v_th 大）|
| 0.0 | 完全关热传导 | 调试 |

**为什么 LaserSlab 0.06**：HEDP 实验经验值，Spitzer 算出的电导率在低密度区高估（实际只有 6% 自由流）。文献推荐初值。

### B.4 各向异性 flux limiter 应用于 perpendicular

**症状**：各向异性扩散后平行方向也限制了，结果不对。

**原因**：误以为 flux limiter 只限制垂直方向。**实际**：限制 perpendicular，然后平行和交叉按同 λ 缩放。

**源码**（`source/physics/Diffuse/DiffuseMain/Unsplit/diff_advanceTherm.F90:L284-L298`）：
```fortran
if (diff_anisoCondForEle) then
   ! Perpendicular conductivity is the "isotropic" part, so we limit the flux by
   ! limiting this component. Parallel and cross conductivities are
   ! then scaled by the same factor to maintain anisotropy.
   call Diffuse_fluxLimiter(cvarPERPCOND, Temptodiffuse, FLLM_VAR, &
        diff_eleFlMode, blockCount, blockList)
   do lb = 1, blockCount
      blockID = blockList(lb)
      call Grid_getBlkPtr(blockID, solnVec)
      solnVec(cvarPARCOND,:,:,:) = solnVec(cvarPARCOND,:,:,:)*solnVec(FLLM_VAR,:,:,:)
      if (diff_useCrossCond) &
           solnVec(cvarCROSSCOND,:,:,:) = solnVec(cvarCROSSCOND,:,:,:)*solnVec(FLLM_VAR,:,:,:)
      call Grid_releaseBlkPtr(blockID, solnVec)
   enddo
```

**理解**：注释明确说"to maintain anisotropy"——保持平行 / 垂直比例不变，整体缩放。

---

## C. dt 限制问题

### C.1 dt_diff_factor = 1e100 禁用（隐式不需要）

**症状**：LaserSlab 设 `dt_diff_factor = 1e100`，为什么？

**回答**：**隐式扩散不需要显式 dt 限制**（无条件稳定）。但 `Diffuse_computeDt` 默认算 `0.5·dx²/D` 返回，对 HEDP 算例（D ~ 1e7）会返回 dt ~ 1e-15，远小于物理时间步长。

**为什么 LaserSlab 设 1e100**：让 Diffuse_computeDt 返回 huge(1.0)，相当于禁用（Driver 用其他 dt 来源：Hydro CFL、Heatexchange、MGD 等）。

**为什么不直接关 `useDiffuseComputeDtTherm = .false.`**：那个开关不传到 Driver_computeDt（设计缺陷），用 `dt_diff_factor=1e100` 是社区惯例。

### C.2 dt_diff_factor = 0（dt 变 0，abort）

**症状**：运行时 abort `[Diffuse]: computed dt is not positive! Aborting!`。

**触发代码**（源码：`source/physics/Diffuse/DiffuseMain/Diffuse_computeDt.F90:L418`）：
```fortran
if (dt_check <= 0.0) call Driver_abortFlash("[Diffuse]: computed dt is not positive! Aborting!")
```

**原因**：
- parfile 错写 `dt_diff_factor = 0`（应是 0.8 或 1e100）
- D_max = NaN（COND_VAR NaN，见 A.3）
- dx = 0（极小网格问题）

**修复**：检查 parfile 和网格。

### C.3 useDiffuseComputeDtTherm 关闭但 parfile 没设

**症状**：HEDP 算例运行慢，dt 太小。

**原因**：`useDiffuseComputeDtTherm` 默认 `.true.`（`source/physics/Diffuse/DiffuseMain/Config:L32`），即使开了隐式求解仍会算 dt 限制。

**修复**：要么关开关（虽然传不到 Driver），要么用 `dt_diff_factor = 1e100`（推荐）。

---

## D. 边界条件错

### D.1 BC 字符串写错

**症状**：HYPRE 报错或 BC 不生效。

**原因**：parfile 写 `"reflecting"` / `"wall"` 等不允许值。

**允许值**（按 L-008 贴 Config）：
```
源码：source/physics/Diffuse/DiffuseMain/Unsplit/diff_saInit.F90:L67-L90
允许的 BC 字符串（通过 RuntimeParameters_mapStrToInt 映射到整数）：
- "periodic"
- "outflow" 或 "neumann"
- "dirichlet"
- "vacuum"
- 其他 → 报错（具体看 Grid 单元的处理）
```

**修复**：用允许值。

### D.2 DIRICHLET 没设值

**症状**：边界 T = 0（默认 -1 → 0），物理错。

**原因**：写 `diff_eleXlBoundaryType = "dirichlet"` 但没写 `diff_eleXlBoundaryValue = 100.0`。

**源码**（`source/physics/Diffuse/DiffuseMain/Diffuse_init.F90:L204-L207`）：
```fortran
!! For Dirichlet BC: initialize boundary value transport coeffs to -1 so they are not used by default
diff_elebcValues(2,:) = -1.
```

**修复**：DIRICHLET 时同时设 `diff_eleXlBoundaryValue = <T_value>`。

### D.3 Yl 边界选错（LaserSlab）

**症状**：温度场反弹，物理错（热不逃出）。

**原因**：把 LaserSlab Yl 设成 `"neumann"` 而非 `"vacuum"`。

**为什么 vacuum**：Yl 是激光进入方向，外部是真空，热 / 辐射应能逃。neumann 会反弹。

**修复**：
```
diff_eleYlBoundaryType = "vacuum"
```

---

## E. 启动 abort

### E.1 unsupported geometry

**症状**：启动 abort `unsupported geometry`。

**触发代码**（源码：`source/physics/Diffuse/DiffuseMain/Diffuse_init.F90:L111-L129`）：
```fortran
if (diff_geometry == CARTESIAN)then
   diff_dirGeom(IAXIS) = XYZ
   ...
elseif(diff_geometry == POLAR)then
   ...
elseif(diff_geometry == CYLINDRICAL) then
   ...
elseif(diff_geometry == SPHERICAL) then
   ...
else
   call Driver_abortFlash("unsupported geometry ")
end if
```

**原因**：geometry 参数错（如 `"cylindrical2d"` 而非 `"cylindrical"`）。

**修复**：用允许的 geometry 值：`cartesian` / `polar` / `cylindrical` / `spherical`。

### E.2 3T EOS 没启用（diff_useEleCond 无效）

**症状**：设 `diff_useEleCond = .true.` 但实际没解电子热传导。

**原因**：没用 `+uhd3t` 或 `+mtmmmt` setup，没有 `TELE_VAR`。Diffuse 自动回退到 1T 模式解 `TEMP_VAR`。

**源码**（`source/physics/Diffuse/DiffuseMain/Unsplit/diff_advanceTherm.F90:L166-L187`）：
```fortran
#ifdef TELE_VAR
   if (.not. (diff_useEleCond .or. diff_useIonCond) ) return
   firstComponent= EOSCOMP_ELE
   Temptodiffuse = TELE_VAR
   ...
#else
   firstComponent= EOSCOMP_MATTER
   Temptodiffuse = TEMP_VAR
   ...
#endif
```

**修复**：setup 加 `+uhd3t`（或 `+mtmmmt`）启用 3T。

### E.3 HYPRE 单元没 REQUIRES

**症状**：编译报 `undefined reference to grid_advancediffusion`。

**原因**：setup 没 REQUIRES `Grid/GridSolvers/HYPRE`。

**修复**：在 problem Config 加：
```
REQUIRES Grid/GridSolvers/HYPRE
```

或用 setup 期变量（如 `+mgd` 自动 REQUIRES）。

### E.4 SupportAnisoCond 没设但开各向异性

**症状**：编译报 `undefined reference to cnd1_var`。

**原因**：parfile 设 `diff_anisoCondForEle = .true.` 但 setup 没 `SupportAnisoCond`。

**源码**（`source/physics/Diffuse/DiffuseMain/Unsplit/Config:L43-L52`）：
```
USESETUPVARS SupportAnisoCond
IF SupportAnisoCond
   PARAMETER diff_anisoCondForEle    BOOLEAN TRUE
   PARAMETER diff_useCrossCond    BOOLEAN FALSE
ELSE
   PARAMETER diff_anisoCondForEle    BOOLEAN CONSTANT FALSE # cannot be turned on in parfile!
   PARAMETER diff_useCrossCond    BOOLEAN CONSTANT FALSE
ENDIF
```

**修复**：setup 加 `SupportAnisoCond` 编译期变量。

---

## F. 性能问题

### F.1 HYPRE 太慢（每步几秒到几十秒）

**症状**：每 hydro 步 HYPRE 占 50%+ 时间。

**原因 1**：网格太细。**修复**：用 AMR 局部加密（vs UG 均匀）。

**原因 2**：`gr_hypreMaxIter` 太大。**修复**：调小（如 200，让 HYPRE 早返回，物理精度仍可接受）。

**原因 3**：`gr_hypreRelTol` 太严。**修复**：放宽到 1e-6。

**原因 4**：求解器选错（PCG 不收敛时迭代多）。**修复**：换 AMG 或 BiCGSTAB。

### F.2 HYPRE Setup 占时间

**症状**：每步 gr_hypreSetupSolver 占时间。

**原因**：HYPRE 团队 2013 建议"每步重设求解器"（避免 communicator 泄漏）。

**源码**（`source/Grid/GridSolvers/HYPRE/gr_hypreSolve.F90:L116-L118`）：
```fortran
!! Rob Falgout recommended on 2013-01-09 to do the solver setup
!! each time before the solver is called.
call gr_hypreSetupSolver(forMag)
```

**修复**：接受这个开销（vs 内存泄漏）。新版 HYPRE 可能不需要，但 FLASH 4.8 保守。

---

## G. MGD 调 Diffuse_solveScalar 的特殊问题

### G.1 互补声明（指向 flash-radtrans）

MGD 通过 `Diffuse_solveScalar` 调 HYPRE 的物理侧问题（rt_mgd* 参数、群结构、源项）在 `flash-radtrans` 已详讲。

本 skill 只补充：MGD 调用的 HYPRE 侧（求解器、容差、BC）和电子热传导用的是**同一套机制**——`gr_hypre*` 参数同时影响两者。

### G.2 rt_mgdthetaImplct vs diff_thetaImplct

**两者独立**：
- `rt_mgdthetaImplct`：MGD 辐射扩散的 θ（默认 1.0）
- `diff_thetaImplct`：电子热传导的 θ（默认 0.5）

**为什么独立**：辐射和电子热传导物理时间尺度不同，可能需要不同 θ。

### G.3 MGDC_VAR 累加

MGD 解辐射扩散时也通过 `Diffuse_solveScalar`，但 iVar = MGDRg_VAR（每群独立）。HYPRE 解的是 MGDRg 的扩散方程，结果累加到 MGDC_VAR（辐射能量变化）。

详见 `flash-radtrans/internals.md §2 Step 5f`。

---

## H. 总结：常见错误速查表

| 错误信息 / 症状 | 原因 | 修复 | 类别 |
|---|---|---|---|
| `Nonconv./failure` in HYPRE | 不收敛 | 见 A.0 诊断引导 | A |
| `num_iterations = 500` | maxIter 太小 | 调到 2000+ | A.1 |
| `final_res_norm = NaN` | COND_VAR NaN | 检查 Conductivity 表 | A.3 |
| PCG 不收敛 | 矩阵非对称 | 换 BiCGSTAB | A.4 |
| 温度场震荡 / 超光速 | fl_none 默认 | 设 fl_larsen | B.1 |
| `Invalid Flux limiter type` | 模式拼错 | 用允许值 | B.2 |
| `[Diffuse]: computed dt is not positive` | dt_diff_factor=0 | 改 0.8 或 1e100 | C.2 |
| `unsupported geometry` | geometry 名错 | 用允许值 | E.1 |
| `undefined reference to ... HYPRE` | HYPRE 没 REQUIRES | Config 加 REQUIRES | E.3 |
| `undefined reference to cnd1_var` | 没设 SupportAnisoCond | setup 加 | E.4 |

---

## I. 延伸阅读

- **Diffuse 总览**：`knowledge/overview.md`
- **参数字典**：`knowledge/params.md`
- **内部实现**：`knowledge/internals.md`
- **典型配置**：`knowledge/recipes.md`
- **MGD 物理 / rt_mgd* 参数**：`flash-radtrans` skill（互补）
- **Conductivity 单元（COND_VAR 来源）**：`flash-material`（Phase 2）
- **手册**：FLASH 4.8 User Guide §20, §23

---

## J. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（beta）：10 段 pitfalls；按 L-012 每段先引导贴现场再列原因；按 L-008 贴 abort 触发代码（dt<=0、unsupported geometry、Invalid flux limiter type、SupportAnisoCond Config）；按 L-013 聚焦主流问题（HYPRE 不收敛 / flux limiter 选错）；8 类常见错误速查表；MGD 互补声明指向 flash-radtrans；按 L-011 讲为什么默认值/为什么这么修 | claude |
