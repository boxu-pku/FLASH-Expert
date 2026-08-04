---
title: Driver 单元总览
skill: flash-driver
category: overview
source_anchors:
  - source/Simulation/Flash.F90
  - source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90:37-450
  - source/Driver/DriverMain/Driver_initFlash.F90:41
  - source/Driver/DriverMain/Driver_sourceTerms.F90:31-70
  - source/Driver/DriverMain/Driver_computeDt.F90
  - source/Driver/DriverMain/Config
  - source/Driver/Driver_interface.F90:79-253
  - source/Driver/Driver_abortFlash.F90
manual_ref: "FLASH 4.8 User Guide §3 Driver Unit（待 Phase 2 转换）"
created: 2026-07-16
last_verified: 2026-07-16
verifier: claude
status: beta
tags:
  - driver
  - main-loop
  - time-stepping
  - sourceTerms
  - Unsplit
  - Split
  - multithreaded
  - INSfracstep
  - STS
---

# Driver 单元总览

> **TL;DR**：Driver 是 FLASH 的"指挥中心"——负责初始化所有单元、按时间步推进模拟、调度各物理单元协同工作。一个 FLASH 可执行文件里只有一个 Driver，但它驱动所有其他单元（Hydro、Grid、Eos、RadTrans、各 sourceTerm 等）。

---

## 1. Driver 是什么——FLASH 的大脑

### 1.1 一句话定位

如果把 FLASH 比作一个工厂：
- **Grid** 是仓库管理员（管 cell 数据存储）
- **Hydro** 是流水线工人（解流体方程）
- **Eos** 是质检员（算温度压强）
- **RadTrans / Diffuse / 各 sourceTerm** 是各车间（辐射、扩散、加源）
- **Driver** 是**总调度**——决定每个时刻哪个车间开工、按什么顺序、用多少时间

没有 Driver，其他单元不知道何时该工作。Driver 自己不算物理，只调度。

### 1.2 Driver 在 FLASH 调用链的位置

```
Simulation/Flash.F90 (main 程序入口)
└── Driver_initFlash (启动时一次性)
│   ├── Driver_initParallel (MPI 初始化)
│   ├── PhysicalConstants_init
│   ├── RuntimeParameters_init (读 parfile)
│   ├── Driver_initFlash (变量/物理单元初始化)
│   │   ├── Grid_init
│   │   ├── Eos_init / Hydro_init / ... 各物理单元 init
│   │   ├── Simulation_init (用户自定义初始化)
│   │   └── Driver_initSourceTerms → 各 sourceTerm init
│   └── IO_init (打开输出文件)
│
└── Driver_evolveFlash ★ (主循环)
    └── 循环每步：
        ├── Hydro
        ├── RadTrans / Diffuse
        ├── Driver_sourceTerms → 各 sourceTerm
        ├── Particles_advance
        ├── Grid_updateRefinement
        ├── IO_output
        └── Driver_computeDt (算下一步 dt)
│
└── Driver_finalizeFlash (收尾)
    ├── 各单元 finalize
    ├── IO 关闭文件
    └── MPI_finalize
```

整个程序就是 `main → init → evolve（循环）→ finalize`。Driver 是中间三个阶段的入口。

### 1.3 Driver 单元的源码结构

`source/Driver/` 目录：

```
source/Driver/
├── Config                                    # stub Config
├── Driver_interface.F90                      # 25 个子程序的接口声明
├── Driver_abortFlash.F90                     # abort 实现（Fortran）
├── Driver_abortFlashC.c                      # abort 实现（C，给 CppAPI 用）
├── Driver_checkMPIErrorCode.F90
├── Driver_computeDt.F90                      # 时间步计算
├── Driver_computeCellLocations.F90
├── Driver_diagnostics.F90
├── Driver_driftUnk.F90                       # drift 检测（数值可重现性）
├── Driver_driftBlock.F90 / Driver_driftSetSrcLoc.F90
├── Driver_evolveFlash.F90                    # ★ stub（被 DriverMain/<variant>/ 替换）
├── Driver_finalizeFlash.F90                  # 收尾
├── Driver_finalizeSourceTerms.F90
├── Driver_getComm.F90 / Driver_getMype.F90 / Driver_getNumProcs.F90
├── Driver_getDt.F90 / Driver_getSimTime.F90 / Driver_getNStep.F90 / ...
├── Driver_init.F90
├── Driver_initFlash.F90                      # ★ 初始化主入口
├── Driver_initMaterialProperties.F90
├── Driver_initNumericalTools.F90
├── Driver_initParallel.F90                   # MPI 初始化
├── Driver_initSourceTerms.F90                # ★ sourceTerm init 调度
├── Driver_logMemoryUsage.F90
├── Driver_mpiThreadSupport.F90
├── Driver_putTimeStamp.F90
├── Driver_setupParallelEnv.F90
├── Driver_sourceTerms.F90                    # ★ stub（被 DriverMain/<variant>/ 替换）
├── Driver_superTimeStep.F90                  # STS 实现
├── Driver_verifyInitDt.F90
├── DriverMain/                               # ★ 实际实现（4 个变体）
│   ├── Config                                # 参数声明 + 变体选择逻辑
│   ├── Driver_data.F90                       # dr_* 全局状态变量
│   ├── Driver_initFlash.F90
│   ├── Driver_sourceTerms.F90                # ★ sourceTerm 调度实现
│   ├── Driver_computeDt.F90
│   ├── Unsplit/Driver_evolveFlash.F90        # ★ 默认变体
│   ├── Split/Driver_evolveFlash.F90          # 燃烧专用
│   ├── multithreaded/Driver_evolveFlash.F90  # OpenMP 并行
│   └── INSfracstep/Driver_evolveFlash.F90    # 不可压 NS
├── localAPI/                                 # 本地辅助函数
├── CppAPI/                                   # C++ 接口
└── Python/                                   # Python 接口
```

→ 标 ★ 的是高频被查的文件。

---

## 2. 主循环（Driver_evolveFlash）

### 2.1 它做什么

主循环是 Driver 的**核心职能**。它是个 do 循环，每轮代表一个时间步：

```fortran
! source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90:131-138（简化）

do dr_nstep = dr_nBegin, dr_nEnd              ! 从 nbegin 步到 nend 步
   ...                                        ! 每步做 6 件事
end do
```

### 2.2 每步的 6 件事（详细）

#### 第 1 件：拿到要处理的 block 列表

```fortran
call Grid_getLocalNumBlks(localNumBlocks)
call Grid_getListOfBlocks(LEAF, blockList, blockCount)
```

**新手概念——AMR leaf block**：FLASH 用 AMR（自适应网格细化），网格在运行时变化。每个 processor 每步开始时问 Grid："我手里有哪些 leaf block（最细层的网格单元）？" 拿到 `blockList` 数组，后面所有计算都对它做。

#### 第 2 件：算 Hydro（流体方程）

```fortran
call Hydro(blockCount, blockList, dr_simTime, dr_dt, dr_dtOld, sweepDummy)
```

解 Euler 方程（质量、动量、能量守恒）。产生激波、湍流、压缩等基本流体行为。Hydro 修改 `DENS_VAR/VELX_VAR/PRES_VAR/EINT_VAR` 等基本守恒量。

#### 第 3 件：算扩散过程（辐射 + 热传导 + 粘性）

```fortran
call RadTrans(blockCount, blockList, dr_dt)    ! 多群扩散（MGD）
call Diffuse(blockCount, blockList, dr_dt)     ! 热传导、磁扩散
```

Hydro 只算**对流**，扩散是**独立物理过程**。扩散通常用隐式求解（HYPRE），因为显式稳定的时间步太小。

#### 第 4 件：算 sourceTerms（含激光）

```fortran
call Driver_sourceTerms(blockCount, blockList, dr_dt)
```

**这一步内部依次调用 10+ 个 sourceTerm**（顺序详见 `knowledge/internals.md §4`）：

```
Driver_sourceTerms
├── Polytrope                        多方过程
├── Stir                             搅拌驱动（湍流 forcing）
├── Turb_calc                        湍流统计
├── Flame_step                       火焰面
├── Burn                             核燃烧
├── Heat                             外部加热
├── Heatexchange                     电子-离子能量交换
├── Cool                             辐射冷却
├── Ionize                           电离/复合
├── EnergyDeposition ★               激光（默认第 10 位）
└── Deleptonize                      中子物质调整
```

每个 sourceTerm 修改自己的目标变量（激光加 `EELE_VAR`，Burn 加 `EION_VAR`），互不直接通信。

#### 第 5 件：推进粒子（如果用 Particles）

```fortran
call Particles_advance(dr_dtOld, dr_dt)
```

活跃粒子（如宇宙学暗物质、激光等离子体示踪粒子）按当前速度场推进。

#### 第 6 件：收尾（重力 / AMR 重化 / IO / 时间步）

```fortran
call Gravity_potentialListOfBlocks(...)        ! 重力势
call Grid_updateRefinement(...)                ! AMR 根据梯度重化网格
call IO_output(...)                            ! 写 plotfile / checkpoint
call Driver_computeDt(...)                     ! 算下一步 dt（CFL + 各种限制）
```

### 2.3 循环终止条件

循环在以下任一条件满足时退出（源码 `Driver_evolveFlash.F90` 各变体内）：

| 条件 | 参数 | 典型值 |
|---|---|---|
| 步数到上限 | `dr_nstep >= dr_nEnd` | 默认 100 |
| 模拟时间到上限 | `dr_simTime >= dr_tmax` | 默认 0.2（用户必设） |
| 墙钟超时 | `wall_clock_time_limit` 秒后 | 默认 604800（7 天） |
| dt 过小 | `dr_dt < dr_dtMinContinue` | 默认 0（不动） |
| IO 触发终止 | `endRunPl / endRun` 标志 | 由 IO 单元设 |
| 用户手动 | Ctrl+C 或调度系统 SIGTERM | — |

详见 `knowledge/params.md §2.2-2.3`。

---

## 3. 4 个 DriverMain 变体

Driver 的主循环有 4 个实现，setup 时选一个。区别在**主循环内部如何处理 Hydro 和 sourceTerms**。

### 3.1 变体对比表

| 变体 | 文件位置 | 何时用 | 核心特点 |
|---|---|---|---|
| **Unsplit**（默认） | `DriverMain/Unsplit/Driver_evolveFlash.F90` | 大多数可压缩 / MHD / 激光算例 | 一步推进，Hydro 用 unsplit 算法（更精确） |
| **Split** | `DriverMain/Split/Driver_evolveFlash.F90` | 燃烧算例（Flame + Burn） | Strang splitting：Hydro 半步 → sourceTerm 全步 → Hydro 半步 |
| **multithreaded** | `DriverMain/multithreaded/Driver_evolveFlash.F90` | OpenMP 并行（同 Split 但多线程） | `threadBlockList=true` 或 `threadWithinBlock=true` 启用 |
| **INSfracstep** | `DriverMain/INSfracstep/Driver_evolveFlash.F90` | 不可压 Navier-Stokes（INS 单元） | fractional step 方法 |

### 3.2 怎么选（决策树）

```
你的算例？
├── 可压缩流体 / MHD / 激光（大多数算例）
│   └── Unsplit（默认，不需要 setup 选项）
├── 燃烧 / 火焰面（Flame + Burn 单元）
│   └── Split（setup 加 +split 或 SplitDriver=true）
├── 需要 OpenMP 并行（单机多核）
│   └── multithreaded（setup 加 threadBlockList=true 或 threadWithinBlock=true）
└── 不可压流体（INS 单元）
    └── INSfracstep（INS 单元自动选）
```

### 3.3 Unsplit vs Split 的本质区别

**Unsplit**（默认）：一个时间步内，Hydro 一次性推进整个 dt，然后 sourceTerms 一次性推进整个 dt。两步显式分离。

**Split**（Strang splitting）：一个时间步内分三段：
1. Hydro 推进 dt/2
2. sourceTerms 推进 dt（全步）
3. Hydro 推进 dt/2

**为什么燃烧算例用 Split**：核燃烧（Burn）和火焰面（Flame）的反应速率可能比流体时间尺度快得多。Unsplit 模式下，Burn 在整步末尾算一次，可能错过快速反应；Split 模式把 Burn 夹在两个 Hydro 半步之间，更精确处理强耦合。

**为什么绝大多数 ICF/激光算例用 Unsplit**：激光（EnergyDeposition）的时间尺度通常和 Hydro 接近，Strang splitting 收益小、代价（多算一次半步 Hydro）大。

源码：变体选择在 `source/Driver/DriverMain/Config`：

```
DEFAULT Unsplit

USESETUPVARS SplitDriver
IF SplitDriver
  DEFAULT Split
ENDIF

EXCLUSIVE Split Unsplit INSfracstep
```

→ `SplitDriver` setup 变量决定走 Split 还是 Unsplit。`multithreaded` 是单独的（`threadBlockList` 等触发）。

---

## 4. 关键全局状态变量（Driver_data 模块）

Driver 在 `source/Driver/DriverMain/Driver_data.F90` 维护一组全局变量，前缀都是 `dr_`。这些变量在整个 Driver 单元内共享，是 Driver 各子程序之间传递状态的"通道"。

### 4.1 时间相关

| 变量 | 类型 | 含义 |
|---|---|---|
| `dr_nstep` | INTEGER | 当前时间步编号（每轮循环 +1） |
| `dr_nBegin` | INTEGER | 起始步（parfile `nbegin`，默认 1） |
| `dr_nEnd` | INTEGER | 终止步（parfile `nend`，默认 100） |
| `dr_simTime` | REAL | 当前模拟时间（CGS 秒） |
| `dr_tInitial` | REAL | 起始时间（parfile `tinitial`，默认 0） |
| `dr_tmax` | REAL | 终止时间（parfile `tmax`，默认 0.2） |
| `dr_dt` | REAL | 当前时间步长 |
| `dr_dtOld` | REAL | 上一步 dt（部分求解器需要） |
| `dr_dtNew` | REAL | 下一步 dt（Driver_computeDt 算出来后存这里） |

### 4.2 MPI/processor

| 变量 | 含义 |
|---|---|
| `dr_globalMe` | 当前 processor 在 GLOBAL_COMM 中的 ID（0 到 N-1） |
| `dr_globalNumProcs` | 总 processor 数 |
| `dr_meshMe` | 当前 processor 在 MESH_COMM 中的 ID |
| `dr_meshComm` | MESH_COMM 通信器 |
| `dr_globalComm` | GLOBAL_COMM 通信器 |

**MASTER_PE** 是个常量（=0），代码里 `if (dr_globalMe == MASTER_PE)` 表示"只有 rank 0 做"（如打印、IO 写）。

### 4.3 控制标志

| 变量 | 含义 |
|---|---|
| `dr_restart` | 是否从 checkpoint 重启（BOOLEAN） |
| `dr_useSTS` | 是否用 Super-Time-Stepping（加速扩散） |
| `dr_useSTSforDiffusion` | STS 是否仅用于扩散 |
| `dr_redshift` | 当前红移（宇宙学算例用） |
| `dr_useRedshift` | 是否启用红移演化 |
| `dr_gridChanged` | AMR 网格这一步是否变了（影响 guard cell 更新） |

### 4.4 时间步限制贡献

Driver_computeDt 收集各单元的 dt 贡献，存这些变量：

| 变量 | 含义 |
|---|---|
| `dr_dtAdvect` | 对流（Hydro）的时间步限制 |
| `dr_dtDiffuse` | 扩散的时间步限制 |
| `dr_dtSubSTS` | STS 子步 dt |

最终 `dr_dt = min(dr_dtAdvect, dr_dtDiffuse, ...) × dr_tstepSlowStartFactor`（起步阶段）或直接 min。

---

## 5. 与其他单元的耦合

### 5.1 上游（谁调用 Driver）

只有 `Simulation/Flash.F90`（程序 main）调用 Driver：

```fortran
! source/Simulation/Flash.F90（简化）
call Driver_initFlash()        ! 启动
call Driver_evolveFlash()      ! 主循环
call Driver_finalizeFlash()    ! 收尾
```

### 5.2 下游（Driver 调用谁）

Driver 调用几乎所有其他单元。详见 `knowledge/internals.md`。

### 5.3 关键约束

- **Driver 是单例**：一个 FLASH 可执行文件只有一个 Driver
- **Driver 不算物理**：只调度，具体计算在各物理单元
- **Driver_data 是全局**：用 use 引入，状态变量在整个 Driver 单元共享
- **Driver 不能被其他单元覆盖**：`Config` 里 `EXCLUSIVE Split Unsplit INSfracstep` 强制互斥

---

## 6. 已知陷阱 / 与手册的差异

### 6.1 手册默认 `tmax = 0.2`，但实际算例几乎都改

源码 `source/Driver/DriverMain/Config:36`：`PARAMETER tmax REAL 0.2`。这是 FLASH 测试时用的默认值，实际算例必须在 parfile 显式设：

```fortran
tmax = 1.0e-9    # 1 纳秒（ICF 算例）
```

不改的话算例只跑到 0.2 秒（CGS 秒，即 0.2 s 实际时间），远超 ICF 物理时间。

### 6.2 `dtinit = 1e-10` 对某些算例过大

默认初始 dt 是 1e-10 秒。对一些高能算例（如激光烧蚀初期、相对论流体），可能太大导致首步数值不稳。建议：

```fortran
dtinit = 1e-14    # 更保守的初始 dt
dr_tstepSlowStartFactor = 0.01    # 让 dt 慢慢长大
```

### 6.3 `wall_clock_time_limit` 默认 7 天，HPC 集群常不够

集群队列常限制 24-72 小时。如果你的算例跑了一半被杀，看这个参数。建议设为集群队列限制的 95%（留 5% 写 checkpoint）：

```fortran
wall_clock_time_limit = 82000    # 22.8 小时（24 小时队列留余量）
```

### 6.4 Split Driver 不是默认

新手以为 Split 更精确，但实际 **Unsplit 才是默认且更常用**。Split 用于特定场景（燃烧）。详见 §3.3。

### 6.5 多线程 Driver 不自动启用

setup 加 `-threadRayTrace=true` 只让激光 ray tracing 多线程。要让 Driver 主循环多线程，需要 `threadBlockList=true`（按 block 分配线程）或 `threadWithinBlock=true`（一个 block 内多线程）。

---

## 7. 延伸阅读

### 7.1 本 skill 内

- `knowledge/params.md` — 完整参数字典
- `knowledge/internals.md` — init/evolve/sourceTerms/computeDt 调用图
- `knowledge/recipes.md` — 典型 setup 命令 + parfile 时间步配置
- `knowledge/pitfalls.md` — 常见错误排查

### 7.2 跨 skill

- `flash-source-reader/snippets/driver-evolve-flash.md` — 预读的源码片段
- `flash-source-reader/snippets/driver-source-terms.md` — sourceTerms 调度片段
- `flash-laser` — 激光在 sourceTerms 第 10 位的详解

### 7.3 外部资料

- FLASH 4.8 User Guide §3 Driver Unit（待 Phase 2 转换）
- Courses / Tutorials：flash.uchicago.edu/site/flashcode/coding/
- 经典论文：FLASH 1 (Fryxell et al. 2000 ApJS)、FLASH 4 (Dubey et al. 2014）

---

## 8. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-16 | 初始创建（Driver 角色、主循环 6 件事、4 变体对比、状态变量、5 条陷阱） | claude |
