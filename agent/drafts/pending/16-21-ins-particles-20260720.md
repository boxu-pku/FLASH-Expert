---
title: 不可压 Navier-Stokes（INS） / Particles 粒子单元
skill: flash-hydro
category: overview
source_anchors:
  - source/physics/IncompNS/Config:1-5
  - source/Particles/Config:1-5
manual_ref: "FLASH 4.8 User Guide §16 (INS) pp.247-248, §21 (Particles) pp.349-370"
created: 2026-07-20
last_verified: 2026-07-20
verifier: opencode-ai
status: draft
tags:
  - INS
  - incompressible
  - Navier-Stokes
  - particles
  - lagrangian
  - tracer
---

# INS / Particles（§16 + §21）

> **TL;DR**：两个非 HEDP 核心单元。**§16 INS**：不可压 NS 求解器（分数步法，IMEX，非 LaserSlab 所需）。**§21 Particles**：拉格朗日示踪/有源粒子框架（LaserSlab 用 `--without-unit=Particles` 排除）。

## §16 INS

- 目录：`source/physics/IncompNS/`
- 解法：分数步投影法（IMEX 隐式扩散 + 显式对流 + Poisson 压力投影）
- 适用：不可压流动（非 HEDP 激光等离子体，后者用可压 3T Hydro）

## §21 Particles

- 目录：`source/Particles/`
- 两类：passive（示踪） + active（有源 Lagrangian 颗粒）
- 粒子子单元：`ParticlesInitialization`（Lattice/WithDensity）、`ParticlesMapping`（Quadratic/CloudInCell）、`ParticlesAdvance`（RungeKutta/Euler）
- LaserSlab **不使用** Particles

## 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-20 | 创建 draft（2 锚点验证） |
