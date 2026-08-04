---
title: 辐射传输与多群扩散（RadTrans / MGD）
skill: flash-radtrans
category: overview
source_anchors:
  - source/physics/RadTrans/RadTransMain/MGD/Config:1-5
  - source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90:1-10
  - source/physics/RadTrans/RadTransMain/MGD/RadTrans_mgdEFromT.F90:1-10
  - source/physics/RadTrans/RadTransMain/MGD/RadTrans_mgdSetEnergy.F90:1-10
  - source/physics/RadTrans/RadTransMain/MGD/RadTrans_mgdSetBc.F90:1-5
  - source/physics/RadTrans/RadTransMain/MGD/rt_data.F90:1-10
  - source/physics/RadTrans/RadTransMain/MGD/RadTrans_computeFluxLimiter.F90:1-10
  - source/Grid/GridSolvers/HYPRE/gr_hypreSolve.F90:1-5
manual_ref: "FLASH 4.8 User Guide §25 (Radiative Transfer Unit) pp.389-396, PDF pp.407-416"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - radtrans
  - MGD
  - multigroup-diffusion
  - flux-limiter
  - mesh-replication
  - planck-integral
  - HYPRE
  - radiation
  - implicit-solver
---

# 辐射传输与多群扩散（§25）

> **TL;DR**：RadTrans 单元目前唯一实现是 MGD（Multigroup Diffusion）。将频域分为 $N_g$ 群，用扩散近似替换完整辐射传输方程。隐式求解每个群的扩散方程，电子能量方程显式 Operator-split。支持 Planck 谱初始化、自定义谱设置、Mesh Replication 并行扩展。

## 1. 物理模型

### 1.1 辐射传输方程（式 25.1-25.2）

完整 RTE：

$$\frac{1}{c}\frac{\partial I}{\partial t} + \hat{\Omega} \cdot \nabla I + \rho\kappa I = \eta$$

电子能量耦合：

$$\frac{\partial u_e}{\partial t} = \int_0^\infty d\nu \int_{4\pi} d\hat{\Omega}(\rho\kappa I - \eta)$$

### 1.2 MGD 扩散近似（式 25.3-25.4）

将频域分为 $N_g$ 群，群 $g$ 范围 $\nu_g$ 到 $\nu_{g+1}$：

$$\frac{1}{c}\frac{\partial u_g}{\partial t} - \nabla \cdot \left(\frac{1}{3\sigma_{t,g}}\nabla u_g\right) + \sigma_{a,g}u_g = \sigma_{e,g}aT_e^4 \frac{15}{\pi^4}[P(x_{g+1}) - P(x_g)]$$

$$\frac{1}{c}\frac{\partial u_e}{\partial t} = \sum_g [\sigma_{a,g}u_g - \sigma_{e,g}aT_e^4 \frac{15}{\pi^4}(P(x_{g+1}) - P(x_g))]$$

其中 $P(x) = \int_0^x \frac{(x')^3}{\exp(x') - 1} dx'$ 为 Planck 积分，$x = h\nu/k_B T_e$。

### 1.3 时间离散化（式 25.6-25.7）

每条群扩散方程隐式求解：

$$\frac{1}{c}\frac{u_g^{n+1} - u_g^n}{\Delta t} - \nabla \cdot D_g^n \nabla u_g^{n+1} + \sigma_{a,g}^n u_g^{n+1} = \sigma_{e,g}^n a(T_e^n)^4 \frac{15}{\pi^4}[P(x_{g+1}^n) - P(x_g^n)]$$

电子能量显式更新。扩散系数 $D_g^n = 1/3\sigma_{t,g}^n$（无通量限制器时）。

### 1.4 通量限制器

控制参数 `rt_mgdFlMode`（见 §19.1.3）。最大通量限为 $q_{\text{max}} = \alpha_r c u_g$，$\alpha_r$ 通过 `rt_mgdFlCoef` 控制。

## 2. 关键参数

### 2.1 setup 变量

| 变量 | 必需 | 说明 |
|---|---|---|
| `+mgd` | 是 | 包含 MGD 单元 |
| `mgd_meshgroups=N` | 是 | 要求 $N \cdot N_{\text{mesh}} \geq N_g$ |
| `mgd_maxgroups=N` | 可选 | 群边界参数数量，默认 101 |

### 2.2 运行时参数

| 参数 | 类型 | 说明 |
|---|---|---|
| `rt_useMGD` | BOOLEAN | 必须设为 `.true.` |
| `rt_mgdNumGroups` | INTEGER | 实际群数 $N_g$ |
| `rt_mgdBounds_###` | REAL | 群边界（$N_g+1$ 个），默认支持到 101 组 |
| `rt_mgdFlMode` | STRING | 通量限制器模式 |
| `rt_mgdFlCoef` | REAL | 通量限制系数（默认 1.0） |
| `rt_mgdXlBoundaryType` | STRING | x 左边界类型：`reflecting`/`neumann`/`dirichlet`/`vacuum` |
| `rt_planckIntMethod` | INTEGER | Planck 积分方法（0=旧, 213/321/621=新） |
| `useOpacity` | BOOLEAN | 必须 `.true.`（Opacity 单元提供 $\kappa$） |

**boundary 参数**：`rt_mgdXlBoundaryType`, `rt_mgdXrBoundaryType`, `rt_mgdYlBoundaryType`, `rt_mgdYrBoundaryType`, `rt_mgdZlBoundaryType`, `rt_mgdZrBoundaryType`

### 2.3 诊断输出变量

checkpoint 中辐射群能量存为 `r001`, `r002`, ..., `r{N_g}`（`MGDR_NONREP_LOC2UNK` 索引读取）。可加入 plot_var 列表。

## 3. 使用流程

### 3.1 setup 示例

```bash
./setup LaserSlab -2d -auto +cylindrical -nxb=16 -nyb=16 \
  +hdf5typeio species=cham,targ +mtmmmt +laser +mgd mgd_meshgroups=6
```

### 3.2 flash.par 示例

```fortran
rt_useMGD = .true.
rt_mgdNumGroups = 4
rt_mgdBounds_1 = 1.0e-6     ! 下限光子能量 keV
rt_mgdBounds_2 = 1.0e-2
rt_mgdBounds_3 = 1.0
rt_mgdBounds_4 = 10.0
rt_mgdBounds_5 = 100.0
useOpacity = .true.
```

### 3.3 初始化 API

Planck 黑体温初始化：

```fortran
call RadTrans_mgdEFromT(blockId, axis, trad, tradActual)
call Grid_putPointData(blockId, CENTER, TRAD_VAR, EXTERIOR, axis, tradActual)
```

自定义谱初始化：

```fortran
call RadTrans_mgdSetEnergy(blockId, axis, group, eg)
call Grid_putPointData(blockId, CENTER, TRAD_VAR, EXTERIOR, axis, tradActual)
```

**源码验证**：`RadTrans_mgdEFromT.F90:1-10` 和 `RadTrans_mgdSetEnergy.F90:1-10` 对应手册 API 定义。

## 4. Mesh Replication 并行策略（§25.1.2）

当群数很多时，域分解不再是高效并行策略（强缩放限制）。Mesh Replication 将 $N_p$ 个进程分为 $N_m$ 组网格副本，每组负责 $\lceil N_g / N_m \rceil$ 个群的求解。

```
例：Ng=100, Np=6
  meshCopyCount=1: 1 个网格，6 进程域分解，每进程 100 组
  meshCopyCount=2: 2 个网格副本，每副本 3 进程，每进程 50 组
```

约束（式 25.8）：`mgdMeshGroups * meshCopyCount >= rt_mgdNumGroups`

## 5. 修改辐射谱（§25.1.4）

因 mesh replication 导致 $e_g$ 分布各进程不完整，需用 NONREP 宏安全访问：

```fortran
do gloc = 1, NONREP_NLOCS(rt_acrossMe, rt_meshCopyCount, rt_mgdNumGroups)
  g = NONREP_LOC2GLOB(gloc, rt_acrossMe, rt_meshCopyCount)       ! 全局群号
  gvar = MGDR_NONREP_LOC2UNK(gloc)                               ! unk 索引
  blkPtr(gvar, i, j, k) = new_value                              ! 修改群能量
end do
call RadTrans_sumEnergy(ERAD_VAR, nblk, blklst)                  ! 跨网格求和
call Eos_wrapped(MODE_DENS_EI_GATHER, blkLimits, blklst(lb))    ! EOS 更新
```

**关键宏**：
- `NONREP_NLOCS(meshCount, myMeshCopyCount, total)`：本进程负责的本地群数
- `NONREP_LOC2GLOB(loc, meshCount, myMeshCopyCount)`：本地索引 → 全局群号
- `MGDR_NONREP_LOC2UNK(loc)`：本地索引 → `unk` 数组索引

## 6. 隐式求解器

MGD 扩散方程通过 §19.1.2 的通用隐式扩散求解器求解。该求解器调用 HYPRE 库的 PFMG/BoomerAMG 等求解器。

**源码验证**：`source/Grid/GridSolvers/HYPRE/gr_hypreSolve.F90:1-5` 为 HYPRE 求解器入口。RadTrans 调用链：`RadTrans.F90` → Diffuse solver → HYPRE。

## 7. 与 Opacity 单元的耦合

MGD 需要 $\sigma_a$、$\sigma_t$、$\sigma_e$，由 Opacity 单元（§23）提供。`useOpacity = .true.` 且须指定模型（IONMIX/SESAME/Tabulated）。

PLANCK 平均 / Rosseland 平均选择：由 Opacity 单元的运行时参数控制（§23.5）。

## 8. 已知陷阱

| 问题 | 说明 |
|---|---|
| Planck 积分精度 | `rt_planckIntMethod=0`（旧）在 $x < 4\times 10^{-4}$ 时有误。推荐 `rt_planckIntMethod=213` |
| 群边界覆盖 | 黑体谱在截断上限外的能量丢失，`tradActual < trad`。需检查最终辐射温度 |
| Mesh Replication 调试 | `meshCopyCount > 1` 时，各进程 `ERAD_VAR` 不一致，需 `RadTrans_sumEnergy` |
| `mgd_meshgroups` 约束 | 公式 $N \cdot N_{mesh} \geq N_g$ 若不满足，运行时报错 |
| 未设置 `rt_useMGD` | MGD 包含但不启用，算例不报错但也无辐射扩散效应 |
| HYPRE 依赖 | MGD 隐式求解需要 HYPRE 库（grid 编译时含 `+hypre`）|

## 9. 延伸阅读

- 本技能：`.claude/skills/flash-radtrans/knowledge/`
- §14 3T HEDP Capabilities：MGD 在多温系统中的角色
- §19.1.2 通用隐式扩散求解器
- §19.1.3 通量限制器选项
- §23 Opacity 单元：IONMIX/SESAME 表格格式
- §35.7.5 Full-physics Laser Driven Simulation：完整 HEDP 示例
- `source/physics/RadTrans/RadTransMain/MGD/ExpRelax/`：扩展松弛迭代求解方法

## 10. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft，基于 FLASH 4.8 UG §25 pp.389-396 + 源码对照 v4.8） | opencode-ai |
