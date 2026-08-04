---
title: Grid 典型配置 — backend / 几何 / AMR / 边界 parfile
skill: flash-grid
category: recipes
source_anchors:
  - source/Grid/GridMain/Config:L16
  - source/Grid/GridMain/paramesh/Config:L18-L74
  - source/Grid/GridMain/gr_initGeometry.F90:L121-L184
  - bin/setup_shortcuts.txt:L56-L58
manual_ref: "FLASH 4.8 User Guide §2 (setup), §7-8 (Grid)"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai-waiting
status: draft
tags:
  - grid
  - recipe
  - backend
  - geometry
  - AMR
  - parfile
---

# Grid 典型配置 recipes

> **TL;DR**：4 类 recipe：backend 选择（setup 命令）+ 几何选择（setup 命令）+ 域和边界（parfile）+ AMR 配置（parfile）。每个 recipe 标"适用场景"，按需选，不按顺序读。

---

## 0. 通用准备

### 0.1 setup 命令结构回顾

```
./setup <SimulationMain/problem> [opts] -auto -objdir=<path>
```

Grid 相关 setup 选项：

| 选项 | 含义 | 示例 |
|---|---|---|
| `+pm4dev` / `+pm40` / `+pm3` / `+pm2` | 选 paramesh backend | `+pm4dev`（默认） |
| `+ug` | 选 Uniform Grid backend（无 AMR） | `+ug` |
| `+cartesian` / `+cylindrical` / `+spherical` / `+polar` | 选几何 | `+cylindrical` |
| `-geometry=<name>` | 同上（等价） | `-geometry=cylindrical` |
| `-1d` / `-2d` / `-3d` | 选维度 | `-2d` |
| `-nxb=N -nyb=N -nzb=N` | 每 block cell 数（默认 8/8/8） | `-nxb=16 -nyb=16` |
| `-maxblocks=N` | 每进程最大 block 数 | `-maxblocks=1000` |

### 0.2 parfile 在哪改

parfile 顶部通常含 setup 命令注释（**注意 L-009：可能不可信**）。要确认实际 setup 命令：

```bash
cat cases/<your_case>/setup_call
```

parfile 里 Grid 相关段（**顶层**，不在 sourceTerm 段）：

```fortran
# 几何 + 域
geometry = "..."
xmin = ...    xmax = ...
ymin = ...    ymax = ...
zmin = ...    zmax = ...

# 边界条件
xl_boundary_type = "..."
xr_boundary_type = "..."
yl_boundary_type = "..."
yr_boundary_type = "..."
zl_boundary_type = "..."
zr_boundary_type = "..."

# 域分块
nblockx = ...
nblocky = ...
nblockz = ...

# AMR
lrefine_min = ...
lrefine_max = ...
nrefs = ...
refine_var_1 = "..."
refine_cutoff_1 = ...
derefine_cutoff_1 = ...
```

---

## 1. Backend 选择 recipe

### Recipe 1.1：默认 paramesh 4 dev（最常用）

**适用**：99% 的算例。AMR 激光、激波管、ICF、燃烧、MHD。

```bash
./setup LaserSlab -2d -auto +cylindrical +laser +mgd +uhd3t \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab
```

**说明**：不指定 backend → 默认 paramesh → paramesh4 → Paramesh4dev。所以**不写 `+pm4dev` 也是它**，但写了更明确。

### Recipe 1.2：UG（无 AMR）

**适用**：PIC、FFT-based Poisson（Pfft）、nofbs MHD、基准对比（固定网格）。

```bash
./setup <problem> -3d -auto +ug +nofbs \
    -nxb=32 -nyb=32 -nzb=32 \
    -objdir=cases/<problem>
```

**注意**：
- UG 算例 lrefine_max 等参数无效（无 AMR）
- 总 cell 数 = `nblockx * NXB × nblocky * NYB × nblockz * NZB`（固定不变）
- 内存消耗正比于总 cell 数

### Recipe 1.3：paramesh 4.0（兼容旧算例）

**适用**：从 FLASH 3 或早期 FLASH 4 移植的旧算例。

```bash
./setup <problem> -2d -auto +pm40 \
    -objdir=cases/<problem>
```

**不推荐新算例用**：4.0 没有 4 dev 的优化（如 masked GC fill、sanitize data）。

---

## 2. 几何选择 recipe

### Recipe 2.1：2D 直角坐标（x-y 平面）

**适用**：平面激波、Karman 涡街、平面 Rayleigh-Taylor。

```bash
./setup <problem> -2d -auto +cartesian \
    -objdir=cases/<problem>
```

parfile：
```fortran
geometry = "cartesian"
xmin = 0.0    xmax = 2.0       # cm
ymin = 0.0    ymax = 2.0       # cm
xl_boundary_type = "outflow"
xr_boundary_type = "outflow"
yl_boundary_type = "outflow"
yr_boundary_type = "outflow"
```

### Recipe 2.2：2D 柱坐标 R-Z 平面（**激光算例常用**）

**适用**：LaserSlab、ICF 直接驱动、柱对称内爆。

```bash
./setup LaserSlab -2d -auto +cylindrical \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab
```

parfile：
```fortran
geometry = "cylindrical"
xmin = 0.0    xmax = 0.02      # R, cm
ymin = 0.0    ymax = 0.05      # Z, cm
xl_boundary_type = "axisymmetric"   # ★ R=0 必须轴对称
xr_boundary_type = "outflow"
yl_boundary_type = "outflow"
yr_boundary_type = "outflow"
```

**关键约束**：径向轴（IAXIS）下界为 0 时，BC 必须 `axisymmetric` 或 `reflecting`。

### Recipe 2.3：1D 球坐标（ICF 内爆）

**适用**：球形内爆、星体演化。

```bash
./setup <problem> -1d -auto +spherical \
    -objdir=cases/<problem>
```

parfile：
```fortran
geometry = "spherical"
xmin = 0.0    xmax = 0.05      # R, cm
xl_boundary_type = "axisymmetric"   # ★ R=0 必须 axisymmetric
xr_boundary_type = "outflow"
```

**注意**：1D 球坐标只有 IAXIS（径向）。`ymin` / `zmin` 等被忽略。

### Recipe 2.4：3D 直角坐标

**适用**：3D 激波、3D Rayleigh-Taylor、3D MHD。

```bash
./setup <problem> -3d -auto +cartesian \
    -nxb=16 -nyb=16 -nzb=16 \
    -objdir=cases/<problem>
```

parfile：
```fortran
geometry = "cartesian"
xmin = 0.0    xmax = 1.0
ymin = 0.0    ymax = 1.0
zmin = 0.0    zmax = 1.0
xl_boundary_type = "periodic"     # 周期边界（3D RT 常用）
xr_boundary_type = "periodic"
yl_boundary_type = "periodic"
yr_boundary_type = "periodic"
zl_boundary_type = "outflow"
zr_boundary_type = "outflow"
```

### Recipe 2.5：3D 球坐标

**适用**：3D ICF、球对称外爆 / 内爆。

```bash
./setup <problem> -3d -auto +spherical \
    -nxb=16 -nyb=16 -nzb=16 \
    -objdir=cases/<problem>
```

parfile：
```fortran
geometry = "spherical"
xmin = 0.0    xmax = 0.1        # R, cm
ymin = 0.0    ymax = 180.0      # θ (极角), 度
zmin = 0.0    zmax = 360.0      # φ (方位角), 度
xl_boundary_type = "axisymmetric"
xr_boundary_type = "outflow"
yl_boundary_type = "reflecting"  # θ=0 (正z方向) 反射
yr_boundary_type = "reflecting"  # θ=180 (负z方向) 反射
zl_boundary_type = "periodic"    # φ 周期
zr_boundary_type = "periodic"
```

**注意**：角度单位是**度**（不是弧度）。

---

## 3. AMR 配置 recipe

### Recipe 3.1：最小 AMR 配置（开 AMR）

**适用**：第一次开 AMR，让网格在密度变化处细化。

parfile：
```fortran
# 基础 AMR
lrefine_min = 1
lrefine_max = 4                # ★ 设 1=无 AMR；这里开 4 层
nrefs = 2                      # 每 2 步重新细化一次

# 细化变量 1：密度
refine_var_1 = "dens"
refine_cutoff_1 = 0.2          # 误差估计 > 0.2 → 细化
derefine_cutoff_1 = 0.05       # < 0.05 → 粗化
refine_filter_1 = 0.01

# 域分块（顶层 level-1 切几块）
nblockx = 4
nblocky = 4
```

**验证**：跑几步后看 plotfile，应该看到激波附近细化到 level 4。

### Recipe 3.2：多变量细化

**适用**：既要细化激波（密度），又要细化火焰（反应进度变量）。

parfile：
```fortran
refine_var_1 = "dens"
refine_cutoff_1 = 0.2
derefine_cutoff_1 = 0.05

refine_var_2 = "flam"
refine_cutoff_2 = 0.1
derefine_cutoff_2 = 0.02
```

**注意**：4 组变量是 OR 关系（任一变量触发就细化）。

### Recipe 3.3：粒子驱动细化

**适用**：PIC 粒子模拟、激光-等离子体作用。

parfile：
```fortran
refine_on_particle_count = .true.
max_particles_per_blk = 50    # > 50 → 细化
min_particles_per_blk = 5     # < 5 → 粗化
```

### Recipe 3.4：固定 lrefine_max（无 AMR，但保留 paramesh）

**适用**：想用 paramesh 但不要 AMR（如基准测试）。

parfile：
```fortran
lrefine_min = 1
lrefine_max = 1               # 不细化
nrefs = 1000000               # 实际上不会触发
```

**或更直接**：用 `+ug` backend。

### Recipe 3.5：时变 lrefine_max

**适用**：算例初期精度要求高，后期降低。

parfile：
```fortran
gr_lrefineMaxByTime = .true.
gr_lrefmaxTime_1 = 1.0e-9     # 在 1 ns 时
gr_lrefmaxTimeValue_1 = 3     # 把 lrefine_max 改成 3

gr_lrefmaxTime_2 = 5.0e-9     # 在 5 ns 时
gr_lrefmaxTimeValue_2 = 2     # 降到 2
```

### Recipe 3.6：按半径衰减 lrefine_max

**适用**：ICF 球对称算例，外区不需要高精度。

parfile：
```fortran
gr_lrefineMaxRedDoByLogR = .true.
gr_lrefineMaxRedRadiusFact = 0.5
x_refine_center = 0.0
y_refine_center = 0.0
z_refine_center = 0.0
```

---

## 4. 边界条件组合 recipe

### Recipe 4.1：周期-周期（标准 RT）

**适用**：3D Rayleigh-Taylor 不稳定性（无边界干扰）。

parfile：
```fortran
xl_boundary_type = "periodic"
xr_boundary_type = "periodic"
yl_boundary_type = "periodic"
yr_boundary_type = "periodic"
zl_boundary_type = "outflow"
zr_boundary_type = "outflow"
```

### Recipe 4.2：反射-反射（盒子封闭）

**适用**：封闭盒子模拟（如内爆）。

parfile：
```fortran
xl_boundary_type = "reflecting"
xr_boundary_type = "reflecting"
yl_boundary_type = "reflecting"
yr_boundary_type = "reflecting"
zl_boundary_type = "reflecting"
zr_boundary_type = "reflecting"
```

### Recipe 4.3：流出-流出（开放域）

**适用**：自由膨胀、激波传出。

parfile：
```fortran
xl_boundary_type = "outflow"
xr_boundary_type = "outflow"
yl_boundary_type = "outflow"
yr_boundary_type = "outflow"
zl_boundary_type = "outflow"
zr_boundary_type = "outflow"
```

### Recipe 4.4：激光算例（轴对称 + 流出）

**适用**：LaserSlab、Sunliang_laser_CH 等。

parfile：
```fortran
xl_boundary_type = "axisymmetric"   # R=0 轴对称
xr_boundary_type = "outflow"        # R 大 → 流出
yl_boundary_type = "outflow"        # Z 小 → 流出
yr_boundary_type = "outflow"        # Z 大 → 流出
```

---

## 5. Block size 选择 recipe

### Recipe 5.1：标准（NXB=NYB=NZB=8）

**适用**：默认，适合大多数算例。

```bash
./setup <problem> -3d -auto -nxb=8 -nyb=8 -nzb=8 -objdir=cases/<problem>
```

### Recipe 5.2：大 block（NXB=NYB=NZB=16）

**适用**：每个 block 工作量增加，减少 block 总数和 MPI 通信开销。Hydro 计算密集型算例。

```bash
./setup LaserSlab -2d -auto -nxb=16 -nyb=16 -objdir=cases/LaserSlab
```

**权衡**：大 block = 更少 MPI 通信 + 更难负载均衡。一般 16 是常用上限。

### Recipe 5.3：长方形 block（NXB ≠ NYB）

**适用**：各向异性算例（如一维拉伸）。

```bash
./setup <problem> -2d -auto -nxb=32 -nyb=4 -objdir=cases/<problem>
```

---

## 6. 完整可抄配置（最小可运行 AMR 算例）

```bash
# setup
./setup Sedov -2d -auto +cartesian -nxb=8 -nyb=8 \
    -objdir=cases/Sedov_amr
```

parfile 关键段：
```fortran
# 几何 + 域
geometry = "cartesian"
xmin = -0.5   xmax = 0.5
ymin = -0.5   ymax = 0.5

# 边界
xl_boundary_type = "outflow"
xr_boundary_type = "outflow"
yl_boundary_type = "outflow"
yr_boundary_type = "outflow"

# AMR
lrefine_min = 1
lrefine_max = 4
nrefs = 2

refine_var_1 = "dens"
refine_cutoff_1 = 0.2
derefine_cutoff_1 = 0.05

# 域分块
nblockx = 4
nblocky = 4
```

**验证**：跑几步后 `Visit` 看 plotfile，应该看到圆形激波附近细化到 level 4。

---

## 7. 通用检查清单

设置完 Grid 参数后，跑前确认：

- [ ] **backend 对**：`cat cases/<case>/setup_call | grep -E "\\+pm|\\+ug"` 看实际选的
- [ ] **几何对**：`grep "geometry" cases/<case>/flash.par`
- [ ] **维度对**：setup 命令的 `-1d/-2d/-3d` 和几何兼容（如 cylindrical 不能 1d）
- [ ] **径向 BC**：如果 `xmin=0` 且 `geometry` 是 cylindrical/spherical/polar，`xl_boundary_type` 必须是 `axisymmetric` 或 `reflecting`
- [ ] **角度单位**：spherical/polar 的角度 parfile 用**度**（不是弧度）
- [ ] **AMR 开了**：`lrefine_max > 1`
- [ ] **细化变量对**：`refine_var_1 = "dens"`（字符串，大小写敏感）
- [ ] **nblockx/y/z 合理**：和 lrefine_max 配合，避免初始 block 数太多或太少
- [ ] **MAXBLOCKS 够**：跑几步后看日志 `Maximum number of blocks reached`？要 `-maxblocks=N` 加大

---

## 8. 延伸阅读

- **完整参数列表**：`knowledge/params.md`
- **AMR 内部机制**：`knowledge/internals.md §4`
- **常见错误**：`knowledge/pitfalls.md`
- **后端对比**：`knowledge/overview.md §2`
- **几何轴向映射**：`knowledge/overview.md §4`

---

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft）：5 类 recipe（backend/几何/AMR/边界/block size）+ 完整可抄最小 AMR 配置 + 通用检查清单 | claude |
