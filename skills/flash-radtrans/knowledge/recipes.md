---
title: RadTrans 典型配置 — LaserSlab MGD + 边界 + flux limiter + 群结构
skill: flash-radtrans
category: recipes
source_anchors:
  - source/Simulation/SimulationMain/LaserSlab/flash.par
  - source/physics/RadTrans/RadTransMain/MGD/Config
  - source/physics/RadTrans/RadTransMain/MGD/rt_init.F90:L37-L131
manual_ref: "FLASH 4.8 User Guide §25"
created: 2026-07-19
last_verified: 2026-07-19
verifier: claude
status: draft
tags:
  - radtrans
  - recipe
  - mgd
  - laser-slab
---

# RadTrans 典型配置 recipes（MGD 聚焦）

> **TL;DR**：按 L-013 聚焦主流量径——LaserSlab MGD 配置（HEDP 标准）。5 类 recipe：MGD setup + flux limiter 选择 + 边界组合 + 群结构设计 + 与 Hydro/EOS 协作。

---

## 0. 通用准备

### 0.1 setup 命令

LaserSlab HEDP 标准配置：

```bash
./setup LaserSlab -2d -auto +cylindrical \
    +laser +mgd +uhd3t \
    species=cham,targ \
    mgd_meshgroups=6 \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab \
    -parfile=example.par
```

关键 setup 变量：
- `+mgd`：选 MGD 变体（替代默认 RadTrans stub）
- `+laser +mgd +uhd3t`：HEDP 三件套（激光 + 辐射扩散 + 三温）
- `species=cham,targ`：chamber + target 物质（用 IONMIX 表）
- `mgd_meshgroups=6`：**setup 期**变量，编译期分配 6 个 MGDR 槽

### 0.2 parfile 关键段

```fortran
# MGD 主控
rt_useMGD = .true.
rt_mgdNumGroups = 6
rt_mgdBounds_1..7 = 1e-1, 1e0, 1e1, 1e2, 1e3, 1e4, 1e5   # eV

# Flux limiter
rt_mgdFlMode = "fl_harmonic"
rt_mgdFlCoef = 1.0

# 边界
rt_mgdXlBoundaryType = "reflecting"
rt_mgdXrBoundaryType = "vacuum"
...

# 时间步
rt_dtFactor = 0.02
```

---

## 1. MGD setup recipe

### Recipe 1.1：LaserSlab 标准（HEDP 默认）

**适用**：ICF、激光等离子体、HEDP 三温算例。

```bash
./setup LaserSlab -2d -auto +cylindrical \
    +laser +mgd +uhd3t \
    species=cham,targ \
    mgd_meshgroups=6 \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab
```

**为什么**：完整 HEDP 链路（激光→MGD 辐射扩散→3T EOS）。`mgd_meshgroups=6` 编译期分配 6 群。

### Recipe 1.2：单群（gray）测试

**适用**：单元测试、教学、验证 MGD 基本工作。

```bash
./setup <problem> -2d -auto +cartesian +mgd \
    mgd_meshgroups=1 \
    -objdir=cases/<problem>_gray
```

parfile：
```fortran
rt_mgdNumGroups = 1
rt_mgdBounds_1 = 1.e-3      # eV
rt_mgdBounds_2 = 1.e5
rt_mgdFlMode = "fl_harmonic"
```

**为什么**：1 群 = gray 模型，物理简单（只有"灰体"辐射），适合快速验证。

### Recipe 1.3：多群精细（70 群）

**适用**：需要精确辐射能谱演化的算例（如 X 射线诊断）。

```bash
./setup <problem> -2d -auto +cylindrical +laser +mgd +uhd3t \
    species=cham,targ \
    mgd_meshgroups=70 \
    -objdir=cases/<problem>_70g
```

parfile：
```fortran
rt_mgdNumGroups = 70
# 70 个 rt_mgdBounds_* 要手动写（eV）
rt_mgdBounds_1 = 1.e-1
rt_mgdBounds_2 = 1.2e-1
... (一直到 rt_mgdBounds_71)
```

**注意**：必须和 IONMIX 不透明度表的 70 群边界**手动对齐**。LaserSlab 默认 IONMIX 表是 100 群（参见 polystyrene-imx-008.cn4），用 70 群需要重新生成匹配的表。

---

## 2. Flux limiter 选择 recipe

### Recipe 2.1：fl_harmonic（LaserSlab 默认 + HEDP 推荐）

```fortran
rt_mgdFlMode = "fl_harmonic"
rt_mgdFlCoef = 1.0
```

**为什么 HEDP 推荐**：调和平均平滑过渡光学厚（纯扩散）和光学薄（自由流）两区，无 `fl_minmax` 的不连续性。

### Recipe 2.2：fl_none（**危险**！仅测试用）

```fortran
rt_mgdFlMode = "fl_none"
```

**为什么危险**：纯扩散会在光学薄区让辐射超光速（违反物理）。**只在测试纯扩散极限时用**。

**症状**：算例跑出来辐射能量爆炸、TELE 异常高。

### Recipe 2.3：fl_larsen（备选）

```fortran
rt_mgdFlMode = "fl_larsen"
```

**何时用**：fl_harmonic 在某些极端算例不够精确时（如辐射激波捕捉）。备选。

### Recipe 2.4：fl_levermorepomraning1981（理论精确）

```fortran
rt_mgdFlMode = "fl_levermorepomraning1981"
```

**何时用**：理论验证（Levermore-Pomraning 1981 论文模型）。生产算例 fl_harmonic 已够。

### 2.5 不存在的取值

源码：`MGD/Config:L26`

**没有** `fl_geometric` / `fl_arithmetic`——其他文档可能误列。写了会 abort。

---

## 3. 边界条件组合 recipe

### Recipe 3.1：LaserSlab 标准（HEDP 典型）

```fortran
rt_mgdXlBoundaryType = "reflecting"      # 激光入射侧（轴对称）
rt_mgdXrBoundaryType = "vacuum"           # 靶背（辐射自由流出）
rt_mgdYlBoundaryType = "vacuum"           # 靶侧（开放）
rt_mgdYrBoundaryType = "reflecting"       # 对称
rt_mgdZlBoundaryType = "reflecting"       # 2D Z 退化
rt_mgdZrBoundaryType = "reflecting"
```

**为什么 X 方向 asymmetric**：
- 左是激光入射方向（圆柱 R=0 轴对称 → reflecting）
- 右是靶背（辐射向外逃逸 → vacuum）

### Recipe 3.2：全开放（无对称）

```fortran
rt_mgdXlBoundaryType = "vacuum"
rt_mgdXrBoundaryType = "vacuum"
rt_mgdYlBoundaryType = "vacuum"
rt_mgdYrBoundaryType = "vacuum"
rt_mgdZlBoundaryType = "vacuum"
rt_mgdZrBoundaryType = "vacuum"
```

**适用**：开放空间辐射问题（如爆炸辐射）。

### Recipe 3.3：Dirichlet（外部辐射源）

```fortran
rt_mgdXlBoundaryType = "dirichlet"
rt_mgdXlBoundaryTemp = 1.e6              # K，边界辐射温度
rt_mgdXrBoundaryType = "vacuum"
```

**适用**：从边界注入黑体辐射（如模拟外部 X 射线源）。

### Recipe 3.4：周期

```fortran
rt_mgdXlBoundaryType = "periodic"
rt_mgdXrBoundaryType = "periodic"
```

**适用**：全周期辐射算例（罕见）。

---

## 4. 群结构设计 recipe

### Recipe 4.1：LaserSlab 6 群（5-decade 对数）

```fortran
rt_mgdNumGroups = 6
rt_mgdBounds_1 = 1.e-1    # eV
rt_mgdBounds_2 = 1.e0
rt_mgdBounds_3 = 1.e1
rt_mgdBounds_4 = 1.e2
rt_mgdBounds_5 = 1.e3
rt_mgdBounds_6 = 1.e4
rt_mgdBounds_7 = 1.e5     # N+1 = 7 个边界
```

**为什么 5-decade 对数**：覆盖 HEDP 典型光子能量范围（远红外到硬 X 射线）。每群跨一个数量级，分辨率均匀。

### Recipe 4.2：精细 X 射线带（高能区加密）

```fortran
rt_mgdNumGroups = 10
# 低能区粗，高能区（X 射线）细
rt_mgdBounds_1 = 1.e0     # 1 eV
rt_mgdBounds_2 = 1.e1     # 10 eV
rt_mgdBounds_3 = 1.e2     # 100 eV
rt_mgdBounds_4 = 5.e2
rt_mgdBounds_5 = 1.e3
rt_mgdBounds_6 = 2.e3
rt_mgdBounds_7 = 3.e3
rt_mgdBounds_8 = 5.e3
rt_mgdBounds_9 = 7.e3
rt_mgdBounds_10 = 1.e4    # 10 keV
rt_mgdBounds_11 = 1.e5    # 100 keV
```

**为什么**：HEDP 激光等离子体主要发射在 keV 量级（X 射线），这区域需要精细分辨率。

### Recipe 4.3：单群（gray，测试用）

```fortran
rt_mgdNumGroups = 1
rt_mgdBounds_1 = 1.e-3
rt_mgdBounds_2 = 1.e5     # 全光谱合并
```

### 4.4 IONMIX 表同步（关键）

**MGD 不自动同步** IONMIX 表群结构！

IONMIX 表（如 `polystyrene-imx-008.cn4`）有自己的群结构（典型 100 群）。MGD 的 `rt_mgdBounds_*` 必须**手动**对齐 IONMIX 表。

**怎么对齐**：
1. 用 `head -10 polystyrene-imx-008.cn4` 看 IONMIX 群边界
2. MGD 的 `rt_mgdBounds_*` 设为 IONMIX 群边界的子集
3. 不对齐 → 物理静默错误（不 abort，但结果错）

---

## 5. 与 Hydro/EOS 协作 recipe

### Recipe 5.1：标准 HEDP 3T + MGD

setup：
```bash
./setup LaserSlab -2d -auto +cylindrical +usm3t +laser +mgd \
    species=cham,targ mgd_meshgroups=6 \
    -nxb=16 -nyb=16 -objdir=cases/LaserSlab
```

parfile 关键段：
```fortran
# EOS（3T）
eosMode = "dens_ie_recal_gather"
gammaIon = 1.6667
gammaEle = 1.6667
gammaRad = 1.3333

# Heatexchange（电子-离子平衡）
useHeatexchange = .true.

# MGD
rt_useMGD = .true.
rt_mgdNumGroups = 6
rt_mgdBounds_1..7 = ...
rt_mgdFlMode = "fl_harmonic"
```

**协作机制**：
1. Hydro 更新 ENER_VAR
2. EOS 算 TELE/TEION
3. EnergyDeposition 沉积到 EELE
4. Heatexchange 平衡 TEION/TELE
5. **RadTrans 扩散辐射**（用 TELE 查 Opacity）
6. RadTrans 反馈到 EELE
7. EOS 重新算温度

### Recipe 5.2：MGD 不开（纯 Hydro 测试）

```bash
./setup Sedov -2d -auto +cartesian -nxb=8 -nyb=8 -objdir=cases/Sedov
# 不加 +mgd
```

parfile：**不写** `rt_useMGD` 或写 `rt_useMGD = .false.`

**为什么**：Sedov 等纯流体算例不需要辐射扩散。

---

## 6. 完整可抄配置（LaserSlab HEDP 最小可运行）

```bash
# setup
./setup LaserSlab -2d -auto +cylindrical \
    +laser +mgd +uhd3t \
    species=cham,targ mgd_meshgroups=6 \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab \
    -parfile=example.par
```

parfile MGD 段：
```fortran
# 主控
rt_useMGD             = .true.
rt_mgdNumGroups       = 6

# 群边界（eV）
rt_mgdBounds_1        = 1.e-1
rt_mgdBounds_2        = 1.e0
rt_mgdBounds_3        = 1.e1
rt_mgdBounds_4        = 1.e2
rt_mgdBounds_5        = 1.e3
rt_mgdBounds_6        = 1.e4
rt_mgdBounds_7        = 1.e5

# Flux limiter（HEDP 必须）
rt_mgdFlMode          = "fl_harmonic"
rt_mgdFlCoef          = 1.0

# 边界（LaserSlab 典型）
rt_mgdXlBoundaryType  = "reflecting"
rt_mgdXrBoundaryType  = "vacuum"
rt_mgdYlBoundaryType  = "vacuum"
rt_mgdYrBoundaryType  = "reflecting"
rt_mgdZlBoundaryType  = "reflecting"
rt_mgdZrBoundaryType  = "reflecting"

# 隐式（默认值，可省略）
rt_mgdthetaImplct     = 1.0

# 时间步
rt_dtFactor           = 0.02
```

**验证**：
```bash
grep "RadTrans\|MGD\|HYPRE" 01-data/<basenm>.log | head -20
```

应看到：
- `RadTrans_init` 完成消息
- 群边界加载（6 群）
- HYPRE 求解每群耗时

---

## 7. 通用检查清单

设 MGD 参数前确认：

- [ ] **setup 加了 +mgd**：`cat cases/<case>/setup_call | grep +mgd`
- [ ] **mgd_meshgroups 和 rt_mgdNumGroups 匹配**：`rt_mgdNumGroups ≤ mgd_meshgroups`
- [ ] **rt_mgdBounds_* 单位是 eV**（不是 erg）：检查数值范围
- [ ] **rt_mgdBounds_* 全部 ≥ 0**（负值启动 abort）
- [ ] **rt_mgdBounds_ 数量 = N+1**（N 群要 N+1 个边界）
- [ ] **IONMIX 表和 rt_mgdBounds 对齐**（用 head 看 .cn4 表的群结构）
- [ ] **rt_mgdFlMode 不是 fl_none**（生产算例必须限流）
- [ ] **边界 BC 合理**（LaserSlab 用 X 左 reflecting，X 右 vacuum）
- [ ] **3T 算例配 +uhd3t + Heatexchange**
- [ ] **mgd_meshgroups 是 setup 变量**（不是 runtime parameter）

---

## 8. 延伸阅读

- **MGD 总览**：`knowledge/overview.md`
- **完整参数列表**：`knowledge/params.md`
- **MGD 主流程**：`knowledge/internals.md §2`
- **常见错误**：`knowledge/pitfalls.md`
- **LaserSlab 参考 parfile**：`source/Simulation/SimulationMain/LaserSlab/flash.par`
- **EOS（3T）**：`flash-eos` skill
- **Heatexchange**：`flash-sourceterms`（Phase 2 后）

---

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft）：5 类 recipe（setup/limiter/边界/群结构/Hydro-EOS 协作）+ LaserSlab 完整可抄配置 + 10 项检查清单 | claude |
