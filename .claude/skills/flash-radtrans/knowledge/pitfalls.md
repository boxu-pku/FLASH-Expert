---
title: RadTrans 常见踩坑 — fl_none / eV 单位 / IONMIX 同步 / Unified 实验
skill: flash-radtrans
category: pitfalls
source_anchors:
  - source/physics/RadTrans/RadTransMain/MGD/Config:L26
  - source/physics/RadTrans/RadTransMain/MGD/rt_init.F90:L37-L131
  - source/physics/RadTrans/RadTransMain/MGD/Unified/README
  - source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90:L415
manual_ref: "FLASH 4.8 User Guide §25"
created: 2026-07-19
last_verified: 2026-07-19
verifier: claude
status: draft
tags:
  - radtrans
  - pitfall
  - mgd
  - flux-limiter
---

# RadTrans 常见踩坑

> **TL;DR**：分 4 大类共 15+ 踩坑：**A 启动期**（参数错、群边界缺）+ **B 运行期数值**（NaN、辐射爆炸、不收敛）+ **C 概念错误**（fl_none 默认、Unified 实验性）+ **D IONMIX 同步**（最隐蔽的物理错误）。按 L-012 诊断类先引导贴现场。

---

## 0. 诊断引导（按 L-012）

遇到 RadTrans abort 先贴：

```bash
# 1. abort 信息
grep -B 2 -A 5 "RadTrans\|MGD\|abort\|HYPRE" 01-data/<basenm>.log | head -40

# 2. RadTrans_init 打印的参数
grep "RadTrans_init\|rt_useMGD\|mgdNumGroups\|mgdFlMode\|mgdBounds" 01-data/<basenm>.log | head -30

# 3. setup 命令
cat cases/<case>/setup_call | grep -E "\+mgd|\+laser|\+uhd3t|mgd_meshgroups"

# 4. parfile MGD 段
grep "rt_mgd\|rt_useMGD\|rt_dtFactor" cases/<case>/flash.par

# 5. IONMIX 表群结构（关键）
head -10 cases/<case>/*.cn4   # 看表的群数和边界
```

**贴完后能给出针对性诊断。** 下面是常见原因作为参考。

---

## A. 启动期踩坑

### A.1 `group boundary was not specified` abort

**触发代码**（`source/physics/RadTrans/RadTransMain/MGD/rt_init.F90`）：

```fortran
call RuntimeParameters_get("rt_mgdBounds_"//i_str, group_bound)
if (group_bound < 0.0) then
    call Driver_abortFlash("MGD: group boundary was not specified")
end if
```

**原因**：`rt_mgdBounds_*` 默认 -1.0，没在 parfile 设。N 群需要 **N+1 个** `rt_mgdBounds_*`。

**修复**：parfile 加全部 N+1 个群边界：

```fortran
rt_mgdNumGroups = 6
rt_mgdBounds_1 = 1.e-1
rt_mgdBounds_2 = 1.e0
...
rt_mgdBounds_7 = 1.e5    # N+1 = 7
```

### A.2 `rt_mgdNumGroups too large` abort

**触发代码**：

```fortran
if (rt_mgdNumGroups > MGDR_NONREP_MAXLOCS * meshCopyCount) then
    call Driver_abortFlash("rt_mgdNumGroups too large")
end if
```

**原因**：parfile 设的 `rt_mgdNumGroups` 超过 setup 期 `mgd_meshgroups`（meshCopyCount=1 时）。

**修复**：检查 setup 命令的 `mgd_meshgroups`：

```bash
cat cases/<case>/setup_call | grep mgd_meshgroups
```

如 `mgd_meshgroups=6`，则 `rt_mgdNumGroups` 必须 ≤ 6。要更多群 → 重新 setup 加大 `mgd_meshgroups`。

### A.3 `Must specify mgd_meshgroups to use multigroup diffusion` abort

**触发代码**：`source/physics/RadTrans/RadTransMain/MGD/Config`（Python 检查）

**原因**：setup 加了 `+mgd` 但没指定 `mgd_meshgroups`。

**修复**：setup 命令加 `mgd_meshgroups=N`：

```bash
./setup <problem> ... +mgd mgd_meshgroups=6 ...
```

### A.4 `rt_mgdBoundEntry` 不识别

**触发代码**：`rt_init.F90:L99-L100`

```fortran
if (rt_mgdBoundEntry /= "grbd_manual") then
    call Driver_abortFlash("Only grbd_manual MGD bound entry implemented")
end if
```

**原因**：parfile 写了不支持的值（如 `"grbd_from_table"`）。

**修复**：默认 `"grbd_manual"` 即可，不用写。

### A.5 `Invalid rt_mgdFlMode` abort

**原因**：parfile 写了不存在的 flMode（如 `fl_geometric` / `fl_arithmetic`）。

**修复**：用允许值之一：
- `fl_none`（仅测试）
- `fl_harmonic`（HEDP 推荐）
- `fl_larsen`
- `fl_minmax`
- `fl_levermorepomraning1981`

---

## B. 运行期数值踩坑

### B.1 辐射能量爆炸（ERAD_VAR 超大）

**症状**：跑几步后 ERAD_VAR 飙升几个数量级，TELE 也异常高。

**最常见原因**：`rt_mgdFlMode = "fl_none"`（默认值！）

**机制**：纯扩散（无限流）在光学薄区让通量超过自由流极限 `c·E`，导致辐射"超光速"传播，能量异常积累。

**修复**（必做）：

```fortran
rt_mgdFlMode = "fl_harmonic"      # 不是默认！必须显式设
rt_mgdFlCoef = 1.0
```

### B.2 MGD HYPRE 不收敛

**症状**：日志反复 `HYPRE did not converge` 或 `MGD retry` 警告。

**可能原因**：
1. **COND_VAR 极端值**：IONMIX 表外推，不透明度异常
2. **dt 太大**：虽然隐式无条件稳定，但极端 dt 仍可能不收敛
3. **边界 BC 错**：vacuum 误用 reflecting，导致能量异常

**修复**：
- 检查 TELE_VAR 范围（`grep "max temp\|min temp" 01-data/<basenm>.log`）
- 检查 parfile 边界类型
- 临时降 `dtinit` 或 `cfl` 测试

### B.3 辐射能量为 0（无扩散发生）

**症状**：跑很多步 ERAD_VAR 始终为 0，TELE 不受辐射影响。

**可能原因**：
1. **EMIS_VAR 没算**：Opacity 查询返回 0（IONMIX 表和物质不匹配）
2. **rt_useMGD = .false.**（默认）但 setup 加了 +mgd → setup 没生效
3. **rt_mgdNumGroups = 0**（默认）

**修复**：
- 确认 parfile `rt_useMGD = .true.`
- 确认 IONMIX 表物质（species 配置）和 Opacity 查询匹配
- 用 `grep "rt_useMGD\|rt_mgdNumGroups" 01-data/<basenm>.log` 看实际值

### B.4 MGDRi 群能量负值

**症状**：plotfile 显示某些群 `MGDRg_VAR < 0`。

**原因**：HYPRE 求解的离散误差，或 flux limiter 在极端 R 值给出负 λ。

**修复**：
- 检查 IONMIX 表群结构匹配
- 临时降 `rt_dtFactor`（开 `rt_computeDt = .true.`）
- 换 flux limiter（fl_harmonic → fl_larsen）

---

## C. 概念错误踩坑

### C.1 fl_none 是 Config 默认（危险陷阱）

源码：`source/physics/RadTrans/RadTransMain/MGD/Config:L26`

```
PARAMETER STRING rt_mgdFlMode "fl_none" [...]
```

**症状**：用户没改 parfile 的 `rt_mgdFlMode` → 用默认 `fl_none` → 辐射超光速。

**修复**：每个 HEDP 算例 parfile **必须**显式设：

```fortran
rt_mgdFlMode = "fl_harmonic"
```

**为什么默认是 fl_none**：让用户能测试纯扩散极限（教学/验证用）。但生产算例必须改。

### C.2 以为 Unified 是更好的选择

源码：`source/physics/RadTrans/RadTransMain/MGD/Unified/README`

```
completely EXPERIMENTAL and has had VERY LIMITED TESTING
```

**症状**：用户读论文觉得 Unified 更精确（无 operator-split 误差），想用。

**为什么不推荐**：
1. README 明示实验性
2. 不支持 mesh replication（`Unified/RadTrans.F90:L35-L38`）
3. 群数受 HYPRE block 矩阵规模限制
4. 时间步控制更复杂（θ_C, θ_D 分开）
5. 社区验证不足

**修复**：用默认 operator-split MGD（LaserSlab 用的）。

### C.3 以为 NeutrinoLeakage 适合 HEDP

**症状**：用户找"辐射输运"看到 NeutrinoLeakage，想用。

**为什么不适合**：NeutrinoLeakage 是**中子**输运（O'Connor & Ott 2010），用于**核心坍缩超新星**。物理完全不同（中子 vs 光子），算法完全不同（ray-based vs diffusion）。

**修复**：HEDP 用 MGD；NeutrinoLeakage 仅核心坍缩超新星。

### C.4 找 RadTrans_mgdStaggeredSource / RadTrans_mgdEvolveModel

**症状**：用户从其他文档看到这些函数名，找不到。

**原因**：**这两个函数在本树不存在**（其他文档可能误列或来自旧版本）。

**修复**：MGD 演化全在 `RadTrans(nblk, blklst, dt, pass)` 一个函数里。

### C.5 以为 rt_mgdBounds 单位是 erg

源码：`source/physics/RadTrans/RadTransMain/MGD/rt_init.F90:L37, L131`

```fortran
real, parameter :: EV_TO_ERGS = 1.60217653e-12
group_bound_erg = group_bound_eV * EV_TO_ERGS
```

**症状**：用户写 `rt_mgdBounds_1 = 1.6e-13`（以为是 erg）→ 实际等于 1.6e-13 / 1.6e-12 = 0.1 eV，刚好和期望的 1e-1 eV 接近 → 物理算错。

**修复**：`rt_mgdBounds_*` 单位是 **eV**：

```fortran
rt_mgdBounds_1 = 1.e-1   # 这是 0.1 eV，不是 0.1 erg
```

### C.6 以为 mgd_meshgroups 是 runtime parameter

**症状**：parfile 写 `mgd_meshgroups = 10` 不生效（实际用 setup 期值）。

**原因**：`mgd_meshgroups` 是 setup 期变量，编译期决定 MGDR 槽位数。改它要重新 setup+make。

**修复**：setup 命令加：

```bash
./setup <problem> ... mgd_meshgroups=10 ...
```

### C.7 以为 MGD 自动应用辐射压力到 Hydro

**症状**：用户期望 `PRAD_VAR` 影响 Hydro，但实际没有。

**原因**：operator-split MGD **不应用** `PRAD_VAR` 到 Hydro。这是已知局限。

**修复**：辐射压力主导的算例（如辐射主导激波）需要：
- 用 Unified 变体（实验性）
- 或显式加辐射压力源项（需改源码）

---

## D. IONMIX 表同步（最隐蔽错误）

### D.1 MGD 群边界和 IONMIX 表不对齐

**症状**：算例跑通，但结果和文献不符（如辐射温度偏低/偏高）。

**原因**：MGD 的 `rt_mgdBounds_*` 和 IONMIX 不透明度表的群边界**不一致**。

**MGD 不自动同步**——用户责任。

**修复**：

```bash
# 1. 看 IONMIX 表的群结构
head -10 cases/<case>/*.cn4
# 第 1 行：Ngroups Ndensities
# 后续是 log 群边界（eV）

# 2. MGD rt_mgdBounds_* 必须是 IONMIX 群边界的子集
# 例：IONMIX 100 群，MGD 用前 6 个边界
```

### D.2 IONMIX 表的物质和 species 不匹配

**症状**：算例启动 OK，但跑出来辐射能量为 0 或异常。

**原因**：setup `species=cham,targ` 但 IONMIX 表是其他物质（如 al）。

**修复**：确认 species 和 IONMIX 表对应：
- `species=cham`（聚苯乙烯） → `polystyrene-imx-008.cn4`
- `species=al`（铝） → `al-imx-003.cn4`

### D.3 IONMIX 表范围太小

**症状**：算例物理量超出 IONMIX 表范围 → 不透明度外推不可靠。

**诊断**：

```bash
grep "out of table\|outside\|extrapolat" 01-data/<basenm>.log | head -10
```

**修复**：用范围更大的表（FEOS 重新生成）。

---

## E. 通用调试流程

按 L-012：

### E.1 看 abort 信息

```bash
grep "RadTrans\|MGD\|HYPRE\|abort" 01-data/<basenm>.log | head -10
```

### E.2 看 RadTrans_init 参数

```bash
grep "RadTrans_init\|rt_useMGD\|rt_mgdNum\|rt_mgdFlMode" 01-data/<basenm>.log | head -15
```

### E.3 看 HYPRE 求解统计

```bash
grep "HYPRE\|iterations\|converge" 01-data/<basenm>.log | tail -20
```

### E.4 看 ERAD_VAR 和 MGDRi_VAR 范围

用 Visit 看 plotfile，确认辐射能量物理合理。

### E.5 跨 skill 协作

| 症状 | 协作链 |
|---|---|
| MGD abort + 激光算例 | `flash-pitfall-finder`（定位）→ `flash-radtrans`（修 MGD）→ `flash-laser`（验证） |
| MGD 不收敛 | `flash-radtrans`（参数）→ `flash-diffuse`（HYPRE 内部，Phase 2） |
| IONMIX 不匹配 | `flash-radtrans`（群结构）→ `flash-material`（表物理，Phase 2） |
| 不知道 abort 来源 | `flash-pitfall-finder`（匹配）→ 对应物理 skill |

---

## F. 延伸阅读

- **MGD 总览**：`knowledge/overview.md`
- **完整参数列表**：`knowledge/params.md`
- **MGD 主流程**：`knowledge/internals.md §2`
- **典型配置**：`knowledge/recipes.md`
- **跨单元踩坑**：`agent/pitfalls/`
- **LaserSlab 参考 parfile**：`source/Simulation/SimulationMain/LaserSlab/flash.par`
- **Diffuse 单元（HYPRE）**：`flash-diffuse`（Phase 2 后）

---

## G. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft）：4 大类 15+ 踩坑（A 启动 5 + B 数值 4 + C 概念 7 + D IONMIX 3）+ 诊断引导层（按 L-012）+ 通用调试流程 + 跨 skill 协作 | claude |
