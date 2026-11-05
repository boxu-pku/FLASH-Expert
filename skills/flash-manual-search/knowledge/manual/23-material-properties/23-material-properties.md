---
title: 物质属性单元（Opacity / Conductivity / Viscosity / MagneticResistivity）
skill: flash-material
category: overview
source_anchors:
  - source/physics/materialProperties/Opacity/Config:1-5
  - source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Config:1-5
  - source/physics/materialProperties/Conductivity/Config:1-5
  - source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Config:1-5
  - source/physics/materialProperties/Conductivity/ConductivityMain/LeeMore/Config:1-5
  - source/physics/materialProperties/MagneticResistivity/Config:1-5
  - source/physics/materialProperties/Viscosity/Config:1-5
  - source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity.F90:1-10
manual_ref: "FLASH 4.8 User Guide §23 (Material Properties) pp.375-386, PDF pp.393-404"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - opacity
  - conductivity
  - thermal-conduction
  - magnetic-resistivity
  - viscosity
  - spitzer
  - lee-more
  - IONMIX
  - Rosseland
  - Planck
  - mass-diffusivity
---

# 物质属性单元（§23）

> **TL;DR**：5 个独立物质属性子单元：Opacity（为 MGD 提供 κ）、Conductivity（SpitzerHighZ/LeeMore 电子热导）、MagneticResistivity（Constant/SpitzerHighZ 磁阻）、Viscosity（Constant 粘度）、MassDiffusivity（仅 stub）。Opacity 的 Multispecies 实现支持 per-species 的 constant/constcm2g/tabulated 三种模型，表格文件为 IONMIX/IONMIX4/IONMIX6 格式。> **互补声明**：本条目与 `skills/flash-material/knowledge/` 互补，侧重手册 §23 的整体结构和使用方式。

## 1. 子单元总览

| 子单元 | 目录 | 用途 | 解算器依赖 |
|---|---|---|---|
| Conductivity | `materialProperties/Conductivity` | 电子热导率 $K_{\text{ele}}$ | Diffuse（隐式热传导） |
| MagneticResistivity | `materialProperties/MagneticResistivity` | 磁阻率 | MHD 求解器 |
| Viscosity | `materialProperties/Viscosity` | 动力粘度 | Hydro / MHD |
| Opacity | `materialProperties/Opacity` | $\sigma_a, \sigma_e, \sigma_t$ | RadTrans / MGD |
| MassDiffusivity | `materialProperties/MassDiffusivity` | 质量扩散率 | 仅 stub |

**目录结构**：`source/physics/materialProperties/` 下 5 个子目录。每个子目录内含 `Config` + `*Main/<implementation>/`（图 23.1-23.2）。

**启用方式**：各子单元通过 runtime parameter 启用（如 `useConductivity=.true.`），或通过 `+laser`、`+mgd` 等 shortcut 自动拉入。

## 2. Thermal Conductivity（§23.1）

| 实现 | 目录 | 公式 | 适用 |
|---|---|---|---|
| Constant | `ConductivityMain/Constant` | 常数体热导率 | 测试 |
| Constant-diff | `ConductivityMain/Constant-diff` | 常数扩散系数 | 测试 |
| SpitzerHighZ | `ConductivityMain/SpitzerHighZ` | 式 23.1：$K_{\text{ele}} = \frac{8}{\pi}\frac{k_B^{7/2}}{e^4\sqrt{m_e}}\frac{1}{1+3.3/\bar{z}}\frac{T_{\text{ele}}^{5/2}}{\bar{z}\ln\Lambda_{ei}}$ | HEDP 模拟 |
| LeeMore | `ConductivityMain/LeeMore` | Lee & More (1984) 改进模型 | 高精度 HEDP |

**关键参数**：`useConductivity = .true.` 启用。

**Spitzer vs LeeMore**：
- 高温区：几乎一致（仅 $\ln\Lambda_{ei}$ 处理不同）
- 低温区：SpitzerHighZ 错误地假设经典等离子体（实际非经典）；LeeMore 显著更准确
- 实践：HEDP 激光加热快速升温，两者差异常可忽略。建议对比测试。

**源码验证**：`source/.../Conductivity/ConductivityMain/SpitzerHighZ/Config:1-5` 和 `source/.../Conductivity/ConductivityMain/LeeMore/Config:1-5`。

## 3. Magnetic Resistivity（§23.2）

| 实现 | 说明 |
|---|---|
| Constant | 常数电阻率 $\eta$ |
| SpitzerHighZ | Spitzer 模型计算的 $\eta$ |

## 4. Viscosity（§23.3）

仅 Constant 实现。`useViscosity = .true.` 启用。`visCoeff` 为常数动力粘度系数。

## 5. Thermoelectric Coefficients（§23.4）

Biermann 电池效应项（$\nabla T_e \times \nabla n_e$ 产生磁场），用于 MHD 无磁场 seed 模拟。

## 6. Opacity（§23.5）

Opacity 单元为 RadTrans/MGD 提供 $\sigma_a$（吸收）、$\sigma_e$（发射）、$\sigma_t$（传输）三类不透明度（单位 $1/\text{cm}$）。

API 接口：

```fortran
call Opacity(soln, ngrp, opacityAbsorption, opacityEmission, opacityTransport)
```

### 6.1 实现列表

| 实现 | 类型 | 说明 |
|---|---|---|
| Constant | 灰体 | 常数 $\kappa$（1/cm），参数 `op_absorbConst`/`op_emissConst`/`op_transConst` |
| Constcm2g | 灰体 | 常数 $\kappa$（cm²/g），参数同上 |
| BremsstrahlungAndThomson | 灰体 | 韧致 + Thomson 散射近似（式 23.8-23.9） |
| OPAL | 灰体 | LLNL OPAL 表查找（恒星不透明度，用于 SNEC 超新星） |
| **Multispecies** | **多群** | **HEDP 主力实现**，per-species per-type 三种模型 |

### 6.2 Multispecies 实现（§23.5.5）

Per-species per-type（吸收/发射/传输）指定模型：

| 模型 | 定义 | 单位 |
|---|---|---|
| `"op constant"` | 常数不透明度 | 1/cm |
| `"op constcm2g"` | 常数不透明度 | cm²/g |
| `"op tabpa"` | IONMIX 表格 Planck 吸收 $\kappa$ | cm²/g |
| `"op tabpe"` | IONMIX 表格 Planck 发射 $\kappa$ | cm²/g |
| `"op tabro"` | IONMIX 表格 Rosseland $\kappa$ | cm²/g |

**Runtime 参数模式**（表 23.1）：

| 参数 | 示例 |
|---|---|
| `op_chamAbsorb` | `"op_tabpa"` |
| `op_chamEmiss` | `"op_tabpe"` |
| `op_chamTrans` | `"op_tabro"` |
| `op_chamFileName` | `"he-imx-005.cn4"` |
| `op_chamFileType` | `"ionmix4"` |

**双线性插值**（式 23.10-23.14）：对表格外的 (T, ρ) 取边界值。支持线性或 log10 变换插值。

**限制**：
- species 必须通过 `species=` setup 变量定义（不可用 Config 中 `SPECIES` 关键字）
- 所有物种使用相同的 energy group 结构（与 RadTrans 一致）

### 6.3 IONMIX4 文件格式（§23.5.6）

顺序：ntemp, ndens → 元素信息 → 群数 $N_g$ → T 列表 → n 列表 → $\bar{z}$ → $P_i$ → $P_e$ → $e_i$ → $e_e$ → ... → 群边界 → **Rosseland** → **Planck 吸收** → **Planck 发射**

每个群不透明度为 `(ndens × ntemp × ngroups)` 三维数组。IONMIX6 额外包含电子比熵。

### 6.4 文件扩展名约定

本仓库中的 IONMIX 表格使用 `.cn4`（IONMIX4 格式）、`.imx`（IONMIX 格式）、`.ses`（SESAME 格式）扩展名。

## 7. Mass Diffusivity（§23.6）

仅提供非操作性 stub。无实际扩散计算。

## 8. 典型 parfile 配置

```fortran
! Conductivity
useConductivity = .true.
! SpitzerHighZ 是默认

! Opacity
useOpacity = .true.
op_chamAbsorb   = "op_tabpa"
op_chamEmiss    = "op_tabpe"
op_chamTrans    = "op_tabro"
op_chamFileName = "he-imx-005.cn4"
op_chamFileType = "ionmix4"
op_targAbsorb   = "op_constcm2g"
op_targAbsorbConst = 10.0
```

## 9. 已知陷阱

| 问题 | 说明 |
|---|---|
| Opacity 不与外部单位直接交互 | Opacity 仅被 RadTrans 内部调用，无外部 `Opacity_*` API |
| 灰体实现忽略 `ngrp` | BremsstrahlungAndThomson 和 Constant 实现忽略群结构 |
| Species 定义限制 | Multispecies opacity 要求通过 `species=` setup 变量定义，不能用 `SPECIES` 关键字 |
| 表外推 | (T, ρ) 超出 IONMIX 表格边界时取边界值（可能引入误差）|
| LeeMore 依赖 | LeeMore 实现需要正确安装和链接（同 SpitzerHightZ） |

## 10. 延伸阅读

- §23（本篇）物质属性参考
- §25 RadTrans/MGD：Opacity 使用方
- §19 Diffuse：热传导隐式求解器
- §18.4 Laser Deposition：激光 HEDP 示例
- §35.7.5 LaserSlab：完整 HEDP 算例（含 SpitzerHighZ + Multispecies opacity）
- `source/Simulation/SimulationMain/LaserSlab/`：setup 配置和 parfile
- `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity.F90:1-10`：主入口

## 11. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft，基于 FLASH 4.8 UG §23 pp.375-386 + 源码对照 v4.8） | opencode-ai |
