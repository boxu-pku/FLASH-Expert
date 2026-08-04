---
title: Physics Utilities（PlasmaState 等离子体辅助计算）
skill: flash-eos
category: overview
source_anchors:
  - source/physics/utilities/PlasmaState/Config:1-5
  - source/physics/utilities/PlasmaState/PlasmaState_ieEquilTime.F90:1-5
  - source/physics/utilities/PlasmaState/PlasmaStateMain/Config:1-5
manual_ref: "FLASH 4.8 User Guide §24 (Physics Utilities) pp.387, PDF pp.405-406"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - plasma-state
  - coulomb-logarithm
  - collision-time
  - equilibration
---

# Physics Utilities / PlasmaState（§24）

> **TL;DR**：PlasmaState（FLASH 4.4 引入）集中提供库仑对数 $\ln\Lambda$、碰撞时间 $\tau$、离子-电子平衡时间 $\tau_{ei}$ 的计算。被 Conductivity/Heatexchange/Hydro 等多个单元调用。

## 1. 提供函数

| 函数 | 用途 |
|---|---|
| `PlasmaState_logLambda` | 库仑对数（ee / ei / ii 可选） |
| `PlasmaState_tau` | 碰撞时间（同可选对） |
| `PlasmaState_ieEquilTime` | 电子-离子平衡时间 $\tau_{ei}$ |
| `PlasmaState_getComposition` | 单元内多种材料元素组成 |

**源码**：`source/physics/utilities/PlasmaState/PlasmaState_ieEquilTime.F90:1-5`。

## 2. 平衡时间公式（§24.1）

$$\tau = \frac{3\sqrt{m_{\text{ele}}}(k_B T_{\text{ele}})^{3/2}}{4\sqrt{2\pi}e^4 \bar{z}^2 n_{\text{ion}} \ln\Lambda_{ei}}$$

其中 $\bar{z}$ 不低于 1.0（floor）。详见 §18.5 Heatexchange。

## 3. 延伸阅读

- §24（本篇）Physics Utilities
- §18.5 Heatexchange：离子-电子热平衡
- §23.1 Thermal Conductivity：Spitzer/LeeMore 使用 PlasmaState

## 4. 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-19 | 创建 draft（3 锚点全部验证） |
