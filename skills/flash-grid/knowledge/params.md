---
title: Grid 参数字典 — 几何 / AMR / 边界 / guardcell / refinement
skill: flash-grid
category: params
source_anchors:
  - source/Grid/GridMain/Config:L50-L102
  - source/Grid/GridMain/paramesh/Config:L9-L282
  - source/Grid/GridMain/UG/Config:L14-L58
  - source/Grid/GridMain/paramesh/paramesh4/Config:L34-L52
manual_ref: "FLASH 4.8 User Guide §7-8"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai-waiting
status: draft
tags:
  - grid
  - parameter
  - geometry
  - AMR
  - refinement
  - boundary
---

# Grid 参数字典

> **TL;DR**：Grid 单元的 runtime parameter 按 5 类组织：**几何 / 边界 / 域 / AMR / 其他**。注意区分 runtime parameter（在 parfile 改）和 setup 变量（要重新 setup+make，不能在 parfile 改）。

---

## 0. 关键概念：setup 变量 vs runtime parameter

源码：`bin/parseCmd.py:L517-L525`、`bin/unitCfg.py:L260-L267`

| 类型 | 在哪改 | 改完要不要重新 setup+make | 例子 |
|---|---|---|---|
| **setup 变量**（编译期） | setup 命令行 | **要** | `NXB`、`NYB`、`NZB`、`MAXBLOCKS`、`NGUARD`、`N_DIM`、`Grid`（backend 选择） |
| **runtime parameter**（运行期） | parfile | 不要 | `xmin`、`lrefine_max`、`refine_var_1`、`xl_boundary_type` |

**判断规则**：

- 名字是 `NXB` / `NYB` / `NZB` / `MAXBLOCKS` / `NGUARD`（**全大写**）→ setup 变量
- 名字以 `nblock` 开头（小写）→ runtime parameter（但语义上更像域划分，不是 block 大小）
- setup 命令行用 `+xxx` / `-xxx` / `key=value` → 都是 setup 变量
- parfile 里的 → 都是 runtime parameter

详见 `flash-param-query` 的 §2.2 "setup 变量 vs runtime parameter"。

---

## 1. 几何参数

源码：`source/Grid/GridMain/Config:L50-L84`

| 参数 | 类型 | 默认 | 单位 | 含义 | 声明位置 |
|---|---|---|---|---|---|
| `geometry` | STRING | `"cartesian"` | — | 几何类型：`cartesian` / `cylindrical` / `spherical` / `polar` | `Config:L76` |
| `geometryOverride` | BOOLEAN | FALSE | — | 跳过几何合理性检查（不建议） | `Config:L80` |
| `unbiased_geometry` | BOOLEAN | FALSE | — | FP 偏差消除（FLASH3 未实现） | `Config:L84` |

### 1.1 域范围

源码：`source/Grid/GridMain/Config:L51-L66`

| 参数 | 类型 | 默认 | 单位 | 含义 |
|---|---|---|---|---|
| `xmin` / `xmax` | REAL | 0.0 / 1.0 | cm（cartesian）/ cm（cylindrical/spherical 径向）/ 度（角向） | x/IAXIS 域 |
| `ymin` / `ymax` | REAL | 0.0 / 1.0 | cm（cartesian/cylindrical J=z）/ 度（polar J=φ）/ 度（spherical J=θ） | y/JAXIS 域 |
| `zmin` / `zmax` | REAL | 0.0 / 1.0 | cm（cartesian/cylindrical K=z）/ 度（spherical K=φ） | z/KAXIS 域 |

**注意单位**：
- 径向（r）：cm
- 直角坐标轴（x, y, z）：cm
- 角向（θ, φ）：**度**（不是弧度！）

### 1.2 几何限制

源码：`source/Grid/GridMain/gr_initGeometry.F90:L153-L184`

- `CYLINDRICAL` + `NDIM==1` → **abort**（柱坐标至少要 R-Z 二维）
- `POLAR` + `NDIM==3` → **abort**（极坐标三维没意义）
- 径向 `xmin=0` 时，对应面 BC 必须 `REFLECTING` 或 `AXISYMMETRIC`，否则 abort

### 1.3 典型配置

```fortran
# 直角 2D
geometry = "cartesian"
xmin = 0.0    xmax = 2.0
ymin = 0.0    ymax = 2.0

# 柱坐标 R-Z 2D（激光算例常用）
geometry = "cylindrical"
xmin = 0.0    xmax = 0.02       # R, cm
ymin = 0.0    ymax = 0.05       # Z, cm
xl_boundary_type = "axisymmetric"   # R=0 必须轴对称
yl_boundary_type = "outflow"
yr_boundary_type = "outflow"

# 球坐标 1D（ICF 内爆）
geometry = "spherical"
xmin = 0.0    xmax = 0.05       # R, cm
xl_boundary_type = "axisymmetric"
xr_boundary_type = "outflow"
```

---

## 2. 边界条件参数

源码：`source/Grid/GridMain/Config:L86-L130`

### 2.1 6 个面

| 参数 | 默认 | 含义 |
|---|---|---|
| `xl_boundary_type` | `"periodic"` | x 轴左面（小 x 侧）BC |
| `xr_boundary_type` | `"periodic"` | x 轴右面（大 x 侧）BC |
| `yl_boundary_type` | `"periodic"` | y 轴左面 |
| `yr_boundary_type` | `"periodic"` | y 轴右面 |
| `zl_boundary_type` | `"periodic"` | z 轴左面 |
| `zr_boundary_type` | `"periodic"` | z 轴右面 |

### 2.2 BC 类型取值

| 值 | 含义 |
|---|---|
| `"periodic"` | 周期（默认） |
| `"outflow"` | 自由出流（导数=0） |
| `"reflecting"` | 反射（速度等奇对称） |
| `"axisymmetric"` | 轴对称（径向轴专用） |
| `"eqtdirichlet"` / `"diode"` | 等温 dirichlet / 二极管 |
| `"user"` | 用户自定义（需实现 `Grid_applyBCEdge`） |
| `"outstream"` / `"inflow"` | 入/出流（可能需更多参数） |

### 2.3 边界优先级（角点处理）

源码：`source/Grid/GridMain/Config:L124-L130`

| 参数 | 默认 | 含义 |
|---|---|---|
| `bndPriorityOne` | 1 | 角点优先用哪轴的 BC（1=IAXIS） |
| `bndPriorityTwo` | 2 | 次优先（2=JAXIS） |
| `bndPriorityThree` | 3 | 三优先（3=KAXIS） |

**何时关心**：不同面 BC 不同时，角点处用谁的？默认按 IAXIS > JAXIS > KAXIS 顺序。

### 2.4 混合 GDS 边界

源码：`source/Grid/GridMain/Config:L137`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `gr_bcEnableApplyMixedGds` | BOOLEAN | TRUE | 启用 `Grid_bcApplyToRegionMixedGds`（不同 gridDataStruct 用不同 BC） |

---

## 3. 域分块参数

源码：`source/Grid/GridMain/paramesh/Config:L9-L15`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `nblockx` | INTEGER | 1 | 初始 level-1 块在 IAXIS 方向的切分数 |
| `nblocky` | INTEGER | 1 | JAXIS |
| `nblockz` | INTEGER | 1 | KAXIS |

**用途**：初始化时把整个域切成 `nblockx × nblocky × nblockz` 个顶层块。后续 AMR 在此基础上细化。

**典型值**：
- 1D 算例：`nblockx=10`（其他=1）
- 2D 算例：`nblockx=4, nblocky=4`（共 16 个顶层块）
- 3D 算例：`nblockx=2, nblocky=2, nblockz=2`（共 8 个顶层块）

**注意**：`nblockx * NXB` 是 level-1 在 IAXIS 的总 cell 数。

---

## 4. AMR / Refinement 参数

源码：`source/Grid/GridMain/paramesh/Config:L18-L282`

### 4.1 层级控制

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `lrefine_min` | INTEGER | 1 | 算例中允许的最小细化层级 |
| `lrefine_max` | INTEGER | 1 | **允许的最大层级（设 1 = 无 AMR）** |
| `lrefine_min_init` | INTEGER | 1 | 初始化时的最小层级 |
| `nrefs` | INTEGER | 2 | 每隔 N 步重新细化/粗化一次 |
| `lrefine_del` | INTEGER | 0 | restart 时把 lrefine_max 减多少（0=不减） |

**最关键的两个**：`lrefine_max`（开 AMR 必须调大）和 `nrefs`（细化频率）。

### 4.2 细化变量与阈值

源码：`source/Grid/GridMain/paramesh/Config:L31-L74`

每细化变量一组 3 个参数（`_N` 中 N=1..4，最多 4 组）：

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `refine_var_N` | STRING | `"none"` | 用于细化判断的变量名（如 `"dens"`、`"temp"`） |
| `refine_cutoff_N` | REAL | 0.8 | 误差估计 > 此阈值 → 细化 |
| `derefine_cutoff_N` | REAL | 0.2 | 误差估计 < 此阈值 → 粗化 |
| `refine_filter_N` | REAL | 0.01 | 反发散滤波 |

**误差估计**：Paramesh 用相邻 block 的梯度除以均值（LOJAStepiewicz 类似方法）。值越大表示该处变化剧烈。

**典型用法**（细化密度变化处）：
```fortran
refine_var_1 = "dens"
refine_cutoff_1 = 0.2
derefine_cutoff_1 = 0.05
refine_filter_1 = 0.01
```

### 4.3 粒子驱动细化

源码：`source/Grid/GridMain/paramesh/Config:L77-L83`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `refine_on_particle_count` | BOOLEAN | FALSE | 用粒子数驱动细化 |
| `max_particles_per_blk` | INTEGER | 100 | 粒子数 > 此值 → 细化 |
| `min_particles_per_blk` | INTEGER | 1 | 粒子数 < 此值 → 粗化 |

### 4.4 插值与守恒

源码：`source/Grid/GridMain/paramesh/Config:L86-L111`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `flux_correct` | BOOLEAN | TRUE（paramesh）/ FALSE（UG） | 粗细边界通量修正 |
| `interpol_order` | INTEGER | 2 | 单调插值阶数（默认 2 阶） |
| `convertToConsvdInMeshInterp` | BOOLEAN | TRUE | 插值时转守恒形式 |
| `convertToConsvdForMeshCalls` | BOOLEAN | FALSE | paramesh 调用前转守恒（老方法） |
| `earlyBlockDistAdjustment` | BOOLEAN | TRUE | restart 后让 Paramesh 早期重分布 block |

### 4.5 lrefine_max 时变（高级）

源码：`source/Grid/GridMain/paramesh/Config:L238-L282`

允许在不同时刻手动改 `lrefine_max`（最多 20 个时刻）：

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `gr_lrefineMaxByTime` | BOOLEAN | FALSE | 启用时变 lrefine_max |
| `gr_lrefmaxTime_1..20` | REAL | -1.0 | 改变的时刻（s） |
| `gr_lrefmaxTimeValue_1..20` | INTEGER | -1 | 该时刻的 lrefine_max 值 |

### 4.6 lrefine_max 按半径/时间衰减（高级）

源码：`source/Grid/GridMain/paramesh/Config:L115-L146`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `gr_lrefineMaxRedDoByLogR` | BOOLEAN | FALSE | 按到中心 log 距离衰减 lrefine_max |
| `gr_lrefineMaxRedRadiusFact` | REAL | 0.0 | 半径因子 |
| `x_refine_center` / `y_refine_center` / `z_refine_center` | REAL | 0.0 | 中心位置 |
| `gr_lrefineMaxRedDoByTime` | BOOLEAN | FALSE | 按时间衰减 |
| `gr_lrefineMaxRedTimeScale` / `gr_lrefineMaxRedTRef` / `gr_lrefineMaxRedLogBase` | REAL | 1.0 / 0.0 / 10.0 | 时间衰减参数 |

### 4.7 Restrict（树自下而上聚合）

源码：`source/Grid/GridMain/paramesh/Config:L155`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `gr_restrictAllMethod` | INTEGER | 3 | 树 restrict 方法（0=不做，1=`gr_restrictTree`，2=`mpi_amr_restrict_fulltree`，3=`Grid_restrictByLevels`） |

---

## 5. Guard cell 相关

### 5.1 runtime parameter（少）

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `reduceGcellFills` | BOOLEAN | FALSE | 跳过冗余 gcfill 调用（优化） |
| `eosMode` | STRING | `"dens_ie"` | gcfill 时 EOS 模式（`"dens_ie"` / `"dens_pres"` / `"dens_temp"` 等） |
| `eosModeInit` | STRING | `"dens_ie"` | 初始化 EOS 模式 |

### 5.2 setup 变量（NGUARD）

源码：`bin/Flash.h.tpl:L440`、`bin/unitCfg.py:L260-L267`

| 变量 | 命令 | 默认 | 含义 |
|---|---|---|---|
| `NGUARD` | 各 unit Config `GUARDCELLS N` 声明 | 4 | 每边 guard cell 数 |

**改 NGUARD 的方法**：找最关心的 unit（如 Hydro），改它的 Config 文件中的 `GUARDCELLS N`，重新 setup+make。

---

## 6. UG backend 专属参数

源码：`source/Grid/GridMain/UG/Config:L14-L58`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `iguard` / `jguard` / `kguard` | INTEGER | 4（PPM/WENO 时 6） | 每轴 guard cell（"Meant for nofbs"） |
| `iGridSize` / `jGridSize` / `kGridSize` | INTEGER | 1 | 全局内部 cell 数（NON_FIXED_BLOCKSIZE 模式） |
| `compute_grid_size` | BOOLEAN | TRUE | runtime 算 grid 大小（NON_FIXED_BLOCKSIZE） |
| `nblockx` / `nblocky` / `nblockz` | INTEGER | 1 | UG 忽略 |
| `flux_correct` | BOOLEAN | FALSE | UG 无 AMR，永远 false |

**注意**：UG 没有 `lrefine_max` 等 AMR 参数（因为无 AMR）。

---

## 7. paramesh 4 dev 专属参数

源码：`source/Grid/GridMain/paramesh/paramesh4/Config:L34-L52`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `gr_sanitizeDataMode` | INTEGER | 1 | 插值后值落到 floor 以下时的处理（0=不处理，1-3=修正，4=abort） |
| `gr_sanitizeVerbosity` | INTEGER | 5 | sanitize 报告冗长度 |
| `enableMaskedGCFill` | BOOLEAN | TRUE | 启用 mask-based guard cell 填充 |

---

## 8. EOS 截断参数

源码：`source/Grid/GridMain/Config:L179-L182`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `smallx` | REAL | 1.E-10 | 物种质量分数下限 |
| `smalle` | REAL | 1.E-10 | 内能下限 |

**注意**：还有 `smlrho` / `smallp` / `smallt` 在 UG Config 和其他位置，详见 `flash-eos`（Phase 2）。

---

## 9. 参数前缀速查

| 前缀 | 含义 | 出处 |
|---|---|---|
| `gr_` | Grid 单元内部全局变量（不在 parfile 改） | `Grid_data.F90` |
| `xl_/xr_/yl_/yr_/zl_/zr_` | 各面参数（边界条件） | `GridMain/Config:L86-L102` |
| `nblock` | 域分块数 | `GridMain/paramesh/Config:L9-L15` |
| `lrefine_` | AMR 层级 | `GridMain/paramesh/Config:L18-L282` |
| `refine_` / `derefine_` | 细化/粗化阈值 | `GridMain/paramesh/Config:L31-L83` |
| `gr_lrefineMaxRed` | lrefine_max 按半径/时间衰减 | `GridMain/paramesh/Config:L119-L146` |
| `gr_lrefmaxTime` | lrefine_max 时变调度 | `GridMain/paramesh/Config:L238-L282` |
| `gr_restrictAllMethod` | 树 restrict 方法 | `GridMain/paramesh/Config:L155` |
| `gr_bcEnable` / `gr_sanitize` / `gr_intpol` | 行为开关 | 各 Config |

---

## 10. 延伸阅读

- **AMR 调度机制**：`knowledge/internals.md §4`
- **典型 AMR 配置**：`knowledge/recipes.md §3`
- **几何轴向映射**：`knowledge/overview.md §4`
- **跨单元查参数**：`flash-param-query` skill + `skills/flash-param-query/knowledge/param-index.md`
- **完整参数扫描**：`find source/Grid -name Config | xargs grep "^PARAMETER"`

---

## 11. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft）：8 类参数（几何/边界/域分块/AMR/guardcell/UG 专属/pm4dev 专属/EOS 截断）+ setup 变量 vs runtime parameter 区分 + 前缀速查 | claude |
