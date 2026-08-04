---
title: Runtime Parameters 运行时参数单元
skill: flash-setup-system
category: overview
source_anchors:
  - source/RuntimeParameters/Config:1-5
  - source/RuntimeParameters/RuntimeParameters_init.F90:1-5
  - source/RuntimeParameters/RuntimeParameters_get.F90:1-5
  - source/RuntimeParameters/RuntimeParameters_interface.F90:1-5
manual_ref: "FLASH 4.8 User Guide §10 (Runtime Parameters Unit) pp.193-196, PDF pp.211-214"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - runtime-parameters
  - flash.par
  - namelist
  - Config
---

# Runtime Parameters 运行时参数（§10）

> **TL;DR**：Config 中声明的 `PARAMETER` 关键字在 setup 期生成 Fortran 代码，运行时从 `flash.par` 自动读取为 namelist 变量存入 `RuntimeParameters_data` 模块。API 含 `RuntimeParameters_get`（读取标量）和 `RuntimeParameters_getVec`（读取向量）。

## 1. 参数声明（Config → 代码生成）

Config 文件声明：

```fortran
PARAMETER gamma REAL 1.4 [0.0 to ]
PARAMETER maxBlocks INTEGER CONSTANT 500
```

setup 通过 `bin/rpUtils.py` 生成：
- `Simulation_rpInit.F90`（namelist read 代码）
- `setup_params`（参数文档列表）
- `RuntimeParameters_data.F90`（存储变量）

`CONSTANT` 参数编译时固定为预处理器符号（Flash.h 中的 `#define`），运行时不可改。

## 2. API

| 函数 | 用途 |
|---|---|
| `RuntimeParameters_init` | 读取 flash.par + 注册默认值 |
| `RuntimeParameters_get` | 获取标量参数值 |
| `RuntimeParameters_getVec` | 获取向量参数值 |
| `RuntimeParameters_mapStrToInt` | 字符串→整数映射（如边界类型） |
| `RuntimeParameters_set` | 运行时覆盖参数值（慎用） |

典型调用（`Simulation_init.F90` 中）：

```fortran
call RuntimeParameters_get("gamma", gamma)
call RuntimeParameters_get("lrefine_max", lrefine_max)
```

## 3. 参数作用域

- 所有单元可访问任意已注册参数（不限声明所属 Config）
- Simulation Config 声明的参数可覆盖同名默认值
- 参数名大小写不敏感（默认转为小写）

## 4. 延伸阅读

- §10（本篇）Runtime Parameters 参考
- §5 Config 文件语法：`PARAMETER` 完整语法
- §6 Flash.h：常量参数如何 -> `#define`
- `bin/rpUtils.py`：setup 期参数代码生成
- `setup_params` 文件：当前算例全部参数列表

## 5. 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-19 | 创建 draft（4 锚点全部验证） |
