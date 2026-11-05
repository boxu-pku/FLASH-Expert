---
title: 质子成像 / 质子发射 / Thomson 散射 / X 射线成像（§28-31）
skill: flash-setup-system
category: overview
source_anchors:
  - source/diagnostics/ProtonImaging/Config:1-5
  - source/diagnostics/ProtonEmission/Config:1-5
  - source/diagnostics/ThomsonScattering/Config:1-5
  - source/diagnostics/XrayImaging/Config:1-5
manual_ref: "FLASH 4.8 User Guide §28-31 (Diagnostics) pp.411-457"
created: 2026-07-20
last_verified: 2026-07-20
verifier: opencode-ai
status: draft
tags:
  - proton
  - thomson
  - x-ray
  - imaging
  - diagnostics
---

# 诊断单元（§28-31）

> **TL;DR**：4 个合成诊断单元：**ProtonImaging**（质子偏转成像）、**ProtonEmission**（质子源发射）、**ThomsonScattering**（Thomson 散射谱计算）、**XrayImaging**（X 射线成像）。不修改变量，仅从 plotfile 数据计算诊断信号。

| 章 | 单元 | 用途 |
|---|---|---|
| §28 | ProtonImaging | 质子束穿过等离子体后的偏转图案 |
| §29 | ProtonEmission | D-D/D-T 聚变质子源模型 |
| §30 | ThomsonScattering | 电子密度涨落散射谱（诊断 $n_e$, $T_e$） |
| §31 | XrayImaging | X 射线透射/自发光成像 |

**注意**：这些是合成诊断（后处理），不在 Driver 主循环中运行。需要专门的诊断配置文件。

## 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-20 | 创建 draft |
