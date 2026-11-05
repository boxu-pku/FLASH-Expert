---
title: Driver 常见错误与排查
skill: flash-driver
category: pitfalls
source_anchors:
  - source/Driver/DriverMain/Driver_initFlash.F90
  - source/Driver/DriverMain/Driver_computeDt.F90
  - source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90
  - source/Driver/Driver_abortFlash.F90
  - source/Driver/DriverMain/Config
manual_ref: "FLASH 4.8 User Guide §3 Driver Troubleshooting（待转换）"
created: 2026-07-16
last_verified: 2026-07-16
verifier: claude
status: beta
tags:
  - driver
  - pitfalls
  - troubleshooting
  - abort
  - dt
  - wall_clock
  - restart
---

# Driver 常见错误与排查

> **TL;DR**：10 类 Driver 相关错误，按"错误信息 → 触发代码 → 原因 → 修复 → 预防"五段式（按 L-008：源码类贴 if 块，非源码类详细机制解释）。

---

## 1. 错误分类速查

| 类别 | 错误数 | 何时触发 |
|---|---|---|
| **A. 启动期参数校验** | 3 | `flash4` 启动后立即 abort |
| **B. 时间步相关** | 3 | 运行中（dt 过小 / 不稳 / 增长异常） |
| **C. 终止条件** | 2 | 算例结束（异常 / 期望外） |
| **D. 变体选择** | 2 | setup 期或编译期 |

---

## A. 启动期参数校验

### A.1 `Driver_initFlash: tmax < tinitial!`

#### 触发代码字段

```fortran
! source/Driver/DriverMain/Driver_initFlash.F90（节选）

if (dr_tmax < dr_tinitial) then
    call Driver_abortFlash("Driver_initFlash: tmax < tinitial!")
end if
```

#### 原因

parfile 里 `tmax`（终止时间）小于 `tinitial`（起始时间）。物理上不可能（不能往回跑）。

#### 修复

检查 parfile：

```fortran
# ❌ 错误示例
tinitial = 1.0
tmax = 0.5          # < tinitial

# ✅ 正确
tinitial = 0.0
tmax = 1.0e-8       # > tinitial
```

#### 预防

parfile 写好后用 `awk` 检查：

```bash
grep -E "^tinitial|^tmax" flash.par
```

---

### A.2 `Driver_initFlash: nend < nbegin!`

#### 触发代码字段

```fortran
! source/Driver/DriverMain/Driver_initFlash.F90（节选）

if (dr_nEnd < dr_nBegin) then
    call Driver_abortFlash("Driver_initFlash: nend < nbegin!")
end if
```

#### 原因

parfile 里 `nend`（终止步）小于 `nbegin`（起始步）。通常发生在 restart 时设错。

#### 修复

```fortran
# 正常算例
nbegin = 1
nend = 100000

# 重启（nbegin 会被 checkpoint 覆盖）
nbegin = 1          # 占位，实际值来自 chk
nend = 1000000      # 足够大
```

---

### A.3 `Driver_initFlash: dtinit must be > 0!`

#### 触发代码字段

```fortran
! source/Driver/DriverMain/Driver_initFlash.F90（节选）

if (dr_dtinit <= 0.0) then
    call Driver_abortFlash("Driver_initFlash: dtinit must be > 0!")
end if
```

#### 原因

`dtinit`（初始 dt）设为 0 或负值。物理无意义。

#### 修复

```fortran
dtinit = 1.0e-12    # 正数，单位秒
```

---

## B. 时间步相关

### B.1 `[Driver] computed dt below dr_dtMinContinue`

#### 触发代码字段

```fortran
! source/Driver/DriverMain/Driver_computeDt.F90 或 Driver_evolveFlash.F90（节选）

if (dr_dt < dr_dtMinContinue) then
    if (dr_dtMinBelowAction == 0) then
        call Driver_abortFlash("[Driver] computed dt below dr_dtMinContinue")
    else
        call IO_writeCheckpoint()
        call Driver_abortFlash("[Driver] computed dt below dr_dtMinContinue, checkpoint written")
    end if
end if
```

#### 原因（5 种可能）

1. **物理过程加剧**：强激波加速、临界密度面收缩等让 CFL 时间尺度变小
2. **数值不稳**：CFL 过大，dt 持续下降试图补偿
3. **EOS 表外推**：温度/密度超表范围，返回非物理值
4. **AMR 过度细化**：某处无限细化让 dx 极小 → dt 极小
5. **物理参数错**：如密度异常低让声速异常高

#### 用户怎么自己定位

**Step 1：看 dt decomposition**

```bash
grep "dt decomposition\|Hydro\|Diffuse\|RadTrans" 01-data/<basenm>.log | tail -20
```

输出例：
```
dt decomposition:
  Hydro:    1.23e-12   (cell 45, block 7)
  Diffuse:  4.56e-13   (cell 12, block 3)   ← 这个最小，决定 dt
  RadTrans: 1.0e100    (no limit)
```

→ 看是哪个单元在限制 dt。

**Step 2：定位限制 cell**

`dr_printTStepLoc = .true.` 时日志含 cell 位置。看那个 cell 的物理量：

```python
import yt
ds = yt.load("01-data/<basenm>_hdf5_plt_cnt_0042")
ad = ds.all_data()
# 看 block 3, cell 12 附近的物理量
print("dens:", ad["dens"][12])
print("tele:", ad["tele"][12])
# 检查是否非物理（负值、HUGE、NaN）
```

**Step 3：按原因修复**

- **物理过程加剧**：降低 CFL（`Courant_factor=0.3`）
- **数值不稳**：降低 CFL + 限幅器更保守
- **EOS 表外推**：换更宽范围表
- **AMR 过度细化**：限制 `lrefine_max`
- **物理参数错**：检查初值

#### 临时绕过（不推荐）

```fortran
dr_dtMinContinue = 1.0e-20    # 几乎不触发
```

掩盖问题，结果可能不可信。

---

### B.2 dt 持续下降，算例越来越慢

#### 症状

`dr_dt` 从 1e-12 一路降到 1e-15，算例跑 N 步后变极慢。

#### 原因（按可能性）

1. **AMR refinement 爆炸**：某处不断细化，dx 越来越小，dt 跟着小
2. **物理演化到强不连续**：激波加速、塌缩等
3. **EOS 表外推**：返回非物理值让数值不稳

#### 诊断

```bash
# 看 AMR 层数变化
grep "max ref level\|lrefine_max" 01-data/<basenm>.log | tail -10

# 看 dt 受谁限制
grep "dt decomposition" 01-data/<basenm>.log | tail -5
```

#### 修复

```fortran
# 限制 AMR 层数
lrefine_max = 6                # 上限

# 或限制细化变量
refine_var_1 = DENS_VAR
refine_var_2 = -1              # 只按密度细化（不按温度）
```

---

### B.3 dt 增长慢（算例跑得慢）

#### 症状

dt 不增加，算例进度极慢（如 1000 步才跑了 1e-12 秒）。

#### 原因

1. `tstep_change_factor` 太小（默认 2.0，但用户改小了）
2. `dr_tstepSlowStartFactor` 太小（默认 0.1）
3. 物理上 dt 就是受 CFL 严格限制（如强激波）

#### 修复

```fortran
# 让 dt 增长更激进
tstep_change_factor = 2.0       # 默认值
dr_tstepSlowStartFactor = 0.5   # 慢启动因子加大（从 0.1 → 0.5）

# 起步 dt 更接近 CFL 极限
dtinit = 1.0e-11                # 比 1e-12 更接近实际 dt
```

---

## C. 终止条件

### C.1 算例跑到一半被杀（wall_clock 超时）

#### 症状

HPC 集群上算例被队列系统杀掉（SIGTERM/SIGXCPU）。或本机跑到 7 天自动停。

#### 原因

- `wall_clock_time_limit`（默认 604800=7 天）超过队列限制
- 集群超时（如 24h 队列）
- Driver 没机会写 checkpoint，丢失数据

#### 修复

```fortran
# 调整 wall_clock_time_limit
wall_clock_time_limit = 82000    # 22.8 小时（24h 队列留余量）

# 配合：让 checkpoint 频率足够
checkpointFileIntervalStep = 100    # 每 100 步写一次
# 或按时间
checkpointFileIntervalTime = 1.0e-9 # 每 1 ns 写
```

#### 预防

- 看集群文档了解队列限制
- 设 `wall_clock_time_limit` 为队列限制的 95%
- 用 `dr_shortenLastStepBeforeTMax = .true.` 让最后一步能写完

---

### C.2 算例只跑了 100 步就停了（nend 触发）

#### 症状

日志显示"reached nend"，但 `dr_simTime` 远小于 `tmax`。

#### 原因

parfile 默认 `nend = 100`（来自 Config），用户没改。

#### 触发代码字段

```fortran
! source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90（循环条件）

do dr_nstep = dr_nBegin, dr_nEnd    ! dr_nEnd 默认 100
   ...
end do
```

#### 修复

```fortran
nend = 1000000    # 大到几乎不可能触发
```

让 `tmax` 主导终止条件。

---

## D. 变体选择

### D.1 想用 Split Driver 但没生效

#### 症状

setup 时希望用 Split，但运行后看日志发现是 Unsplit。

#### 原因

setup 命令没正确传 `SplitDriver=true`。

#### 修复

```bash
# 正确（SplitDriver=true）
./setup FlamChannel ... SplitDriver=true -objdir=cases/my_case

# 验证 setup 生效
grep "SplitDriver\|DEFAULT Split\|DEFAULT Unsplit" cases/my_case/setup_call
```

---

### D.2 multithreaded 启用了但没用多线程

#### 症状

setup 加了 `threadBlockList=true`，但运行时只用了 1 核。

#### 原因

运行时没设 `OMP_NUM_THREADS`，或 MPI 调度方式不对。

#### 修复

```bash
# 设线程数
export OMP_NUM_THREADS=8

# 启动
mpirun -np 4 ./flash4 -par_file flash.par

# 验证 OpenMP 启用
grep "FLASH_OPENMP" cases/my_case/setup_defines
# 应该看到 #define FLASH_OPENMP 1
```

---

## 3. 调试通用流程

### 3.1 abort 时该收集什么信息

1. **完整 abort 信息**（含 `[<routine>]` 前缀和 message）
2. **`cases/<name>/setup_call`**（确认 setup 命令）
3. **`flash.par`**（确认实际配置）
4. **日志开头 100 行**（含 Driver 初始化信息）
5. **日志最后 100 行**（含 abort 前的状态）

### 3.2 启用调试模式

```bash
./setup ... -debug -objdir=cases/<name>_debug
cd cases/<name>_debug && make -j4
```

`-debug` 用 `FFLAGS_DEBUG`（含 `-ffpe-trap=invalid,zero,overflow -fbounds-check -O0`），早暴露数值问题。

### 3.3 看性能瓶颈

```bash
# 看 Timers 统计（运行结束时打印）
grep "Timer\|Hydro\|sourceTerms\|IO\|Grid" 01-data/<basenm>.log | tail -50
```

找出最耗时的单元，针对性优化。

---

## 4. 已知陷阱

### 4.1 `dtinit` 默认 1e-10 对高能算例过大

激光烧蚀初期、相对论流体首步可能数值不稳。建议：

```fortran
dtinit = 1.0e-14               # 更保守
dr_tstepSlowStartFactor = 0.01 # 慢启动
tstep_change_factor = 1.5      # 保守增长
```

### 4.2 `wall_clock_time_limit` 是软限制

Driver 每步检查。如果某步特别长（如 IO 写大文件），可能超时一段时间才停。`kill -9` 则完全没机会写 checkpoint。

### 4.3 `nend = 100` 默认值

新手算例常被这个限制触发，以为算例"自然停了"。改成 1000000 让 `tmax` 主导。

### 4.4 STS 配置错可能让算例发散

`allowDtSTSDominate = .true.` + `nstepTotalSTS` 太大 → 数值不稳。先用保守配置测试。

### 4.5 重启改 setup 不行

变量数变了 → "variable mismatch" abort。要改 setup 只能从头跑。

---

## 5. 延伸阅读

### 5.1 本 skill 内

- [[knowledge/overview]] — Driver 角色和状态变量
- [[knowledge/params]] — 时间步参数详解
- [[knowledge/internals]] — 调用图
- [[knowledge/recipes]] — 典型配置

### 5.2 跨 skill

- `flash-pitfall-finder` — 自动匹配本文件条目
- `flash-source-reader` — 找 abort 对应源码
- `agent/pitfalls/ffpe-trap-and-nan.md` — 数值异常通用排查
- `agent/pitfalls/restart-incompatibility.md` — 重启失败详解
- `agent/pitfalls/mpi-errors.md` — MPI 相关 abort

### 5.3 外部

- `source/Driver/DriverMain/Config` — 参数定义
- `source/Driver/Driver_abortFlash.F90` — abort 实现
- FLASH 邮件列表档案（搜错误原文）

---

## 6. 维护说明

本文件是"活的"踩坑库。每遇到新的 Driver 相关 abort，按 D-004 决策生成草稿到 `agent/drafts/pending/`，审核后 promote。

---

## 7. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-16 | 初始创建（10 条踩坑：3 启动 + 3 时间步 + 2 终止 + 2 变体 + 5 陷阱） | claude |
