---
title: ffpe-trap 触发 / NaN / 浮点异常
category: 运行期数值异常
severity: fatal（运行时 abort）
first_seen: 2026-06-17
last_verified: 2026-07-12
verifier: claude
status: beta
tags:
  - 数值
  - NaN
  - ffpe-trap
  - 浮点
  - debug
  - 数值溢出
---

# ffpe-trap 触发 / NaN / 浮点异常

## 错误信息

### 形式 1：ffpe-trap 触发（gfortran -debug 模式）
```
forrtl: error (65): floating invalid
forrtl: info (78): IEEE_INVALID_FLAG
forrtl: info (79): IEEE_DIVIDE_BY_ZERO_FLAG
forrtl: info (80): IEEE_OVERFLOW_FLAG

Image              PC                Routine            Line        Source
flash4             0000000001B23456  Unknown               Unknown  Unknown
...
```

### 形式 2：plotfile 出现 NaN
```python
import yt
ds = yt.load("01-data/lasslab_hdf5_plt_cnt_0010")
ad = ds.all_data()
print(ad["tele"].max())   # → nan
```

### 形式 3：日志主动报告
```
[Driver] step 123: NaN detected in DENS_VAR
```

### 形式 4：结果异常但不 abort
没有 error，但 TELE_VAR 出现 1e100、DENS_VAR 出现负值等非物理结果。

## 原因分类

| 类别 | 典型原因 | 出现频率 |
|---|---|---|
| **除零** | `gaussianRadius=0`、`targetSemiAxisMinor=0` | 高 |
| **数值溢出** | 自定义函数发散（如 gaussianInverse2D 没截断） | 中 |
| **CFL 违反** | 时间步过大，Hydro 不稳定 | 中 |
| **EOS 表外推** | T 或 ρ 超出表范围 | 中 |
| **物理初值错** | 初始密度为 0、负温度 | 低 |
| **AMR refinement 爆炸** | 强梯度处细化层数失控 | 低 |
| **MPI race condition** | 多线程 + 未保护共享数据 | 低 |

## 诊断流程

### Step 1：定位首次 NaN 出现的位置

```bash
# 看日志找最早出现 NaN 的步数
grep -n "NaN\|nan\|inf" 01-data/<basenm>.log | head -5
```

找到第 N 步首次出现。

### Step 2：定位哪些变量

加载第 N 步和 N-1 步的 plotfile，对比哪个变量首次变 NaN：
```python
import yt
import numpy as np
ds_prev = yt.load(f"01-data/lasslab_hdf5_plt_cnt_{N-1:04d}")
ds_now  = yt.load(f"01-data/lasslab_hdf5_plt_cnt_{N:04d}")

for var in ["dens", "tele", "tion", "trad", "pres", "depo"]:
    arr_prev = ds_prev.all_data()[var]
    arr_now  = ds_now.all_data()[var]
    nan_count = np.isnan(arr_now).sum()
    if nan_count > 0:
        print(f"{var}: {nan_count} NaN cells (prev: {np.isnan(arr_prev).sum()})")
```

### Step 3：定位 cell 位置

找到 NaN cell 后，看它在 domain 的哪里：
- 在边界 → BC 错（如 BC 类型与几何不匹配）
- 在 target 附近 → 物理模型问题（如激光沉积发散）
- 在 AMR refinement 边界 → prolongation/restriction 错
- 在强激波处 → CFL 不够或限幅器不够强

### Step 4：按类别排查

#### A. 除零（最常见）
```bash
# 搜源码找潜在除零（除法 + 可能零的分母）
rg "gaussianRadius|targetSemiAxis|aspectRatio.*=" .claude/skills/flash-laser/
```

parfile 检查：
- `ed_gaussianRadius*_<i>` 必须 > 0
- `ed_targetSemiAxisMinor_<i>` 必须 > 0
- 任何除法运算的分子分母都检查

#### B. 数值溢出
看自定义截面函数（如有），特别是 `gaussianInverse*` 没截断。

#### C. CFL 迱反
日志看 `dt decomposition`，找最大贡献者：
```
[Driver_computeDt] dt decomposition:
  Hydro:    1.23e-12
  Diffuse:  4.56e-13   ← 这个最小，决定 dt
  Laser:    -1
```
如果 dt 被压到极小但仍 abort，可能初值就有问题。

加大 `Courant_factor`（默认 0.8）到 0.4 看是否改善。

#### D. EOS 表外推
查 EOS 表的 (ρ, T) 范围。激光算例 T_e 可能飙到 10 keV+，超过表的覆盖范围。

#### E. 物理初值
```fortran
# Simulation_initBlock.F90 检查
if (sim_rhoAmbient <= 0) call Driver_abortFlash("negative density!")
if (sim_teleAmbient <= 0) call Driver_abortFlash("negative T_e!")
```

## 修复

### 临时修复（让算例能跑）

1. **去掉 -debug**：编译时不用 `-ffpe-trap`，让 NaN 静默传播（不推荐，掩盖问题）
2. **加大 cellWallThicknessFactor**：默认 1e-6 → 1e-4，增加数值裕度
3. **降低 Courant**：`Courant_factor = 0.4`（默认 0.8）

### 根因修复

按上面诊断流程找到原因后，针对性修：
- 除零：补保护代码（`if (denom > 0) then ... else default_value`）
- 自定义函数：加边界截断
- 初值错：改 `Simulation_initBlock.F90`
- EOS 表：换更宽范围的表

## 调试技巧

### 启用 -debug

```bash
./setup <problem> ... -debug -objdir=cases/<name>_debug
cd cases/<name>_debug && make -j4
```

`-debug` 用 `FFLAGS_DEBUG`，含 `-ffpe-trap=invalid,zero,overflow -fbounds-check -O0`。

### 二分法

如果是某个时间步开始 NaN，把那个步的 plotfile 当 restart 起点，逐步缩小到具体子步。

### 加打印

在可疑位置加：
```fortran
print *, "DEBUG before X: dens=", solnData(DENS_VAR, i, j, k)
! 调用 X
print *, "DEBUG after X: dens=", solnData(DENS_VAR, i, j, k)
```

## 源码锚点

- `cases/LaserSlab/Makefile.h:FFLAGS_DEBUG` — 含 -ffpe-trap 的 flag 定义
- `bin/setup.py` — `-debug` 选项处理
- 各物理单元的数值保护代码（搜 `if .* > 0` 或 `Driver_abortFlash.*negative`）

## 预防

- 数值密集型算例（强激波、激光、相对论）默认开 `-debug` 跑测试
- 自定义函数加边界保护
- 初值用 `Simulation_initBlock.F90` 严格检查
- EOS 表范围留余量（覆盖预期 T、ρ 的 2 倍）

## 延伸

- 激光特定 NaN 场景：`flash-laser/knowledge/pitfalls.md §C.3`
- Hydro 数值问题：`flash-hydro` skill（Phase 2）
- EOS 表外推：`flash-eos` skill（Phase 2）
