---
title: 扩散项（Diffuse / HYPRE 隐式求解器）
skill: flash-diffuse
category: overview
source_anchors:
  - source/physics/Diffuse/Config:1-10
  - source/physics/Diffuse/DiffuseMain/Config:1-8
  - source/physics/Diffuse/DiffuseMain/Unsplit/Config:1-14
  - source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:1-10
  - source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveCoupledScalar.F90:1-5
  - source/physics/Diffuse/DiffuseMain/Unsplit/diff_advanceTherm.F90:1-5
  - source/Grid/GridSolvers/HYPRE/Unified/gr_uhypreSolve.F90:1-5
  - source/Simulation/SimulationMain/LaserSlab/Config:70-80
manual_ref: "FLASH 4.8 User Guide §19 (Diffusive Terms) pp.329-336, PDF pp.347-358"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - diffuse
  - hypre
  - implicit-solver
  - thermal-conduction
  - flux-limiter
  - MGD
  - Unsplit
---

# 扩散项（§19）

> **TL;DR**：Diffuse 单元是 MGD 辐射扩散和电子热传导的**底层隐式求解器**。3 个互斥变体：Unsplit（HYPRE，LaserSlab 实际使用）、Split（Strang 方向分裂，旧版）、CG（共轭梯度）。Unsplit + HYPRE 是 HEDP 标准路径。支持通量限制器、各项同性/异性热扩散、自定义标量扩散。

## 1. 五组分

| 组分 | 目录 | HEDP 路径 |
|---|---|---|
| DiffuseFluxBased（显式通量） | `DiffuseFluxBased/` | PPM Hydro 内部调用（hy_ppm_sweep） |
| **General Implicit Solver** | `DiffuseMain/Unsplit/` | **← HYPRE → MGD + 热传导（主路径）** |
| Flux Limiters | `DiffuseMain/` | 通量限制器（电导、辐射） |
| Isotropic Thermal Diffusion | `DiffuseMain/Unsplit/` | 各项同性热传导 |
| Anisotropic Thermal Diffusion | `DiffuseMain/Unsplit/` | 异性热传导（磁场） |

**三个互斥变体**（`DiffuseMain/Config:8`）：`EXCLUSIVE Unsplit Split CG`

## 2. Unsplit + HYPRE（主路径）

### 2.1 通用隐式扩散

方程形式（式 19.1）：

$$A\frac{\partial f}{\partial t} + Cf = \nabla \cdot B\nabla f + D$$

离散化（式 19.2，θ-加权）：

$$A^n\frac{f^{n+1} - f^n}{\delta t} + C^n f^{n+1} = \theta(\nabla \cdot B^n \nabla f^{n+1}) + (1-\theta)(\nabla \cdot B^n \nabla f^n) + D$$

| θ | 方法 |
|---|---|
| 0.0 | 显式 |
| 0.5 | Crank-Nicolson |
| 1.0 | Backward Euler（默认：完全隐式，无条件稳定） |

**注意**：A, B, C 在 $t^n$ 评估（时间滞后线性化），非完全隐式（仅在常数情形完全隐式）。时间步可通过 `dt_diff_factor` 缩放。

### 2.2 HYPRE 接口

**源码验证**：`Unsplit/Config:3` → `REQUIRES Grid/GridSolvers/HYPRE/Unified`（强制依赖）。

HYPRE 提供结构化（PFMG、SMG）和代数（BoomerAMG、PCG、GMRES）求解器。底层调用 `Grid/GridSolvers/HYPRE/Unified/gr_uhypreSolve.F90`。

### 2.3 LaserSlab 实际使用

```bash
# setup_call 铁证：
--unit=physics/Diffuse/DiffuseMain/Unsplit
```

```fortran
# Config 铁证：
REQUESTS physics/Diffuse/DiffuseMain/Unsplit
```

**源码验证**：`source/Simulation/SimulationMain/LaserSlab/Config` 含上述 REQUESTS 行。

## 3. 热传导（§19.1.4-19.1.5）

### 3.1 各项同性热传导

3T 等离子体电子热传导方程（按 §14 式 14.10）：

$$\frac{\partial(\rho e_{\text{ele}})}{\partial t} = \nabla \cdot K_{\text{ele}} \nabla T_{\text{ele}}$$

Diffuse 调用 `Conductivity` 单元计算 $K_{\text{ele}}$，HYPRE 隐式求解。

**源码**：`diff_advanceTherm.F90` 实现各项同性电子热传导步。

### 3.2 各项异性热传导

含磁场方向依赖的电导率张量，适用于磁化等离子体。

## 4. Flux Limiters（§19.1.3）

物理动机：经典 Spitzer 热传导在陡峭 $T_e$ 梯度区预测非物理高通量（> 自由流限值 $n_e k_B T_e v_{\text{therm}}$）。

API：`Diffuse_getFluxLimiter(dcoeff, ifl, mode)` 修改扩散系数。

| mode | 说明 |
|---|---|
| `"none"` | 不限制 |
| `"user"` | 用户自定义 |
| `"max"` | 最大值限制 |

默认限制器在 HEDP 模拟中自动启用（`useDiffuse=.true.` 时）。

## 5. 边界条件（§19.1.2.1）

| 条件 | 含义 | 适用 |
|---|---|---|
| `"neumann"` | ∂f/∂n = 0（零通量） | 绝缘/反射壁 |
| `"dirichlet"` | f = 固定值 | 固定温度 BC |
| `"vacuum"` | 出射通量 = cf | 真空辐射 BC |
| `"general"` | A·f + B·∂f/∂n = C | 一般 Robin BC |

## 6. 参数速查

| 参数 | 默认 | 说明 |
|---|---|---|
| `useDiffuse` | `.false.` | 启用隐式扩散求解 |
| `dt_diff_factor` | — | 扩散时间步缩放（> 1.0 可更激进但 HYPRE 可能不收敛） |
| `useDiffuseTherm` | — | 是否含热传导 |
| `useDiffuseVisc` | — | 是否含黏性 |
| `diff_theta` | 1.0 | θ 隐式权重 |

## 7. 与其他单元的连接

| 上游 | 下游 | 关系 |
|---|---|---|
| RadTrans/MGD | **Diffuse → HYPRE** | MGD 隐式求解通过 Diffuse |
| Conductivity | **Diffuse (electron cond)** | SpitzerHighZ/LeeMore 提供 $K_{\text{ele}}$ |
| Driver | Diffuse | Driver_evolveFlash 中算子分裂调用 |
| Hydro PPM | DiffuseFluxBased | hy_ppm_sweep 含显式扩散通量 |

## 8. 已知陷阱

| 问题 | 说明 |
|---|---|
| HYPRE 不收敛 | `dt_diff_factor < 1.0` 减小时间步可助收敛 |
| Split vs Unsplit 互斥 | 不能同时包含，`EXCLUSIVE` 强制互斥 |
| CG 变体 | 未广泛测试，Unsplit+HYPRE 是推荐路径 |
| AMR 通量守恒 | 隐式求解器不通过 Grid_conserveFluxes，HYPRE 系统内嵌通量守恒 |

## 9. 延伸阅读

- §14 3T HEDP：热传导在 Operator-Split 中的位置
- §19（本篇）Diffuse 参考
- §23.1 Thermal Conductivity：SpitzerHighZ/LeeMore 电导率
- §23.5 Opacity：MGD 不透明度
- §25 RadTrans/MGD：多群辐射扩散（通过 Diffuse 求解）
- §35.7.5 LaserSlab：完整 HEDP 示例
- `source/Grid/GridSolvers/HYPRE/Unified/`：HYPRE 统一接口

## 10. 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-19 | 创建 draft |
