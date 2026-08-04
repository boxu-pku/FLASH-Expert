---
title: Driver 参数完整字典
skill: flash-driver
category: params
source_anchors:
  - source/Driver/DriverMain/Config
  - source/Driver/DriverMain/Driver_data.F90
  - source/Driver/DriverMain/Driver_computeDt.F90
  - source/Driver/DriverMain/Driver_initFlash.F90
manual_ref: "FLASH 4.8 User Guide §3 Driver Runtime Parameters（待转换）"
created: 2026-07-16
last_verified: 2026-07-16
verifier: claude
status: beta
tags:
  - driver
  - parameters
  - runtime-parameters
  - dr_
  - timestep
  - STS
---

# Driver 参数完整字典

> **TL;DR**：Driver 单元在 `source/Driver/DriverMain/Config` 声明 ~30 个 runtime parameter，前缀都是 `dr_` 或单字（如 `tmax`、`nend`）。按"时间步控制 / 终止条件 / 重启 / 墙钟 / STS / drift / 并行"7 类组织。

---

## 1. 参数生成机制

**源码**：`source/Driver/DriverMain/Config`

和激光单元一样，Driver 也用 `Config` 文件声明参数。但 Driver 的参数**不动态生成**（不像 `ed_*_<i>`），都是固定名字。

Config 文件含 4 类声明：
1. **`D <name> <description>`** — 参数文档（生成到 `setup_params`）
2. **`PARAMETER <name> <type> <default>`** — 参数声明
3. **`USESETUPVARS` / `IF` / `ENDIF`** — 条件编译逻辑（如根据 `SplitDriver` 选变体）
4. **`PPDEFINE`** — 编译期宏（如 `FLASH_OPENMP`）

详见 `agent/param-index.md §1. Driver`。

---

## 2. 全局参数（30 个）

### 2.1 时间步控制

| 参数 | 类型 | 默认 | 单位 | 含义 |
|---|---|---|---|---|
| `dtinit` | REAL | 1e-10 | s | 初始时间步 |
| `dtmin` | REAL | 1e-10 | s | 物理最小 dt（低于此值通常 abort） |
| `dtmax` | REAL | 1e5 | s | 物理最大 dt |
| `tstep_change_factor` | REAL | 2.0 | — | dt 单步最大变化倍数。每步 dt 最多乘这个因子（防止 dt 突跳） |
| `dr_tstepSlowStartFactor` | REAL | 0.1 | — | 慢启动因子。初始 dt 是 CFL 计算 dt 的这个倍数（保守起步） |
| `dr_dtMinContinue` | REAL | 0.0 | s | 最小允许 dt。计算出的 dt 低于此值时按 `dr_dtMinBelowAction` 处理 |
| `dr_dtMinBelowAction` | INTEGER | 1 | — | dt 过小时的行为：0=立即 abort，1=写 checkpoint 后 abort |
| `dr_usePosdefComputeDt` | BOOLEAN | false | — | 启用正定 dt 限制器（防止某些变量变负） |
| `dr_posdefDtFactor` | REAL | 1.0 | — | 正定限制器系数（类似 CFL）。设 -1 用 Hydro 的 CFL |
| `dr_numPosdefVars` | INTEGER | 4 | — | 正定限制器监控的变量数（动态生成 `dr_posdefVar_<i>`） |
| `dr_posdefVar_<i>` | STRING | "none" | — | 第 i 个正定监控变量名（动态生成） |

**新手重点**：
- `dtinit` 太大 → 首步数值不稳
- `tstep_change_factor` 默认 2.0 → dt 每步最多翻倍（防止突然变大导致不稳定）
- `dr_dtMinContinue` 是"早警告"机制——dt 异常小时主动 abort，避免算出一堆 NaN

### 2.2 模拟范围（终止条件）

| 参数 | 类型 | 默认 | 单位 | 含义 |
|---|---|---|---|---|
| `nbegin` | INTEGER | 1 | — | 起始步编号 |
| `nend` | INTEGER | 100 | — | 终止步编号（达到则停） |
| `tinitial` | REAL | 0.0 | s | 起始模拟时间 |
| `tmax` | REAL | **0.2** | s | 终止模拟时间（达到则停）。⚠️ 默认 0.2 是测试值，实际算例必改 |

**终止逻辑**（在 Driver_evolveFlash 循环条件里）：
- `dr_nstep >= dr_nEnd` → 退出
- `dr_simTime >= dr_tmax` → 退出
- 任一先满足即停

**典型设置**：
```fortran
# ICF 算例（纳秒时间尺度）
tinitial = 0.0
tmax = 1.0e-8         # 10 ns
nend = 100000         # 大值，主要由 tmax 触发

# 天体物理算例（秒或更长）
tmax = 1.0e3
nend = 10000
```

### 2.3 重启（Restart）

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `restart` | BOOLEAN | false | 是否从 checkpoint 重启 |
| `initializeParticleAtRestart` | BOOLEAN | false | 重启时是否重新初始化粒子（不读 checkpoint 里的粒子数据） |

**使用方法**：
```fortran
# flash.par
restart = .true.
checkpointFileNumber = 20    # 从 chk_0020 重启
basenm = "01-data/mycase_"   # 同原 parfile
```

**注意**：restart 要求 setup 一致（变量、几何、block 结构不变）。否则报"variable mismatch"等错。详见 `agent/pitfalls/restart-incompatibility.md`。

### 2.4 墙钟时间限制

| 参数 | 类型 | 默认 | 单位 | 含义 |
|---|---|---|---|---|
| `wall_clock_time_limit` | REAL | 604800 | s（墙钟） | 总墙钟时间限制。超过则进入"优雅退出"流程（写 checkpoint 后停）。-1 禁用 |

**新手重点**：
- 默认 7 天，HPC 集群常不够（集群队列限制 24-72 小时）
- 集群算例建议设为队列限制的 95%（留时间写 checkpoint）
- 单机算例可设 -1（不限制）

```fortran
# 24 小时 HPC 队列
wall_clock_time_limit = 82000    # 22.8 小时

# 单机不限
wall_clock_time_limit = -1.0
```

### 2.5 Super-Time-Stepping（STS）

STS 是加速**扩散**过程的方法。扩散的显式时间步正比于 $\Delta x^2$，比 Hydro 的 $\Delta x$ 严格得多。STS 用一组非均匀子步（Chebyshev 多项式）让扩散能跑更大的"等效"时间步。

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `useSTS` | BOOLEAN | false | 启用 STS |
| `useSTSforDiffusion` | BOOLEAN | false | TRUE=STS 仅加速扩散（不加速对流），FALSE=也加速对流 |
| `allowDtSTSDominate` | BOOLEAN | false | 是否允许 STS 的 dt 大于 Hydro 的 CFL dt |
| `nuSTS` | REAL | 0.1 | STS 稳定性参数（< 1） |
| `nstepTotalSTS` | INTEGER | 5 | STS 子步数 |

**何时用 STS**：
- 算例被扩散限制（`dr_dtDiffuse << dr_dtAdvect`）
- 典型场景：高电导率/不透明度等离子体、强热传导

**何时不用**：
- 对流限制算例（Hydro 主导）→ STS 无效
- 强非线性（激波、燃烧）→ STS 可能不稳

**典型配置**：
```fortran
useSTS = .true.
useSTSforDiffusion = .true.    # 仅加速扩散（保守）
allowDtSTSDominate = .false.   # 不超过 Hydro dt
nuSTS = 0.1                    # 默认稳定性
nstepTotalSTS = 5              # 5 个子步
```

### 2.6 Drift 检测（数值可重现性）

Drift 是 FLASH 4.6+ 引入的"位级漂移检测"——检查 block 数据在不同运行间是否产生微小差异（由浮点累加顺序、MPI reduce 等导致）。

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `meshCopyCount` | INTEGER | 1 | 计算网格副本数（用于 drift 对比） |
| `drift_trunc_mantissa` | INTEGER | 2 | 比较时忽略的尾数位数（3 bits ≈ 1 sigdig） |
| `drift_verbose_inst` | INTEGER | 0 | 从哪个实例开始详细日志（0=禁用） |
| `drift_break_inst` | INTEGER | 0 | 在哪个实例中断（调试用） |
| `drift_tuples` | BOOLEAN | false | 是否以 Python tuple 格式输出 |

**新手建议**：保持默认。只在调试可重现性问题时改。

### 2.7 并行 / 处理器分布

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `iProcs` | INTEGER | 1 | i 方向 processor 数（部分拓扑感知 Grid 用） |
| `jProcs` | INTEGER | 1 | j 方向 |
| `kProcs` | INTEGER | 1 | k 方向 |

**注意**：多数 Grid 后端（如 paramesh）自动决定 processor 分布。这些参数仅用于某些特殊拓扑（如 UG）。

### 2.8 诊断 / 日志

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `dr_printTStepLoc` | BOOLEAN | true | 每步打印时，是否显示"哪个 cell 触发了 dt 限制" |
| `eachProcWritesOwnAbortLog` | BOOLEAN | false | abort 时每个 processor 写自己的日志（vs 只 rank 0 写） |
| `dr_abortPause` | INTEGER | 2 | abort 前暂停秒数（给 gdb attach 留时间） |
| `sweepOrder` | INTEGER | 123 | Split Driver 方向扫描顺序（123 = x→y→z，其他：132/213/231/312/321） |

### 2.9 宇宙学

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `zInitial` | REAL | -1.0 | 初始红移（< 0 表示不用宇宙学） |
| `zFinal` | REAL | 0.0 | 终止红移（达到则停） |

**注意**：宇宙学算例（CCSN、Panecake 等）专用。普通算例不用。

### 2.10 其他

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `dr_shortenLastStepBeforeTMax` | BOOLEAN | false | TRUE=最后一步自动缩短以恰好达到 tmax（不超调） |

---

## 3. setup 变量（编译期）

Driver 单元有少量 setup 变量（在 setup 命令行设，决定编译期行为）：

| setup 变量 | 默认 | 含义 |
|---|---|---|
| `SplitDriver` | false | 启用 Split Driver（变体选择） |
| `threadBlockList` | false | OpenMP 按 block 分（启用 multithreaded Driver） |
| `threadWithinBlock` | false | OpenMP 在 block 内分 |
| `threadRayTrace` | false | 仅激光 ray tracing 多线程（不影响 Driver 主循环） |
| `threadProtonTrace` | false | ProtonImaging 单元的多线程 |
| `dr_numPosdefVars` | 4 | 正定 dt 限制器监控的变量数（决定生成多少 dr_posdefVar_<i>） |

**何时用 setup 变量 vs runtime parameter**：
- 影响编译（含 `#ifdef`、生成参数槽位）→ setup 变量
- 仅运行时行为 → runtime parameter

---

## 4. setup 变量 vs runtime parameter 对照表

新手最容易混淆。常见组合：

| 想改的 | 在哪改 | 重新 setup+make? |
|---|---|---|
| 总时间步数 | parfile `nend=N` | 否 |
| 终止时间 | parfile `tmax=X` | 否 |
| 初始 dt | parfile `dtinit=X` | 否 |
| 启用 STS | parfile `useSTS=.true.` | 否 |
| 用 Split Driver | setup 命令 `SplitDriver=true` | **是** |
| 启用 OpenMP 并行 | setup 命令 `threadBlockList=true` | **是** |
| 监控 5 个正定变量 | setup 命令 `dr_numPosdefVars=5` | **是**（生成 5 个 `dr_posdefVar_<i>` 参数槽） |

**判断规则**：
- 名字含 `Build`（如 `threadBlockListBuild`）→ setup 变量
- 在 Config 的 `IF ... ENDIF` 块里读 → setup 变量
- 在 Config 的 `PARAMETER` 行（不在 IF 里）→ runtime parameter

---

## 5. 常见错误

### 5.1 `dt below dr_dtMinContinue`

```
[Driver] computed dt = 1.0e-15 below dr_dtMinContinue = 1.0e-10
```

→ 算出的 dt 太小。可能原因：
- 物理过程加剧（强激波加速）
- 数值不稳（CFL 过大）
- EOS 表外推

修复：
```fortran
# 临时：降低 dr_dtMinContinue
dr_dtMinContinue = 1.0e-15

# 根因：降低 CFL，或检查初值/物理参数
```

详见 `knowledge/pitfalls.md` 的"dt 持续下降"条目。

### 5.2 `wall_clock_time_limit exceeded`

```
[Driver] wall_clock_time_limit = 604800.000000 exceeded
```

→ 算例超过 7 天。修复：
```fortran
wall_clock_time_limit = -1.0    # 禁用（单机）
# 或
wall_clock_time_limit = 82000   # 适应 24h 队列
```

### 5.3 `nend reached but tmax not`

算例只跑了 100 步就停了，没到 tmax。原因：默认 `nend=100`，被这个先触发。修复：

```fortran
nend = 1000000    # 大到几乎不可能触发，让 tmax 主导
```

### 5.4 STS 不生效

设了 `useSTS=.true.` 但 dt 没变大。可能原因：
- 算例被 Hydro 主导（`dr_dtAdvect < dr_dtDiffuse`）→ STS 无效
- `allowDtSTSDominate = .false.` 限制 STS 不超过 Hydro → 改成 .true.（但小心稳定性）

---

## 6. 已知陷阱

### 6.1 `tmax = 0.2` 是测试默认

Config 默认 `tmax = 0.2`（200 毫秒）。实际算例几乎都改：

```fortran
# ICF 算例
tmax = 1.0e-8      # 10 ns

# 天体物理
tmax = 1.0e3       # 1000 秒
```

不改的话算例跑 0.2 秒停（可能远超你的预期物理时间）。

### 6.2 `dtinit = 1e-10` 对高能算例过大

激光烧蚀初期、相对论流体等高能算例，首步可能数值不稳。建议：

```fortran
dtinit = 1.0e-14                # 更保守
dr_tstepSlowStartFactor = 0.01  # 让 dt 慢慢长大（CFL × 0.01 起步）
tstep_change_factor = 1.5       # 每步最多乘 1.5（更保守，默认 2.0）
```

### 6.3 `wall_clock_time_limit` 不影响"实际运行时间"

它只是个**软限制**——Driver 每步检查，超过就写 checkpoint 后停。如果你 `kill -9 flash4`，没机会写 checkpoint，可能丢数据。

### 6.4 `sweepOrder` 只对 Split Driver 有效

Unsplit 是方向耦合的，不分扫描顺序。Split Driver 才按 123/132 等顺序扫描。

### 6.5 STS 不是"总是好的"

STS 加速扩散，但**对强非线性扩散（如辐射流体）可能不稳**。先用小 `nstepTotalSTS`（如 3）测试。

---

## 7. 延伸阅读

- [[knowledge/overview]] — Driver 角色 + 主循环
- [[knowledge/internals]] — Driver_computeDt 怎么算 dt
- [[knowledge/recipes]] — 典型 setup 命令 + parfile 时间步配置
- [[knowledge/pitfalls]] — 时间步相关踩坑

### 跨 skill

- `flash-param-query` — 跨单元查参数
- `flash-source-reader/snippets/driver-evolve-flash.md` — 主循环源码片段
- `agent/pitfalls/ffpe-trap-and-nan.md` — 数值异常（dt 相关）
- `agent/pitfalls/mpi-errors.md` — MPI 相关 abort

### 外部

- `source/Driver/DriverMain/Config` — 真正权威的参数定义
- `source/Driver/DriverMain/Driver_data.F90` — 全局变量声明
- `bin/Readme.SetupVars` — setup 变量机制文档

---

## 8. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-16 | 初始创建（30+ 参数按 10 类组织 + setup 变量 + 常见错误 + 5 条陷阱） | claude |
