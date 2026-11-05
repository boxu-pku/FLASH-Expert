---
title: Diffuse 配置 recipes — Unsplit+HYPRE 标准配置 + 5 求解器对比
skill: flash-diffuse
category: recipes
source_anchors:
  - source/Simulation/SimulationMain/LaserSlab/Config
  - source/Simulation/SimulationMain/LaserSlab/flash.par
  - source/physics/Diffuse/DiffuseMain/Unsplit/Config:L25-L128
  - source/Grid/GridSolvers/HYPRE/Config:L31-L155
manual_ref: "FLASH 4.8 User Guide §20, §23"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: beta
tags:
  - diffuse
  - recipes
  - parfile
  - hypre
  - laser-slub
  - flux-limiter
---

# Diffuse 配置 recipes（按 L-013 聚焦主流）

> **TL;DR**：4 个 recipe 覆盖典型场景：① LaserSlab 标准（HEDP 主流，详讲）；② 1T 简单热传导（教学）；③ 大规模生产（>1M cells）；④ 各向异性扩散（MHD）。每个 recipe 给"为什么这么配 + parfile + setup 命令"。5 HYPRE 求解器对比表单独章节。**按 L-004 教学顺序**：最小 → 典型 → 特殊 → 进阶。

---

## 1. 最小可运行配置（教学 / 测试）

### 1.1 场景

1D / 2D 笛卡尔网格，单一物质，简单热传导测试。**不用于 HEDP**（没有陡梯度、没有低密度区、没有 flux limiter 问题）。

### 1.2 setup 命令

```bash
./setup <myProblem> -2d -auto +cartesian \
    +ug \
    -nxb=16 -nyb=16 \
    -objdir=cases/<myProblem>
```

**为什么 `+ug`**：uniform grid 最简单，测试用。LaserSlab 用 `+pm4dev`（AMR）。

### 1.3 parfile 片段（最小）

```fortran
# === Diffuse 主控 ===
useDiffuse       = .true.
useDiffuseTherm  = .true.
diffusion_cutoff_density = 1.e-10

# === θ（用 CN 2 阶精度，教学优先精度）===
diff_thetaImplct = 0.5

# === flux limiter（教学场景不超光速，可不限制）===
diff_eleFlMode   = "fl_none"

# === 边界（4 面零梯度）===
diff_eleXlBoundaryType = "neumann"
diff_eleXrBoundaryType = "neumann"
diff_eleYlBoundaryType = "neumann"
diff_eleYrBoundaryType = "neumann"

# === dt（保守，教学用）===
dt_diff_factor = 0.5

# === HYPRE（默认 PCG + AMG）===
gr_hypreSolverType    = "HYPRE_PCG"
gr_hyprePCType        = "HYPRE_AMG"
gr_hypreMaxIter       = 100
gr_hypreRelTol        = 1.0e-8
```

### 1.4 为什么这么配

| 参数 | 值 | 为什么 |
|---|---|---|
| diff_thetaImplct | 0.5 | Crank-Nicolson 2 阶精度（教学优先精度）|
| diff_eleFlMode | fl_none | 简单测试不超光速，不需要限制 |
| dt_diff_factor | 0.5 | 保守（教学算例小，dt 限制不影响）|
| gr_hypreSolverType | PCG | 默认，对称正定矩阵最优 |
| gr_hyprePCType | AMG | 默认，BoomerAMG 对扩散方程最优 |

---

## 2. LaserSlab 标准（HEDP 主流）

### 2.1 场景

HEDP（High Energy Density Physics）/ ICF（Inertial Confinement Fusion）激光打靶。LaserSlab 是 HEDP 标准参考算例。特点：
- 2D R-Z 柱坐标
- 多物质（CH cham + CH targ）
- 3T EOS（电子+离子+辐射）
- 激光沉积（flash-laser）
- MGD 多群辐射扩散（flash-radtrans）
- **电子热传导**（本 skill 重点）

### 2.2 setup 命令

源码：`cases/LaserSlab/setup_call`

```bash
./setup LaserSlab -2d -auto +cylindrical \
    +hdf5typeio \
    species=cham,targ \
    +mtmmmt \
    +laser +uhd3t +mgd \
    mgd_meshgroups=6 \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab \
    -parfile=example.par
```

**为什么这么配**：
- `+cylindrical`：2D R-Z（HEDP 标准几何）
- `+mtmmmt`：multi-temp multi-material EOS（3T 多物质）
- `+uhd3t`：Unsplit Hydro 3T（Driver 顺序）
- `+mgd`：MGD 多群辐射扩散（自动 REQUESTS `DiffuseMain/Unsplit`）
- `mgd_meshgroups=6`：6 群辐射
- `+laser`：激光沉积
- `+hdf5typeio`：HDF5 输出（flash-io）

**注意**：`+mgd` 隐式 REQUIRES `physics/Diffuse/DiffuseMain/Unsplit`（见 `source/Simulation/SimulationMain/LaserSlab/Config`）。所以**用户不需要显式写 `+diffuse`**。

### 2.3 parfile 完整片段

源码：`source/Simulation/SimulationMain/LaserSlab/flash.par`

```fortran
# === Diffuse 主控 ===
useDiffuse      = .true.
diff_useEleCond = .true.       # 启用电子热传导（3T）
# diff_useIonCond = .false.    # 离子热传导（HEDP 通常关，离子温度变化慢）

# === θ + flux limiter（LaserSlab 经典配置）===
diff_thetaImplct = 1.0         # 后向 Euler，无条件稳定
                                 # ★ 为什么不用 0.5：HEDP 陡梯度 CN 会震荡
diff_eleFlMode  = "fl_larsen"  # Larsen 平滑过渡
diff_eleFlCoef  = 0.06         # HEDP 经验值（有效热传导为自由流的 6%）
                                 # ★ 为什么 0.06：Spitzer 算出的高电导率在低密度区高估

# === 边界条件（6 面）===
diff_eleXlBoundaryType = "neumann"   # 左（r=0 轴）零梯度
diff_eleXrBoundaryType = "neumann"   # 右（出靶）
diff_eleYlBoundaryType = "vacuum"    # ★ 底（激光进入方向，真空让热逃）
diff_eleYrBoundaryType = "neumann"   # 顶（出靶）
diff_eleZlBoundaryType = "neumann"   # 3D 用（2D 忽略）
diff_eleZrBoundaryType = "neumann"

# === dt（隐式不需要 dt 限制，禁用避免步数过多）===
dt_diff_factor = 1.0e+100

# === HYPRE ===
gr_hypreSolverType    = "HYPRE_AMG"   # 直接 BoomerAMG（HEDP 大网格推荐）
                                       # ★ 为什么不用 PCG：超大问题避免双重存储
gr_hyprePrintSolveInfo = .true.       # 打印收敛信息（调试用）
```

### 2.4 为什么是这个配置

| 项 | 选择 | 为什么 |
|---|---|---|
| diff_thetaImplct = 1.0 | 后向 Euler | HEDP 陡梯度（激光沉积 fs 时间尺度）CN 会震荡；无条件稳定重要（dt 大）|
| diff_eleFlMode = fl_larsen | Larsen | 平滑过渡，HEDP 文献标准（vs fl_minmax 突变，fl_harmonic 偏保守）|
| diff_eleFlCoef = 0.06 | 6% 自由流 | HEDP 经验值——Spitzer 算出的电子热传导系数在低密度区高估（实际只 6% 自由流）|
| Yl = vacuum | 真空 | 激光进入方向是真空，让热可逃（neumann 会反弹回去，物理错）|
| dt_diff_factor = 1e100 | 禁用 | 隐式无条件稳定，dt 限制是显式约束（HEDP 物理时间步长本就大，显式 dt 会小到不可用）|
| gr_hypreSolverType = AMG | BoomerAMG | LaserSlab 典型 100×100 = 10⁴ cells，PCG+AMG 也可，但 AMG 独立更快 |

### 2.5 验证配置生效

```bash
cd cases/LaserSlab
grep -E "diff_|gr_hypre" setup_defines
# 应看到：-DDIFF_USEELECOND, FLASH_3T 等

grep -E "diff_thetaImplct|diff_eleFlMode|gr_hypreSolverType" flash.par
# 验证 parfile 读了
```

运行后看日志：
```bash
grep "HYPRE SOLVE\|num_iterations\|final_res_norm" 01-data/<basenm>.log
# 看 HYPRE 是否收敛（num_iterations < maxIter）
```

---

## 3. 大规模生产（>1M cells）

### 3.1 场景

3D 大网格 / 多机并行算例（如 100³ = 10⁶ cells 以上）。**问题**：标准 PCG+AMG 内存大，需要换更高效的求解器。

### 3.2 setup 命令

```bash
./setup <myProblem> -3d -auto +cartesian +pm4dev \
    +laser +uhd3t +mgd \
    mgd_meshgroups=10 \
    -nxb=8 -nyb=8 -nzb=8 \
    maxblocks=2000 \
    -objdir=cases/<myProblem>_3d \
    -parfile=big.par
```

**为什么 `+pm4dev`**：AMR（PARAMESH dev）支持局部加密，比 UG 省内存。

### 3.3 parfile 片段

```fortran
# === Diffuse 主控 ===
useDiffuse      = .true.
diff_useEleCond = .true.
diff_useIonCond = .true.        # 3D 大算例可能要离子热传导

# === θ + flux limiter ===
diff_thetaImplct = 1.0
diff_ionThetaImplct = 1.0       # 离子也全隐式
diff_eleFlMode  = "fl_larsen"
diff_eleFlCoef  = 0.06
diff_ionFlMode  = "fl_larsen"
diff_ionFlCoef  = 0.10          # 离子稍微大些（离子自由流更大）

# === 边界（3D 6 面）===
diff_eleXlBoundaryType = "neumann"
diff_eleXrBoundaryType = "neumann"
diff_eleYlBoundaryType = "neumann"
diff_eleYrBoundaryType = "neumann"
diff_eleZlBoundaryType = "neumann"
diff_eleZrBoundaryType = "neumann"

# === dt ===
dt_diff_factor = 1.0e+100

# === HYPRE（大规模优化）===
gr_hypreSolverType    = "HYPRE_AMG"      # 直接 AMG（vs PCG+AMG 省内存）
gr_hypreMaxIter       = 1000             # 大网格要更多迭代
gr_hypreRelTol        = 1.0e-6           # 物理精度 1e-6 够（vs 默认 1e-8）
gr_hyprePrintSolveInfo = .true.
gr_hypreAbsTol        = 1.0e-20          # 防 b 范数很大时不灵敏
```

### 3.4 为什么这么配

| 项 | 选择 | 为什么 |
|---|---|---|
| gr_hypreSolverType = AMG | 直接 AMG | PCG 内部存 x, p, q, r, z 等 5+ 向量，大网格内存吃不消；AMG 直接求解内存小 |
| gr_hypreMaxIter = 1000 | 翻倍 | 大网格条件数大，500 步可能不够 |
| gr_hypreRelTol = 1e-6 | 放宽 | 物理精度 1e-6 足够；1e-8 浪费迭代 |
| gr_hypreAbsTol = 1e-20 | 启用 | b 范数很大时（大体积能量），相对容差不灵敏 |
| diff_ionFlCoef = 0.10 | 离子稍大 | 离子自由流通量比电子大（v_th ∝ 1/sqrt(m)），限制系数可稍宽 |

---

## 4. 各向异性扩散（MHD）

### 4.1 场景

强磁场等离子体（如磁化 ICF / 天体物理 jet）。电子沿磁力线运动远比垂直快，需要各向异性扩散（CND1=平行 / CND2=垂直 / CND3=交叉）。

### 4.2 setup 命令

```bash
./setup <myMHDProblem> -2d -auto +cartesian +pm4dev \
    +mhd +laser +uhd3t +mgd \
    SupportAnisoCond \
    species=cham,targ \
    -objdir=cases/<myMHDProblem>
```

**为什么 `SupportAnisoCond`**：setup 期变量，开启 CND1/CND2/CND3 变量声明（编译期）。

### 4.3 parfile 片段

```fortran
# === 各向异性扩散 ===
diff_anisoCondForEle = .true.    # 电子各向异性（MHD 必须开）
# diff_anisoCondForIon = .false. # 离子各向异性（可选）
diff_useCrossCond = .false.      # 交叉项（CND3），默认关，复杂物理才开

# === θ + flux limiter（垂直方向限制）===
diff_thetaImplct = 1.0
diff_eleFlMode  = "fl_larsen"
diff_eleFlCoef  = 0.06

# === 边界 ===
diff_eleXlBoundaryType = "neumann"
diff_eleXrBoundaryType = "neumann"
diff_eleYlBoundaryType = "neumann"
diff_eleYrBoundaryType = "neumann"

# === HYPRE（非对称矩阵可能要 BiCGSTAB）===
gr_hypreSolverType    = "HYPRE_BICGSTAB"   # ★ 为什么不用 PCG：flux limiter 让矩阵非对称
gr_hyprePCType        = "HYPRE_AMG"
gr_hypreMaxIter       = 1000
```

### 4.4 为什么这么配

| 项 | 选择 | 为什么 |
|---|---|---|
| diff_anisoCondForEle = .true. | 开启 | MHD 算例磁场强，必须各向异性（否则垂直热传导严重高估）|
| SupportAnisoCond (setup) | 编译期 | 决定 CND1/2/3 变量是否声明；REQUIRES `physics/Hydro/HydroMain/unsplit/MHD_StaggeredMesh`（见 `HYPRE/Config:L148-L151`）|
| diff_useCrossCond = .false. | 默认关 | 交叉项（CND3）增加复杂度，少见用 |
| gr_hypreSolverType = BiCGSTAB | 非对称 | flux limiter 让系数 cell-face 依赖，矩阵非对称，PCG 不适用 |

### 4.5 注意：flux limiter 应用于 perpendicular

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/diff_advanceTherm.F90:L284-L298`

```fortran
if (diff_anisoCondForEle) then
   ! Perpendicular 是 isotropic 部分，限制它
   call Diffuse_fluxLimiter(cvarPERPCOND, Temptodiffuse, FLLM_VAR, ...)
   ! 然后平行和交叉按同 λ 缩放
   solnVec(cvarPARCOND) *= solnVec(FLLM_VAR)
   if (diff_useCrossCond) solnVec(cvarCROSSCOND) *= solnVec(FLLM_VAR)
end if
```

**为什么这样**：保持各向异性比不变（平行 / 垂直比例固定），只整体缩放。

---

## 5. 5 HYPRE 求解器对比

源码：`source/Grid/GridSolvers/HYPRE/gr_hypreSetupSolver.F90:L228-L373`

### 5.1 对比表（按 L-011 讲为什么）

| 求解器 | 适用矩阵 | 收敛速度 | 内存 | 何时选 | 为什么 |
|---|---|---|---|---|---|
| **HYPRE_PCG** | 对称正定 | 快 O(sqrt(κ)) | 中（5+ 向量）| **默认**，扩散方程标准 | CG 是对称正定问题最优迭代法 |
| **HYPRE_AMG** | 任意 | 中（多重网格 O(N)）| 大（多重层次）| LaserSlab / 大规模 | 直接求解，避免 PCG 双重存储 |
| HYPRE_BICGSTAB | 非对称 | 中（2 倍 PCG work/iter）| 中 | flux limiter 让矩阵非对称 | 非对称矩阵 CG 不收敛 |
| HYPRE_GMRES | 任意 | 慢但稳 | 大（k 维 Krylov）| 最难收敛问题 | 理论保证收敛但慢 |
| HYPRE_HYBRID | 任意 | 自适应 | 中 | 旧 HYPRE 推荐 | 自动 DSCG → AMG-PCG 切换，新版用 PCG+AMG 取代 |
| HYPRE_SPLIT | 特殊 | - | 小 | 结构化网格特殊 | SStruct-split，少见 |

### 5.2 何时换求解器

**症状 → 求解器**：

| 症状 | 可能原因 | 推荐求解器 |
|---|---|---|
| 默认 PCG 收敛慢（>500 iter）| 条件数大 | AMG 独立，或 BiCGSTAB |
| PCG 不收敛（final_res_norm 不下降）| 矩阵非对称（flux limiter）| BiCGSTAB |
| BiCGSTAB 也不收敛 | 病态 | GMRES |
| 内存不够 | 大网格 | AMG（vs PCG）|
| 速度优先 | 中小网格 | PCG + AMG |

### 5.3 预条件子（PC）选择

源码：`source/Grid/GridSolvers/HYPRE/gr_hypreSetupSolver.F90:L131-L221`

| PC | 含义 | 何时选 | 为什么 |
|---|---|---|---|
| **HYPRE_AMG** | BoomerAMG 多重网格 | **默认** | 扩散方程最优（多重网格近似 A⁻¹）|
| HYPRE_ILU | Euclid ILU | 中小问题 | 不完全 LU 分解，简单 |
| HYPRE_PARASAILS | 稀疏近似逆 | 并行扩展 | 适合大规模并行 |
| HYPRE_NONE | 无 PC | 调试 | 看求解器本身性能 |

**为什么默认 AMG**：BoomerAMG 对扩散方程的最优预条件（多重网格层次结构），收敛速度比 ILU 快几个数量级。

---

## 6. flux limiter 选择决策树

```
要解什么物理？

├── MGD 辐射扩散
│   └── fl_harmonic（推荐）或 fl_levermorepomraning1981（精确）
│       └── 为什么 harmonic：平滑过渡，对光学薄区表现稳健
│
├── 电子热传导（HEDP / LaserSlab）
│   └── fl_larsen + coef=0.06
│       └── 为什么 larsen：HEDP 标准经验值，平滑过渡
│
├── 离子热传导
│   └── fl_larsen + coef=0.10（或 fl_none，离子扩散系数小，问题不大）
│
├── 磁扩散
│   └── fl_none 或 fl_larsen
│       └── 为什么 none 可接受：磁场强度本身有上限
│
├── 极端陡梯度（如激波后）
│   └── fl_minmax（最保守，但可能突变）
│
└── 教学简单问题（无超光速）
    └── fl_none（不限制）
```

---

## 7. 边界条件选择

### 7.1 决策表

| 物理场景 | BC | 为什么 |
|---|---|---|
| 周期算例（如湍流）| `periodic` | 物理量循环 |
| 开放边界（如激光打靶远场）| `neumann` 或 `outflow` | 零梯度，物理量自由流出 |
| 真空边界（辐射逃逸）| `vacuum` | 让辐射 / 热逃到真空 |
| 固定温度（如加热壁）| `dirichlet` + 值 | T = T_bc 固定 |
| 反射边界（如 r=0 轴）| `neumann`（隐式反射）| ∂T/∂r = 0 轴对称 |
| 入射辐射 | `dirichlet` 或定制 | 设入射通量 |

### 7.2 LaserSlab 6 面 BC 解析（按 L-011）

```
2D R-Z 网格：

       Yr (neumann) — 顶，出靶面（热可流出）
       ↑
       │
Xl ────┼──── Xr (neumann) — 右，出靶面
(轴)   │
       │
       Yl (vacuum) — 底，激光进入方向，真空让热逃

Xl = r=0 轴（轴对称，零梯度）
Xr = 远场（出靶面）
Yl = 激光进入方向（真空，辐射可逃）
Yr = 出靶面（热可流出）
```

**为什么 Yl = vacuum 而不是 neumann**：
- Yl 是激光从外部进入的边界
- 外部是真空（密度极低）
- vacuum BC 让辐射 / 热可以"逃"到真空（不反弹）
- neumann 会把辐射反弹回算例区域，物理错

---

## 8. setup 期变量 vs 运行期参数

按 L-009 警告：**setup 期变量不能在 parfile 改**。

| 变量 | 类型 | 怎么设 |
|---|---|---|
| `mgd_meshgroups` | setup 期 | setup 命令 `mgd_meshgroups=6` |
| `SupportAnisoCond` | setup 期 | setup 命令 `SupportAnisoCond`（开关）|
| `MHD` | setup 期 | setup 命令 `+mhd` |
| `nDim` | setup 期 | setup 命令 `-2d` / `-3d` |
| `diff_anisoCondForEle` | **CONSTANT**（如开 SupportAnisoCond 否则不可改）| setup 期决定 |
| 其他 diff_* | 运行期 | parfile |
| gr_hypre* | 运行期 | parfile |

验证 setup_call 实际：
```bash
cat cases/<case>/setup_call
```

---

## 9. 延伸阅读

- **Diffuse 总览 / 设计**：`knowledge/overview.md`
- **参数字典（diff_* / gr_hypre*）**：`knowledge/params.md`
- **内部实现（HYPRE 矩阵组装）**：`knowledge/internals.md`
- **常见错误**：`knowledge/pitfalls.md`
- **LaserSlab parfile 完整**：`source/Simulation/SimulationMain/LaserSlab/flash.par`
- **MGD 配置 recipes**：`flash-radtrans/knowledge/recipes.md`
- **手册**：FLASH 4.8 User Guide §20, §23

---

## 10. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（beta）：9 段 recipes；按 L-004 教学顺序（最小 → 典型 → 大规模 → 各向异性）；按 L-013 聚焦 LaserSlab（HEDP 主流）详讲，其他简要；按 L-011 每个参数给"为什么这么配"；5 HYPRE 求解器对比表；flux limiter 决策树；6 面 BC 决策表；LaserSlab Yl=vacuum 物理解释；setup 期 vs 运行期变量区分（L-009）| claude |
