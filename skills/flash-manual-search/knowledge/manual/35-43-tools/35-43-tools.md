---
title: 测试问题与可视化/分析工具（§35-43）
skill: flash-setup-system
category: overview
source_anchors:
  - source/Simulation/Flash.F90:1-5
  - tools/fidlr3.0/README:1-5
manual_ref: "FLASH 4.8 User Guide §35-43 (Test Problems + Tools) pp.479-600"
created: 2026-07-20
last_verified: 2026-07-20
verifier: opencode-ai
status: draft
tags:
  - test-problems
  - visit
  - sfocu
  - fidlr
  - drift
---

# 测试问题与工具（§35-43）

> **TL;DR**：§35（~70 页）列出所有分发的测试问题，按物理领域分组。§36-43（~50 页）覆盖可视化/分析工具和 FLASH 辅助功能。

## §35 测试问题（关键算例）

| 算例 | 目录 | 测试内容 |
|---|---|---|
| Sedov | `SimulationMain/Sedov/` | 球形爆炸波（纯 Hydro） |
| Sod | `SimulationMain/Sod/` | 冲击管（1D 间断） |
| **LaserSlab** | `SimulationMain/LaserSlab/` | **全物理 HEDP（3T+MGD+Laser）** |
| MGDInfinite | `SimulationMain/RadTrans/` | 0D 辐射耦合 |
| MGDStep | `SimulationMain/RadTrans/` | 1D 辐射+热传导 |
| ShafranovShock | `SimulationMain/RadTrans/` | 3T 冲击波 |
| ReinickeMeyer | `SimulationMain/RadTrans/` | 球面波+热传导 |
| NeiTest | `SimulationMain/NeiTest/` | 非平衡电离 |

**源码**：每算例有完整 `Config + flash.par + Simulation_init*.F90`。

## §36-43 工具

| 章 | 工具 | 用途 |
|---|---|---|
| §36 | VisIt | 并行可视化（推荐替代 IDL） |
| §37 | sfocu | F90 单元测试框架 |
| §38 | Drift | PM4dev block 列表漂移修复 |
| §39 | fidlr3.0 | IDL 交互式可视化（传统工具） |
| §43 | OpenMP Hybrid | 混合 MPI+OpenMP 多线程 |

## 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-20 | 创建 draft |
