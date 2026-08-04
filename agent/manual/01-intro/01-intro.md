---
title: 引言（What's New / Known Issues）
skill: flash-setup-system
category: overview
source_anchors:
  - source/Simulation/Flash.F90:1-5
  - bin/genFiles.py:1-5
manual_ref: "FLASH 4.8 User Guide §1 (Introduction) pp.1-16, PDF pp.19-34"
created: 2026-07-20
last_verified: 2026-07-20
verifier: opencode-ai
status: draft
tags:
  - introduction
  - known-issues
---

# 引言（§1）

> **TL;DR**：§1 是非技术性简介——FLASH 4.8 的新特性、已知问题列表、外部贡献、用户指南使用说明。主要读者是首次接触 FLASH 的用户。

## 1. What's New in FLASH4

- Block-AMR 3 个后端（PM4dev/UG/Chombo）
- 多温 3T HEDP 能力（见 §14）
- MGD 辐射扩散 + Laser ray-tracing（见 §18.4 + §25）
- Multipole/Multigrid/BHTree Poisson（见 §20）
- 单元测试框架 sfocu（见 §37）

## 2. Known Issues（§1.3）

详见 `RELEASE-NOTES` 文件。关键条目：

- `-noclobber` 与 `+hdf5typeIO` 不兼容
- `enucDtFactor` 默认极大（燃烧时间步限制未充分测试）
- PM4dev `gr_pmrpForceConsistency` 影响 restart 精度
- Absoft 编译器优化可能生成错误码

## 3. 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-20 | 创建 draft |
