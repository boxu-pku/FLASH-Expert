---
title: Driver 典型配置
skill: flash-driver
category: recipes
source_anchors:
  - source/Driver/DriverMain/Config
  - source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90
  - source/Driver/DriverMain/Split/Driver_evolveFlash.F90
  - source/Driver/DriverMain/multithreaded/Driver_evolveFlash.F90
  - cases/LaserSlab/setup_call
  - cases/Sedov/setup_call
manual_ref: "FLASH 4.8 User Guide §3 Driver Setup（待转换）"
created: 2026-07-16
last_verified: 2026-07-16
verifier: claude
status: beta
tags:
  - driver
  - recipes
  - setup
  - 变体
  - STS
  - parfile
---

# Driver 典型配置

> **TL;DR**：Driver 的"配置"主要是两类：**setup 命令选变体**（Unsplit/Split/multithreaded）+ **parfile 控制时间步/终止条件**。本文给 5 个典型 recipe，覆盖大多数实际场景。

---

## 1. 通用规则

### 1.1 setup 命令位置

Driver 变体在 setup 命令行选，**不能在 parfile 改**。例：

```bash
./setup <problem> ... [Driver 变体选项] ... -objdir=cases/<case>
```

### 1.2 parfile 时间步控制位置

时间步相关参数都在 parfile 顶层（不在某 sourceTerm 段），例：

```fortran
# flash.par 顶层
tmax = 1.0e-8
nend = 100000
dtinit = 1.0e-12
```

### 1.3 决策树：选哪个变体

```
你的算例？
├── 可压缩流体 / MHD / 激光（90% 算例）
│   └── Unsplit（默认，不需要 setup 选项）
├── 燃烧 / 火焰面（Flame + Burn 单元）
│   └── Split（setup 加 SplitDriver=true）
├── 需要 OpenMP 并行
│   └── multithreaded（setup 加 threadBlockList=true 或 threadWithinBlock=true）
└── 不可压流体（INS 单元）
    └── INSfracstep（INS 单元自动选）
```

---

## 2. Recipe 1：默认 Unsplit（最常用）

### 2.1 适用场景

90% 的 FLASH 算例：Sedov、激光烧蚀、Sod 振动管、CCSN、WindTunnel 等。

### 2.2 setup 命令

**不需要任何 Driver 相关选项**——默认就是 Unsplit。

```bash
# 例：基础 Sedov 算例
./setup Sedov -auto -objdir=cases/sedov_default
```

```bash
# 例：激光算例
./setup laser_CH -2d -auto +pm4dev -geometry=cylindrical \
    -nxb=16 -nyb=16 +mtmmmt +laser +mgd +uhd3t \
    species=cham,targ1,targ2,targ3 mgd_meshgroups=6 \
    -parfile=flash.par -objdir=cases/my_laser
```

### 2.3 parfile 时间步配置（基础版）

```fortran
# ===== 时间步控制 =====
tinitial = 0.0           # 起始时间（s）
tmax = 1.0e-8            # 终止时间（10 ns，ICF 典型）

nbegin = 1               # 起始步
nend = 100000            # 终止步（设大让 tmax 主导）

dtinit = 1.0e-12         # 初始 dt（保守起步）
tstep_change_factor = 2.0   # 每步最多翻倍
dr_tstepSlowStartFactor = 0.1  # 慢启动（dt = CFL × 0.1 起步）

# ===== 终止 =====
wall_clock_time_limit = 604800   # 7 天默认（单机可设 -1）
```

### 2.4 验证

跑几步后看日志：

```bash
grep "dr_nstep\|dr_simTime\|dr_dt" 01-data/<basenm>.log | head -10
```

应该看到：
- `dr_nstep` 每步 +1
- `dr_simTime` 每步加 `dr_dt`
- `dr_dt` 慢慢增长（受 tstep_change_factor 限制）

---

## 3. Recipe 2：Split Driver（燃烧/火焰算例）

### 3.1 适用场景

- FlamChannel、RTFlame 等火焰面算例
- 含 Burn 单元（核反应）的算例
- 反应-扩散强耦合问题

### 3.2 setup 命令（加 SplitDriver=true）

```bash
./setup FlamChannel -2d -auto +flame +burn \
    SplitDriver=true \
    -objdir=cases/flame_split
```

或等价的 `+split` 选项（部分版本支持）：

```bash
./setup FlamChannel -2d -auto +flame +burn +split \
    -objdir=cases/flame_split
```

### 3.3 工作机制（Strang splitting）

```
一个时间步 dt 内：
1. Hydro 推进 dt/2
2. sourceTerms 推进 dt（整步）：
   ├── Burn（核反应）
   ├── Flame（火焰面）
   └── ... 其他 sourceTerm
3. Hydro 推进 dt/2
```

**为什么用 Strang**：燃烧反应速率可能比流体快，Unsplit 模式（Hydro 整步 + sourceTerm 整步）会错过快速反应。Split 把反应夹在两个 Hydro 半步之间，更精确。

### 3.4 parfile 注意

Split Driver 的 parfile 和 Unsplit 几乎一样，但要注意：

```fortran
# Split 可能需要更小 dt（反应时间尺度短）
dtinit = 1.0e-14          # 比 Unsplit 保守

# sweepOrder 控制 Split 内部方向扫描顺序（Unsplit 无此参数）
sweepOrder = 123          # x→y→z（默认）
```

### 3.5 何时不用 Split

- 激光算例（激光反应速率和流体接近，Unsplit 够用）
- 单纯流体（无 sourceTerm 强耦合）
- 测试算例（Unsplit 更简单）

---

## 4. Recipe 3：multithreaded Driver（OpenMP 并行）

### 4.1 适用场景

- 单机多核机器
- 想充分利用 CPU（如 32 核服务器）
- ICF 全 3D 算例（计算量大）

### 4.2 setup 命令（加 threadBlockList 或 threadWithinBlock）

```bash
./setup Sedov -3d -auto \
    threadBlockList=true \
    -objdir=cases/sedov_3d_mt
```

或：

```bash
./setup Sedov -3d -auto \
    threadWithinBlock=true \
    -objdir=cases/sedov_3d_mt
```

**区别**：
- `threadBlockList=true`：每个线程处理一个 block（粗粒度，简单）
- `threadWithinBlock=true`：一个 block 内部多线程（细粒度，更复杂但可能更快）

### 4.3 运行时设 OpenMP 线程数

setup 命令只决定**编译**支持多线程，运行时还要设 `OMP_NUM_THREADS`：

```bash
# 4 个 MPI process × 8 线程 = 32 核
export OMP_NUM_THREADS=8
mpirun -np 4 ./flash4 -par_file flash.par
```

### 4.4 激光算例的多线程

激光算例 ray tracing 也可多线程，独立于 Driver：

```bash
./setup laser_CH -2d -auto +pm4dev ... \
    threadRayTrace=true \       # 仅激光 ray tracing 多线程
    threadBlockList=true \      # Driver 主循环也多线程
    -objdir=cases/laser_mt
```

`threadRayTrace` 比 `threadBlockList` 影响范围小（只加速激光部分）。

### 4.5 注意事项

- **OpenMP + MPI 混合**：每个 MPI process 内的线程数由 `OMP_NUM_THREADS` 决定
- **不是所有单元都 OpenMP 安全**：某些单元（如带全局状态的）可能 race condition
- **性能不一定线性**：内存带宽、cache 局部性等限制 scaling

---

## 5. Recipe 4：STS 加速扩散

### 5.1 适用场景

- 算例被扩散主导（`dr_dtDiffuse << dr_dtAdvect`）
- 高电导率等离子体（强热传导）
- 强辐射扩散（高 Z 物质）

### 5.2 parfile 配置

```fortran
# ===== STS 加速 =====
useSTS = .true.
useSTSforDiffusion = .true.    # 仅加速扩散（保守起步）
allowDtSTSDominate = .false.   # 不让 STS 超过 Hydro dt
nuSTS = 0.1                    # 默认稳定性
nstepTotalSTS = 5              # 5 个子步
```

### 5.3 工作机制

STS（Super-Time-Stepping）用 Chebyshev 多项式构造一组非均匀子步，让扩散能用比显式更大的"等效"dt：

```
原显式扩散 dt：0.5 × dx² / D ≈ 1e-15 s（很小）
STS 等效 dt：nstepSTS² × 原 dt ≈ 25 × 1e-15 = 2.5e-14 s
```

→ 实际算例 dt 从 1e-15 提到 2.5e-14，加速 25 倍。

### 5.4 何时不用 STS

- 对流主导（Hydro dt < Diffuse dt）→ STS 无效
- 强非线性（激波、燃烧）→ STS 可能不稳
- 调试算例 → 先用显式确认正确性

### 5.5 调参建议

```fortran
# 起步配置（保守）
useSTS = .true.
useSTSforDiffusion = .true.
allowDtSTSDominate = .false.
nuSTS = 0.1
nstepTotalSTS = 3              # 先用 3 个子步

# 进阶（如果起步稳定）
nstepTotalSTS = 5              # 加到 5
allowDtSTSDominate = .true.    # 让 STS 主导 dt
```

### 5.6 验证

看日志 dt：

```bash
grep "dr_dt\|dr_dtDiffuse\|dr_dtSTS" 01-data/<basenm>.log | head -20
```

应该看到 `dr_dt` 受 `dr_dtSTS` 限制（不是 `dr_dtDiffuse`）。

---

## 6. Recipe 5：从 checkpoint 重启

### 6.1 适用场景

- 算例跑到一半被杀（队列超时、机器宕机）
- 想从中途继续（如先跑到 t=5ns，分析后再跑到 t=10ns）
- 修改了 parfile 想从某点重新开始

### 6.2 parfile 配置

```fortran
# ===== Restart 配置 =====
restart = .true.
checkpointFileNumber = 20      # 从 chk_0020 重启
basenm = "01-data/mycase_"     # ★ 必须和原 parfile 一致

# 时间步设置（会被 checkpoint 覆盖，但建议保留）
tmax = 1.0e-8
nend = 100000

# 如果 checkpoint 里粒子数据有问题，重新初始化
initializeParticleAtRestart = .false.
```

### 6.3 setup 命令（必须和原 case 一致）

重启用的 objdir **必须和原 case 的 setup 一致**——变量、几何、block 结构、物理单元都相同。

```bash
# 用原 setup 命令（不要改任何 setup 选项）
./setup laser_CH -2d -auto +pm4dev ... \
    -parfile=flash_restart.par \
    -objdir=cases/mycase      # 同原 objdir

cd cases/mycase

# 把 chk 文件复制到 01-data/（如果路径不一样）
cp /path/to/backup/mycase_hdf5_chk_0020 01-data/

./flash4 -par_file flash_restart.par
```

### 6.4 注意事项

- **不能改 setup**：变量数变了 → "variable mismatch" abort
- **不能跨 FLASH 版本**：4.7 的 chk 不能在 4.8 重启
- **checkpoint 完整性**：如果 chk 文件损坏（写时中断），可能 abort
- 详见 `agent/pitfalls/restart-incompatibility.md`

---

## 7. 通用 parfile 时间步配置模板

适合大多数算例的"安全配置"：

```fortran
# ===== 时间步 =====
tinitial = 0.0
tmax = <你的终止时间>
nbegin = 1
nend = 1000000               # 大值，让 tmax 主导

dtinit = <估算的初始 dt>     # 见下文估算方法
dtmin = 1.0e-20              # 防止异常 abort
dtmax = 1.0e5                # 防止异常 dt

tstep_change_factor = 1.5    # 保守（默认 2.0 略激进）
dr_tstepSlowStartFactor = 0.05  # 慢启动

# ===== 终止 =====
wall_clock_time_limit = 604800  # 或按队列调整

# ===== 诊断 =====
dr_printTStepLoc = .true.    # 打印哪个 cell 限制 dt
```

### 7.1 怎么估算初始 dt

经验公式：

```
dtinit ≈ CFL × dx / (cs_max + |v|_max)
```

其中：
- `CFL` ≈ 0.4（保守）
- `dx` = 最小 cell 大小（cm）
- `cs_max` = 最大声速（cm/s）
- `|v|_max` = 最大流体速度

例：dx=1e-3 cm, cs=1e7 cm/s → dtinit ≈ 0.4 × 1e-3 / 1e7 = 4e-11 s

设保守点：dtinit = 1e-12 s（更小，让慢启动慢慢加大）。

---

## 8. Driver 配置检查清单

跑算例前确认这些：

```
□ setup 命令的 Driver 变体选对了吗？（默认 Unsplit 适合大多数）
□ parfile 含 tmax（必设，默认 0.2 通常太小）
□ parfile 含 nend（足够大让 tmax 主导）
□ dtinit 合理（不太大导致首步不稳）
□ wall_clock_time_limit 适合运行环境
□ 输出频率（plotFileIntervalStep）合理
□ checkpoint 频率（checkpointFileIntervalStep）合理
□ 如果用 STS，参数组合（useSTS/useSTSforDiffusion/nuSTS/nstepTotalSTS）合理
□ 如果多线程，OMP_NUM_THREADS 设了
```

---

## 9. 已知陷阱

### 9.1 Unsplit 是默认，但新手常误以为"Split 更精确"

实际 Unsplit 是 FLASH 4 主推，多数算例用 Unsplit。Split 仅用于特定场景（燃烧）。

### 9.2 `threadRayTrace` 不影响 Driver 主循环

只让激光 ray tracing 多线程。要让整个 Driver 多线程，需要 `threadBlockList` 或 `threadWithinBlock`。

### 9.3 STS 配置错会让算例不稳

`allowDtSTSDominate = .true.` + `nstepTotalSTS` 太大（如 20）→ 数值不稳。先用保守配置（.false. + 3）测试。

### 9.4 重启时改 setup 不行

变量数变了 → abort。如果非要改 setup（如加单元），只能从头跑，不能重启。

### 9.5 wall_clock_time_limit 是软限制

Driver 每步检查。如果某步特别长（如 IO 写大文件），可能超时一段时间才停。

---

## 10. 延伸阅读

### 10.1 本 skill 内

- [[knowledge/overview]] — Driver 角色 + 4 变体本质区别
- [[knowledge/params]] — 30+ 参数详解
- [[knowledge/internals]] — 调用图
- [[knowledge/pitfalls]] — 常见错误

### 10.2 跨 skill

- `flash-source-reader/snippets/driver-evolve-flash.md` — 主循环源码
- `agent/pitfalls/restart-incompatibility.md` — 重启失败详解
- `agent/pitfalls/mpi-errors.md` — MPI 相关问题

### 10.3 真实案例参考

- `cases/Sedov/setup_call` — 基础算例 setup
- `cases/LaserSlab/setup_call` — 激光算例 setup
- `cases/Sunliang_laser_CH/setup_call` — 多物种激光 setup

---

## 11. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-16 | 初始创建（5 个 recipe：Unsplit 默认 / Split / multithreaded / STS / Restart + 通用模板 + 检查清单） | claude |
