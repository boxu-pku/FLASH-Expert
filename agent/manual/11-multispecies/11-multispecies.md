---
title: 多物种单元（Multispecies）
skill: flash-multispecies
category: overview
source_anchors:
  - source/Multispecies/Config:1-5
  - source/Multispecies/Multispecies_init.F90:1-5
  - source/Multispecies/Multispecies_setProperty.F90:1-5
  - source/Multispecies/MultispeciesMain/Config:1-5
manual_ref: "FLASH 4.8 User Guide §11 (Multispecies Unit) pp.197-200, PDF pp.215-222"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - multispecies
  - species
  - abundance
  - mass-fraction
  - sumy
  - ye
---

# 多物种单元（§11）

> **TL;DR**：Multispecies 管理 FLASH 中的多流体物种（属性 + 查询 + 求和）。两种定义方式：传统 `SPECIES AIR` + `SPECIES SF6` Config 关键字，或 `species=cham,targ` setup 变量（推荐，LaserSlab 实际使用）。索引映射到 Flash.h（`HE4_SPEC`、`NI56_SPEC` 等）。API 含 `Multispecies_setProperty`、`Multispecies_getSum`、`Multispecies_getAvg` 等。

## 1. 两种定义方式

| 方式 | 语法 | Flash.h 索引 | 推荐场景 |
|---|---|---|---|
| Config SPECIES | `SPECIES AIR`（Simulation Config） | 编译时固定 | 少量固定物种 |
| **setup 变量** | `species=cham,targ`（setup 命令行） | `MultispeciesMain/Config` 动态生成 | HEDP / LaserSlab（推荐） |

**源码**：`source/Multispecies/MultispeciesMain/Config` 根据 `species=` setup 变量自动生成 `SPECIES` 指令。

## 2. 物种属性

每个物种的属性在 `Simulation_initSpecies.F90` 中使用 `Multispecies_setProperty` 初始化：

```fortran
call Multispecies_setProperty(HE4_SPEC, A, 4.0)
call Multispecies_setProperty(HE4_SPEC, Z, 2.0)
call Multispecies_setProperty(HE4_SPEC, GAMMA, 1.66666666667e0)
```

支持属性：`A`（原子质量数）、`Z`（原子序数）、`GAMMA`（绝热指数）、`E`（结合能）、`N`（中子数）等。

## 3. API 速查

| 函数 | 用途 |
|---|---|
| `Multispecies_setProperty` | 设置物种属性 |
| `Multispecies_getProperty` | 查询物种属性（标量） |
| `Multispecies_getPropertyVector` | 查询物种属性（向量） |
| `Multispecies_getSum` | 计算 ΣY_i · prop（按属性加权和） |
| `Multispecies_getAvg` | 计算平均属性（按质量分数加权） |
| `Multispecies_getSumInv` | 计算 Σ(Y_i / prop)（倒数加权和） |
| `Multispecies_getSumFrac` | 按分数加权和 |

## 4. 与 Flash.h 的索引映射

```
NPROP_VARS → SPECIES_BEGIN ~ SPECIES_END → MASS_SCALARS_BEGIN ~ MASS_SCALARS_END
```

`NSPECIES` = 物种总数。代码中使用 `HE4_SPEC`、`SF6_SPEC` 等整数索引访问 `unk` 中的物种质量分数。

## 5. 延伸阅读

- §11（本篇）Multispecies 参考
- §6 Flash.h：物种索引排列规则
- §15 Hydro：物种质量分数平流 + 归一化
- §17 EOS：物种重量对状态方程的贡献
- §23.5 Opacity Multispecies：per-species 不透明度

## 6. 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-19 | 创建 draft（4 锚点，全部 `[ -e ]` 验证通过） |
