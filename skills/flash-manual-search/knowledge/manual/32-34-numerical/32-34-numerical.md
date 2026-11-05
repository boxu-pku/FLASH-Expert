---
title: 数值工具（Interpolate / Roots / RungeKutta）
skill: flash-setup-system
category: overview
source_anchors:
  - source/numericalTools/Interpolate/Config:1-5
  - source/numericalTools/Roots/Config:1-5
  - source/numericalTools/RungeKutta/Config:1-5
manual_ref: "FLASH 4.8 User Guide §32-34 (Interpolate/Roots/RungeKutta) pp.457-467"
created: 2026-07-20
last_verified: 2026-07-20
verifier: opencode-ai
status: draft
tags:
  - interpolation
  - roots
  - runge-kutta
  - numerical
---

# 数值工具（§32-34）

> **TL;DR**：共享数值工具库——**Interpolate**（1D/2D/3D 线性 + 多项式插值）、**Roots**（二次/三次/四次多项式求根）、**RungeKutta**（自适应步长 Cash-Karp RK45 + Euler）。各物理单元按需调用，不由 Driver 统一调度。

## §32 Interpolate

- 1/2/3D 线性 + Lagrange 多项式
- 用于 EOS/Opacity 表格查找、Ray-tracing 等

## §33 Roots

- 二次、三次、四次多项式解析求根
- 用于 EOS Newton-Raphson 迭代的初始猜测

## §34 RungeKutta

- Cash-Karp RK45（自适应步长）
- Euler/Heun/Bogacki-Shampine 等定步长方法
- 被 Burn（反应网络）、Particles（迹线积分）、Laser（Ray 追踪）调用

## 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-20 | 创建 draft（3 锚点验证） |
