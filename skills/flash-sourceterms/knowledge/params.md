---
title: sourceTerms 参数字典 — Heatexchange 完整 + 其他 sourceTerms 主控
skill: flash-sourceterms
category: params
source_anchors:
  - source/physics/sourceTerms/Heatexchange/Config
  - source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Config:L15-L19
  - source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Config
  - source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Constant/Config
manual_ref: "FLASH 4.8 User Guide §18"
created: 2026-07-20
last_verified: 2026-07-20
verifier: claude
status: draft
tags:
  - sourceterms
  - parameter
  - heatexchange
  - spitzer
---

# sourceTerms 参数字典（Heatexchange 聚焦）

> **TL;DR**：按 L-013 聚焦 Heatexchange 参数。**重要**：**没有 `hxcouple` 参数**（FLASH 4.8 源码零命中），用户提到的可能是 `hx_couplingConst12`（Constant 变体）的误称。每个参数给**默认值依据**（按 L-011）。

---

## 0. 命名约定

**Heatexchange 参数前缀 `hx_`**（加上少数顶层 `useHeatexchange`）。parfile 写完整名：

```fortran
useHeatexchange = .true.
hx_dtFactor = 1.e+100
hx_ieTimeCoef = 1.0
```

**其他 sourceTerms 各有自己前缀**：`useBurn` / `useCool` / `useHeat` / `useStir` / `useIonize` / `useFlame` 等。

---

## 1. Heatexchange 主控

### 1.1 顶层（Heatexchange/Config）

| 参数 | 类型 | 默认 | 默认值依据 |
|---|---|---|---|
| `useHeatexchange` | BOOLEAN | FALSE（顶层）→ TRUE（选了变体后） | 顶层默认关；选 HeatexchangeMain 子目录时自动 TRUE |

### 1.2 HeatexchangeMain

源码：`source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Config:L15-L19`

| 参数 | 类型 | 默认 | 默认值依据 |
|---|---|---|---|
| `useHeatexchange` | BOOLEAN | TRUE | 选了 HeatexchangeMain 自动 TRUE |
| `hx_logLevel` | INTEGER | 700 | 日志阈值。比较 HX_LOGLEVEL_* 宏（300/400/500/1000） |

**HX_LOGLEVEL_* 宏**（`HeatexchangeMain/Heatexchange.h`）：

| 宏 | 值 | 含义 |
|---|---|---|
| `HX_LOGLEVEL_WARN_DATA` | 300 | 数据相关警告 |
| `HX_LOGLEVEL_WARN_USE` | 400 | 使用相关警告 |
| `HX_LOGLEVEL_INFO_FALLBACK` | 500 | 负能量回退信息 |
| `HX_LOGLEVEL_INFO_ALL` | 1000 | 全部信息 |

---

## 2. Spitzer 变体（LaserSlab 用的）

源码：`source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Config`

| 参数 | 类型 | 默认 | 默认值依据 |
|---|---|---|---|
| `hx_dtFactor` | REAL | 0.5 | 每步最多交换 cv·|ΔT| 占内能的比例。<1 保证解析解精度。**LaserSlab 设 1e100 禁用**（见 §2.1） |
| `hx_ieTimeCoef` | REAL | 1.0 | eqtime 倍数。<1 加快平衡，>1 减慢（调试用） |
| `hx_relTol` | REAL | -1.0 | 温度相对容差。负值 = 继承 `eos_tolerance` |

### 2.1 为什么 LaserSlab 设 hx_dtFactor = 1e100

源码：`source/Simulation/SimulationMain/LaserSlab/flash.par:L263`

```fortran
hx_dtFactor = 1.0e+100
```

**默认 0.5 的含义**：每步能量交换 |ΔE| < 0.5 × eint（防止单步过度交换导致数值震荡）。

**LaserSlab 禁用的原因**：

1. **hydro dt 已被严格限制**：CFL + 激光物理限制 dt ~ 1e-13 s
2. **eqtime << dt_hydro**：HEDP 中 eqtime ~ 1-100 ps，dt_hydro ~ 100 fs，eqtime/dt_hydro > 10 → 一步内已基本完全平衡
3. **HX dt 限制会让步数过多**：如果开 HX dt，dt < 0.5·eqtime ~ 0.5-50 ps，但 hydro CFL 已经 100 fs → HX 不限制（dt 取 min 后还是 hydro 限制）

**接受后果**：一步内全平衡（eqtime << dt_hydro 时物理合理）。

### 2.2 何时改 hx_ieTimeCoef

```fortran
hx_ieTimeCoef = 0.5     # 加快平衡（物理不准，调试用）
hx_ieTimeCoef = 2.0     # 减慢平衡（模拟强耦合延迟）
```

**正常算例用默认 1.0**。

---

## 3. Constant 变体（简单测试）

源码：`source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Constant/Config`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `hx_couplingConst12` | REAL | 1.0 | 离子-电子耦合系数（自定义值，不算 ln Λ） |
| `hx_couplingConst13` | REAL | 0.0 | 离子-辐射耦合系数 |
| `hx_couplingConst23` | REAL | 1.0 | 电子-辐射耦合系数 |

**注意**：**没有 `hxcouple` 参数**（用户提示中可能误称）。

---

## 4. ConstCoulomb 变体（简化 Spitzer）

源码：`source/physics/sourceTerms/Heatexchange/HeatexchangeMain/ConstCoulomb/Config`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `hx_coulombLog` | REAL | 1.0 | 固定 ln Λ 值（不算 PlasmaState） |
| `hx_singleSpeciesA` / `hx_singleSpeciesZ` | REAL | 1.0 | 单物质场景（无 Multispecies 时） |

---

## 5. LeeMore 变体（高 Z）

源码：`source/physics/sourceTerms/Heatexchange/HeatexchangeMain/LeeMore/`

**参数同 Spitzer**（hx_dtFactor / hx_ieTimeCoef / hx_relTol），但内部调 `PlasmaState_logLambda` 时用 Lee-More 模式（密度/简并修正的 ln Λ）。

**何时选 LeeMore**：高 Z 物质（Au、W、CH foam）、T < 100 eV、强耦合或简并等离子体。

---

## 6. Immediate 变体（强制平衡）

源码：`source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Immediate/Config`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `hx_applyToRadiation` | BOOLEAN | FALSE | TRUE 时也强制 TRAD 平衡；FALSE 只平衡 TEION/TELE |

**算法**：调 `Eos_wrapped(MODE_DENS_EI_MAT_EQUI)` 一步强制平衡。

**用途**：调试、初始化强制 T_ion = T_ele。**不要生产用**。

---

## 7. Driver_sourceTerms 调用顺序

源码：`source/Driver/DriverMain/Driver_sourceTerms.F90:L55-L73`

| sourceTerm | 默认调用顺序 | 备注 |
|---|---|---|
| Polytrope | 1 | |
| Stir | 2 | |
| Turb_calc | 3 | |
| Flame_step | 4 | |
| Burn | 5 | |
| Heat | 6 | |
| **Heatexchange** | **7** | ★ LaserSlab 用 |
| Cool | 8 | |
| Ionize | 9 | |
| **EnergyDeposition**（激光） | **10** | ★ 默认最后；DRIVER_EDEARLY 可前移 |
| Deleptonize | 11 | |

**调整顺序**：setup 加 `+edearly` 让激光最先（DRIVER_EDEARLY 宏）。

---

## 8. 其他 sourceTerms 主控参数（简要，按 L-013）

### 8.1 Burn

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `useBurn` | BOOLEAN | FALSE | 启用核燃烧 |
| `burn_dtFactor` | REAL | — | 燃烧 dt 系数 |
| ... | | | 详见手册 §18.1 |

### 8.2 Cool

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `useCool` | BOOLEAN | FALSE | 启用辐射冷却 |
| `cfl_cool` | REAL | — | 冷却 dt 系数 |

### 8.3 Heat / Stir / Ionize / Flame / Polytrope

各 `use<Unit> = .false.`（默认关）。详见对应单元 Config。

---

## 9. LaserSlab 参考 parfile（Heatexchange 部分）

源码：`source/Simulation/SimulationMain/LaserSlab/flash.par:L178, L263`

```fortran
# Heatexchange 主控
useHeatexchange = .true.

# 时间步（LaserSlab 禁用 HX dt 限制）
hx_dtFactor = 1.0e+100

# 其他用默认值
# hx_ieTimeCoef = 1.0   # 默认
# hx_relTol = -1.0      # 继承 eos_tolerance
# hx_logLevel = 700     # 默认
```

---

## 10. 参数前缀速查

| 前缀 | 含义 | 出处 |
|---|---|---|
| `useHeatexchange` | Heatexchange 主控（顶层 + HeatexchangeMain） | Heatexchange/Config |
| `hx_logLevel` | 日志阈值 | HeatexchangeMain/Config |
| `hx_dtFactor` / `hx_ieTimeCoef` / `hx_relTol` | Spitzer/LeeMore 共有 | Spitzer/Config |
| `hx_couplingConst12/13/23` | Constant 变体专属 | Constant/Config |
| `hx_coulombLog` | ConstCoulomb 变体专属 | ConstCoulomb/Config |
| `hx_applyToRadiation` | Immediate 变体专属 | Immediate/Config |
| `useBurn` / `useCool` / `useHeat` / `useStir` / `useIonize` / `useFlame` | 其他 sourceTerms 主控 | 各单元 Config |

---

## 11. 延伸阅读

- **Heatexchange 总览 / 数学模型**：`knowledge/overview.md`
- **Heatexchange.F90 主流程**：`knowledge/internals.md`
- **典型配置**：`knowledge/recipes.md`
- **常见错误**：`knowledge/pitfalls.md`
- **跨单元查参数**：`flash-param-query` skill + `agent/param-index.md`

---

## 12. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-20 | 初始创建（draft）：10 类参数 + 默认值依据（L-011）+ LaserSlab 参考 parfile + 前缀速查 + hxcouple 不存在警告 | claude |
