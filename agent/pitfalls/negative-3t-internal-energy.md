---
title: 3T 内能变负导致 hy_uhd_unsplitUpdateMultiTemp abort（ICF 间接驱动首步崩溃）
category: 运行期数值 abort
severity: fatal（abort）
first_seen: 2026-08-05
last_verified: 2026-08-05
verifier: claude
status: stable
tags:
  - 3T
  - hydro
  - unsplit
  - icf
  - indirect-drive
  - negative-energy
  - hllc
  - cfl
---

# 3T 内能变负导致 hy_uhd_unsplitUpdateMultiTemp abort

## 错误信息

```
DRIVER_ABORT: [hy_uhd_unsplitUpdateMultiTemp] Negative 3T internal energy, CHECK LOG
```

通常在第 1-3 步内崩（dtinit 后 1-2 倍 dt）。源码 abort 处自带诊断信息：

```
You might be able to get things to keep running by trying
more diffusive hydro options (reduce CFL, order, etc...)
```

## 触发场景

经典 HEDP/ICF 启动场景，三个条件同时出现：
1. **3T + MGD 物理模式**（+mtmmmt +uhd3t +mgd）
2. **极高密度对比度**（≥1e3，典型 ICF 靶丸 cham vs target 是 1e6）
3. **辐射瞬时启动 / 强温度梯度**（边界辐射浴 t=0 直接施加 Tr=200 eV，与初始 290 K 物质相差 8000 倍）

FLASH 4.8 的 `ICF3D_CH` 算例（RadSlab 派生）首次运行就在 step 2 崩——CH 球（1.05 g/cc）外面 He（1e-6 g/cc），200 eV 恒定辐射浴从 6 面注入。

## 原因

### 数值机制

`hy_uhd_unsplitUpdateMultiTemp.F90` 在每个 CTU step 后检查 3T 内能：

```fortran
if(uion_adv < 0.0) ...  ! 离子能量 advection 后为负
if(uele_adv < 0.0) ...  ! 电子能量 advection 后为负
if(urad_adv < 0.0) ...  ! 辐射能量 advection 后为负
```

**触发链**：
1. 辐射浴 t=0 直接打到 cham/targ 界面
2. 第一个 CTU step 内，电子温度瞬间被加热（tele 从 290 K → 几百 eV）
3. 温度梯度极陡（dx = 1-5 μm 量级），HLLC Riemann solver 在强梯度界面给出**过冲的通量**
4. advection 通量把界面附近的电子/离子内能推成负值
5. abort

### 为什么 HLLC 崩

HLLC 求解器分辨接触间断（contact discontinuity），但在密度对比度 ≥1e3 的"硬"界面附近，接触分辨会给出非物理的内能分布。**HLL**（不分辨接触）反而更稳。

### 为什么 MC limiter 崩

MC limiter 是"锐利"的二阶 TVD limiter，在强梯度处允许大的斜率，加剧过冲。**minmod** 是"保守"的，更耗散但更稳。

## 修复

### 方法 A：组合降激进（推荐先试）

parfile 4 行改动：

```fortran
cfl            = 0.1        # 默认 0.4，降 4 倍 dt
order          = 1          # 默认 3，改一阶上风（最耗散）
slopeLimiter   = "minmod"   # 默认 "mc"，更耗散 limiter
RiemannSolver  = "hll"      # 默认 "hllc"，不分辨接触间断
```

代价：精度下降，但能跑通。**确认稳定后逐步放回**（先 order=2，再 cfl=0.2，再 hllc，每改一个观察几十步）。

### 方法 B：辐射源渐变启动（治本）

恒定辐射 → Gaussian 渐进：

```fortran
sim_radSourceType = 1              # 0=constant → 1=Gaussian
sim_radSourceTMin = 50.0           # 起始 50 eV
sim_radSourceTMax = 200.0          # 峰值 200 eV
sim_radSourcePeak = 5.0e-11        # 50 ps 峰值时刻
sim_radSourceFWHM = 2.0e-11        # 20 ps FWHM
```

辐射前 ~30 ps 渐升，烧蚀波平滑建立。

### 方法 C：CH 球预热

把初始温度从 290 K 提到 1 eV，避免 8000 倍温度跳变：

```fortran
sim_teleTarg = 11604.5             # 1 eV
sim_tionTarg = 11604.5
sim_tradTarg = 11604.5
```

### 方法 D：缩小密度对比度

```fortric
sim_rhoCham = 1.0e-3               # 默认 1e-6 → 1e-3，对比度从 1e6 降到 1e3
```

### 推荐组合

**方法 A 单独试**——4 行改动最快，能跑通就够。

如果方法 A 仍崩：A + B 组合（A 让 hydro 更稳，B 让驱动更软）。

## 源码锚点

- `source/physics/Hydro/HydroMain/unsplit_rad/multiTemp/hy_uhd_unsplitUpdateMultiTemp.F90:550-580` — abort 触发位置
- `source/physics/Hydro/HydroMain/unsplit_rad/multiTemp/hy_uhd_unsplitUpdateCastroLike.F90:905, 1373` — 同类 abort（Castro-like 变体）
- `source/Simulation/SimulationMain/RadSlab/Simulation_adjustEvolution.F90` — 辐射浴注入逻辑

## 预防

新算例启动时如果包含"3T + 高密度对比 + 辐射驱动"三件套，**默认就用 method A 的保守配置**，跑通后再放参数。不要直接用 LaserSlab/RadSlab 默认的 cfl=0.4 + order=3 + mc + hllc。

具体策略：
- ICF 间接驱动首跑：cfl=0.1, order=1, minmod, hll（方法 A 默认值）
- 跑过 100 步稳定后：cfl → 0.2
- 再稳定 100 步：order → 2
- 再稳定：RiemannSolver → hllc（如果需要接触分辨）

## 延伸

- 相关踩坑：[[eos-newton-convergence]] — EOS Newton 不收敛（同样可能由强温度梯度引发）
- 相关 skill：`flash-hydro/knowledge/pitfalls.md §C.1`（HLLC 在强激波崩）
- 相关源码：`hy_uhd_unsplitUpdateMultiTemp` 是 3T Unsplit (CTU) 的核心，每次 CTU step 后都检查

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-08-05 | 初始创建，来自 ICF3D_CH 算例调试（method A 验证有效）| claude |
