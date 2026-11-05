---
name: flash-driver
description: |
  FLASH 4.8 Driver 单元专家。处理主循环 Driver_evolveFlash、初始化 Driver_initFlash、
  sourceTerms 调度 Driver_sourceTerms、时间步 Driver_computeDt、4 个变体（Unsplit/Split/multithreaded/INSfracstep）、
  STS 超时间步、wall_clock 超时、drift 检测、Driver_abortFlash。
  触发词：driver, evolveFlash, initFlash, sourceTerms, computeDt, dr_, 主循环, 时间步,
        CFL, STS, super time stepping, Split, Unsplit, INSfracstep, wall_clock
triggers:
  # 中文
  - Driver
  - 主循环
  - 时间步
  - 时间步进
  - 主驱动
  - 驱动单元
  - 调度器
  - sourceTerms 调用顺序
  - 初始化流程
  - 收尾流程
  - 数值不稳定
  - 超时间步
  - 墙钟
  - 重启
  - 中止
  # 英文
  - Driver
  - Driver_evolveFlash
  - Driver_initFlash
  - Driver_finalizeFlash
  - Driver_sourceTerms
  - Driver_computeDt
  - Driver_getDt
  - Driver_getSimTime
  - Driver_getNStep
  - Driver_getMype
  - Driver_getComm
  - Driver_getNumProcs
  - Driver_abortFlash
  - Driver_checkMPIErrorCode
  - Driver_initParallel
  - Driver_initSourceTerms
  - Driver_finalizeSourceTerms
  - Driver_diagnostics
  - Driver_driftUnk
  - Driver_superTimeStep
  - Driver_logMemoryUsage
  - evolveFlash
  - sourceTerms
  - computeDt
  - dr_
  - dtinit
  - dtmin
  - dtmax
  - tmax
  - tinitial
  - nbegin
  - nend
  - wall_clock_time_limit
  - tstep_change_factor
  - restart
  - initializeParticleAtRestart
  - useSTS
  - useSTSforDiffusion
  - allowDtSTSDominate
  - nuSTS
  - nstepTotalSTS
  - sweepOrder
  - Split
  - Unsplit
  - multithreaded
  - INSfracstep
  - SplitDriver
  - CFL
  - STS
  - super time stepping
  - drift
  - drift_unsk
  - dr_printTStepLoc
  - dr_usePosdefComputeDt
  - dr_posdefDtFactor
  - zInitial
  - zFinal
when_to_use: |
  调用本 skill 的场景：
  1. 用户问主循环结构（"FLASH 怎么推进时间步"、"evolveFlash 做什么"）
  2. 用户问初始化流程（"FLASH 启动时做什么"、"initFlash 顺序"）
  3. 用户问 sourceTerms 调用顺序（"为什么激光排在第 10 位"、"DRIVER_EDEARLY 是什么"）
  4. 用户问时间步控制（"dt 怎么算"、"为什么 dt 越来越小"、"CFL 用多少"）
  5. 用户问 setup 选 Driver 变体（"Split vs Unsplit"、"什么时候用 multithreaded"）
  6. 用户问终止条件（"模拟什么时候停"、"tmax vs nend"）
  7. 用户问重启（"restart 怎么用"、"checkpointFileNumber 设几"）
  8. 用户问 STS（"超时间步是什么"、"useSTS 怎么设"）
  9. 用户问 wall_clock 超时（"算例跑了一半被杀"、"wall_clock_time_limit 设多少"）
  10. 用户问 abort 机制（"Driver_abortFlash 怎么用"、"怎么优雅退出"）
when_not_to_use: |
  **不调用本 skill 的场景**：
  - 具体某个 sourceTerm 的内部（如激光 ed_*）→ `flash-laser`（或对应物理 skill）
  - Grid 相关 → `flash-grid`（Phase 2 后）
  - Hydro 求解器 → `flash-hydro`（Phase 2 后）
  - 找源码位置 → `flash-source-reader`
  - 错误诊断 → `flash-pitfall-finder`
  - 查具体参数含义 → `flash-param-query`
layer: knowledge
phase: 2
status: stable
created: 2026-06-17
last_updated: 2026-07-18
owner: user
---

# flash-driver — Driver 单元专家

> **状态**：✅ stable（5 道验收考题全部通过，2026-07-18；Phase 2 第一个知识层 skill）

## 1. 角色与边界

### 1.1 我是做什么的

回答 FLASH **Driver 单元**相关的所有问题——FLASH 的"指挥中心"：

| 范畴 | 详见 |
|---|---|
| 物理原理 + 设计 | `knowledge/overview.md` — Driver 角色、主循环、4 变体、状态变量 |
| 参数字典 | `knowledge/params.md` — 30+ 参数（时间步/终止/STS/drift） |
| 内部实现 | `knowledge/internals.md` — initFlash/evolveFlash/sourceTerms/computeDt 调用图 |
| 典型配置 | `knowledge/recipes.md` — setup 变体 + parfile 时间步配置 |
| 踩坑排查 | `knowledge/pitfalls.md` — dt 过小、wall_clock 超时、变体选错等 |

### 1.2 我不做什么

| 用户问题类型 | 归属 skill |
|---|---|
| 激光（EnergyDeposition） | `flash-laser` |
| Hydro 求解器内部 | `flash-hydro`（Phase 2） |
| Grid / AMR | `flash-grid`（Phase 2） |
| EOS | `flash-eos`（Phase 2） |
| 找源码位置 | `flash-source-reader` |
| 错误信息匹配 | `flash-pitfall-finder` |
| 参数含义（不深入） | `flash-param-query` |
| 跑算例 | `flash-case-runner`（Phase 3） |

## 2. 行为协议

按 `agent/TEMPLATES/skill-template.md §2` 通用协议。核心要点（按 L-001~L-008）：

- **讲逻辑**（L-001）：不只列函数/参数，讲清楚控制流和数据流
- **不用 mermaid**（L-002）：调用关系用文字+缩进
- **贴源码相关代码**（L-008）：abort 类查询贴出 `Driver_abortFlash` 所在 if；非源码错（如 MPI）不凑数
- **面向新手**：解释每个 FLASH 术语（如"AMR leaf block"、"sourceTerm"），不假设用户懂

## 3. knowledge/ 子目录

| 文件 | 内容 |
|---|---|
| `knowledge/overview.md` | Driver 角色 + 主循环结构 + 4 变体对比 + 状态变量 |
| `knowledge/params.md` | 30+ 参数完整字典（时间步控制/终止条件/STS/drift/重启等） |
| `knowledge/internals.md` | initFlash + evolveFlash + sourceTerms + computeDt 调用图 |
| `knowledge/recipes.md` | 典型 setup 命令 + parfile 时间步配置 + 4 变体选择决策 |
| `knowledge/pitfalls.md` | 常见错误（dt 过小、wall_clock 超时、变体选错、STS 误用） |

## 4. examples/

Driver 的"例子"主要是 setup 命令变体（不是 parfile 片段）：

| 文件 | 内容 |
|---|---|
| `examples/setup-unsplit.sh` | 默认 Unsplit Driver setup 命令（适用大多数算例） |
| `examples/setup-split.sh` | Split Driver setup 命令（燃烧算例） |
| `examples/setup-multithreaded.sh` | multithreaded Driver setup 命令（OpenMP 并行） |
| `examples/parfile-timestep.txt` | 时间步控制相关 parfile 片段 |

## 5. 示例问答（验收基准）

### Q1: FLASH 主循环在哪？怎么工作？
**A**: 见 `knowledge/overview.md §1-2` + `knowledge/internals.md §3`。`Driver_evolveFlash` 是主循环，每步做 6 件事：取 block 列表 → Hydro → 扩散 → sourceTerms → 粒子 → 收尾（重力/AMR/IO/dt）。

### Q2: sourceTerms 调用顺序是什么？为什么激光排第 10？
**A**: 见 `knowledge/internals.md §4`。默认顺序 Polytrope → ... → EnergyDeposition（第 10）→ Deleptonize。激光排后是为了数值稳定（等温度场算完再加）。

### Q3: dt 越来越小怎么办？
**A**: 见 `knowledge/pitfalls.md` 的 "dt 持续下降" 条目。可能原因：物理过程加强（如激波加速）、CFL 太大、EOS 表外推。诊断：看日志 dt decomposition。

### Q4: Split vs Unsplit 怎么选？
**A**: 见 `knowledge/recipes.md §2`。默认 Unsplit（大多数算例）；燃烧/火焰用 Split（Strang splitting）；多核用 multithreaded。

### Q5: wall_clock_time_limit 怎么设？
**A**: 见 `knowledge/params.md §2.3`。默认 604800 秒（7 天）。设为 -1 禁用。HPC 集群通常按队列限制设（如 24 小时 = 86400）。

## 6. 关键源码入口

| 想理解 | 看哪个文件 |
|---|---|
| 主循环 | `source/Driver/DriverMain/<variant>/Driver_evolveFlash.F90` |
| 初始化 | `source/Driver/DriverMain/Driver_initFlash.F90` |
| sourceTerms 调度 | `source/Driver/DriverMain/Driver_sourceTerms.F90` |
| 时间步计算 | `source/Driver/DriverMain/Driver_computeDt.F90` |
| abort 实现 | `source/Driver/Driver_abortFlash.F90` + `Driver_abortFlashC.c` |
| 状态变量 | `source/Driver/DriverMain/Driver_data.F90`（含 `dr_*` 全局变量） |
| Config（参数声明） | `source/Driver/DriverMain/Config` |
| interface 声明 | `source/Driver/Driver_interface.F90` |
| 程序入口（main） | `source/Simulation/Flash.F90` |

## 7. 待办

- [ ] 跑 5 道验收考题，全部通过则升级 stable
- [ ] 持续累积踩坑（运行算例时遇到 Driver 相关问题）
- [ ] Phase 2+ 其他 skill 协作验证

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-07-16 | 升级 draft → beta（Phase 2 启动）：扩展 triggers（60+ 关键词含全部 dr_/Driver_* 前缀）；按 flash-laser 模板 + L-001~L-008 经验规划 5 knowledge + examples；Phase 2 第一个知识层 skill | claude |
