---
title: sourceTerms 常见踩坑 — TELE 不变 / EELE 异常 / hxcouple 不存在 / DRIVER_EDEARLY
skill: flash-sourceterms
category: pitfalls
source_anchors:
  - source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange.F90:L124-L307
  - source/Driver/DriverMain/Driver_sourceTerms.F90:L55-L73
  - source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Config:L17
manual_ref: "FLASH 4.8 User Guide §18"
created: 2026-07-20
last_verified: 2026-07-20
verifier: claude
status: draft
tags:
  - sourceterms
  - pitfall
  - heatexchange
---

# sourceTerms 常见踩坑

> **TL;DR**：分 4 大类共 12+ 踩坑：**A 启动期**（变体错、3T 没启用）+ **B 运行期数值**（TELE 不变、EELE 异常、能量不守恒）+ **C 概念错误**（hxcouple 不存在、Immediate 误用）+ **D 其他 sourceTerms**。按 L-012 诊断类先引导贴现场。

---

## 0. 诊断引导（按 L-012）

遇到 Heatexchange 异常先贴：

```bash
# 1. abort 信息
grep -B 2 -A 5 "Heatexchange\|HX\|abort\|fallback" 01-data/<basenm>.log | head -40

# 2. Heatexchange_init 打印的参数
grep "Heatexchange_init\|useHeatexchange\|hx_dtFactor\|hx_ieTimeCoef" 01-data/<basenm>.log | head -15

# 3. setup 命令（验证变体）
cat cases/<case>/setup_call | grep -E "Heatexchange|\\+uhd3t|\\+3t"

# 4. parfile Heatexchange 段
grep "useHeatexchange\|hx_" cases/<case>/flash.par

# 5. TELE/TEION 范围（看是否物理合理）
grep "max TELE\|min TELE\|max TION\|min TION" 01-data/<basenm>.log | tail -10
```

**贴完后能给出针对性诊断。** 下面是常见原因作为参考。

---

## A. 启动期踩坑

### A.1 `Heatexchange requested but multiTemp EOS not selected` abort

源码：`HeatexchangeMain/Config:L17`

```
REQUIRES physics/Eos/EosMain/multiTemp
```

**症状**：setup 加了 Heatexchange 但启动 abort。

**原因**：Heatexchange 必须配 3T EOS（multiTemp）。单温度（1T）下 T_ion = T_ele 永远成立，Heatexchange 没意义。

**修复**：setup 加 `+3t` 或 `+uhd3t`：

```bash
./setup <problem> ... +3t +heatexchange ...
# 或
./setup LaserSlab ... +uhd3t ...   # +uhd3t 自动包含 +3t
```

### A.2 `useHeatexchange` 默认 FALSE（顶层）

**症状**：跑出来 TELE/TEION 没变化（Heatexchange 没调）。

**原因**：Heatexchange 顶层 Config 默认 `useHeatexchange = FALSE`。

**修复**：parfile 显式开：

```fortran
useHeatexchange = .true.
```

### A.3 选错变体（Config 默认 Constant，不是 Spitzer）

**症状**：用了 Constant 变体，物理参数 `hx_couplingConst12` 默认值不准，结果不对。

**原因**：HeatexchangeMain/Config 默认 `DEFAULT Constant`。但 LaserSlab Config 显式 `REQUESTS ... Spitzer`，所以 LaserSlab 自动选 Spitzer。**自定义算例可能默认 Constant**。

**修复**：自定义算例显式选变体：

```bash
./setup <problem> ... \
    --with-unit=physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer ...
```

---

## B. 运行期数值踩坑

### B.1 TELE/TEION 始终不变（Heatexchange 没工作）

**症状**：跑很多步后 TELE 和 TEION 仍差距大，没趋同。

**可能原因**：
1. **`useHeatexchange = .false.`**（默认关）
2. **没 3T EOS**（Heatexchange 调用前 return）
3. **`hx_ieTimeCoef = 0`**（人为禁用）
4. **TELE 和 TEION 已相等**（dt 内平衡已完成，看起来"没变"）

**诊断**：
```bash
grep "useHeatexchange" 01-data/<basenm>.log
grep "Heatexchange" 01-data/<basenm>.log | head -5   # 看是否调用
```

**修复**：确认 parfile `useHeatexchange = .true.` + 算例是 3T（+3t）。

### B.2 EELE 出现异常值（负值或极大）

**症状**：plotfile 显示某些 cell `EELE_VAR < 0` 或 `EELE_VAR >> 物理`。

**可能原因**：
1. **EOS cv 跳变**：相变或电离突变时 cv 大幅变化，解析 ODE 解给负能量
2. **hx_dtFactor 太大**：单步交换过多能量

**修复**：
- 检查 EOS 表（是否有 cv 异常区域）
- 临时降 `hx_dtFactor`（如 0.5 或 0.1）

### B.3 能量不守恒（EION + EELE 总和变化）

**症状**：算例诊断显示 `EION + EELE` 在 Heatexchange 调用后变化。

**原因**：Heatexchange 解析 ODE 解保证严格守恒，能量不守恒来自其他原因：
1. **EOS 同时被调**（MODE_DENS_EI_GATHER 后 cv 改变）
2. **其他 sourceTerm 改了能量**（如 EnergyDeposition 在 Heatexchange 后调）
3. **数值精度**（浮点误差，但量级应该极小 ~10⁻¹⁵）

**诊断**：在 Heatexchange 调用前后分别打印 EION + EELE。

### B.4 负能量回退频繁触发

**症状**：日志反复警告 "negative energy fallback"。

**原因**：EOS cv 跳变剧烈。

**修复**：
- 检查 EOS 表（Helmholtz / ionmix）
- 降 `hx_dtFactor`（每步少交换）
- 临时换 Immediate 变体（强制平衡）

---

## C. 概念错误踩坑

### C.1 用 `hxcouple` 参数（不存在）

**症状**：parfile 写 `hxcouple = ...` 不生效。

**原因**：**FLASH 4.8 没有 `hxcouple` 参数**（源码零命中）。

**修复**：用正确的参数名：
- Constant 变体：`hx_couplingConst12` / `hx_couplingConst13` / `hx_couplingConst23`
- ConstCoulomb 变体：`hx_coulombLog`
- Spitzer/LeeMore：用 `hx_ieTimeCoef`（eqtime 倍数）

### C.2 Immediate 当生产变体用

**症状**：用户读论文觉得 Immediate 简单（一步平衡），生产用。

**原因**：Immediate 调 `Eos_wrapped(MODE_DENS_EI_MAT_EQUI)` 强制 T_ion = T_ele，**忽略 ps 时间尺度**。物理失真（HEDP 中电子和离子在 ps 时间尺度上不平衡）。

**修复**：生产用 Spitzer（或 LeeMore 高 Z）。Immediate 仅调试或初始化用。

### C.3 以为 Heatexchange 处理辐射平衡

**症状**：用户期望 Heatexchange 让 TRAD 和 TELE 趋同。

**原因**：Heatexchange/Spitzer **不耦合辐射**（TRAD_VAR）。辐射-电子平衡由 RadTrans/MGD 处理。

**修复**：辐射平衡看 `flash-radtrans` skill。Heatexchange 只做离子-电子。

**例外**：Constant 变体含 `hx_couplingConst13` / `hx_couplingConst23`（离子-辐射、电子-辐射），但 LaserSlab 不用 Constant。

### C.4 以为 DRIVER_EDEARLY 改变物理结果

**症状**：用户加 `+edearly` 后结果变，以为是 bug。

**原因**：DRIVER_EDEARLY 让激光从默认第 10 位调到第 0 位（最先）。**算例结果会变**（operator-split 顺序敏感），这是预期行为。

**修复**：理解 operator-split 的顺序依赖。LaserSlab 默认不用 +edearly（激光最后），改了就要重新验证物理。

### C.5 以为 hx_dtFactor=1e100 是 bug

**症状**：用户看 LaserSlab flash.par 写 `hx_dtFactor = 1.0e+100`，以为是笔误。

**原因**：**故意禁用 HX dt 限制**。LaserSlab 的 hydro dt 已被 CFL + 激光物理严格限制，eqtime << dt_hydro，dt 限制多余。

**修复**：理解 HEDP 时间尺度（eqtime ~ ps，dt_hydro ~ 100 fs，eqtime/dt > 10 → 一步内基本完全平衡，不需要 dt 限制）。

### C.6 以为 Spitzer 适合所有物质

**症状**：高 Z 物质（Au、W）算例用 Spitzer 结果不准。

**原因**：Spitzer 假设弱耦合（Γ << 1）+ 全电离。高 Z 物质在 T < 100 eV 时不满足。

**修复**：高 Z 用 LeeMore（密度 + 简并修正）。

---

## D. 其他 sourceTerms 踩坑（简要，非 HEDP）

### D.1 Burn 启动报"nuclear network not found"

**原因**：Burn 需要核反应网络（如 Aprox13、Aprox19、Iso7）。setup 加 `+burn` 但没指定网络。

**修复**：setup 加网络选项：

```bash
./setup <problem> ... +burn+Aprox13 ...
```

### D.2 Cool 表加载失败

**原因**：Cool 用 `Λ(T)` 表（如 Dalgarno-McCray），表文件没找到。

**修复**：在算例 Config 加 `DATAFILES myCoolTable.txt`。

### D.3 Stir 看不到湍流

**原因**：Stir 需要足够长的时间让 OU 过程驱动湍流。

**修复**：延长算例时间 + 检查 stir 参数（驱动尺度、振幅）。

---

## E. 通用调试流程

按 L-012：

### E.1 看 abort 信息

```bash
grep "Heatexchange\|HX\|abort" 01-data/<basenm>.log | head -10
```

### E.2 看 Heatexchange_init 参数

```bash
grep "Heatexchange_init\|useHeatexchange\|hx_" 01-data/<basenm>.log | head -15
```

### E.3 看 TELE/TEION 历史

```bash
grep "TELE\|TEION\|TION\|max.*min" 01-data/<basenm>.log | tail -20
```

### E.4 看 fallback 触发

```bash
grep "fallback\|negative\|warning" 01-data/<basenm>.log | head -10
```

### E.5 跨 skill 协作

| 症状 | 协作链 |
|---|---|
| HX abort + 激光算例 | `flash-pitfall-finder`（定位）→ `flash-sourceterms`（修 HX）→ `flash-laser`（验证激光） |
| TELE/TEION 不平衡 | `flash-sourceterms`（HX 参数）→ `flash-eos`（3T EOS 配置） |
| EnergyDeposition 顺序问题 | `flash-sourceterms`（DRIVER_EDEARLY）→ `flash-laser`（激光） |
| 不知道 abort 来源 | `flash-pitfall-finder`（匹配）→ 对应物理 skill |

---

## F. 延伸阅读

- **sourceTerms 总览**：`knowledge/overview.md`
- **完整参数列表**：`knowledge/params.md`
- **Heatexchange.F90 主流程**：`knowledge/internals.md §2`
- **典型配置**：`knowledge/recipes.md`
- **EnergyDeposition（激光）**：`flash-laser` skill
- **EOS（3T）**：`flash-eos` skill
- **跨单元踩坑**：`skills/flash-pitfall-finder/knowledge/pitfalls/`
- **手册**：FLASH 4.8 User Guide §18

---

## G. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-20 | 初始创建（draft）：4 大类 12+ 踩坑（A 启动 3 + B 数值 4 + C 概念 6 + D 其他 sourceTerms 3）+ 诊断引导层（按 L-012）+ 通用调试流程 + 跨 skill 协作 | claude |
