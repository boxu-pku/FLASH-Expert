---
title: Driver 驱动单元（主循环 Driver_evolveFlash）
skill: flash-driver
category: overview
source_anchors:
  - source/Driver/Config:1-5
  - source/Driver/DriverMain/Config:1-5
  - source/Simulation/Flash.F90:1-10
  - source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90:1-10
  - source/Driver/Driver_initFlash.F90:1-5
manual_ref: "FLASH 4.8 User Guide §7 (Driver Unit) pp.99-105, PDF pp.117-124"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - driver
  - evolveFlash
  - initFlash
  - main-loop
  - sourceTerms
  - operator-split
---

# Driver 驱动单元（§7）

> **TL;DR**：Driver 是 FLASH 的顶层调度器。两个变体：Split（算子分裂，适配分裂 PPM）和 Unsplit（通用，LaserSlab 使用）。核心调用链：`Driver_initParallel` → `Driver_initFlash` → `Driver_evolveFlash` → `Driver_finalizeFlash`。进化循环中依次调度 Hydro → sourceTerms（Burn/Heat/Ionize/Stir/Heatexchange/EnergyDeposition）→ Diffuse → RadTrans → Grid → IO。

## 1. 程序入口

`main` 由 `Simulation/Flash.F90` 提供（等价于 C `main()`）：

```fortran
program Flash
  call Driver_initParallel()
  call Driver_initFlash()
  call Driver_evolveFlash()
  call Driver_finalizeFlash()
end program Flash
```

**源码**：`source/Simulation/Flash.F90:1-10`。

## 2. 两个变体

| 变体 | 目录 | 适配 |
|---|---|---|
| **Unsplit** | `DriverMain/Unsplit/` | 通用（Unsplit Hydro、MHD、INS），LaserSlab 使用 |
| Split | `DriverMain/Split/` | 仅适配分裂 PPM Hydro |

**源码**：`source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90:1-10` 为 Unsplit 主循环入口。

## 3. 单时间步调用序列（Unsplit）

```
1. Hydro 推进            ← Hydro_computeDt + Hydro_evolve
2. sourceTerms            ← Driver_sourceTerms
   ├── Burn
   ├── Heat/Cool
   ├── Ionize
   ├── Stir
   └── Heatexchange
3. EnergyDeposition       ← 激光光线追踪沉积
4. Diffuse                ← 隐式电子热传导（HYPRE）
5. RadTrans               ← MGD 辐射扩散（HYPRE）
6. Grid_updateRefinement  ← AMR 细化/粗化 + 负载均衡
7. Grid_fillGuardCells    ← Guard cell 填充
8. IO_output              ← checkpoint/plotfile
9. Driver_computeDt       ← CFL + 各单元时间步限制
```

## 4. 关键 API

| 函数 | 作用 |
|---|---|
| `Driver_initParallel` | 初始化 MPI + OpenMP |
| `Driver_initFlash` | 初始化所有单元（Grid/Eos/Hydro/IO/...） |
| `Driver_evolveFlash` | 主时间步循环 |
| `Driver_finalizeFlash` | 清理 + 最后 IO |
| `Driver_sourceTerms` | 调度 Burn/Heat/Ionize/Stir/Heatexchange |
| `Driver_computeDt` | 全局时间步限制（min over CFL + 各单元） |
| `Driver_abortFlash` | 终止运行 |

## 5. 延伸阅读

- §7（本篇）Driver 参考
- §2 Quick Start：三步完整流程
- §14 3T HEDP：Operator-Split 各步对应 Driver 循环
- `source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90`：实际主循环源码

## 6. 变更日志

| 日期 | 改动 |
|---|---|
| 2026-07-19 | 创建 draft（5 锚点，全部 `[ -e ]` 验证通过） |
