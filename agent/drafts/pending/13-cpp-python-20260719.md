---
title: Cpp & Python 接口单元
skill: flash-setup-system
category: overview
source_anchors:
  - source/Cpp/Config:1-3
  - bin/parseCmd.py:1-10
manual_ref: "FLASH 4.8 User Guide §13 (Cpp & Python units) pp.209-211, PDF pp.227-231"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - cpp
  - python
  - pybind11
  - flashPar
---

# Cpp & Python 单元（§13）

> **TL;DR**：Cpp 提供 FLASH ↔ C++ ↔ Python 的绑定（pybind11），可用 `flashPar.py` 替代 `flash.par`，setup 参数从 Python 脚本读取。实验性功能，主要用于高级集成。

## 1. 功能

| 能力 | 说明 |
|---|---|
| `flashPar.py` 替代 flash.par | Python 脚本控制运行时参数 |
| setup 参数从列表读取 | `--pyparfile=<name>` 选项 |
| Simulation 定制 | Python 替换 Fortran 源文件 |

常规 HEDP/LaserSlab 不需要此单元（标准 flash.par 即足够）。

## 2. 延伸阅读

- §13（本篇）Cpp & Python 参考
- §5 setup 参数：`--pyparfile` 选项
- `bin/parseCmd.py`：setup 命令行解析

## 3. 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-19 | 创建 draft（2 锚点全部验证） |
