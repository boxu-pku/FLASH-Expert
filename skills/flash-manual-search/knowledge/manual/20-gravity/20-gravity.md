---
title: 引力单元（Gravity / Poisson 求解器）
skill: flash-hydro
category: overview
source_anchors:
  - source/physics/Gravity/GravityMain/Constant/Config:1-3
  - source/physics/Gravity/GravityMain/Poisson/Config:1-5
  - source/physics/Gravity/GravityMain/PointMass/Config:1-3
  - source/Grid/GridSolvers/BHTree/Wunsch/gr_bhBotNodeContrib.F90:1-5
  - source/Grid/GridSolvers/Multigrid/Grid_solvePoisson.F90:1-5
  - source/physics/Gravity/GravityMain/Poisson/Multipole/Gravity_init.F90:1-5
manual_ref: "FLASH 4.8 User Guide §20 (Gravity Unit) pp.341-348, PDF pp.359-369"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - gravity
  - poisson
  - multipole
  - bhtree
  - multigrid
  - pfft
---

# 引力单元（§20）

> **TL;DR**：Gravity 提供外场（Constant/PlanePar/PointMass/UserDefined）和自洽 Poisson 求解（Multipole/Multigrid/BHTree/Pfft）。Poisson 实现通过 Grid/GridSolvers 求解 $\nabla^2\phi = 4\pi G\rho$。

## 1. 外部引力场（§20.2）

| 实现 | 目录 | 参数 |
|---|---|---|
| Constant | `GravityMain/Constant` | `grav`（大小）+ `x,y,z` 方向 |
| PlanePar | `GravityMain/PlanePar` | 平面平行场 |
| PointMass | `GravityMain/PointMass` | `ptmass`（质量）+ `ptxpos/ptypos/ptzpos` |
| UserDefined | `GravityMain/UserDefined` | 自定义 $\phi(x)$ + $g(x)$ |

外部场不额外占用 `unk` 存储。

## 2. 自洽 Poisson 求解（§20.3）

### 2.1 求解器选址

| 求解器 | setup 快捷 | 特点 |
|---|---|---|
| Multipole（原版） | 默认 | 渐近展开 + P^M 求和 |
| Multipole（改进版） | `+newMP` | 2D 柱 / 3D Cartesian，OpenMP |
| BHTree | `+bhtree` | Barnes-Hut 树码 O(N log N) |
| Multigrid | `+multigrid` | V-cycle，含 Hybrid（Pfft + MG） |
| Pfft | `+pfft` | FFT Poisson 预处理 |

Poisson 求解器源码在 `Grid/GridSolvers/` 下，被 Gravity/Poisson 调用（详见 §8.10）。

### 2.2 边界条件

- **周期**：Pfft 原生支持
- **孤立**：Multipole + Multigrid（Robin BC $\partial\phi/\partial r + \phi/r = 0$）

## 3. 延伸阅读

- §20（本篇）Gravity 参考
- §8.10 GridSolvers：Poisson 求解器细节
- §15.1 PPM `ppm_modifystates`：引力 + Hydro 耦合

## 4. 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-19 | 创建 draft |
