---
title: Sedov 爆炸算例——完整跑法（入门）
skill: flash-case-runner
category: recipe
case: Sedov
difficulty: 入门
estimated_time: 5-10 分钟（4 核）
physics: 纯 Hydro，单物质，无激光/MGD/3T
---

# Sedov 爆炸算例配方
> 路径约定：`$FLASH_ROOT` = FLASH 4.8 仓库根目录（本机 `/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8`）；`$FLASH_LIBS` = 外部库根目录（本机 `/home/ubuntu/local/flash/myFLASH4.8`）。其它机器按实际路径替换。


> Sedov 是 FLASH 的**入门算例**——最简单的纯 Hydro 模拟。如果你第一次跑 FLASH，从这里开始。
>
> **跑通 Sedov 的价值**：验证环境（MPI/编译/loader）配通了。如果 Sedov 都跑不通，肯定是环境问题不是物理问题。

## 1. 算例物理简介

**Sedov 爆炸** = 一个点源爆炸，能量在均匀介质中传播形成球面激波。1959 年 Sedov 给出自相似解析解，是经典的激波管验证问题。

**物理**：
- 单物质（默认 gamma=5/3 的理想气体）
- 单温（无 Tele/Tion/Trad 区分）
- 纯 Euler Hydro（无粘性、无磁、无重力）
- 笛卡尔 / 球坐标 2D 或 3D

**验证什么**：FLASH 的 Riemann solver + AMR 在激波传播上的精度和稳定性。

## 2. 完整跑法（4 步）

### 步骤 1: setup

```bash
cd $FLASH_ROOT

# Sedov 是最简单的 setup——无需任何 setup-variables
./setup Sedov -auto -objdir=cases/Sedov
```

**setup 命令解析**（L-011 讲为什么）：

| 参数 | 作用 |
|---|---|
| `Sedov` | 选 SimulationMain/Sedov 算例 |
| `-auto` | 跳过交互式 |
| `-objdir=cases/Sedov` | 输出到 cases/Sedov（本机约定） |

**为什么 Sedov 不需要 -2d / +laser 等**：Sedov Config 不依赖 setup-variables（不像 LaserSlab 必须指定 species=）。

### 步骤 2: make

```bash
cd cases/Sedov

# 本机 libmpi 冲突处理（虽然 Sedov 不用 HYPRE，但保险做）
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak
make -j4 2>&1 | tee make.log
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40

# 验证 flash4 生成
ls -lh flash4
# 应该看到 -rwxrwxr-x ... 30M+ ... flash4
```

**典型编译时间**：30s - 1 分钟（4 核）。

### 步骤 3: run

> **硬约束**：在 `cases/Sedov/01-data/` 里启动——所有输出（plt/chk/log）落 01-data，objdir 根目录只留编译产物。

```bash
# 必须先 source flash_env.sh（即使 Sedov 也用 MPI）
source $FLASH_ROOT/flash_env.sh

cd cases/Sedov
mkdir -p 01-data && cd 01-data

# 单进程跑（验证用）
mpirun -np 1 ../flash4 -par_file ../flash.par 2>&1 | tee flash.log

# 或多进程跑（4 核）
mpirun -np 4 ../flash4 -par_file ../flash.par 2>&1 | tee flash.log
```

**Sedov 默认 parfile**（`source/Simulation/SimulationMain/Sedov/flash.par`，setup 时复制到 objdir）：
- `sim_pAmbient = 1.E-5`（背景压力）
- `sim_rhoAmbient = 1.`（背景密度）
- `sim_expEnergy = 1.`（爆炸能量）
- `sim_rInit = 0.05`（爆炸区初始半径）
- `sim_xctr = 0.5`（爆炸中心 x）
- `sim_maxTime = 1.0`（模拟结束时间）

### 步骤 4: 看结果

```bash
# 看 plotfile 数量（输出都在 01-data/ 里）
ls cases/Sedov/01-data/*_hdf5_plt_*

# 看日志最后几行
tail -10 cases/Sedov/01-data/flash.log
# 应该看到 "Simulation completed successfully"

# 看 simTime 推进
grep -i "simTime\|simulation time" cases/Sedov/01-data/flash.log | tail -10

# 看 block 数演化（AMR 加密）
grep -i "block" cases/Sedov/01-data/flash.log | tail -20
```

**可视化**（用 Visit / Python）：
```bash
# Plotfile 是 HDF5 格式
# 用 flash Python 包：
# pip install flashph
# 或用 yt：pip install yt
```

## 3. 一键脚本

见 `examples/run-sedov.sh`：
```bash
bash $FLASH_ROOT/skills/flash-case-runner/examples/run-sedov.sh
```

## 4. 常见坑

### 4.1 libmpi 冲突（虽然 Sedov 不用 HYPRE）

**机制**：即使 Sedov 不链接 libHYPRE.so，flash4 仍依赖 mpich 的 libmpi。系统 libmpi.so.40 仍可能冲突。

**修复**：仍然 source flash_env.sh。**所有 FLASH 算例都必须 source**。

### 4.2 parfile 顶部 setup 注释可能错（L-009）

Sedov parfile 顶部可能写：
```
# setup: ./setup Sedov -2d +cartesian ...
```

**不要看注释，看 setup_call**：
```bash
cat cases/Sedov/setup_call
```

### 4.3 Sedov 跑出来没激波

**可能原因**：
- `sim_expEnergy = 0`（爆炸能量为 0）→ 检查 parfile
- `sim_rInit = 0`（爆炸区半径为 0）→ 至少 0.01
- 初值有问题 → 看 `Simulation_initBlock.F90`

### 4.4 Sedov 跑太久

**可能原因**：
- `sim_maxTime = 10`（默认 1.0，超过 5 就慢）
- AMR 加密太多 → 调 `lrefine_max = 3`

## 5. Sedov 配置变体（简要）

### 2D 笛卡尔（默认）

```bash
./setup Sedov -2d +cartesian -auto -objdir=cases/Sedov_2d_cart
```

### 2D 球坐标（球面爆炸）

```bash
./setup Sedov -2d -geometry=spherical -auto -objdir=cases/Sedov_2d_sph
```

### 3D（球面爆炸，最真实）

```bash
./setup Sedov -3d -auto -objdir=cases/Sedov_3d
# 注意：3D 比 2D 慢 10 倍以上
```

## 6. 验证标准

跑通后：
- [ ] `flash4` 生成
- [ ] `flash.log` 末尾有 "completed successfully"
- [ ] 至少 5+ plotfile 生成
- [ ] `simTime` 推进到 `sim_maxTime`
- [ ] 没看到 NaN / abort

如果都 OK，环境配通，可以跑更复杂的算例（如 LaserSlab）。

## 7. 关联

- 详细操作：`knowledge/overview.md` + `setup_guide.md` + `make_guide.md` + `run_guide.md`
- 一键脚本：`examples/run-sedov.sh`
- Hydro 物理原理：`flash-hydro` skill
- Sedov 源码：`source/Simulation/SimulationMain/Sedov/`
