---
name: flash-laser
description: |
  FLASH 4.8 激光（EnergyDeposition/Laser）单元专家。
  覆盖全部 ed_* parfile 参数（38 全局 + pulse/beam 动态生成）、6 种内置截面函数 + 自定义方法、
  ray tracing 几何光学机制（临界密度、逆韧致吸收、折射）、2D RZ 3D-in-2D 模式、
  EnergyDeposition 内部调用图与数据结构（ed_beams/ed_pulses/ed_rays）、
  Config genLines Python 机制、典型 ICF 配置（super-Gaussian / 多束对称打靶）、
  12 类常见 abort 排查（编译/启动/运行/概念）。
  触发词：激光, laser, ed_, EnergyDeposition, ray tracing, 几何光学, 逆韧致, 临界密度,
        光斑, 脉冲, super-Gaussian, ICF, depo, EELE_VAR, gridWeight, genLines
triggers:
  # 中文
  - 激光
  - 光斑
  - 脉冲
  - 临界密度
  - 逆韧致
  - 几何光学
  - 沉积
  - 烧蚀
  - ICF
  - 平顶
  - 高斯
  - 环形
  - 多束
  # 英文（单元名 + 关键概念）
  - laser
  - Laser
  - EnergyDeposition
  - ray tracing
  - ray-tracing
  - geometric optics
  - inverse bremsstrahlung
  - critical density
  - super-Gaussian
  - flattop
  - ICF
  - gridWeight
  - genLines
  - CellAverage
  - CubicInterpolation
  - LaserSlab
  - LaserIO
  # 参数前缀（catch-all）
  - ed_
  - ed_maxBeams
  - ed_maxPulses
  - ed_maxRayCount
  - ed_numberOfBeams
  - ed_numberOfPulses
  - ed_numberOfRays
  - ed_wavelength
  - ed_pulseNumber
  - ed_crossSectionFunctionType
  - ed_gridType
  - ed_gaussianExponent
  - ed_gaussianRadius
  - ed_gaussianCenter
  - ed_lensX
  - ed_lensY
  - ed_lensZ
  - ed_lensSemiAxisMajor
  - ed_targetX
  - ed_targetY
  - ed_targetZ
  - ed_targetSemiAxisMajor
  - ed_targetSemiAxisMinor
  - ed_semiAxisMajorTorsionAxis
  - ed_semiAxisMajorTorsionAngle
  - ed_time
  - ed_power
  - ed_numberOfSections
  - ed_laser3Din2D
  - ed_laser3Din2DwedgeAngle
  - ed_gradOrder
  - ed_useLaserIO
  - ed_printBeams
  - ed_depoVarName
  - ed_rayZeroPower
  - ed_cellWallThicknessFactor
  - useEnergyDeposition
  - threadRayTrace
  # 源码关键标识
  - ed_beams
  - ed_pulses
  - ed_rays
  - RAY_POSX
  - RAY_POWR
  - RAY_BEAM
  - RAY_DENC
  - ed_setupBeams
  - ed_setupPulses
  - ed_setupRays
  - ed_createRays
  - ed_traceRays
  - ed_updatePlasma
  - ed_checkReuseDepo
  - ed_beamCrossSectionWeight
  - ed_beamCrossSectionFunctions
  - ed_inverseBremsstrahlungRate
  - ed_computeBeamPower
when_to_use: |
  调用本 skill 的场景：
  1. 用户问 ed_* 前缀的任何参数（含义/默认值/单位/怎么改）
  2. 用户问激光物理机制：临界密度 N_c、逆韧致吸收率 ν、折射、几何光学追踪
  3. 用户问 parfile 怎么写：圆光斑/椭圆/平顶 super-Gaussian/环形/多束
  4. 用户问自定义截面函数（如 flattopGaussian）的源码修改方法
  5. 用户问 2D RZ + 3D-in-2D 模式、wedge 角等几何配置
  6. 用户问 EnergyDeposition 单元源码（Config genLines、调用图、数据结构）
  7. 用户调试激光算例 abort（Not enough beam runtime parameters / Wrong time order / Negative pulse power 等）
  8. 用户问 depo 变量、EELE_VAR 沉积机制、能量守恒检查
  9. 用户问 LaserIO 可视化 ray 轨迹
  10. 用户提到 LaserSlab / Sunliang_laser_CH / laser_CH 算例
when_not_to_use: |
  **不调用本 skill 的场景**（即使问题里出现"laser"关键词）：
  - 涉及 rt_*（辐射传输）、mgd_*（多群扩散）参数 → `flash-radtrans`
    例："激光和 MGD 怎么耦合" → flash-radtrans
  - 涉及 hy_*（流体）参数 → `flash-hydro`
  - 涉及 EELE_VAR 的 EOS 计算机制（不是沉积机制） → `flash-eos`
  - 涉及 .cn4 / .imx / .ses 不透明度表 → `flash-material`
    （**重要**：激光用逆韧致公式，**不读 opacity 表**！改 opacity 不影响激光吸收）
  - 涉及 HYPRE / Diffuse 求解器 → `flash-diffuse`
  - 涉及纯源码定位（"这个函数在哪定义"）→ `flash-source-reader`
  - 涉及纯错误信息匹配（"这个 abort 什么意思"）→ `flash-pitfall-finder`
  - 涉及运行 setup/make/run → `flash-case-runner`
layer: knowledge
phase: 1
status: stable
created: 2026-06-17
last_updated: 2026-07-12
owner: user
---

# flash-laser — 激光（EnergyDeposition）单元专家

> **状态**：✅ stable（5 个 knowledge 文件齐全 + 5 道验收考题全部满分通过，2026-07-12）

## 1. 角色与边界

### 1.1 我是做什么的

回答 FLASH 中激光相关的所有问题。覆盖范围（按 knowledge 文件组织）：

| 范畴 | 详见 | 覆盖内容 |
|---|---|---|
| 物理原理 | `knowledge/overview.md` | 几何光学模型、临界密度、逆韧致吸收、折射、能量沉积到 EELE_VAR、grid vs cross-section 解耦 |
| 参数字典 | `knowledge/params.md` | 38 个全局参数 + pulse/beam 动态生成参数；setup 变量 vs runtime parameter；单位陷阱；白名单 |
| 内部实现 | `knowledge/internals.md` | EnergyDeposition_init / EnergyDeposition 调用图（含 mermaid）、ed_beams/ed_pulses/ed_rays 数据结构、Config genLines Python 机制 |
| 典型配置 | `knowledge/recipes.md` | 4 个完整 parfile 配置（最小可运行 / ICF super-Gaussian / 椭圆偏心扭转 / 6 束对称打靶）+ 环形补充 |
| 踩坑排查 | `knowledge/pitfalls.md` | 12 类 abort 排查（编译/启动/运行/概念）+ 通用调试流程 |
| 可直接抄的 parfile | `examples/*.par` | 3 个 parfile 片段，可 cp 到 case 目录直接跑 |

### 1.2 我不做什么

| 用户问题类型 | 归属 skill | 原因 |
|---|---|---|
| 辐射传输（rt_*、MGD） | `flash-radtrans` | 多群扩散是独立机制，与激光无能量耦合 |
| 流体求解（hy_*） | `flash-hydro` | Hydro 是另一个单元 |
| EOS / 三温耦合机制（EELE_VAR 怎么算） | `flash-eos` | 激光只**写入** EELE_VAR，计算温度靠 EOS |
| 不透明度表（.cn4 / .imx / op_*） | `flash-material` | **激光不读 opacity 表**，用逆韧致公式 |
| HYPRE / 扩散求解器 | `flash-diffuse` | 独立单元 |
| 找源码位置（"ed_setupBeams 在哪"） | `flash-source-reader` | 工具 skill |
| 错误信息匹配（abort 字符串） | `flash-pitfall-finder` | 工具 skill（会反过来查本 skill 的 pitfalls.md） |
| 运行 setup/make/run | `flash-case-runner` | 操作 skill |

## 2. 行为协议

### 2.1 接到查询时

1. **理解意图**：判断问题属于哪个范畴（参数/物理/源码/配置/调试）
2. **检索本 skill 的 knowledge/**：
   - 用 `rg -i '<keyword>' .claude/skills/flash-laser/knowledge/` 找相关段落
   - 命中 → 基于内容回答，**必须引用源码路径:行号**
   - 未命中 → 进入 2.3
3. **回答格式**：
   ```
   <直接答案>

   > **源码锚点**: source/path/file.F90:LXX
   > **相关参数**: <列出相关 ed_* runtime parameters>
   > **延伸**: <指向具体 knowledge 文件的章节>
   ```

### 2.2 涉及 parfile 修改时

1. 优先推荐 `examples/*.par` 中的现成配置
2. 如需定制，从最接近的 recipe 改起，不要从零写
3. 提醒单位（μm / cm / s / W / 度）
4. 提醒 `ed_maxBeams/Pulses/RayCount` 是否需要改（→ 重新 setup+make）

### 2.3 知识库未覆盖时

**严格禁止**编造答案。按下面流程：

1. 老实告诉用户："本 skill 当前 knowledge 未覆盖此问题"
2. 给出可能的解决路径：
   - 涉及代码 → 调用 `flash-source-reader`
   - 涉及物理原理 → 调用 `flash-manual-search`
   - 涉及 abort → 调用 `flash-pitfall-finder`
3. **询问用户**："要不要我生成草稿到 `agent/drafts/pending/`？"
4. 用户同意 → 按 `agent/TEMPLATES/knowledge-entry.md` 模板生成草稿

### 2.4 调试 abort 时

1. 提取 abort 信息中的 `[<routine_name>]` 前缀和 message
2. 在 `knowledge/pitfalls.md` 找匹配条目
3. 输出：错误原因 + 修复步骤 + 预防方法
4. 如未匹配，调用 `flash-pitfall-finder` 扩大搜索

## 3. knowledge/ 子目录索引

| 文件 | 内容 | 行数 | 状态 |
|---|---|---|---|
| `knowledge/overview.md` | 物理原理 + 设计动机（12 个源码锚点） | 430 | beta |
| `knowledge/params.md` | 38 全局参数 + pulse/beam 字典（7 个源码锚点） | 367 | beta |
| `knowledge/internals.md` | 调用图 + 数据结构 + genLines（9 个源码锚点） | 634 | beta |
| `knowledge/recipes.md` | 4+1 个典型配置（7 个源码锚点） | 552 | beta |
| `knowledge/pitfalls.md` | 12 条踩坑 + 调试流程（7 个源码锚点） | 468 | beta |

总计 ~2451 行 knowledge + 378 行 examples parfile。

## 4. examples/ 索引

| 文件 | 配置 | 适用 |
|---|---|---|
| `examples/minimal-gaussian.par` | Recipe 1 | 第一次配置 / 验证流程 |
| `examples/icf-supergaussian.par` | Recipe 2 | ICF 直接驱动 / 科研主力 |
| `examples/multi-beam-6.par` | Recipe 4 | 6 束对称打靶 |
| `examples/README.md` | 目录说明 | 选哪个文件 |

## 5. 示例问答（验收基准）

### Q1: 怎么把激光波长从 1.053 μm 改成 0.351 μm？
**A**: 直接改 parfile 里 `ed_wavelength_<i> = 0.351`（单位 μm）。注意临界密度 N_c ∝ 1/λ²，三倍频后 N_c 提高 9 倍，吸收特性会变。详见 `knowledge/overview.md §1.2`。

### Q2: 启动报 `ed_setupBeams: Not enough beam runtime parameters` 怎么解决？
**A**: `ed_numberOfBeams`（parfile）超过了 `ed_maxBeams`（setup 编译期，默认 6）。在 setup 命令加 `ed_maxBeams=N` 重新 setup+make。详见 `knowledge/pitfalls.md §B.1`。

### Q3: 我想做环形光斑（中心暗、亮环），parfile 怎么写？
**A**: `ed_crossSectionFunctionType_<i> = "gaussianInverse2D"`，注意 `targetSemiAxis > gaussianRadius` 截断边缘发散。详见 `knowledge/recipes.md §7`。

### Q4: 解释 `Driver_sourceTerms` 调用 `EnergyDeposition` 的顺序？
**A**: 默认在 sourceTerms 序列中后段（Heatexchange/Cool 之后）；`DRIVER_EDEARLY` 宏可让它排前。源码 `Driver/DriverMain/Driver_sourceTerms.F90:44-69`。详见 `knowledge/internals.md §2.1`。

### Q5: 我的激光沉积能量比预期少 30%，可能的原因？
**A**: 5 种可能：pulse 时段没覆盖 simTime、target 椭圆太小、grid 边界丢 ray、临界密度反射、单位错。诊断流程见 `knowledge/pitfalls.md §C.1`。

## 6. 待办

- [ ] 跑 5 道验收考题（Q1-Q5），全部答对则升级 stable
- [ ] 根据实际触发情况持续微调 description
- [ ] Phase 2+：根据用户提问补充更多 knowledge 条目（自动草稿 → 用户审核）

## 7. 关键源码入口（供 source-reader 调用参考）

| 想理解 | 看哪个文件 |
|---|---|
| 整体初始化流程 | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/EnergyDeposition_init.F90` |
| 每步执行流程 | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/EnergyDeposition.F90` |
| 参数生成机制 | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/Config` |
| pulse 表解析 | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserPulses/ed_setupPulses.F90` |
| beam 参数解析 + 白名单 | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserBeams/ed_setupBeams.F90` |
| 6 种截面函数实现 | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserBeams/ed_beamCrossSectionFunctions.F90` |
| gridWeight 归一化 | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserBeams/ed_beam3DGridWeightRadial.F90` |
| 2D RZ + 3D ray 追踪 | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserRayTrace/CellAverage/ed_traceBlockRays2DCyl3D.F90` |
| 逆韧致率公式 | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserUtilities/ed_inverseBremsstrahlungRate.F90` |
| 沉积到 EELE_VAR | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserUtilities/ed_updatePlasma.F90` |
| Driver 调用入口 | `source/Driver/DriverMain/Driver_sourceTerms.F90` |

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-06-17 | knowledge/overview.md 完成 | claude |
| 2026-06-17 | knowledge/params.md 完成 | claude |
| 2026-06-17 | knowledge/internals.md 完成 | claude |
| 2026-06-17 | knowledge/recipes.md 完成 | claude |
| 2026-06-17 | knowledge/pitfalls.md 完成 | claude |
| 2026-06-17 | examples/ 3 个 parfile + README 完成 | claude |
| 2026-07-10 | **按 D-007 全面精调 description**（升级 draft → beta）：扩展 triggers 到 80+ 个（含全部 ed_* 前缀、源码标识、新触发词如 gridWeight/genLines/CellAverage/depo/EELE_VAR）；扩充 when_to_use 为 10 类场景；明确 when_not_to_use（特别标注"激光不读 opacity 表"）；新增 §3 knowledge 索引和 §5 示例问答 | claude |
| 2026-07-12 | **升级 beta → stable**：5 道验收考题全部满分通过（用户评分）；flash-laser 成为第一个 stable 状态的 skill | claude |

## 9. 待办与已知问题

- [x] 跑 5 道验收考题，全部通过则升级 stable — **2026-07-12 全部满分**
- [ ] 在实际使用中观察触发率（每月 review）
- [ ] 若被误触发：强化 `when_not_to_use`
- [ ] 若漏触发：扩展 `description` 和 `triggers`
- [ ] 累积实战问题，定期补 knowledge 条目（按 D-004 自动扩写规则）
