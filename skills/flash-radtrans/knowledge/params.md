---
title: RadTrans 参数字典 — MGD 求解控制 / 群结构 / 边界 / 隐式
skill: flash-radtrans
category: params
source_anchors:
  - source/physics/RadTrans/RadTransMain/MGD/Config
  - source/physics/RadTrans/RadTransMain/MGD/rt_init.F90:L37-L131
  - source/physics/RadTrans/RadTransMain/Config:L14
  - source/physics/RadTrans/RadTransMain/MGD/Unified/Config
manual_ref: "FLASH 4.8 User Guide §25"
created: 2026-07-19
last_verified: 2026-07-19
verifier: claude
status: draft
tags:
  - radtrans
  - parameter
  - mgd
  - flux-limiter
---

# RadTrans 参数字典（MGD 聚焦）

> **TL;DR**：按 L-013 聚焦 MGD 主流参数。**关键**：`rt_mgdBounds_*` 单位是 **eV**（不是 erg！）；`mgd_meshgroups` 是 setup 期变量（不是 runtime parameter）。每个参数给**默认值依据**（按 L-011）。

---

## 0. 命名约定

**所有 MGD 参数前缀 `rt_mgd`**（除了少数顶层 `rt_*`）。parfile 写完整名：

```fortran
rt_useMGD = .true.
rt_mgdFlMode = "fl_harmonic"
rt_mgdBounds_1 = 1.e-1
```

**没有 `hy_` 或 `eos_` 前缀混淆**。

---

## 1. 主控参数

源码：`source/physics/RadTrans/RadTransMain/MGD/Config`

| 参数 | 类型 | 默认 | 默认值依据 |
|---|---|---|---|
| `useRadTrans` | BOOLEAN | FALSE | 顶层 RadTrans/Config。算例 setup 加 `+radTrans` 或 `+mgd` 时被 REQUESTS 自动 TRUE |
| `rt_useMGD` | BOOLEAN | FALSE | 默认 FALSE，但 `useRadTrans=TRUE` 时变体选 MGD → 实际 TRUE |

---

## 2. Flux limiter

| 参数 | 类型 | 默认 | 默认值依据 |
|---|---|---|---|
| `rt_mgdFlMode` | STRING | **`"fl_none"`** | **Config 默认 fl_none 危险**！测试纯扩散极限用。**LaserSlab 必须改为 `"fl_harmonic"`**。详见 `overview.md §3.2` |
| `rt_mgdFlCoef` | REAL | 1.0 | 限流系数倍数。1.0 = 标准；<1 更严格限流；>1 接近自由流 |

**`rt_mgdFlMode` 允许值**：

| 值 | 描述 |
|---|---|
| `fl_none` | 不限流（**默认但危险**） |
| **`fl_harmonic`** | 调和平均（**HEDP 推荐，LaserSlab 用**） |
| `fl_larsen` | Larsen 七阶多项式 |
| `fl_minmax` | min/max 组合 |
| `fl_levermorepomraning1981` | Levermore-Pomraning 1981 |

**注意**：**没有** `fl_geometric` / `fl_arithmetic`（不存在于本树）。

---

## 3. 能群结构

| 参数 | 类型 | 默认 | 默认值依据 |
|---|---|---|---|
| `mgd_meshgroups`（setup 期） | INTEGER | — | **必须指定**，否则 setup abort。编译期最大群数（分配 MGDR1..n 槽） |
| `mgd_maxgroups`（setup 期） | INTEGER | 100 | 编译期上界，控制 `rt_mgdBounds_N` 槽位数和 `MGD_MAXGROUPS` PPDEFINE |
| `rt_mgdNumGroups` | INTEGER | 0 | 实际用群数。**必须 > 0 且 ≤ mgd_meshgroups**，否则 rt_init abort |
| `rt_mgdBoundEntry` | STRING | `"grbd_manual"` | **只实现了 grbd_manual**（手动设）。从 `rt_mgdBounds_*` 读 |
| `rt_mgdBounds_<i>` | REAL | -1.0 | 第 i 个群边界（i=1..N+1）。**单位 eV**（不是 erg）！负值 → rt_init abort |

**单位转换**（源码 `rt_init.F90:L37, L131`）：

```
EV_TO_ERGS = 1.60217653e-12
group_bound_erg = group_bound_eV * EV_TO_ERGS
```

**典型 LaserSlab 6 群配置**：

```fortran
rt_mgdNumGroups = 6
rt_mgdBounds_1 = 1.e-1   # eV
rt_mgdBounds_2 = 1.e0
rt_mgdBounds_3 = 1.e1
rt_mgdBounds_4 = 1.e2
rt_mgdBounds_5 = 1.e3
rt_mgdBounds_6 = 1.e4
rt_mgdBounds_7 = 1.e5    # N+1 = 7 个边界
```

---

## 4. 边界条件

源码：`MGD/RadTrans.F90:L266-L274`

### 4.1 边界类型

| 参数 | 默认 | 允许值 |
|---|---|---|
| `rt_mgdXlBoundaryType` / `Xr` / `Yl` / `Yr` / `Zl` / `Zr` | `"reflecting"` | `periodic, reflecting, vacuum, dirichlet, neumann, outflow, outstream` |

### 4.2 Dirichlet 边界温度

| 参数 | 默认 | 用途 |
|---|---|---|
| `rt_mgdXlBoundaryTemp` / `Xr` / ... | -1.0 | 边界辐射温度（K）。只在 BC 类型为 `dirichlet` 时用。负值 = 0 |

### 4.3 BC 类型映射（内部）

源码：`MGD/RadTrans.F90:L266-L274`

```
PERIODIC    → GRID_PDE_BND_PERIODIC
DIRICHLET   → GRID_PDE_BND_DIRICHLET
OUTFLOW | REFLECTING → GRID_PDE_BND_NEUMANN
VACUUM      → GRID_PDE_BND_VACUUM
```

---

## 5. 时间步 + 隐式

| 参数 | 类型 | 默认 | 默认值依据 |
|---|---|---|---|
| `rt_mgdthetaImplct` | REAL | 1.0 | 隐式度 θ∈[0,1]。1.0 = 全后向 Euler（无条件稳定，HEDP 必须） |
| `rt_computeDt` | BOOLEAN | FALSE | TRUE 时 `RadTrans_computeDt` 限制 hydro dt。LaserSlab **不开**（隐式不需要） |
| `rt_dtFactor` | REAL | 0.1 | 辐射 dt 系数（只在 `rt_computeDt=TRUE` 时生效）。LaserSlab 设 0.02 |
| `rt_timeGroups` | BOOLEAN | FALSE | 每群计时器。和 `meshCopyCount>1` 不兼容 |
| `rt_groupBarrier` | BOOLEAN | FALSE | 群间 MPI_Barrier（profile 用） |
| `rt_tempChangeRelTol` | REAL | 1.e3 | 每步 ΔT 相对容差（ExpRelax 专属） |

### 5.1 θ 选择

| θ | 含义 | 何时选 |
|---|---|---|
| **1.0**（默认） | 全后向 Euler | HEDP 必须（无条件稳定） |
| 0.5 | Crank-Nicolson | 2 阶精度，但 `dt·c·κ > 2` 震荡 |
| 0.0 | 全显式 | 不稳定（**禁止**） |

---

## 6. Unified 变体专属（实验性，不推荐）

源码：`source/physics/RadTrans/RadTransMain/MGD/Unified/Config`

| 参数 | 类型 | 默认 | 用途 |
|---|---|---|---|
| `rt_mgdthetaC` | REAL | -1.0 | 吸收耦合隐式度。-1 = 用 `rt_mgdthetaImplct` |
| `rt_mgdthetaD` | REAL | 0.5 | 发射耦合隐式度。-1 = 用 `rt_mgdthetaImplct` |
| `rt_tightIonCoupling` | BOOLEAN | FALSE | 假设电子-离子强耦合 → 用 cv（混合）替代 cv_ele |

**警告**：README 明示 "completely EXPERIMENTAL and has had VERY LIMITED TESTING"。**生产算例不要用**。

---

## 7. ExpRelax 变体专属（罕用）

源码：`source/physics/RadTrans/RadTransMain/MGD/ExpRelax/Config`

| 参数 | 类型 | 默认 | 用途 |
|---|---|---|---|
| `rt_expRelaxMaxIter` | INTEGER | 3 | 外迭代最大次数（T_e ↔ E_r 平衡） |

---

## 8. LaserSlab 参考 parfile（HEDP 典型）

源码：`source/Simulation/SimulationMain/LaserSlab/flash.par`

```fortran
# 主控
rt_useMGD             = .true.

# 群结构
rt_mgdNumGroups       = 6
rt_mgdBounds_1..7     = 1e-1, 1e0, 1e1, 1e2, 1e3, 1e4, 1e5   # eV

# Flux limiter
rt_mgdFlMode          = "fl_harmonic"
rt_mgdFlCoef          = 1.0

# 边界
rt_mgdXlBoundaryType  = "reflecting"     # 激光入射侧（对称）
rt_mgdXrBoundaryType  = "vacuum"          # 靶背（自由流出）
rt_mgdYlBoundaryType  = "vacuum"
rt_mgdYrBoundaryType  = "reflecting"
rt_mgdZlBoundaryType  = "reflecting"      # 2D 算例 Z 是退化维
rt_mgdZrBoundaryType  = "reflecting"

# 时间步
rt_dtFactor           = 0.02              # 实际不生效（rt_computeDt 默认 FALSE）
# rt_mgdthetaImplct   = 1.0               # 默认值，可省略
```

---

## 9. 参数前缀速查

| 前缀 | 含义 |
|---|---|
| `rt_mgdFl*` | Flux limiter（限流器） |
| `rt_mgdBounds_*` | 群边界（**单位 eV**） |
| `rt_mgdNumGroups` | 群数 |
| `rt_mgdXl/Xr/Yl/Yr/Zl/Zr BoundaryType` | 6 个面的 BC |
| `rt_mgdXl/Xr/... BoundaryTemp` | Dirichlet BC 温度 |
| `rt_mgdtheta*` | 隐式度 |
| `mgd_meshgroups` / `mgd_maxgroups` | setup 期变量（**无 rt_ 前缀**） |

---

## 10. 延伸阅读

- **MGD 总览 / 数学模型**：`knowledge/overview.md`
- **MGD 主流程**：`knowledge/internals.md`
- **典型配置**：`knowledge/recipes.md`
- **常见错误**：`knowledge/pitfalls.md`
- **跨单元查参数**：`flash-param-query` skill + `skills/flash-param-query/knowledge/param-index.md`

---

## 11. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft）：8 类参数 + 默认值依据（按 L-011）+ LaserSlab 参考 parfile + 前缀速查 + 单位警告（eV） | claude |
