---
title: Grid 常见踩坑 — 几何 / 边界 / AMR / API / guard cell
skill: flash-grid
category: pitfalls
source_anchors:
  - source/Grid/GridMain/gr_initGeometry.F90:L153-L184
  - source/Grid/GridMain/Grid_getBlkPtr.F90:L19-L22
  - source/Grid/GridMain/paramesh/Grid_markRefineDerefine.F90:L44
  - source/Grid/Grid_fillGuardCells.F90:L233
  - source/Grid/GridMain/paramesh/Grid_data.F90:L243-L252
manual_ref: "FLASH 4.8 User Guide §7-8"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai-waiting
status: draft
tags:
  - grid
  - pitfall
  - geometry
  - AMR
  - guardcell
  - API
---

# Grid 常见踩坑

> **TL;DR**：12 类常见 Grid 踩坑，分 4 大类：**A. 启动期**（geometry / BC 不合法）+ **B. 运行期数值**（AMR 不触发、guard cell 脏）+ **C. API 误用**（getBlkPtr 不配对）+ **D. 概念错误**（lrefine_max、backend 选择）。

---

## A. 启动期踩坑

### A.1 `invalid geometry for this dimension` abort

**触发代码**：

```fortran
! source/Grid/GridMain/gr_initGeometry.F90:153-158
if (gr_geometry == CYLINDRICAL .and. NDIM == 1) then
    call Driver_abortFlash("invalid geometry for this dimension")
end if
if (gr_geometry == POLAR .and. NDIM == 3) then
    call Driver_abortFlash("invalid geometry for this dimension")
end if
```

**原因**：几何 + 维度组合不合法。

| 几何 | 合法维度 |
|---|---|
| cartesian | 1D / 2D / 3D |
| cylindrical | 2D / 3D（**1D 不合法**） |
| spherical | 1D / 2D / 3D |
| polar | 2D（**3D 不合法**） |

**修复**：改 setup 命令的 `-1d/-2d/-3d` 或几何选项。

### A.2 `Radial axis cannot be zero ... unless BC is reflecting/axisymmetric` abort

**触发代码**：

```fortran
! source/Grid/GridMain/gr_initGeometry.F90:172-184
if (xmin < 0.0) call Driver_abortFlash("radial axis cannot be negative")
if (xmin == 0.0 .and. &
    (xl_boundary_type /= "reflecting" .and. xl_boundary_type /= "axisymmetric")) then
    call Driver_abortFlash("Radial axis cannot be zero unless BC is reflecting/axisymmetric")
end if
```

**原因**：径向（IAXIS）下界为 0（典型）时，BC 必须 `reflecting` 或 `axisymmetric`。

**修复**：parfile 改：
```fortran
xl_boundary_type = "axisymmetric"     # 或 "reflecting"
```

**典型场景**：cylindrical R-Z 算例从 0 开始，必须 axisymmetric。

### A.3 backend 不存在或 setup 错

**错误信息**：`SetupError: Unit Grid not found` 或 `Grid is ambiguous`

**原因**：用了不存在的 backend 名（如 `+cylindricalRZ` 没这个 setup 选项）。

**修复**：
- 检查 backend 名：`+pm4dev` / `+pm40` / `+pm3` / `+pm2` / `+ug`
- 检查几何名：`+cartesian` / `+cylindrical` / `+spherical` / `+polar`（**没有 cylindricalRZ**）
- 看 `bin/setup_shortcuts.txt` 全部可用快捷方式

### A.4 NGUARD 不够导致 Hydro 算错或 abort

**原因**：PPM Upwind Hydro 需要 NGUARD=6，但 setup 默认 4。

**修复**：检查 Hydro Config 文件是否声明 `GUARDCELLS 6`：

```bash
cat source/physics/Hydro/HydroMain/unsplit/Config | grep GUARDCELLS
```

如果没有，要么用更简单的 Hydro 选项（如不 ppm upwind），要么在 Hydro Config 加 `GUARDCELLS 6` 然后重新 setup+make。

### A.5 `Maximum number of blocks reached` 警告或 abort

**原因**：`MAXBLOCKS`（setup 期）不够，AMR 细化时单进程 block 数超过。

**修复**：setup 命令加 `-maxblocks=N`：

```bash
./setup <problem> ... -maxblocks=2000 ...
```

**怎么知道够不够**：跑几步看日志，应该有 `block count = N`。N 接近 MAXBLOCKS 就要加大。

---

## B. 运行期数值踩坑

### B.1 AMR 不触发（lrefine_max 已设但网格不细化）

**症状**：plotfile 看不到细化结构，所有 cell 都是 level 1。

**可能原因**（按优先级）：

1. `refine_var_1 = "none"` 或没设 → 细化准则没启用
2. `refine_cutoff_N` 太大（如 0.9）→ 误差估计永远达不到
3. `nrefs` 太大（如 1000）→ 步数还不够触发
4. `interpol_order = 0` → 插值失败
5. `lrefine_max = 1` → 根本没开 AMR

**诊断**：跑几步看日志，搜 `refine` / `derefine` 字样。Paramesh 会打印每步 refine/derefine 了多少 block。

**修复**（典型配置）：
```fortran
refine_var_1 = "dens"
refine_cutoff_1 = 0.2          # ★ 不要太大
derefine_cutoff_1 = 0.05
lrefine_max = 4                # ★ > 1
nrefs = 2                      # 每 2 步检查
```

### B.2 网格过度细化（lrefine_max 飙到顶）

**症状**：内存爆、跑得超慢；plotfile 看到 level 全跑到 `lrefine_max`。

**可能原因**：

1. `refine_cutoff_N` 太小（如 0.01）→ 几乎所有 cell 都触发细化
2. `refine_filter_N` 没用 → 噪声触发细化
3. 物理量本身有 NaN 或剧烈震荡（如激光未沉积但 gridWeight 已设）

**修复**：
```fortran
refine_cutoff_1 = 0.3          # 加大阈值
refine_filter_1 = 0.05         # 加大滤波
```

并检查物理量是否正常（看 plotfile）。

### B.3 `guard cell is not filled` 或计算发散

**症状**：跑几步 NaN、Hydro abort。

**原因**：物理计算前没调 `Grid_fillGuardCells`，guard cell 是旧值。

**诊断**：找物理单元的代码，看主循环是否有：

```fortran
call Grid_fillGuardCells(CENTER, ALLDIR)
```

在 Hydro / sourceTerms 之前。

**修复**：在物理计算前显式 fillGuardCells。如果用了 Driver 标准循环，应该已经填了（Driver_sourceTerms 之前）。

### B.4 角度单位用弧度（错）

**症状**：spherical/polar 算例几何范围错（如本意 0-180° 但写 0-π）。

**原因**：FLASH 接受的 `ymin`/`ymax`/`zmin`/`zmax` 在角度轴上是**度**（不是弧度）。

**修复**：parfile 角度用度：
```fortran
ymin = 0.0    ymax = 180.0     # θ，度（不是 π）
zmin = 0.0    zmax = 360.0     # φ，度（不是 2π）
```

### B.5 NO_PERMANENT_GUARDCELLS 下数据不一致

**症状**：Paramesh 4 dev（`+pm4dev`）算例结果异常、偶尔 abort。

**原因**：见 `knowledge/internals.md §10`。修改 solnData 后立刻读 guard cell，但 guard cell 没刷新。

**修复**：修改 solnData 后要：
```fortran
call Grid_releaseBlkPtr(blockID, solnData, CENTER)
call Grid_fillGuardCells(CENTER, ALLDIR)
call Grid_getBlkPtr(blockID, solnData, CENTER)
! 现在再读 guard cell
```

---

## C. API 误用踩坑

### C.1 `Grid_getBlkPtr` 后忘 `Grid_releaseBlkPtr`

**症状**：内存泄漏；NO_PERMANENT_GUARDCELLS 模式下 abort。

**原因**：getBlkPtr / releaseBlkPtr 必须严格配对。

**触发代码**（`source/Grid/GridMain/Grid_getBlkPtr.F90:L19-L22`）：
```fortran
! Paramesh 4 dev 的 NO_PERMANENT_GUARDCELLS 下，
! 同时持有两个 block 指针会 abort
```

**修复**：

```fortran
! ✅ 正确
call Grid_getBlkPtr(blockID, solnData, CENTER)
! ... 操作 ...
call Grid_releaseBlkPtr(blockID, solnData, CENTER)   ! ★ 必加

! ❌ 错误：忘记 release
call Grid_getBlkPtr(blockID, solnData, CENTER)
! ... 操作 ...
! 函数返回，solnData 指针泄漏
```

**经验法则**：每写一次 `Grid_getBlkPtr`，立刻写配对的 `Grid_releaseBlkPtr`，再填中间逻辑。

### C.2 同时持有两个 block 指针

**症状**：NO_PERMANENT_GUARDCELLS 下直接 abort。

**原因**：见 C.1。

**修复**：用 `Grid_getBlkData` 拷出来再操作，或用 `Grid_putBlkData` 写回。

```fortran
! ✅ 正确：拷出来
real :: dataA(NUNK_VARS, GRID_IHI_GC, GRID_JHI_GC, GRID_KHI_GC)
call Grid_getBlkData(b1, CENTER, DENS_VAR, EXTERIOR, [1,1,1], dataA, [NXB,NYB,NZB])

call Grid_getBlkPtr(b2, solnB, CENTER)
! 用 dataA 和 solnB
call Grid_releaseBlkPtr(b2, solnB, CENTER)
```

### C.3 用错 gridDataStruct（CENTER vs FACEX）

**症状**：拿到的是 cell 数据但以为是 face 数据，或反之。

**原因**：第 3 参数填错。

**修复**：
```fortran
! 取 cell 数据
call Grid_getBlkPtr(blockID, solnData, CENTER)
! solnData(DENS_VAR, i, j, k) 等

! 取 IAXIS 面心磁场
call Grid_getBlkPtr(blockID, faceData, FACEX)
! faceData(MAGX_FACE_VAR, i, j, k)（注意 IAXIS 多一个面）
```

### C.4 索引范围用错（blkLimits vs blkLimitsGC）

**症状**：循环跑到了 guard cell 区域，读到了脏数据。

**原因**：用 `blkLimitsGC` 循环物理计算。

**修复**：
- 物理计算遍历 → 用 `blkLimits`（内部 cell）
- 模板/插值需要邻居 → 用 `blkLimitsGC`（含 guard cell，**前提是已 fillGuardCells**）

```fortran
! ✅ 物理计算
do k = blkLimits(LOW, KAXIS), blkLimits(HIGH, KAXIS)
   ...

! ❌ 物理计算误用 GC
do k = blkLimitsGC(LOW, KAXIS), blkLimitsGC(HIGH, KAXIS)
   ... ! 这会写到 guard cell，下次 fillGuardCells 会被覆盖
```

### C.5 facevarxs 拼写错误

**症状**：编译错（`unresolved symbol facevarxs`）。

**原因**：变量名是 `facevarx` / `facevary` / `facevarz`（**没有 `s` 后缀**）。

**修复**：去掉 `s`。

### C.6 直接 use Grid_data 读 gr_*

**症状**：代码可读性差，将来 backend 切换会坏。

**原因**：物理单元不应该直接访问 Grid 内部全局变量 `gr_*`。

**修复**：用 Grid_get* API：
- 取几何 → `Grid_getGeometry`
- 取 block 边界框 → `Grid_getBlkBoundBox`
- 取 cell 坐标 → `Grid_getCellCoords`
- 取 block 大小 → `Grid_getDeltas` 或 `Grid_getBlkPhysicalSize`

---

## D. 概念错误踩坑

### D.1 以为 NXB/NYB/NZB 是 runtime parameter

**症状**：parfile 写 `NXB = 16` 没生效。

**原因**：`NXB` 是 setup 期编译常量（写进 `Flash.h`）。

**修复**：setup 命令行 `-nxb=16`，重新 setup+make。

### D.2 以为 lrefine_max=1 就是开 AMR

**症状**：plotfile 没看到细化。

**原因**：`lrefine_max` 默认 1 = 单层 = **无 AMR**。

**修复**：parfile 设 `lrefine_max > 1`（典型 4-6）。

### D.3 以为 nblockx/y/z 决定 MPI 进程数

**症状**：跑了多个进程，但 block 数对不上。

**原因**：`nblockx/y/z` 决定 **block 切分**，不是 MPI 进程数。

**修复**：MPI 进程数由 `mpirun -np N` 决定。Paramesh 自动把 block 分配给进程。

### D.4 用 UG 但 parfile 设 lrefine_max

**症状**：parfile 接受但无效。

**原因**：UG backend 无 AMR，AMR 参数被忽略。

**修复**：要么用 paramesh（去掉 `+ug`），要么删掉 AMR 参数。

### D.5 以为 cylindrical + 2d 是 R-φ（其实是 R-Z）

**症状**：算例结果和预期完全不同。

**原因**：见 `knowledge/overview.md §4`。cylindrical + 2D = R-Z 平面，φ 被丢掉。

**修复**：
- 想要 R-Z → `cylindrical + 2d` ✓
- 想要 R-φ → `polar + 2d`（不是 cylindrical）
- 想要 3D 柱 → `cylindrical + 3d`（含 φ）

### D.6 以为可以热切换 backend

**症状**：把 parfile 改了 backend 选择，重启报错。

**原因**：backend 是 **setup 期编译决定**，不是 runtime parameter。

**修复**：换 backend 要重新 setup+make：

```bash
./setup <problem> ... +ug ...    # 改成 UG
```

### D.7 以为 `+pm4dev` 只是 backend 选择

**症状**：不知道 `+pm4dev` 还有副作用。

**原因**：`+pm4dev` 不只设 backend，还设 `FlashAvoidOrrery=True`（关闭 Paramesh 4 dev 的 Orrery 框架）。

**修复**：了解副作用；如果想要 Orrery，自己手动设 `Grid=PM4DEV` 但不 `FlashAvoidOrrery`。

---

## E. 通用调试流程

遇到 Grid 相关 abort 时：

### E.1 看 abort 信息

```bash
grep "Driver_abortFlash\|abort" 01-data/<basenm>.log
```

### E.2 看 geometry 检查

```bash
grep "geometry\|Geometry" 01-data/<basenm>.log
```

### E.3 看 AMR 统计

```bash
grep "refine\|derefine\|lrefine" 01-data/<basenm>.log | head -20
```

### E.4 看 block 分布

```bash
grep "block count\|nblocks" 01-data/<basenm>.log | head -20
```

### E.5 用 flash-pitfall-finder

如果 abort 信息含具体 routine 名，调 `flash-pitfall-finder` skill 匹配踩坑条目。

### E.6 跨 skill 协作

| 症状 | 协作链 |
|---|---|
| 激光算例 + Grid 错 | `flash-pitfall-finder`（定位）→ `flash-grid`（修复）→ `flash-laser`（验证） |
| 网格细化但 Hydro 算错 | `flash-grid`（AMR 配置）→ `flash-hydro`（Hydro 适应 AMR） |
| 不知道 abort 来源 | `flash-pitfall-finder`（匹配）→ 对应物理 skill（深入） |

---

## F. 延伸阅读

- **Grid 参数完整字典**：`knowledge/params.md`
- **AMR 内部机制**：`knowledge/internals.md §4`
- **典型配置**：`knowledge/recipes.md`
- **跨单元踩坑**：`skills/flash-pitfall-finder/knowledge/pitfalls/`
- ** Driver 主循环 Grid 调用顺序**：`flash-driver/knowledge/internals.md`
- **找 Grid_* 源码**：`flash-source-reader` skill

---

## G. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft）：12 类踩坑（A 启动 5 + B 运行 5 + C API 6 + D 概念 7 = 实际共 23 条细分）+ 通用调试流程 + 跨 skill 协作 | claude |
