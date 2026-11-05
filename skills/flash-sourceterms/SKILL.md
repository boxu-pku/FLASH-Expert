---
name: flash-sourceterms
description: |
  FLASH 4.8 sourceTerms 单元专家（非 Hydro 的源项）。
  按 L-013 聚焦主流量径——Heatexchange（HEDP 3T 算例的电子-离子能量平衡，LaserSlab 用 Spitzer 变体）；
  覆盖：5 个 Heatexchange 变体（Constant / ConstCoulomb / Spitzer ⭐ / LeeMore / Immediate）、
  Spitzer-Härm 平衡时间公式（eqtime ~ T³/²/（Z²·n·lnΛ））、Coulomb 对数 ln Λ、
  解析 ODE 解（指数衰减）、能量守恒（cvion·ΔTion + cvele·ΔTele = 0）、
  PlasmaState 工具（logLambda / ieEquilTime / tau）、
  Driver_sourceTerms 调用顺序（默认 7 位，激光默认 10 位）、
  Heatexchange_computeDt 时间步限制（hx_dtFactor）；
  非 HEDP 简要：Burn（核燃烧）/ Cool（辐射冷却）/ Heat（外热）/ Stir（湍流）/ Ionize（电离）/ Flame（火焰）/ Polytrope；
  EnergyDeposition（激光）归属 flash-laser skill，本 skill 只引用不重复。
  触发词：sourceterms, 源项, Heatexchange, 电子-离子平衡, Spitzer, Spitzer-Härm,
        LeeMore, Coulomb logarithm, ln Lambda, 等离子体状态,
        Burn, Cool, Heat, Stir, Ionize, Flame, Polytrope,
        3T 平衡, TEION, TELE, EION, EELE,
        hx_, useHeatexchange, hx_dtFactor, hx_ieTimeCoef, hx_relTol, hx_logLevel,
        PlasmaState, DRIVER_EDEARLY, operator-split
triggers:
  # 中文
  - 源项
  - 源条款
  - 能量交换
  - 热交换
  - 电子离子平衡
  - 三温平衡
  - 等离子体平衡
  - 库仑对数
  - 库仑碰撞
  - 斯皮策
  - 燃烧
  - 核燃烧
  - 辐射冷却
  - 加热源
  - 湍流驱动
  - 电离
  - 火焰
  - 多方
  # 英文
  - sourceTerms
  - sourceterms
  - source term
  - Heatexchange
  - heatexchange
  - HeatExchange
  - hx_
  - useHeatexchange
  - hx_dtFactor
  - hx_ieTimeCoef
  - hx_relTol
  - hx_logLevel
  - hx_couplingConst
  - Spitzer
  - Spitzer-Härm
  - SpitzerHaerm
  - LeeMore
  - Lee-More
  - ConstCoulomb
  - Immediate
  - Coulomb
  - Coulomb logarithm
  - ln Lambda
  - lnLambda
  - logLambda
  - PlasmaState
  - PlasmaState_ieEquilTime
  - PlasmaState_logLambda
  - PlasmaState_tau
  - equilibration
  - equilibration time
  - eqtime
  - ieEquilTime
  # 其他 sourceTerms（简要）
  - Burn
  - burn
  - useBurn
  - Cool
  - cool
  - useCool
  - Heat
  - useHeat
  - Stir
  - stir
  - useStir
  - Ionize
  - ionize
  - useIonize
  - Flame
  - flame
  - useFlame
  - Polytrope
  - polytrope
  - Turb
  - Deleptonize
  - PrimordialChemistry
  - Circuit
  # 调用顺序
  - DRIVER_EDEARLY
  - Driver_sourceTerms
  - operator-split
  - operator splitting
  - Strang
  # 3T / 变量
  - 3T
  - TEION
  - TELE
  - TERAD
  - EION_VAR
  - EELE_VAR
  - ERAD_VAR
  - TION_VAR
  - cvion
  - cvele
  - MODE_DENS_EI_MAT_EQUI
  # API
  - Heatexchange
  - Heatexchange_init
  - Heatexchange_finalize
  - Heatexchange_computeDt
  - Burn
  - Burn_init
  - Burn_computeDt
  - Cool
  - Cool_computeDt
  - Heat
  - Stir
  - Ionize
  - Flame_step
when_to_use: |
  调用本 skill 的场景：
  1. 用户问 Heatexchange（"电子-离子怎么平衡"、"Spitzer 公式"、"eqtime 怎么算"）
  2. 用户问 3T 平衡机制（"TELE 和 TEION 怎么趋同"、"为什么需要 Heatexchange"）
  3. 用户问 Heatexchange 变体选择（"Spitzer vs LeeMore"、"Immediate 是什么"）
  4. 用户问 Coulomb 对数（"ln Λ 怎么算"、"什么时候用 Lee-More"）
  5. 用户问 hx_dtFactor / hx_ieTimeCoef（"时间步怎么限制"、"为什么 LaserSlab 设 1e100"）
  6. 用户问 Driver_sourceTerms 调用顺序（"为什么激光默认第 10 位"、"DRIVER_EDEARLY 是什么"）
  7. 用户调试 Heatexchange（"TELE 不变"、"EELE 异常"、"能量不守恒"）
  8. 用户问其他 sourceTerms（"Burn 怎么用"、"Stir 是什么"）—— 简要回答，按 L-013 非 HEDP
  9. 用户问 sourceTerm 和 Hydro 的耦合（"operator-split 是什么"）
  10. 用户问 LaserSlab 配置 Heatexchange 的典型 parfile（hx_dtFactor=1e100 等）
when_not_to_use: |
  **不调用本 skill 的场景**：
  - 激光沉积（EnergyDeposition） → `flash-laser`（已详讲，本 skill 只引用）
  - EOS 三温耦合机制 → `flash-eos`
  - MGD 辐射扩散 → `flash-radtrans`
  - 不透明度 / 电导率表 → `flash-material`（Phase 2）
  - HYPRE 隐式求解 → `flash-diffuse`（Phase 2）
  - Driver 主循环 → `flash-driver`
  - Grid / AMR → `flash-grid`
  - 找 sourceTerms_* 源码位置 → `flash-source-reader`
  - 错误信息匹配 → `flash-pitfall-finder`
  - 参数基本属性 → `flash-param-query`
  - 跑算例 → `flash-case-runner`（Phase 3）
layer: knowledge
phase: 2
status: stable
created: 2026-06-17
last_updated: 2026-07-30
owner: user
---

# flash-sourceterms — sourceTerms 单元专家（非 Hydro 源项）

> **状态**：✅ stable（5 道验收考题全部通过，2026-07-30；Phase 2 第六个 stable 知识层 skill）
>
> **按 L-013 聚焦主流**：本 skill 主讲 **Heatexchange**（HEDP 3T 算例的电子-离子能量平衡，LaserSlab 用 Spitzer 变体）。其他 sourceTerms（Burn/Cool/Heat/Stir/Ionize/Flame/Polytrope）多用于天体物理，简要带过。EnergyDeposition（激光）归 `flash-laser` skill，本 skill 只引用。

## 1. 角色与边界

### 1.1 我是做什么的

回答 FLASH **sourceTerms 单元**相关问题——所有"非 Hydro 源项"的处理：

| 范畴 | 详见 |
|---|---|
| 物理原理 + 设计 | `knowledge/overview.md` — sourceTerms 角色 + Heatexchange 5 变体 + operator-split 设计 + 非 HEDP 简要 |
| 参数字典 | `knowledge/params.md` — useHeatexchange / hx_dtFactor / hx_ieTimeCoef / hx_relTol 等 |
| 内部实现 | `knowledge/internals.md` — Heatexchange.F90 主流程 + Spitzer 算法 + PlasmaState 耦合 |
| 典型配置 | `knowledge/recipes.md` — LaserSlab Heatexchange 配置 + 5 变体选择 + parfile |
| 踩坑排查 | `knowledge/pitfalls.md` — TELE 不变、EELE 异常、能量不守恒、hx_dtFactor 等陷阱 |

### 1.2 我不做什么

| 用户问题类型 | 归属 skill |
|---|---|
| 激光沉积（EnergyDeposition） | `flash-laser` |
| EOS 三温耦合 | `flash-eos` |
| MGD 辐射扩散 | `flash-radtrans` |
| 不透明度 / 电导率表 | `flash-material`（Phase 2） |
| HYPRE 隐式求解 | `flash-diffuse`（Phase 2） |
| Driver 主循环 | `flash-driver` |
| Grid / AMR | `flash-grid` |
| 找源码位置 | `flash-source-reader` |
| 错误匹配 | `flash-pitfall-finder` |
| 参数基本属性 | `flash-param-query` |

## 2. 行为协议

按 `agent/TEMPLATES/skill-template.md §2` 通用协议。核心要点（按 L-001~L-014）：

- **讲逻辑**（L-001）：不只是列 Heatexchange 变体，讲清楚每个的物理意义、何时选
- **不用 mermaid**（L-002）：调用关系用文字+缩进
- **贴源码相关代码**（L-008）：abort 类查询贴 `Driver_abortFlash` 所在 if
- **核心 4 段 + 引导项**（L-010）：核心段必给详细，引导项按需展开
- **讲为什么**（L-011）：选择/配置/概念类问题必给"为什么这么设计/为什么默认这个值"
- **诊断类先引导贴现场**（L-012）：NaN / 不收敛等先要用户贴日志/setup/parfile
- **公式 CLI 友好**（L-012）：用 ASCII / 代码块，不用 `$...$`
- **聚焦主流路径**（L-013）：Heatexchange 是主流，详讲；Burn/Cool/Heat/Stir/Ionize/Flame 简要
- **专业术语先解释**（L-014）：Spitzer-Härm / Coulomb logarithm / equilibration 等先定义再讲机制
- **面向新手**：解释每个术语（"operator-split"、"3T"、"cv"）

## 3. knowledge/ 子目录

| 文件 | 内容 |
|---|---|
| `knowledge/overview.md` | sourceTerms 角色 + Heatexchange 5 变体对比 + operator-split 设计动机 + 非 HEDP 简要 + 术语速查（L-014）|
| `knowledge/params.md` | Heatexchange 参数完整字典（主控 / Spitzer / LeeMore / 其他变体）|
| `knowledge/internals.md` | Heatexchange.F90 主流程 + Spitzer 解析 ODE 解 + PlasmaState 耦合 + Driver_sourceTerms 调用顺序 |
| `knowledge/recipes.md` | LaserSlab Heatexchange 配置 + 5 变体选择 + parfile + 调用顺序调整 |
| `knowledge/pitfalls.md` | 常见错误（TELE 不变、EELE 异常、能量不守恒、hx_dtFactor 陷阱、hxcouple 不存在等）|

## 4. examples/

| 文件 | 内容 |
|---|---|
| `examples/setup-heatexchange-spitzer.sh` | LaserSlab Heatexchange/Spitzer setup 命令（HEDP 标准） |
| `examples/parfile-heatexchange.txt` | Heatexchange 完整 parfile 片段（含 hx_dtFactor / hx_ieTimeCoef） |

## 5. 示例问答（验收基准）

### Q1: Heatexchange 是什么？为什么 HEDP 需要？
**A**: 见 `knowledge/overview.md §1-2`。**Heatexchange = 电子-离子（-辐射）能量平衡源项**。HEDP 中激光沉积到电子（fs 时间尺度），离子通过库仑碰撞慢慢被电子加热（ps 时间尺度）。**没有 Heatexchange**，TELE 和 TEION 会持续漂移，物理失真。Heatexchange 按 Spitzer-Härm 公式让两温度趋同。

### Q2: 5 个 Heatexchange 变体怎么选？默认是哪个？
**A**: 见 `knowledge/overview.md §3` + `knowledge/recipes.md §2`。**Config 默认 Constant**（简单测试），**LaserSlab 用 Spitzer**（HEDP 标准，含库仑对数自动计算）。高 Z 物质（Au、CH foam）用 **LeeMore**。调试或强制平衡用 **Immediate**。

### Q3: Spitzer-Härm 公式是什么？eqtime 怎么算？
**A**: 见 `knowledge/internals.md §3`。Spitzer-Härm 是经典弱耦合等离子体的电子-离子平衡时间公式：`eqtime ~ T_ele^(3/2) / (Z² · n_ion · ln Λ)`。ln Λ 由 PlasmaState_logLambda 算（典型 HEDP 值 1-10）。解析 ODE 解保证能量严格守恒。

### Q4: 为什么 LaserSlab 设 hx_dtFactor = 1e100？
**A**: 见 `knowledge/params.md §1.3` + `knowledge/recipes.md §3`。**默认 hx_dtFactor = 0.5**（每步最多交换一半内能）。但 LaserSlab 的 hydro dt 已被 CFL + 激光物理严格限制，Spitzer eqtime 通常远小于 dt_hydro，dt 限制会让步数过多。设 1e100 **禁用 HX dt 限制**，接受一步内全平衡（因为 eqtime << dt_hydro，物理合理）。

### Q5: Heatexchange 后 TELE/TEION 没变（能量不守恒）？
**A**: 见 `knowledge/pitfalls.md §B`。**先贴现场**（按 L-012）：日志、setup、parfile、TELE/TEION 范围。常见原因：(1) `useHeatexchange = .false.`（默认关）；(2) 没用 3T EOS（Heatexchange REQUIRES multiTemp）；(3) ENERGY_EXCHANGE_Fallback 触发（cv 跳变）；(4) DRIVER_EDEARLY 让激光在 Heatexchange 前（顺序错）。

## 6. 关键源码入口

| 想理解 | 看哪个文件 |
|---|---|
| Heatexchange 公共接口（4 函数） | `source/physics/sourceTerms/Heatexchange/Heatexchange_interface.F90` |
| Heatexchange 主入口（每步调） | `source/physics/sourceTerms/Heatexchange/Heatexchange.F90`（stub）→ `HeatexchangeMain/<variant>/Heatexchange.F90` |
| **Spitzer 实现**（LaserSlab 用） | `source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange.F90:L124-L307` |
| Spitzer 初始化 | `source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange_init.F90:L39-L48` |
| Spitzer 时间步计算 | `source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange_computeDt.F90` |
| LeeMore 实现（高 Z） | `source/physics/sourceTerms/Heatexchange/HeatexchangeMain/LeeMore/` |
| Immediate 实现（强制平衡） | `source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Immediate/` |
| Constant 变体（含 hxc13/hxc23 辐射耦合） | `source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Constant/` |
| Heatexchange 模块状态 | `source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Heatexchange_data.F90` |
| Heatexchange 顶层 Config | `source/physics/sourceTerms/Heatexchange/Config` |
| HeatexchangeMain Config | `source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Config` |
| Spitzer Config（hx_dtFactor 等） | `source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Config` |
| **Driver_sourceTerms 调用顺序** | `source/Driver/DriverMain/Driver_sourceTerms.F90:L55-L73` |
| Driver_computeDt（HX 注册） | `source/Driver/DriverMain/Driver_computeDt.F90:L393-L394` |
| PlasmaState 工具（ln Λ + eqtime） | `source/physics/utilities/PlasmaState/PlasmaStateMain/` |
| PlasmaState_ieEquilTime | `source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_ieEquilTime.F90:L36-L62` |
| PlasmaState_logLambda | `source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_logLambda.F90` |
| 其他 sourceTerms（Burn/Cool/Heat/Stir/Ionize/Flame/Polytrope） | `source/physics/sourceTerms/<Unit>/` |
| LaserSlab Config（REQUESTS Spitzer） | `source/Simulation/SimulationMain/LaserSlab/Config:L10` |
| LaserSlab flash.par（hx_dtFactor=1e100） | `source/Simulation/SimulationMain/LaserSlab/flash.par:L263` |

## 7. 待办

- [ ] 跑 5 道验收考题，全部通过则升级 stable
- [ ] 持续累积踩坑（用户实战 HEDP 算例遇到 Heatexchange 问题时）
- [ ] Phase 2+ 后续 skill 协作验证（如 flash-material 解释 Conductivity/SpitzerHighZ）

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-07-20 | **升级 draft → beta**（Phase 2 第六个知识层 skill）：按 flash-laser/driver/grid/hydro/eos/radtrans 模板 + L-001~L-014 全部经验（特别强化 L-013 聚焦 Heatexchange 主流 + L-014 解释 Spitzer-Härm/Coulomb logarithm 等术语）；扩展 triggers（150+ 关键词含全部 sourceTerms 名、Heatexchange 5 变体、hx_ 前缀、PlasmaState、Driver_sourceTerms）；5 knowledge 文件齐 + 2 examples（1 setup 脚本 + 1 parfile 片段）；含完整 Heatexchange 单元讲解（Spitzer 算法 / eqtime 公式 / 解析 ODE 解 / 能量守恒 / PlasmaState 耦合 / Driver 调用顺序 / 与 EOS/Hydro/Laser 协作）；按 L-013 主讲 Heatexchange（HEDP 主流）+ 简要带过 Burn/Cool/Heat/Stir/Ionize/Flame/Polytrope（非 HEDP）；EnergyDeposition（激光）只引用 flash-laser 不重复；待验收 | claude |
| 2026-07-30 | **升级 beta → stable**：5 道验收考题全部通过；flash-sourceterms 成为 Phase 2 第六个 stable 知识层 skill | claude |
