---
title: 监控单元（Cosmology / Logfile / Timers & Profilers）
skill: flash-driver
category: overview
source_anchors:
  - source/physics/Cosmology/Config:1-5
  - source/monitors/Logfile/Config:1-5
  - source/monitors/Timers/Config:1-5
manual_ref: "FLASH 4.8 User Guide §22 (Cosmology) pp.371-374, §26 (Logfile) pp.399-403, §27 (Timers) pp.405-408"
created: 2026-07-20
last_verified: 2026-07-20
verifier: opencode-ai
status: draft
tags:
  - cosmology
  - logfile
  - timers
  - profiling
---

# 监控与宇宙学（§22 + §26 + §27）

> **TL;DR**：§22 Cosmology（红移/膨胀因子坐标变换 + 共动单位）、§26 Logfile（标准输出日志）、§27 Timers & Profilers（函数级计时/性能分析）。HEDP 模拟不依赖 Cosmology。

## §22 Cosmology

- Einstein-de Sitter / ΛCDM 背景宇宙学
- 共动坐标：物理坐标 = $a(t)$ × 共动坐标
- 红移 z 作为独立变量（替代 t）
- 非 HEDP 所需（LaserSlab 用普通坐标）

## §26 Logfile

- `Logfile_stampMessage` 写带时间戳的消息到 `<basenm>.log`
- 每时间步记录：步数/时间/∆t/Etot/质量等积分量
- 运行结束打印性能摘要

## §27 Timers & Profilers

- `Timers_start/stop` 包围关键代码段
- 可计 MPI 通信、计算、IO 各占比
- Profiler 按函数/区域汇总时间

## 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-20 | 创建 draft（3 锚点验证） |
