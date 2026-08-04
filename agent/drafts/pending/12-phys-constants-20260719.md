---
title: Physical Constants 物理常量单元
skill: flash-eos
category: overview
source_anchors:
  - source/PhysicalConstants/Config:1-3
  - source/PhysicalConstants/PhysicalConstants_init.F90:1-5
  - source/PhysicalConstants/PhysicalConstants_get.F90:1-5
manual_ref: "FLASH 4.8 User Guide §12 (Physical Constants Unit) pp.201-203, PDF pp.223-226"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - physical-constants
  - units
  - cgs
---

# Physical Constants 物理常量（§12）

> **TL;DR**：集中管理所有物理常量（Avogadro、Boltzmann、光速、Planck、Stefan-Boltzmann、电子质量/电荷等），单位为 CGS。通过 `PhysicalConstants_get` 统一查询，避免各单元散落硬编码常量。

## 1. 设计目的

FLASH 各物理单元需要多种物理常量。PhysicalConstants 提供：
- 单一数据源（避免不一致）
- CGS 单位制（与 FLASH 整体一致）
- setup 期根据 Config 决定启用哪些常量

## 2. API

| 函数 | 用途 |
|---|---|
| `PhysicalConstants_init` | 加载默认常量值 |
| `PhysicalConstants_get` | 查询指定常量（如 `"Avogadro"`, `"Boltzmann"`） |

```fortran
use PhysicalConstants_interface, ONLY: PhysicalConstants_get
real :: Na, kb
call PhysicalConstants_get("Avogadro", Na)
call PhysicalConstants_get("Boltzmann", kb)
```

## 3. 延伸阅读

- §12（本篇）物理常量参考
- §23 Material Properties：常量在物质属性中的应用
- 各单元 init 例程中通过 `PhysicalConstants_get` 获取常量值

## 4. 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-19 | 创建 draft（3 锚点全部验证） |
