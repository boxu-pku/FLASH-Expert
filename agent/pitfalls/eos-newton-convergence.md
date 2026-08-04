---
title: EOS Newton-Raphson 不收敛（低密度 + 高温度 + 混合物质）
category: 运行期数值
severity: fatal（abort）
first_seen: 2026-08-02
last_verified: 2026-08-03
verifier: claude
status: stable
tags:
  - eos
  - newton
  - convergence
  - multitype
  - 混合物质
---

# EOS Newton-Raphson 不收敛（低密度 + 高温度 + 混合物质）

## 错误信息

```
Newton-Raphson failed in multitemp, multitype Eos.F90
MODE_DENS_EI_ION
INPUTS:
mass density                 =    1.011E-05
ion specific internal energy =    1.382E+12

CURRENT ITERATION:
ion temperature              =    6.321E+04
mass fractions:
  cham   1.884E-01
  tar1   8.116E-01

 too many iterations, reached          50

DRIVER_ABORT: [Eos] Error: too many iterations in Newton-Raphson
```

## 原因

cham（He，极低密度 ~1e-5 g/cm³）和 tar1（CH）的**界面混合区域**出现极端物理条件：

1. **激光直接打在物质界面上** → 界面处密度极低但能量沉积极高
2. **EOS 表外推**：polystyrene-imx-008.cn4 在 (ρ~1e-5, e~1e12) 组合下超出表的有效范围
3. **混合物质的 Abar/Zbar 跳变**：cham(Z=2) + tar1(Z=6) 混合使 Newton 迭代不稳定

## 修复（3 项，组合使用）

### 修复 1：放宽 EOS 迭代参数

```fortran
eos_maxNewton  = 100      # 默认 50 → 100
eos_tolerance  = 1.e-6    # 默认 1e-8 → 1e-6
smlrho         = 1.e-10   # 加密度 floor
smalle         = 1.e-10   # 加内能 floor
```

### 修复 2：缩小激光光斑（避免直射界面）

```fortran
# 激光半径 < 靶半径，留余量避免直射 cham/tar 界面
ed_targetSemiAxisMajor_1 = 150.0e-04   # 原 200μm（= 靶半径）
ed_gaussianRadiusMajor_1 = 150.e-04
```

**为什么**：激光半径 = 靶半径时光斑边缘直射物质界面，界面处 cham 密度极低（~1e-5）但被加热到极高温度，EOS 表无法收敛。缩小到 75% 靶面后，光斑完全在靶内部，避免界面极端条件。

### 修复 3：提高 cham 初始密度

```fortran
sim_rhoCham = 1.0e-4   # 原 1e-6 → 1e-4，减少界面密度对比度
```

## 验证

修复后 Sunliang_Xray 算例从 step 228 abort → **稳定跑到 1668+ 步（simTime 1.35 ns），无 abort**。

## 预防

- 激光光斑半径 ≤ 靶半径 × 80%（留 20% 余量）
- cham 初始密度 ≥ 1e-4 g/cm³（避免极低密度混合区）
- 新算例启动时先设 eos_maxNewton=100 + eos_tolerance=1e-6（保守起步）
