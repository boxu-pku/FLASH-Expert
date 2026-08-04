---
title: sourceTerms 典型配置 — Heatexchange setup + 5 变体选择 + parfile
skill: flash-sourceterms
category: recipes
source_anchors:
  - source/Simulation/SimulationMain/LaserSlab/Config:L10
  - source/Simulation/SimulationMain/LaserSlab/flash.par:L178-L263
  - source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Config
manual_ref: "FLASH 4.8 User Guide §18"
created: 2026-07-20
last_verified: 2026-07-20
verifier: claude
status: draft
tags:
  - sourceterms
  - recipe
  - heatexchange
  - laser-slab
---

# sourceTerms 典型配置 recipes（Heatexchange 聚焦）

> **TL;DR**：按 L-013 聚焦主流量径——LaserSlab Heatexchange/Spitzer 配置（HEDP 标准）。5 类 recipe：Heatexchange setup + 5 变体选择 + hx_dtFactor 配置 + 调用顺序调整 + 其他 sourceTerms 启用。

---

## 0. 通用准备

### 0.1 setup 命令

LaserSlab HEDP 标准配置（自动 REQUESTS Heatexchange/Spitzer）：

```bash
./setup LaserSlab -2d -auto +cylindrical \
    +laser +mgd +uhd3t \
    species=cham,targ \
    mgd_meshgroups=6 \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab \
    -parfile=example.par
```

**LaserSlab Config 自动 REQUESTS**：

```
REQUESTS physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer
```

所以 `+uhd3t`（3T）setup 自动选 Spitzer。**不需要单独写 `+heatexchange`**。

### 0.2 parfile 关键段

```fortran
# Heatexchange 主控
useHeatexchange = .true.

# 时间步（LaserSlab 禁用 HX dt 限制）
hx_dtFactor = 1.0e+100

# 其他用默认值
# hx_ieTimeCoef = 1.0
# hx_relTol = -1.0
# hx_logLevel = 700
```

---

## 1. Heatexchange setup recipe

### Recipe 1.1：LaserSlab 自动（HEDP 默认）

**适用**：LaserSlab 等带 `+uhd3t` 的 HEDP 算例。

```bash
./setup LaserSlab -2d -auto +cylindrical \
    +laser +mgd +uhd3t \
    species=cham,targ mgd_meshgroups=6 \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab
```

**为什么自动**：`+uhd3t` 包含 3T EOS，3T 必须有 Heatexchange 平衡。LaserSlab Config 的 `REQUESTS ... HeatexchangeMain/Spitzer` 自动选 Spitzer 变体。

### Recipe 1.2：自定义 3T 算例 + 选 Heatexchange 变体

**适用**：自定义算例，想选非默认 Heatexchange 变体。

```bash
# 选 LeeMore（高 Z 物质）
./setup <problem> -2d -auto +cylindrical +3t +laser +mgd \
    --with-unit=physics/sourceTerms/Heatexchange/HeatexchangeMain/LeeMore \
    -objdir=cases/<problem>_LeeMore

# 或选 Constant（简单测试）
./setup <problem> -2d -auto +3t \
    --with-unit=physics/sourceTerms/Heatexchange/HeatexchangeMain/Constant \
    -objdir=cases/<problem>_constHX
```

### Recipe 1.3：3T 但不要 Heatexchange（不平衡）

**适用**：调试——想看 TELE/TEION 各自演化，不让它们平衡。

```bash
./setup <problem> -2d -auto +3t +laser +mgd \
    --without-unit=physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer \
    -objdir=cases/<problem>_noHX
```

parfile：
```fortran
useHeatexchange = .false.
```

**警告**：物理失真（TELE 会持续高于 TEION）。

---

## 2. Heatexchange 变体选择 recipe

### Recipe 2.1：Spitzer（HEDP 默认 + LaserSlab 用）

**适用**：标准 HEDP（DT、CH、Al 等低-中 Z 物质）。

```bash
./setup LaserSlab ... +uhd3t ...
```

parfile：
```fortran
useHeatexchange = .true.
hx_dtFactor = 1.0e+100
hx_ieTimeCoef = 1.0
```

**为什么 HEDP 推荐 Spitzer**：
1. 经典等离子体适用（T~100 eV，n~10²² cm⁻³，弱耦合）
2. PlasmaState 自动算 ln Λ
3. 解析 ODE 解严格能量守恒

### Recipe 2.2：LeeMore（高 Z 物质）

**适用**：Au hohlraum 壁、CH foam、W 靶、T < 100 eV 的稠密等离子体。

```bash
./setup <problem> ... +3t +laser +mgd \
    --with-unit=physics/sourceTerms/Heatexchange/HeatexchangeMain/LeeMore ...
```

**为什么用 LeeMore**：Spitzer 低估高 Z 物质电导率。Lee-More (1984) 用密度和简并修正的 ln Λ，对 warm dense matter 实验数据符合更好。

### Recipe 2.3：ConstCoulomb（简化 Spitzer）

**适用**：单物质算例 + 想固定 ln Λ（不等 PlasmaState 每步算）。

```bash
./setup <problem> ... +3t \
    --with-unit=physics/sourceTerms/Heatexchange/HeatexchangeMain/ConstCoulomb ...
```

parfile：
```fortran
hx_coulombLog = 5.0          # 固定 ln Λ 值
hx_singleSpeciesA = 27.0     # Al 的 A
hx_singleSpeciesZ = 13.0     # Al 的 Z
```

**用途**：性能优化（不算 ln Λ）+ 简化物理（固定耦合）。

### Recipe 2.4：Constant（自定义耦合系数）

**适用**：教学、调试、验证 Heatexchange 接口。

```bash
./setup <problem> ... +3t \
    --with-unit=physics/sourceTerms/Heatexchange/HeatexchangeMain/Constant ...
```

parfile：
```fortran
hx_couplingConst12 = 1.0e-15    # 离子-电子耦合系数（自定义值）
hx_couplingConst13 = 0.0        # 离子-辐射（关）
hx_couplingConst23 = 1.0e-15    # 电子-辐射
```

**用途**：测试代码逻辑，不追求物理准确。

### Recipe 2.5：Immediate（强制平衡）

**适用**：调试、初始化强制 T_ion = T_ele。

```bash
./setup <problem> ... +3t \
    --with-unit=physics/sourceTerms/Heatexchange/HeatexchangeMain/Immediate ...
```

parfile：
```fortran
hx_applyToRadiation = .false.   # 只平衡 TEION/TELE，不动 TRAD
```

**警告**：忽略 ps 时间尺度，物理失真。**生产算例不要用**。

---

## 3. hx_dtFactor 配置 recipe

### Recipe 3.1：LaserSlab 标准（禁用 HX dt 限制）

```fortran
hx_dtFactor = 1.0e+100
```

**为什么禁用**：hydro dt 已被 CFL + 激光物理严格限制；eqtime << dt_hydro，dt 限制多余。

### Recipe 3.2：标准（每步交换一半内能）

```fortran
hx_dtFactor = 0.5     # 默认
```

**适用**：保守算例，确保数值稳定。

### Recipe 3.3：保守（每步交换 10%）

```fortran
hx_dtFactor = 0.1
```

**适用**：cv 跳变剧烈（如相变）的算例，防止解析解震荡。

---

## 4. Driver_sourceTerms 调用顺序 recipe

### Recipe 4.1：默认顺序（激光第 10 位）

```bash
./setup LaserSlab ... +uhd3t ...
# 不加 +edearly
```

### Recipe 4.2：激光提前（DRIVER_EDEARLY 宏）

```bash
./setup LaserSlab ... +uhd3t +edearly ...
```

效果：EnergyDeposition 调到位置 0（最先）。

**何时用**：算例需要激光先沉积再算其他（如激光驱动的初始压力建立）。

### Recipe 4.3：自定义调用顺序（高级）

修改 `source/Driver/DriverMain/Driver_sourceTerms.F90` 直接重排 call 顺序——不推荐（升级 FLASH 时冲突）。

---

## 5. 其他 sourceTerms 启用 recipe

### Recipe 5.1：Burn（核燃烧，非 HEDP）

```bash
./setup <problem> ... +burn ...
```

parfile：
```fortran
useBurn = .true.
# burn_dtFactor = ...
```

**注意**：HEDP 算例不用（激光算例无核燃烧）。

### Recipe 5.2：Cool（辐射冷却，非 HEDP）

```bash
./setup <problem> ... +cool ...
```

parfile：
```fortran
useCool = .true.
# cfl_cool = ...
```

### Recipe 5.3：Stir（湍流驱动，非 HEDP）

```bash
./setup <problem> ... +stir ...
```

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

parfile Heatexchange 段：
```fortran
# 主控
useHeatexchange = .true.

# 时间步（LaserSlab 禁用 HX dt 限制）
hx_dtFactor = 1.0e+100

# 其他用默认值
# hx_ieTimeCoef = 1.0      # Spitzer/LeeMore 默认
# hx_relTol = -1.0         # 继承 eos_tolerance
# hx_logLevel = 700        # 默认
```

**验证**：
```bash
grep "Heatexchange\|hx_\|Spitzer" 01-data/<basenm>.log | head -20
```

应看到：
- `Heatexchange_init` 完成消息
- Spitzer 变体激活
- hx_dtFactor = 1e100（如设）

---

## 7. 通用检查清单

设 Heatexchange 参数前确认：

- [ ] **3T 算例（+uhd3t）**：Heatexchange REQUIRES multiTemp
- [ ] **useHeatexchange = .true.**：默认关，必须开
- [ ] **hx_dtFactor 合理**：LaserSlab 1e100（禁用）；保守 0.5；调试 0.1
- [ ] **变体正确**：Spitzer（HEDP 标准）/ LeeMore（高 Z）/ Constant（测试）
- [ ] **没有用不存在的 hxcouple**：FLASH 4.8 没有 hxcouple 参数（只有 hx_couplingConst12 等）
- [ ] **DRIVER_EDEARLY**：如要激光提前，setup 加 +edearly
- [ ] **hx_ieTimeCoef = 1.0**：默认（除非调试）
- [ ] **TELE/TEION 在合理范围**：plotfile 看是否物理合理

---

## 8. 延伸阅读

- **Heatexchange 总览**：`knowledge/overview.md`
- **完整参数列表**：`knowledge/params.md`
- **Heatexchange.F90 主流程**：`knowledge/internals.md §2`
- **常见错误**：`knowledge/pitfalls.md`
- **LaserSlab 参考 parfile**：`source/Simulation/SimulationMain/LaserSlab/flash.par:L178, L263`
- **EnergyDeposition（激光）**：`flash-laser` skill
- **EOS（3T）**：`flash-eos` skill
- **Driver 主循环**：`flash-driver` skill

---

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-20 | 初始创建（draft）：5 类 recipe（setup/变体/dt/调用顺序/其他 sourceTerms）+ LaserSlab 完整可抄配置 + 8 项检查清单 | claude |
