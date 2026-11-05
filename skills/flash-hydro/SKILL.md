---
name: flash-hydro
description: |
  FLASH 4.8 Hydro 单元专家（流体动力学求解器）。
  处理 6 个互斥变体（split: PPM/MHD_8Wave/RHD；unsplit: Hydro_Unsplit/MHD_StaggeredMesh；
  unsplit_rad: RadFLAH 辐射流体）；split (Strang) vs unsplit (CTU) 设计差异；
  Riemann solver 选择（HLL/HLLC/HLLD/Roe/LLF/Marquina/Hybrid，默认 HLLC）；
  slope limiter（minmod/MC/vanLeer/vanLeer15/hybrid/limited，默认 vanLeer）；
  特征变量限制（charLimiting）、3D CTU（CFL≤1）、shockDetect；
  MHD 处理：USM-CT（constrained transport）vs Powell 8-wave；
  12 个 Hydro_* 公共 API（Hydro/Hydro_init/Hydro_computeDt 等）+ ~50 个内部 hy_uhd_* 函数；
  EOS 截断（small/smlrho/smallp）、AMR flux correction、guard cell 填充策略。
  触发词：hydro, hy_, Riemann, HLL, HLLC, HLLD, Roe, CTU, MUSCL, PPM, WENO,
        CFL, courant, slope limiter, vanLeer, minmod, MC,
        unsplit, split, Strang, USM, MHD, 8wave, magnetic, Biermann, Hall,
        shockDetect, charLimiting, 3T, multiTemp
triggers:
  # 中文
  - 流体
  - 流体力学
  - 流体动力学
  - 激波
  - 黎曼
  - 黎曼求解器
  - 限制器
  - 斜率
  - 特征变量
  - 守恒
  - 守恒律
  - 通量
  - 通量修正
  - 磁场
  - 磁流体
  - 激波探测
  - 分裂
  - 维度分裂
  - 不分裂
  # 英文（单元名 + 关键概念）
  - Hydro
  - hydro
  - hydrodynamics
  - hydro_
  - hy_
  - hy_uhd
  - UHD
  - CTU
  - Corner Transport
  - MUSCL
  - PPM
  - Piecewise Parabolic
  - WENO
  - WENO5
  - WENOZ
  - GP
  - Godunov
  - Strang
  - split
  - unsplit
  - unsplitHydro
  - uhd
  - splitHydro
  - pureHydro
  # Riemann solver
  - Riemann
  - RiemannSolver
  - HLL
  - HLLC
  - HLLD
  - Roe
  - LLF
  - Lax-Friedrichs
  - Marquina
  - Hybrid
  - flux
  - fluxes
  - flux_correct
  - flux correction
  # Limiter
  - limiter
  - slope
  - vanLeer
  - vanLeer15
  - minmod
  - MC
  - monotonized central
  - TVD
  - charLimiting
  - characteristic
  - hybridOrder
  - PosPreserv
  - steepening
  - flattening
  # Shock
  - shock
  - shockDetect
  - shockStrength
  - shockLowerCFL
  - Balsara
  # CFL / timestep
  - CFL
  - cfl
  - courant
  - computeDt
  - hydroComputeDtOption
  - cvisc
  - artificial viscosity
  # MHD
  - MHD
  - magnetic
  - magnetic field
  - magnetic pressure
  - 8wave
  - 8-wave
  - Powell
  - USM
  - usm
  - staggered mesh
  - constrained transport
  - CT
  - killdivb
  - killdivb8w
  - divB
  - divergence cleaning
  - MAGX_VAR
  - MAGY_VAR
  - MAGZ_VAR
  - MAGP_VAR
  - DIVB_VAR
  - FACEVAR
  - facevarx
  - facevary
  - facevarz
  - Hall
  - Nernst
  - Biermann
  - CrossField
  - Seebeck
  - resistive
  - hyperResistivity
  # 3T / multi-fluid
  - 3T
  - three temperature
  - multiTemp
  - 3t
  - usm3t
  - multiFluid
  - VOF
  # 关键参数
  - useHydro
  - updateHydroFluxes
  - order
  - spatialOrder
  - hy_3Torder
  - transOrder
  - slopeLimiter
  - LimitedSlopeBeta
  - use_3dFullCTU
  - use_hybridOrder
  - PosKappa1
  - PosKappa2
  - use_avisc
  - use_upwindTVD
  - conserveAngMom
  - use_auxEintEqn
  - EOSforRiemann
  - energyFix
  - ForceHydroLimit
  - prolMethod
  - use_Biermann
  - use_Hall
  - use_Nernst
  - use_CrossField
  - currFlMode
  - entropy
  - entropyFixMethod
  # 截断
  - small
  - smlrho
  - smallp
  - smalle
  - smallt
  - smallu
  - smallx
  # 源文件
  - hy_uhd_unsplit
  - hy_uhd_getRiemannState
  - hy_uhd_getFaceFlux
  - hy_uhd_unsplitUpdate
  - hy_uhd_prim2con
  - hy_uhd_con2prim
  - hy_uhd_TVDslope
  - hy_uhd_shockDetect
  - hy_uhd_HLL
  - hy_uhd_HLLC
  - hy_uhd_HLLD
  - hy_uhd_Roe
  - hy_uhd_LLF
  - hy_uhd_Marquina
  - hy_uhd_staggeredDivb
  - hy_uhd_getElectricFields
  - hy_uhd_addHallFluxes
  - hy_uhd_addBiermannFluxes
  - hy_uhd_addNernstFluxes
  - hy_uhd_addResistiveFluxes
  - hy_uhd_energyFix
  - hy_ppm_sweep
  - hy_8wv_sweep
  - hy_slopeLimiters
  - Hydro_computeDt
  - Hydro_init
when_to_use: |
  调用本 skill 的场景：
  1. 用户问 Hydro 变体选择（"split vs unsplit"、"+usm 还是 +8wave"、"为什么默认 unsplit"）
  2. 用户问 Riemann solver（"HLLC vs Roe"、"哪个更稳"、"默认是哪个"）
  3. 用户问 slope limiter（"vanLeer 和 MC 哪个好"、"charLimiting 是什么"）
  4. 用户问 CFL / 时间步（"hy_cfl 怎么取"、"CFL 太大怎样"、"hydroComputeDtOption"）
  5. 用户问 MHD（"USM vs 8-wave"、"CT 是什么"、"killdivb"、"Hall 项"）
  6. 用户问激波处理（"shockDetect"、"激波附近负密度"、"Hybrid Riemann"）
  7. 用户问 3T（"3Torder"、"三个温度怎么算"、"usm3t"）
  8. 用户问数值发散（"出现 NaN"、"密度变负"、"能量不守恒"）
  9. 用户问 PPM/WENO（"order=3 还是 5"、"PPM-Upwind 何时用"）
  10. 用户问 setup 命令（"+usm"、"+uhd"、"+splitHydro"、"+mhd"）
when_not_to_use: |
  **不调用本 skill 的场景**：
  - 网格 / AMR / 几何 / Grid_* API → `flash-grid`
  - 主循环何时调 Hydro → `flash-driver`
  - 时间步计算（Driver_computeDt）→ `flash-driver`（Hydro 只提供 Hydro_computeDt）
  - EOS 内部机制（三温耦合怎么算） → `flash-eos`（Phase 2 后）
  - 找 Hydro_* 源码位置 → `flash-source-reader`
  - 错误信息匹配 → `flash-pitfall-finder`
  - 参数基本属性（不深入） → `flash-param-query`
  - 激光 / Burn / Cool 等 sourceTerm → 对应 `flash-laser` / `flash-sourceterms`
  - 跑算例 → `flash-case-runner`（Phase 3）
layer: knowledge
phase: 2
status: stable
created: 2026-06-17
last_updated: 2026-07-19
owner: user
---

# flash-hydro — Hydro 单元专家（流体动力学求解器）

> **状态**：✅ stable（5 道验收考题全部通过，2026-07-19；Phase 2 第三个 stable 知识层 skill）

## 1. 角色与边界

### 1.1 我是做什么的

回答 FLASH **Hydro 单元**相关的所有问题——FLASH 所有流体过程的"求解器核心"：

| 范畴 | 详见 |
|---|---|
| 物理原理 + 设计 | `knowledge/overview.md` — Hydro 角色、6 变体对比、split/unsplit 设计差异、MHD 处理 |
| 参数字典 | `knowledge/params.md` — CFL / Riemann / 限幅器 / 截断 / MHD 完整字典（~70 参数） |
| 内部实现 | `knowledge/internals.md` — 12 个公共 API + ~50 个 hy_uhd_* 调用图、CTU 流程、flux correction |
| 典型配置 | `knowledge/recipes.md` — split/unsplit setup + Riemann solver 选择 + MHD/3T 配置 |
| 踩坑排查 | `knowledge/pitfalls.md` — CFL 不稳、负密度、Riemann 选错、MHD divB 发散等 |

### 1.2 我不做什么

| 用户问题类型 | 归属 skill |
|---|---|
| Grid / AMR / 几何 | `flash-grid` |
| Driver 主循环何时调 Hydro | `flash-driver` |
| Driver_computeDt（全局 dt） | `flash-driver` |
| EOS 三温耦合机制 | `flash-eos`（Phase 2） |
| 找源码位置 | `flash-source-reader` |
| 错误匹配 | `flash-pitfall-finder` |
| 参数基本属性 | `flash-param-query` |
| 激光 / Burn / Cool | `flash-laser` / `flash-sourceterms` |
| 跑算例 | `flash-case-runner`（Phase 3） |

## 2. 行为协议

按 `agent/TEMPLATES/skill-template.md §2` 通用协议。核心要点（按 L-001~L-011）：

- **讲逻辑**（L-001）：不只是列 Riemann solver，讲清楚每个的物理含义、何时选
- **不用 mermaid**（L-002）：调用关系用文字+缩进
- **贴源码相关代码**（L-008）：abort 类查询贴 `Driver_abortFlash` 所在 if
- **核心 4 段 + 引导项**（L-010）：核心段必给详细，引导项按需展开
- **讲为什么**（L-011）：选择/配置/概念类问题必给"为什么这么设计/为什么默认这个值"
- **面向新手**：解释每个术语（"CTU"、"Riemann solver"、"特征变量"）

## 3. knowledge/ 子目录

| 文件 | 内容 |
|---|---|
| `knowledge/overview.md` | Hydro 角色 + 6 变体对比 + split/unsplit 设计差异 + MHD 处理（USM/CT vs Powell 8-wave） |
| `knowledge/params.md` | Hydro 参数完整字典（主控 / 重构 / Riemann / 限幅器 / 截断 / MHD / 3T） |
| `knowledge/internals.md` | 12 公共 API + hy_uhd_* 调用图 + CTU 流程 + AMR flux correction + guard cell 填充 |
| `knowledge/recipes.md` | 6 变体 setup + Riemann solver 选择 + MHD/3T 配置 + CFL 调优 |
| `knowledge/pitfalls.md` | 常见错误（CFL 不稳、负密度、Riemann 选错、divB 发散、CharLimiting 关掉等） |

## 4. examples/

| 文件 | 内容 |
|---|---|
| `examples/setup-unsplit.sh` | unsplit pure hydro（默认）setup 命令 |
| `examples/setup-usm-mhd.sh` | USM-MHD（unsplit + constrained transport）setup |
| `examples/setup-split-ppm.sh` | split PPM（燃烧算例）setup |
| `examples/parfile-hydro.txt` | Hydro 参数 parfile 片段（CFL/Riemann/限幅器/截断） |

## 5. 示例问答（验收基准）

### Q1: split 和 unsplit 有什么区别？默认是哪个？
**A**: 见 `knowledge/overview.md §3`。split = Strang 维度分裂（X→Y→Z 三次 1D sweep），unsplit = CTU 多维 Godunov 一次更新。**默认 unsplit/Hydro_Unsplit**（不指定时），因为 CTU 无分裂误差、支持 3T/MHD/多流体、单次调用更好并行。

### Q2: Riemann solver 选哪个？默认是？
**A**: 见 `knowledge/overview.md §5` + `knowledge/recipes.md §3`。**默认 HLLC**（恢复接触间断、不需 entropy fix）。MHD 推荐 HLLD；强激波鲁棒性用 Hybrid 或 Marquina；调试用 LLF。

### Q3: hy_cfl 设多少？为什么默认 0.8？
**A**: 见 `knowledge/params.md §1.3`。**默认 0.8**——CFL 接近理论上限 1（CTU 的稳定限），留 20% 余量给非线性。强激波降到 0.4-0.5；保守起步 0.3。

### Q4: MHD 用 +usm 还是 +8wave？
**A**: 见 `knowledge/overview.md §6` + `knowledge/recipes.md §4`。**默认 +usm**（USM-CT，∇·B 保持机器精度）；+8wave 是 Powell 8-wave 分裂法（更耗散但简单）。新算例用 USM；旧算例移植可能依赖 8-wave。

### Q5: 算例跑出 NaN / 负密度，可能原因？
**A**: 见 `knowledge/pitfalls.md §B`。5 类原因：CFL 太大、Riemann 选错（HLLC 在强激波可能崩）、截断太低（small/smlrho）、限幅器关掉（charLimiting）、AMR 边界 flux 不守恒。诊断流程：先看 NaN 出现位置 → 看是否激波附近 → 调 Riemann/CFL/限幅器。

## 6. 关键源码入口

| 想理解 | 看哪个文件 |
|---|---|
| Hydro 公共接口（12 函数） | `source/physics/Hydro/Hydro_interface.F90` |
| Hydro 主入口（每步调） | `source/physics/Hydro/Hydro.F90`（stub）→ `HydroMain/<variant>/Hydro.F90` |
| Hydro 初始化（读所有 hy_* 参数） | `source/physics/Hydro/HydroMain/unsplit/Hydro_init.F90` |
| unsplit 主流程 | `source/physics/Hydro/HydroMain/unsplit/Hydro_Unsplit/hy_uhd_unsplit.F90` |
| Riemann solver 调度 | `source/physics/Hydro/HydroMain/unsplit/hy_uhd_getFaceFlux.F90` |
| 各 Riemann solver 实现 | `source/physics/Hydro/HydroMain/unsplit/hy_uhd_{HLL,HLLC,Roe,LLF,Marquina}.F90` |
| HLLD（MHD 专用） | `source/physics/Hydro/HydroMain/unsplit/MHD_StaggeredMesh/hy_uhd_HLLD.F90` |
| Slope limiter 函数 | `source/physics/Hydro/HydroMain/hy_slopeLimiters.F90` |
| TVD slope 调度 | `source/physics/Hydro/HydroMain/unsplit/hy_uhd_TVDslope.F90` |
| 激波探测 | `source/physics/Hydro/HydroMain/unsplit/hy_uhd_shockDetect.F90` |
| CTU 保守更新 | `source/physics/Hydro/HydroMain/unsplit/hy_uhd_unsplitUpdate.F90` |
| 能量修正（避免灾难性消去） | `source/physics/Hydro/HydroMain/unsplit/hy_uhd_energyFix.F90` |
| MHD CT divB 清理 | `source/physics/Hydro/HydroMain/unsplit/MHD_StaggeredMesh/hy_uhd_staggeredDivb.F90` |
| MHD 电场计算 | `source/physics/Hydro/HydroMain/unsplit/MHD_StaggeredMesh/hy_uhd_getElectricFields.F90` |
| 时间步计算 | `source/physics/Hydro/HydroMain/unsplit/Hydro_computeDt.F90` |
| UHD 变量索引 | `source/physics/Hydro/HydroMain/unsplit/UHD.h`（HY_DENS, HY_VELX, ...） |
| 变体选择 Config | `source/physics/Hydro/HydroMain/Config` |
| Unsplit Config（~70 参数） | `source/physics/Hydro/HydroMain/unsplit/Config` |
| MHD USM Config | `source/physics/Hydro/HydroMain/unsplit/MHD_StaggeredMesh/Config` |
| Split PPM Config | `source/physics/Hydro/HydroMain/split/PPM/Config` |

## 7. 待办

- [ ] 跑 5 道验收考题，全部通过则升级 stable
- [ ] 持续累积踩坑（用户实战算例遇到 Hydro 相关问题时）
- [ ] Phase 2+ 后续 skill 协作验证（如 flash-eos 解释三温耦合，本 skill 解释 Hydro 怎么用）

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-07-19 | **升级 draft → beta**（Phase 2 第三个知识层 skill）：按 flash-laser/driver/grid 模板 + L-001~L-011 全部经验（特别强化 L-011 "讲为什么"）；扩展 triggers（150+ 关键词含全部 hy_/Hydro_/hy_uhd_ 前缀、6 变体、所有 Riemann solver、限幅器、MHD 概念、关键参数）；5 knowledge 文件齐 + 4 examples（3 setup 脚本 + 1 parfile 片段）；含完整 Hydro 单元讲解（6 变体 / split vs unsplit / Riemann 调度 / CTU 流程 / MHD CT / flux correction）；待验收 | claude |
| 2026-07-19 | **升级 beta → stable**：5 道验收考题全部通过；首轮反馈两条：(1) 公式 `$\\partial U/\\partial t$` CLI 不渲染 → 改 ASCII 代码块（Q1 重答）；(2) Q5 直接列原因没引导贴报错 → 加 Step 0 引导层（Q5 重答）→ 沉淀 L-012（诊断类先引导贴现场 + 公式 CLI 友好）+ 同步修订 flash-pitfall-finder §4；二轮通过；flash-hydro 成为 Phase 2 第三个 stable 知识层 skill | claude |
