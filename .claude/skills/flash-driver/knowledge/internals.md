---
title: Driver 内部调用图
skill: flash-driver
category: internals
source_anchors:
  - source/Simulation/Flash.F90
  - source/Driver/DriverMain/Driver_initFlash.F90:41
  - source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90:37-450
  - source/Driver/DriverMain/Driver_sourceTerms.F90:31-70
  - source/Driver/DriverMain/Driver_computeDt.F90
  - source/Driver/DriverMain/Driver_initSourceTerms.F90:37
  - source/Driver/DriverMain/Driver_finalizeSourceTerms.F90:35
  - source/Driver/DriverMain/Driver_data.F90
  - source/Driver/Driver_abortFlash.F90
manual_ref: "FLASH 4.8 User Guide §3 Driver Internals（待转换）"
created: 2026-07-16
last_verified: 2026-07-16
verifier: claude
status: beta
tags:
  - driver
  - call-graph
  - 调用图
  - 数据流
  - 控制流
  - lifecycle
---

# Driver 内部调用图

> **TL;DR**：Driver 单元 3 个阶段——初始化（一次性）、主循环（每步）、收尾（一次性）。每个阶段做什么、调谁、状态怎么传，本文档完整梳理。**所有调用关系用文字+缩进表达**（按 L-002 不用 mermaid）。

---

## 1. 程序生命周期（顶层视角）

```
Simulation/Flash.F90 (main 程序入口)
│
├── Driver_initFlash (启动一次)
│   ├── Driver_initParallel
│   ├── PhysicalConstants_init / RuntimeParameters_init / Logfile_init
│   ├── Driver_initFlash (内部第二次调用，含各物理单元 init)
│   │   ├── Grid_init
│   │   ├── PhysicalConstants_init
│   │   ├── Multispecies_init
│   │   ├── Hydro_init / Eos_init / RadTrans_init / Diffuse_init
│   │   ├── Gravity_init / Conductivity_init / Viscosity_init / Opacity_init
│   │   ├── IO_init
│   │   ├── Driver_initSourceTerms → 各 sourceTerm init
│   │   ├── Simulation_init (用户自定义)
│   │   └── Driver_verifyInitDt
│   └── (准备进入主循环)
│
├── Driver_evolveFlash ★ (主循环)
│   └── do dr_nstep = nbegin, nend (循环每步)
│       ├── Grid_getLocalNumBlks / Grid_getListOfBlocks (拿 block 列表)
│       ├── [可选] Driver_superTimeStep (STS 加速)
│       ├── Hydro (流体方程)
│       ├── RadTrans / Diffuse (扩散过程)
│       ├── Driver_sourceTerms → 各 sourceTerm
│       ├── Particles_advance (粒子推进)
│       ├── Gravity_potentialListOfBlocks (重力)
│       ├── Grid_updateRefinement (AMR 重化)
│       ├── IO_output (写 plotfile / chk)
│       └── Driver_computeDt (算下一步 dt)
│
└── Driver_finalizeFlash (收尾一次)
    ├── Driver_finalizeSourceTerms → 各 sourceTerm finalize
    ├── 各物理单元 finalize
    ├── IO_finalize
    ├── Timers_getSummary (打印性能统计)
    └── MPI_finalize
```

---

## 2. 初始化阶段（Driver_initFlash）

**源码**：`source/Driver/DriverMain/Driver_initFlash.F90:41`

### 2.1 步骤序列

```
Driver_initFlash
├── Driver_initParallel                     MPI 初始化
│   ├── MPI_init
│   ├── Driver_setupParallelEnv
│   └── Driver_mpiThreadSupport
│
├── Logfile_init                            日志系统初始化
├── RuntimeParameters_init                  参数系统初始化
├── RuntimeParameters_read                  读 parfile
├── RuntimeParameters_bcast                 广播参数到所有 processor
│
├── PhysicalConstants_init                  物理常数
├── Driver_computeCellLocations             cell 坐标
├── Grid_init                               网格初始化
├── Multispecies_init                       物种
├── Hydro_init                              流体
├── Eos_init                                状态方程
├── RadTrans_init                           辐射传输
├── Diffuse_init                            扩散
├── Gravity_init                            重力
├── Conductivity_init / Viscosity_init      物质属性
├── Opacity_init
├── IO_init                                 输入输出
│
├── Driver_initMaterialProperties           物质属性初始化
├── Driver_initNumericalTools               数值工具
├── Driver_initSourceTerms ★                sourceTerm init 调度
│   ├── Polytrope_init
│   ├── Stir_init
│   ├── Flame_init
│   ├── Burn_init
│   ├── Heat_init
│   ├── Heatexchange_init
│   ├── Cool_init
│   ├── Ionize_init
│   ├── EnergyDeposition_init ★             激光（详见 flash-laser）
│   ├── Deleptonize_init
│   └── Turb_init
│
├── Simulation_init                         用户自定义初始化
│   └── Simulation_initBlock                每个 block 的初值
│
├── Driver_verifyInitDt                     验证初始 dt 合法
├── Timers_init                             计时器
└── (准备进入主循环)
```

### 2.2 关键校验（abort 触发条件）

`Driver_initFlash.F90` 含多处校验，常见 abort：

```fortran
! source/Driver/DriverMain/Driver_initFlash.F90（节选）

if (dr_tmax < dr_tinitial) then
    call Driver_abortFlash("Driver_initFlash: tmax < tinitial!")
end if

if (dr_nEnd < dr_nBegin) then
    call Driver_abortFlash("Driver_initFlash: nend < nbegin!")
end if

if (dr_dtinit <= 0.0) then
    call Driver_abortFlash("Driver_initFlash: dtinit must be > 0!")
end if
```

→ 看到这些 abort 信息，对照本节源码就能定位根因。

---

## 3. 主循环（Driver_evolveFlash）

**源码（默认 Unsplit）**：`source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90:37-450`

### 3.1 循环骨架

```fortran
! source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90:131-138

do dr_nstep = dr_nBegin, dr_nEnd
   ! 每步做 6 件事（详见 §3.2-3.7）
   ...
end do
```

### 3.2 第 1 件：拿 block 列表

```fortran
! :145-150
call Grid_getLocalNumBlks(localNumBlocks)
call Grid_getListOfBlocks(LEAF, blockList, blockCount)
```

**数据流**：
- 调用前：Grid 内部维护 block 树
- 调用后：本 processor 拿到一个 `blockList(1:blockCount)` 整数数组，含所有 leaf block ID

**为什么每步都做**：AMR 网格在运行时变化（重化、负载均衡），blockList 可能每步不同。

### 3.3 第 2 件：Hydro 求解

```fortran
! :288-294
call Timers_start("Hydro")
call Hydro(blockCount, blockList, dr_simTime, dr_dt, dr_dtOld, sweepDummy)
call Timers_stop("Hydro")
call Driver_driftUnk(__FILE__,__LINE__,driftUnk_flags)
```

**数据流**：
- 输入：blockList、当前 dt
- 修改：`DENS_VAR/VELX_VAR/PRES_VAR/EINT_VAR` 等守恒量
- 输出：调用后 unk 数组含更新后的流体状态

`Driver_driftUnk` 在主要计算后调用，记录 unk 数据的"指纹"（用于可重现性检查）。

### 3.4 第 3 件：扩散过程

```fortran
! :296-303
call RadTrans(blockCount, blockList, dr_dt)
call Diffuse(blockCount, blockList, dr_dt)
call Driver_driftUnk(__FILE__,__LINE__,driftUnk_flags)
```

**数据流**：
- RadTrans 修改：`ERAD_VAR`（辐射能量密度）、`TRAD_VAR`（辐射温度）
- Diffuse 修改：`EELE_VAR/EION_VAR`（电子/离子内能，通过热传导）、磁场分量（磁扩散）

### 3.5 第 4 件：sourceTerms 调度

```fortran
! :307-310
call Timers_start("sourceTerms")
call Driver_sourceTerms(blockCount, blockList, dr_dt)
call Timers_stop("sourceTerms")
call Driver_driftUnk(__FILE__,__LINE__,driftUnk_flags)
```

**`Driver_sourceTerms` 内部调用顺序**（详见 §4）：10+ 个 sourceTerm 依次执行。

### 3.6 第 5 件：粒子推进

```fortran
! :320-322
call Timers_start("Particles_advance")
call Particles_advance(dr_dtOld, dr_dt)
call Timers_stop("Particles_advance")
```

**新手概念**：FLASH 支持被动粒子（流场中的标记物）和活跃粒子（自引力等）。Particles_advance 按当前速度场推进它们的位置。

不用 Particles 单元的算例（如多数 ICF 算例）这步是 no-op。

### 3.7 第 6 件：收尾（重力/AMR/IO/dt）

```fortran
! :330-450（节选）

# 重力（如果用 Gravity 单元）
call Gravity_potentialListOfBlocks(blockCount, blockList)

# AMR 重化（按梯度调整网格）
if (mod(dr_nstep, nrefs) == 0) then
   call Grid_updateRefinement(dr_nstep, dr_simTime)
   ! 重化后 blockList 变了，重新拿
   call Grid_getLocalNumBlks(localNumBlocks)
   call Grid_getListOfBlocks(LEAF, blockList, blockCount)
end if

# IO 输出（按步数或时间触发）
call IO_output(dr_simTime, dr_nstep)

# 算下一步 dt
call Driver_computeDt(dr_dtNew, dr_dtOld)
dr_dt = dr_dtNew

# 推进时间
dr_simTime = dr_simTime + dr_dt
```

---

## 4. sourceTerms 调度（Driver_sourceTerms）

**源码**：`source/Driver/DriverMain/Driver_sourceTerms.F90:31-70`

### 4.1 完整调用顺序

```fortran
! source/Driver/DriverMain/Driver_sourceTerms.F90:31-70（简化）

subroutine Driver_sourceTerms(blockCount, blockList, dt, pass)
   integer, intent(IN) :: blockCount, blockList(:)
   real, intent(IN) :: dt
   integer, OPTIONAL, intent(IN) :: pass

#ifdef DRIVER_EDEARLY
   call EnergyDeposition(blockCount, blockList, dt, dr_simTime, pass)   ! 排最前
#endif

   call Polytrope(blockCount, blockList, dt)
   call Stir(blockCount, blockList, dt)
   call Turb_calc(blockCount, blockList)
   call Flame_step(blockCount, blockList, dt)
   call Burn(blockCount, blockList, dt)
   call Heat(blockCount, blockList, dt, dr_simTime)
   call Heatexchange(blockCount, blockList, dt)
   call Cool(blockCount, blockList, dt, dr_simTime)
   call Ionize(blockCount, blockList, dt, dr_simTime)

#ifndef DRIVER_EDEARLY
   call EnergyDeposition(blockCount, blockList, dt, dr_simTime, pass)   ! 默认排这里（第 10 位）
#endif

   call Deleptonize(blockCount, blockList, dt, dr_simTime)
end subroutine
```

### 4.2 调用顺序的物理动机

每个 sourceTerm 修改自己的目标变量。顺序决定"谁看到什么状态"：

| 顺序 | sourceTerm | 目标变量 | 为什么这个位置 |
|---|---|---|---|
| 1 | Polytrope | EELE | 简单加源，先算 |
| 2 | Stir | 动量（VELX/Y/Z） | 外部驱动，先于内部过程 |
| 3 | Turb_calc | （诊断，不修改 unk） | 算统计量 |
| 4 | Flame_step | 物种丰度 | 反应速率 |
| 5 | Burn | EION、物种 | 核反应释放能量 |
| 6 | Heat | EELE | 用户自定义外热源 |
| 7 | Heatexchange | EELE ↔ EION | 让 T_e、T_i 趋于平衡 |
| 8 | Cool | EELE 减 | 平衡后扣损失 |
| 9 | Ionize | EELE、abundance | T_e 稳定后算电离 |
| **10** | **EnergyDeposition** | **EELE（激光沉积）** | **默认：等所有热损失算完再加** |
| 11 | Deleptonize | abundance、YE_MSCALAR | 收尾 |

**关键观察**：激光（10）在 `Heatexchange (7)`/`Cool (8)` 之后，避免同一步内多次迭代导致的不稳定。

### 4.3 DRIVER_EDEARLY 宏

如果 setup 时定义 `DRIVER_EDEARLY`，激光排到第 1 位（在 Polytrope 之前）：

```bash
./setup laser_CH ... -defines=DRIVER_EDEARLY ...
```

**何时用**：激光驱动的燃烧模拟（先加热触发反应）。

**默认不用**：保持 `#ifndef DRIVER_EDEARLY`，激光在第 10 位。

### 4.4 `pass` 参数（Split Driver 用）

`Driver_sourceTerms` 接收可选 `pass` 参数：
- 不传：Unsplit Driver，整步一次
- `pass=1`：Split Driver 前半步（Hydro 已跑 dt/2）
- `pass=2`：Split Driver 后半步

split Driver 一个时间步内调 Driver_sourceTerms 两次（pass=1 和 pass=2）。

---

## 5. 时间步计算（Driver_computeDt）

**源码**：`source/Driver/DriverMain/Driver_computeDt.F90`

### 5.1 算法

Driver_computeDt 收集各单元的 dt 贡献，取**最小值**作为最终 dt：

```
各单元贡献：
├── Hydro（dr_dtAdvect）        按 CFL：dt = CFL × dx / (cs + |v|)
├── Diffuse（dr_dtDiffuse）      扩散稳定：dt = 0.5 × dx² / D
├── RadTrans（rt_dt）            辐射扩散
├── Gravity                     重力（如 Courant 类）
├── Burn、Cool 等 sourceTerm    反应/冷却时间尺度
└── 各单元自定义限制

最终 dt：
dr_dt = min(各贡献) × dr_tstepSlowStartFactor
                                              ↑ 慢启动因子（默认 0.1，起步阶段）

# 慢启动结束后（dt >= 上一步 dt × tstep_change_factor）：
dr_dt = min(各贡献) × 1.0
```

### 5.2 STS 处理

如果 `dr_useSTS = .true.`，Driver_computeDt 会算两个 dt：
- `dr_dt`：常规 dt（受所有单元限制）
- `dr_dtSTS`：仅受扩散限制的 dt（用于 STS 加速）

如果 `allowDtSTSDominate = .true.`，允许 `dr_dt = dr_dtSTS`（让扩散用更大 dt）。

### 5.3 终止条件检查

每步 Driver_computeDt 后，Driver_evolveFlash 检查：

```fortran
if (dr_dt < dr_dtMinContinue) then
    if (dr_dtMinBelowAction == 0) then
        call Driver_abortFlash("dt below dr_dtMinContinue!")
    else
        call IO_writeCheckpoint()  # 写 checkpoint
        call Driver_abortFlash("dt below dr_dtMinContinue!")
    end if
end if

# 检查最后一步是否要缩短
if (dr_shortenLastStepBeforeTMax .and. dr_simTime + dr_dt > dr_tmax) then
    dr_dt = dr_tmax - dr_simTime
end if
```

---

## 6. 关键数据结构

### 6.1 Driver_data 模块（全局状态）

**源码**：`source/Driver/DriverMain/Driver_data.F90`

Driver 用 `Driver_data` 模块维护全局状态，前缀都是 `dr_`。所有 Driver 子程序通过 `use Driver_data` 共享这些变量。

完整变量列表见 `knowledge/overview.md §4`。

### 6.2 blockList 数组

```fortran
integer :: blockCount                              ! 本 processor 的 block 数
integer :: blockList(MAXBLOCKS)                    ! block ID 列表
```

每步开始由 `Grid_getListOfBlocks(LEAF, blockList, blockCount)` 填充。

### 6.3 unk 数组（cell 数据）

通过 `Grid_getBlkPtr(blockID, solnData, CENTER)` 取指针：

```fortran
real, pointer :: solnData(:,:,:,:)    ! 4D: (变量索引, i, j, k)
```

索引如 `DENS_VAR=1`、`TELE_VAR=11` 等由 `Flash.h` 定义。

---

## 7. abort 机制（Driver_abortFlash）

**源码**：`source/Driver/Driver_abortFlash.F90`

### 7.1 工作流程

```
某子程序发现错误
   ↓
call Driver_abortFlash("错误信息")
   ↓
Driver_abortFlash 内部：
├── Logfile_stampMessage(message)         写主日志
├── if (eachProcWritesOwnAbortLog)        写每 processor 日志（可选）
├── sleep(dr_abortPause)                  暂停 N 秒（给 gdb attach 留时间）
├── Driver_checkMPIErrorCode              检查 MPI 错误
└── MPI_ABORT(comm, code)                 杀掉所有 processor
```

### 7.2 为什么不直接 `stop`

直接 `stop` 只杀当前 processor，其他 processor 继续跑（死循环或卡死）。`MPI_ABORT` 杀掉所有 processor，让 mpirun 退出。

### 7.3 错误信息格式

FLASH 约定错误信息含 `[<routine>]` 前缀：

```fortran
call Driver_abortFlash("[EnergyDeposition_init] ERROR: ed_depoVarName is invalid.")
```

→ 用户看错误信息就知道是哪个 routine abort 的，便于查源码（`rg "\\[EnergyDeposition_init\\]" source/`）。

---

## 8. 已知陷阱

### 8.1 Driver_initFlash 内部调用了两次（易混淆）

`Driver_initFlash.F90` 第一次是顶层的 `Driver_initFlash`（启动），第二次是内部 `Driver_initFlash`（含各单元 init）。看堆栈跟踪别混淆。

### 8.2 Driver_evolveFlash 各变体差异大

Unsplit 和 Split 的 Driver_evolveFlash 代码结构不同（Split 有 Strang splitting 的两次 Hydro 调用）。改源码时要确认用哪个变体。

### 8.3 Driver_sourceTerms 接受 `pass` 但不是每个 sourceTerm 都用

`pass` 只对 Split Driver 有意义。每个 sourceTerm 内部通常 `if (present(pass)) ...`，但不一定真用到。

### 8.4 Driver_computeDt 调用顺序晚于你想的

你以为"算完 sourceTerms 就算 dt"？实际是：sourceTerms → Particles → Gravity → AMR → IO → 最后才 Driver_computeDt。这样能反映所有变化。

---

## 9. 延伸阅读

### 9.1 本 skill 内

- [[knowledge/overview]] — Driver 角色与状态变量
- [[knowledge/params]] — 时间步参数详解
- [[knowledge/recipes]] — 典型 setup 命令
- [[knowledge/pitfalls]] — 常见错误

### 9.2 跨 skill

- `flash-source-reader/snippets/driver-evolve-flash.md` — 主循环源码片段
- `flash-source-reader/snippets/driver-source-terms.md` — sourceTerms 调度片段
- `flash-laser/knowledge/internals.md §2.1` — 激光在 sourceTerms 中的位置

### 9.3 外部

- `source/Simulation/Flash.F90` — 程序 main 入口
- `source/Driver/DriverMain/<variant>/Driver_evolveFlash.F90` — 各变体实现
- `source/Driver/DriverMain/Driver_data.F90` — 全局变量

---

## 10. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-16 | 初始创建（生命周期 + 主循环 6 件事 + sourceTerms 调度 + computeDt + abort 机制） | claude |
