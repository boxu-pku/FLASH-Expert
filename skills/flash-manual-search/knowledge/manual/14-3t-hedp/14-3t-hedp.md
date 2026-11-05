---
title: 3T HEDP 能力（三温高能量密度物理）
skill: flash-eos
category: overview
source_anchors:
  - source/physics/Eos/EosMain/multiTemp/Config:1-10
  - source/physics/Hydro/HydroMain/unsplit/hy_uhd_3tConfig:1-5
  - source/physics/sourceTerms/Heatexchange/Config:1-5
  - source/physics/materialProperties/Conductivity/Config:1-5
  - source/physics/materialProperties/Opacity/Config:1-5
  - source/physics/RadTrans/RadTransMain/MGD/Config:1-5
  - source/physics/sourceTerms/EnergyDeposition/Config:1-5
  - source/Simulation/SimulationMain/LaserSlab/Config:1-10
manual_ref: "FLASH 4.8 User Guide §14 (3T HEDP) pp.213-216, PDF pp.231-235"
created: 2026-07-19
last_verified: 2026-07-19
verifier: opencode-ai
status: draft
tags:
  - 3T
  - HEDP
  - operator-split
  - multiTemp
  - heatexchange
  - electron-conduction
  - MGD
  - laser-deposition
  - LaserSlab
---

# 3T HEDP 能力（§14）

> **TL;DR**：§14 是 FLASH HEDP 套件的"总纲"章节（仅 4 页）。它不引入新代码，而是展示 7 个单元（Hydro multiTemp + Eos multiTemp + Heatexchange + Diffuse/Conductivity + RadTrans/MGD + EnergyDeposition/Laser + Opacity）如何协作求解三温（$T_{\text{ion}} \neq T_{\text{ele}} \neq T_{\text{rad}}$）欧拉方程组 + 辐射扩散 + 激光沉积。完整示例见 `LaserSlab` 算例（§35.7.5）。

## 1. 物理方程组

### 1.1 质量、动量和总能量守恒（式 14.1）

$$\frac{\partial\rho}{\partial t} + \nabla\cdot(\rho\mathbf{v}) = 0$$

$$\frac{\partial}{\partial t}(\rho\mathbf{v}) + \nabla\cdot(\rho\mathbf{v}\mathbf{v}) + \nabla P_{\text{tot}} = 0$$

$$\frac{\partial}{\partial t}(\rho E_{\text{tot}}) + \nabla\cdot[(\rho E_{\text{tot}} + P_{\text{tot}})\mathbf{v}] = Q_{\text{las}} - \nabla\cdot\mathbf{q}$$

其中：
- $P_{\text{tot}} = P_{\text{ion}} + P_{\text{ele}} + P_{\text{rad}}$（式 14.2）
- $E_{\text{tot}} = e_{\text{ion}} + e_{\text{ele}} + e_{\text{rad}} + \frac{1}{2}\mathbf{v}\cdot\mathbf{v}$（式 14.3）
- $\mathbf{q} = \mathbf{q}_{\text{ele}} + \mathbf{q}_{\text{rad}}$（式 14.4，总热流 = 电子传导 + 辐射）
- $Q_{\text{las}}$ = 激光加热源项

### 1.2 分量内能方程（式 14.5）

$$\frac{\partial}{\partial t}(\rho e_{\text{ion}}) + \nabla\cdot(\rho e_{\text{ion}}\mathbf{v}) + P_{\text{ion}}\nabla\cdot\mathbf{v} = \rho\frac{c_{v,\text{ele}}}{\tau_{ei}}(T_{\text{ele}} - T_{\text{ion}})$$

$$\frac{\partial}{\partial t}(\rho e_{\text{ele}}) + \nabla\cdot(\rho e_{\text{ele}}\mathbf{v}) + P_{\text{ele}}\nabla\cdot\mathbf{v} = \rho\frac{c_{v,\text{ele}}}{\tau_{ei}}(T_{\text{ion}} - T_{\text{ele}}) - \nabla\cdot\mathbf{q}_{\text{ele}} + Q_{\text{abs}} - Q_{\text{emis}} + Q_{\text{las}}$$

$$\frac{\partial}{\partial t}(\rho e_{\text{rad}}) + \nabla\cdot(\rho e_{\text{rad}}\mathbf{v}) + P_{\text{rad}}\nabla\cdot\mathbf{v} = \nabla\cdot\mathbf{q}_{\text{rad}} - Q_{\text{abs}} + Q_{\text{emis}}$$

## 2. Operator-Split 分解

FLASH 将 14.5 式 operator-split 为如下子问题：

| 子问题 | 负责单元 | 相关章节 |
|---|---|---|
| **Hydro 平流 + 功**（式 14.6） | Hydro multiTemp | §15.1.5 |
| **离子-电子平衡**（式 14.8） | Heatexchange | §18.5.1 |
| **电子热传导**（式 14.10） | Diffuse + Conductivity | §19 + §23.1 |
| **辐射扩散**（MGD） | RadTrans + Opacity | §25 + §23.5 |
| **激光沉积** | EnergyDeposition / Laser | §18.4 |

## 3. 各分量贡献的单元目录

| 物理效应 | FLASH 单元 | setup 快捷 | 源码路径 |
|---|---|---|---|
| 3T 流体力学 | Hydro Unsplit multiTemp | `+uhd3t` | `physics/Hydro/HydroMain/unsplit/hy_uhd_3tConfig` |
| 3T 状态方程 | Eos multiTemp | `+mtmmmt` | `physics/Eos/EosMain/multiTemp/` |
| 离子-电子热平衡 | Heatexchange | `+laser` 自动 | `physics/sourceTerms/Heatexchange/` |
| 电子热导率 | Conductivity | `+laser` 自动 | `physics/materialProperties/Conductivity/` |
| 隐式扩散求解 | Diffuse（调用 HYPRE） | `+hypre` | 见 §19 |
| 多群辐射扩散 | RadTrans MGD | `+mgd` | `physics/RadTrans/RadTransMain/MGD/` |
| 不透明度 | Opacity | `+mgd` 隐含 | `physics/materialProperties/Opacity/` |
| 激光能量沉积 | EnergyDeposition / Laser | `+laser` | `physics/sourceTerms/EnergyDeposition/` |

### 3.1 典型 setup 命令

```bash
./setup LaserSlab -2d -auto +cylindrical -nxb=16 -nyb=16 \
  +hdf5typeio species=cham,targ +mtmmmt +laser +mgd mgd_meshgroups=6 \
  -objdir=cases/LaserSlab -parfile=example.par
```

**源码验证**：`source/Simulation/SimulationMain/LaserSlab/Config:1-10` 包含了 required units 的完整声明，可作为 HEDP 算例的模板。

## 4. 典型 HEDP 模拟的时间步循环

```
每一时间步:
  1. Hydro (3T unsplit):
     求解式 14.6（平流 + 功）
     Eos_wrapped 更新分量压力和声速

  2. Heatexchange:
     求解式 14.8（离子-电子温度平衡）

  3. Diffuse (electron conduction):
     求解式 14.10（隐式电子热传导）
     Conductivity 提供 Kele

  4. RadTrans (MGD):
     求解式 25.6（隐式多群辐射扩散）
     Opacity 提供 σa, σt, σe
     HYPRE 求解隐式方程组

  5. EnergyDeposition (Laser):
     光线追踪 → 逆韧致吸收 → Qlas 沉积到 EELE_VAR

  6. 计算新时间步 ∆t
```

实际调度顺序由 `Driver_sourceTerms` 和 `EnergyDeposition` 在 Driver 主循环中的位置决定。3T 的 HYDRO 步骤见 §15.1.5。

## 5. 包含的验证算例

| 算例 | 印刷页 | 测试内容 |
|---|---|---|
| MGDInfinite | §35.6.1 | 0D 电子-离子-辐射能量交换 |
| MGDStep | §35.6.2 | 1D 电子传导 + 离子-离子平衡 + MGD |
| ShafranovShock | §35.8.1 | 1D 无辐射冲击波（$T_{\text{ele}} \neq T_{\text{ion}}$） |
| GrayDiffRadShock | §35.8.2 | 1D 辐射冲击波结构 |
| ReinickeMeyer | §35.8.3 | 球面爆炸波 + 热传导 |
| **LaserSlab** | **§35.7.5** | **全物理 2D（3T + 表驱动 EOS + MGD + 电子传导 + 激光）** |

## 6. 已知陷阱

| 问题 | 说明 |
|---|---|
| 3T 流体做功项处理 | 冲击波处发散，需特殊处理（见 §15.1.5 的两种方法） |
| 辐射温度 ≠ 黑体平衡 | `Trad` 仅表示总辐射能密度的温度等效值（$T_{\text{rad}} = (u_{\text{rad}}/a)^{1/4}$），不等于假设黑体平衡 |
| 多群辐射扩散与维数 | 3T 中辐射场频率依赖而非灰色近似，$N_g$ 群数决定精度与计算代价平衡 |
| 各组件耦合 | 7 个独立单元需 setup 正确包含（`+mtmmmt +laser +mgd +hypre` 等快捷方式可简化） |
| 计算代价 | 全物理 HEDP 模拟开销巨大，建议从 MGDInfinite/MGDStep 逐步验证再到 LaserSlab |

## 7. 延伸阅读

- §14（本篇）HEDP 总纲
- §15.1.5 Hydro multiTemp：3T 流体力学实现
- §17.4 multiTemp EOS：3T 状态方程
- §18.4 Laser Deposition：激光光线追踪
- §18.5 Heatexchange：离子-电子平衡
- §19 Diffuse：隐式扩散求解器
- §23 Opacity + Conductivity：物质属性
- §25 RadTrans / MGD：多群辐射扩散
- §35.7.5 LaserSlab：完整 HEDP 算例

## 8. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft，基于 FLASH 4.8 UG §14 pp.213-216 + 源码对照 v4.8） | opencode-ai |
