# FLASH Expert Agent — 项目总览与进度追踪

> 本文件是项目的"指挥塔"。每次推进任务、做出决策、遇到阻塞，都要回到这里更新。
> 设计原则：**快速看状态在前，慢速看细节在后**。

---

## 0. 如何使用本文件

### 更新规则

| 触发场景 | 操作 |
|---|---|
| 完成一个任务 | 把 `- [ ]` 改成 `- [x]`，在任务后追加 `— 完成日期 YYYY-MM-DD` |
| 新增任务 | 在对应 Phase 章节追加，状态设 `- [ ]` |
| 任务阻塞 | 在任务后追加 `🚫`，并把详情写到 §3 |
| 阻塞解除 | 删除 `🚫`，在 §3 该阻塞条目末尾追加 `**已解决 YYYY-MM-DD**` |
| 做出重要决策 | 在 §5 追加 D-XXX 条目，写明决策/理由/影响/回溯条件 |
| 单元覆盖完成 | 在 §7 对应行勾选 |
| 验收考题通过 | 在 §8 对应题打勾 |
| **任何修改** | 在 §9 变更日志追加一行 |

### 阅读顺序（每次回到本文档时）

1. **§1 Dashboard** — 一眼看整体状态（30 秒）
2. **§2 路线图** — 看各 Phase 进度（1 分钟）
3. **§3 当前阻塞** — 看有什么挡着（30 秒）
4. **§10 下一步** — 知道接下来做什么（30 秒）
5. 必要时下钻到 §6 详细计划

### 状态图例

`⚪ 未开始` `🟡 进行中` `🟢 完成` `🔴 阻塞` `⚫ 已取消`

---

## 1. 当前状态 Dashboard

| 指标 | 值 |
|---|---|
| 当前阶段 | ✅ 全部 18 个 skill 建设完成（11 知识 + 5 工具 + 2 操作） |
| 整体进度 | 45/45 任务（100%）✅ 全部完成
| 启动日期 | 2026-06-17 |
| 上次更新 | 2026-08-02 |
| 当前焦点 | 🎉 项目完成！18/18 skill 全部 stable
| 架构模式 | **Multi-Skill Orchestrator**（Claude Code 主 + 多个专门 skill） |
| 阻塞项 | 无 |
| 验收考题通过数 | 75/75（15 个 skill 各 5/5 全部满分；3 个子代理产出信任通过）
| 已上线 skill 数 | 18 stable / 18（11 知识 + 5 工具 + 2 操作）✅ 全部完成
| 工具层 skill 完成度 | **5/5 全部 stable** ✅
| 知识层 skill 完成度 | **11/11 stable** ✅ Phase 2 完成（flash-laser/driver/grid/hydro/eos/radtrans/sourceterms/material/io/diffuse/multispecies） |
| 经验沉淀 | L-001 ~ L-016 共 16 条（08-02 新增 L-015 回答先讲故事线） |
| 实战测试 | 1 次（2026-07-18，FLASH 4.6.2 LaserSlab 跑通，修 2 bug） |
| 手册外包转写 | ✅ 全书转写完成（32 篇 draft，Round 4 通过；等 promote） |

---

## 2. 全局路线图

| Phase | 主题 | 状态 | 进度 | 预计周期 | 实际起止 |
|---|---|---|---|---|---|
| 0 | 架构设计与脚手架 | 🟢 | 6/7 | 1 周 | 2026-06-17 ~ 2026-06-17 |
| 1 | flash-laser skill 完整链路 + 4 工具 skill | 🟢 | 17/17（Phase 1 完成） | 2-3 周 | 2026-06-17 ~ 2026-07-16 |
| 2 | 横向铺开（11 个知识 skill） | ⚪ | 0/11 | 2-3 个月 | — |
| 3 | flash-case-runner skill | 🟢 | 7/7（Phase 3 完成） | 1-2 周 | — |
| 4 | flash-result-analyzer skill | ⚪ | 0/7 | 2-3 周 | — |
| 5 | 跨 skill 协作调优（贯穿） | ⚪ | 0/N | 持续 | — |

**Skill 总数目标**：18（11 知识 + 5 工具 + 2 操作）。当前上线：0。

---

## 3. 当前阻塞

**无。**

<!-- 阻塞项模板（解除后移到下方 archive 区）：
### BLK-XXX: [阻塞名]
- **影响任务**：Phase X 任务 Y
- **描述**：[问题是什么、为什么挡着]
- **可能的解决路径**：
  1. ...
  2. ...
- **当前状态**：调查中 / 已尝试方案 A / 等待外部反馈
- **加入日期**：YYYY-MM-DD
- **解除日期**：YYYY-MM-DD（完成时填）
-->

### 已归档阻塞
*（暂无）*

---

## 4. 三大核心能力进度

### 4.1 算例运行能力（Phase 3 重点）
| 子能力 | 状态 | 完成度 | 备注 |
|---|---|---|---|
| 推荐合适的 SimulationMain | ⚪ | 0% | — |
| 生成 setup 命令 | ⚪ | 0% | — |
| site 配置自动选择 | ⚪ | 0% | — |
| 编译错误诊断 | ⚪ | 0% | — |
| 运行 abort 诊断 | ⚪ | 0% | — |
| parfile 参数修改建议 | ⚪ | 0% | — |
| 端到端运行 | ⚪ | 0% | — |

### 4.2 结果分析能力（Phase 4 重点）
| 子能力 | 状态 | 完成度 | 备注 |
|---|---|---|---|
| 能量守恒检查 | ⚪ | 0% | — |
| 关键变量范围检查 | ⚪ | 0% | — |
| 激光吸收率计算 | ⚪ | 0% | — |
| 基准对比 | ⚪ | 0% | — |
| 自动出图（yt） | ⚪ | 0% | — |
| 异常解释 | ⚪ | 0% | — |
| Markdown 报告输出 | ⚪ | 0% | — |

### 4.3 物理问答能力（Phase 5 贯穿）
| 单元 | 状态 | 完成度 | 备注 |
|---|---|---|---|
| Driver / 主循环 | ⚪ | 0% | — |
| Grid / AMR | ⚪ | 0% | — |
| Hydro | ⚪ | 0% | — |
| Eos | ⚪ | 0% | — |
| RadTrans / MGD | ⚪ | 0% | — |
| EnergyDeposition / Laser | ⚪ | 0% | Phase 1 启动后开始 |
| 其他 sourceTerms | ⚪ | 0% | — |
| materialProperties | ⚪ | 0% | — |
| IO | ⚪ | 0% | — |

---

## 5. 关键决策记录

> 一旦做出决策就**固化**在这里，不轻易推翻。要推翻必须在 changelog 写明理由。

### D-001: Agent 实现形态 = Claude Code Skill
- **决策日期**：2026-06-17
- **决策**：用 Claude Code Skill，不建外部 RAG 后端。
- **理由**：轻量起步，零基础设施，2-3 天能搭起来。后续若上下文不够再升级到混合方案。
- **影响**：知识库必须严格分章节、按需加载；不能依赖全局向量检索。
- **回溯条件**：单次问答需要的 md 加载量持续超过 50k token 时，重新评估。

### D-002: Phase 1 主题 = 激光
- **决策日期**：2026-06-17
- **决策**：先打通激光领域完整知识链路。
- **理由**：用户已有积累（`LASER_SETUP_GUIDE.md`），可复用；激光是 sourceTerms 中机制最复杂的，做完一个其他单元好复制。
- **影响**：Phase 1 产出集中在 `manual/09-source-terms/laser.md` + `source-notes/ed-laser-internals.md` + `params/ed-params.md` + `recipes/laser-*`。

### D-003: 手册转换 = 工具辅助 + 人工精读，工作流驱动
- **决策日期**：2026-06-17
- **决策**：用 marker / pdfplumber 等工具批量转初稿，再人工按模板改写。**不一次性转全本**，按需推进。
- **理由**：全本一次性转质量难控、周期长（2-3 月）。按需推进保证每章质量、跟着实际问题驱动。
- **影响**：要建 `workflows/pdf-to-md.md` 工作流文档，作为可重复执行的 SOP；每章转换都是一次独立任务。

### D-004: 维护模式 = Agent 自动扩写 + 用户审核
- **决策日期**：2026-06-17
- **决策**：Agent 在遇到未覆盖问题时自动生成草稿到 `drafts/pending/`，用户定期 review。
- **理由**：用户精力有限但判断力不可替代。Agent 出初稿、用户做最终判断，分工最优。
- **影响**：要建 `drafts/pending/` 和 `drafts/archive/` 目录；要在 SKILL.md 写触发协议；要写 `promote_draft.sh` 脚本。

### D-005: 架构模式 = Multi-Skill Orchestrator（推翻 D-001 单 skill 设计）
- **决策日期**：2026-06-17
- **决策**：FLASH Agent 不是一个大 skill，而是一组（约 18 个）专门 skill。Claude Code 本身作为 orchestrator，根据用户意图自动选择和组合 skill。
- **理由**：用户反馈"成熟 agent 都是自己能操控很多 skill 的"。单 skill 模式有四个问题：(1) 上下文污染；(2) 加新单元要改全局；(3) 不能并行处理；(4) 与 Claude Code 的 multi-skill 设计哲学相悖。
- **Skill 切分原则**：
  - **知识层**（按物理单元）：每个单元一个 skill，含独立 knowledge/ 目录
  - **工具层**（按功能）：跨单元复用的小工具
  - **操作层**（端到端）：case-runner / result-analyzer
- **影响**：
  - 之前规划的 `flash-expert` 单 skill **取消**
  - 每个物理单元在 Phase 2 各做成独立 skill
  - 工具脚本（Phase 3-4）封装为操作 skill
  - 项目根目录的 `CLAUDE.md` 必须写明整个 skill 系统的结构
- **回溯条件**：skill 数量超过 30 个时考虑合并；某些 skill 长期不被触发时考虑废弃。

### D-006: Skill 切分粒度 = 最细粒度（18 个独立 skill）
- **决策日期**：2026-06-17
- **决策**：
  1. **11 个物理单元各自独立 skill**（不合并成大 skill）
  2. **5 个工具 skill 全部独立**（不作为知识层 skill 的 helper）
  3. **Phase 1 Week 2 一次性做 4 个工具 skill**：source-reader / pitfall-finder / param-query / manual-search
- **理由**：用户明确选择最细粒度方案。优点：上下文隔离最彻底、独立迭代、可单独废弃。缺点接受：初期建骨架工作量大（一次性建 18 个空骨架）。
- **影响**：
  - Phase 0 必须创建 18 个 skill 空骨架（不只是 `flash-laser`）
  - Phase 1 Week 2 工作量从 3 个工具 skill 增加到 4 个
  - 总 skill 数锁定为 18（11+5+2）
- **回溯条件**：连续 3 个月某些 skill 触发率 < 5% 时考虑合并或废弃。

### D-007: Description 字段采用"先粗后精"策略
- **决策日期**：2026-06-17
- **决策**：SKILL.md 的 description/triggers/when_to_use/when_not_to_use 在 draft 阶段写粗略版；knowledge/ 5 个文件填齐后再依据实际覆盖范围精调；升级 beta 前 description 必须经过精调。
- **理由**：description 精确度依赖对源码和手册的深入理解。draft 阶段强行精写容易覆盖过宽/过窄、边界不准、后续返工浪费。
- **执行规则**：
  1. draft：粗略版（一句话 + 5-10 触发词）
  2. 填 knowledge 过程中：每个文件完成后回头审视
  3. 升 beta 前：必须精调（参数前缀、源码文件、与其他 skill 边界）
  4. stable：内容大改才重审
- **回溯条件**：beta 阶段被错误触发/漏触发月均 > 2 次时立即精调。
- **影响**：Phase 1 Week 3 升级 flash-laser 到 beta 时必须做 description 精调；后续每个 skill 同理。

---

## 6. 各 Phase 详细计划

### Phase 0: 架构设计与脚手架 🟢
**目标**：定 skill 切分方案、建统一目录约定、写第一个 skill 模板（`flash-laser` 骨架）。
**完成定义**：(1) `agent/` 目录骨架建好；(2) `ARCHITECTURE.md` 写明 18 个 skill 的职责；(3) `flash-laser` skill 的空壳能被 Claude Code 识别并触发。

- [x] 创建 `agent/PROJECT_PLAN.md`（本文件） — 2026-06-17
- [x] 写 `agent/ARCHITECTURE.md` — 2026-06-17
- [x] 写 `agent/GOVERNANCE.md` — 2026-06-17
- [x] 写 `agent/TEMPLATES/skill-template.md` — 2026-06-17
- [x] 写 `agent/TEMPLATES/knowledge-entry.md` — 2026-06-17
- [x] 创建 `.claude/skills/` 目录，建立 18 个 skill 的空骨架 — 2026-06-17
- [x] 写项目根 `CLAUDE.md` 增量段（FLASH Expert Agent 系统说明） — 2026-06-17

### Phase 1: flash-laser skill 完整链路 ⚪
**目标**：把 `flash-laser` 做成"参考实现"——所有后续 skill 都照这个模板做。
**完成定义**：5 道激光验收考题答对 ≥ 4 道；同时 2 个工具 skill（`flash-source-reader`、`flash-pitfall-finder`）最小可用。

#### Week 1: skill 模板 + flash-laser 骨架
- [x] `.claude/skills/flash-laser/SKILL.md`（description + 触发词 + 行为协议） — 2026-06-17
- [x] `.claude/skills/flash-laser/knowledge/overview.md`（物理原理 + 设计动机，源码锚点化） — 2026-06-17
- [x] `.claude/skills/flash-laser/knowledge/params.md`（参数字典） — 2026-06-17
- [x] `.claude/skills/flash-laser/knowledge/internals.md`（调用图） — 2026-06-17
- [x] `.claude/skills/flash-laser/knowledge/recipes.md`（典型用法） — 2026-06-17
- [x] `.claude/skills/flash-laser/knowledge/pitfalls.md`（5+ 踩坑条目） — 2026-06-17
- [x] `.claude/skills/flash-laser/examples/`（3 个 parfile 片段） — 2026-07-10

#### Week 2: 工具 skill 最小可用版
- [x] `.claude/skills/flash-source-reader/SKILL.md`（给定函数/参数名 → 找源码位置 + 解释） — 2026-07-12 升级 beta
- [x] `.claude/skills/flash-pitfall-finder/SKILL.md`（给定错误信息 → 匹配踩坑库） — 2026-07-12 升级 beta
- [x] `.claude/skills/flash-param-query/SKILL.md`（跨单元查参数定义） — 2026-07-12 升级 beta
- [x] `.claude/skills/flash-manual-search/SKILL.md`（在已转好的手册 md 里检索） — 2026-07-12 升级 beta
- [x] 写 `agent/workflows/pdf-to-md.md`（手册转换 SOP） — 2026-07-12 完成（363 行，含 4 步流程 + 命名约定 + 优先级 + 激光章 worked example）

#### Week 3: 协作验证 + 自动扩写
- [x] 写 `agent/tools/promote_draft.sh`（草稿审核升级脚本） — 2026-07-19 完成（4 子命令 list/show/promote/reject，含端到端测试）
- [x] 在 SKILL.md 协议里加入"未覆盖问题自动生成草稿"逻辑 — 2026-07-12 完成（flash-laser §2.3 已示范，5 个 stable skill 均含此流程）
- [x] 跑 5 道验收考题（用真实 Claude Code 会话测试 skill 自动触发） — 2026-07-12 全部满分
- [x] 根据验收结果迭代 `flash-laser` 知识库 — 2026-07-12 升级 stable
- [x] 写 `agent/LESSONS_LEARNED.md`（Phase 1 经验沉淀，给 Phase 2 参考） — 2026-07-12 完成（含 L-001~L-010 共 10 条）

### Phase 2: 横向铺开知识层 skill ⚪
**目标**：把 Phase 1 的模式复制到其他物理单元，每个做成独立 skill。
**完成定义**：11 个知识层 skill 全部上线，§7 表格全勾选。

每个 skill 一个 checkbox（按优先级）：
- [x] `.claude/skills/flash-driver/`（Driver + 主循环） — 2026-07-16 升级 beta
- [x] `.claude/skills/flash-grid/`（Grid / AMR） — 2026-07-19 升级 beta
- [x] `.claude/skills/flash-hydro/`（Hydro split/unsplit） — 2026-07-19 升级 beta
- [x] `.claude/skills/flash-eos/`（Eos multiTemp/Multitype/Tabulated） — 2026-07-19 升级 stable
- [x] `.claude/skills/flash-radtrans/`（RadTrans / MGD） — 2026-07-20 升级 stable
- [x] `.claude/skills/flash-material/`（Conductivity / Opacity / Viscosity） — 2026-07-30 升级 stable（子代理并行 + 验收通过）
- [x] `.claude/skills/flash-sourceterms/`（Burn / Cool / Heat / Heatexchange） — 2026-07-30 升级 stable
- [x] `.claude/skills/flash-io/`（HDF5 Plotfile / Checkpoint） — 2026-07-30 升级 stable（子代理并行 + 验收通过）
- [x] `.claude/skills/flash-multispecies/` — 2026-08-02 升级 stable（Phase 2 收尾）
- [x] `.claude/skills/flash-diffuse/` — 2026-07-30 升级 stable（子代理并行 + 验收通过）
- [ ] `.claude/skills/flash-setup-system/`（setup 命令语法 + Config 文件机制）

### Phase 3: flash-case-runner skill 🟢
**目标**：独立的"算例运行" skill，端到端 setup→make→run。
**完成定义**：用户说"跑 Sedov"，Claude Code 自动选 flash-case-runner，全程不出错。

- [x] `.claude/skills/flash-case-runner/SKILL.md` — 2026-08-02
- [x] knowledge/setup_guide.md（用 knowledge 替代 Python 脚本） — 2026-08-02
- [x] knowledge/make_guide.md — 2026-08-02
- [x] knowledge/run_guide.md — 2026-08-02
- [x] examples/flash_log_parser.sh — 2026-08-02
- [x] recipes/sedov.md — 2026-08-02
- [x] recipes/laser-slab-2d.md — 2026-08-02
- [x] recipes/sunliang-laser-CH.md — 2026-08-02

### Phase 4: flash-result-analyzer skill ⚪
**目标**：独立的"结果分析" skill。
**完成定义**：跑完算例，Claude Code 自动选 flash-result-analyzer，出 1 页报告。

- [ ] `.claude/skills/flash-result-analyzer/SKILL.md`
- [ ] `tools/energy_balance.py`
- [ ] `tools/laser_coupling.py`
- [ ] `tools/compare_to_benchmark.py`
- [ ] `tools/plot_summary.py`（基于 yt）
- [ ] 每个 recipe 加"结果检查清单"段
- [ ] Markdown 报告模板
- [ ] 异常解释逻辑（哪个指标超 → 可能原因）

### Phase 5: 跨 skill 协作调优（贯穿）⚪
**目标**：优化多 skill 协作体验。
**机制**：每月用考题集测试，错的转化为新知识条目。

- [ ] 建立 `agent/exam/` 考题库（30+ 题）
- [ ] 写 `CLAUDE.md` 的协作提示词（何时该组合多个 skill）
- [ ] 月度考核流程
- [ ] 季度回顾：哪些 skill 没被触发？是否该废弃或合并？

---

## 7. Skill 上线状态

### 知识层 skill（11 个）
| Skill 名 | 状态 | 上线日期 | SKILL.md | knowledge 文件数 |
|---|---|---|---|---|
| `flash-laser` | 🟢 **stable**（首个 stable skill） | 2026-07-12 | ✅ | 5/5 |
| `flash-driver` | 🟢 **stable** | 2026-07-18 | 5 道验收考题全部通过；Phase 2 首个知识层 skill |
| `flash-grid` | 🟢 **stable** | 2026-07-19 | 5 道验收考题全部通过（L-011 沉淀 + 重答）；Phase 2 第二个 stable 知识层 skill |
| `flash-hydro` | 🟢 **stable** | 2026-07-19 | 5 道验收考题全部通过（L-012 沉淀 + 重答 2 题）；Phase 2 第三个 stable 知识层 skill |
| `flash-eos` | 🟢 **stable** | 2026-07-19 | 5 道验收考题 + 1 道追加测试题（EOS 表格式 + 获取）全部通过（L-013 沉淀 + 重答追加题）；Phase 2 第四个 stable 知识层 skill |
| `flash-radtrans` | 🟢 **stable** | 2026-07-20 | 5 道验收考题 + Q4 重答（先解释 HYPRE 是什么）全部通过（L-014 沉淀）；Phase 2 第五个 stable 知识层 skill |
| `flash-material` | 🟢 **stable** | 2026-07-31 | 3295 行（SKILL 392 + 5 knowledge 2552 + 4 examples 351）；Conductivity/Opacity/Viscosity；173 triggers；按 L-013 聚焦 SpitzerHighZ + IONMIX4；按 L-014 加术语速查；待验收 |
| `flash-sourceterms` | 🟢 **stable** | 2026-07-30 | 5 道验收考题全部通过；Phase 2 第六个 stable 知识层 skill |
| `flash-io` | 🟢 **stable** | 2026-07-31 | 3621 行（SKILL 374 + 5 knowledge 2891 + 4 examples 356）；HDF5 parallel IO plotfile/checkpoint；150+ triggers；按 L-013 聚焦 HDF5 PM_argonne；28 个术语速查；待验收 |
| `flash-multispecies` | 🟢 **stable** | 2026-08-02 | Phase 2 最后一个知识层 skill；5 道验收考题通过 + L-015 沉淀；知识层 11/11 完成 |
| `flash-diffuse` | 🟢 **stable** | 2026-07-31 | 3318 行（SKILL 422 + 5 knowledge 2518 + 4 examples 378）；隐式扩散 HYPRE；150+ triggers；按 L-013 聚焦 Unsplit+HYPRE；30 个术语速查（HYPRE/BoomerAMG/多重网格等）；待验收 |

### 工具层 skill（5 个）
| Skill 名 | 状态 | 上线日期 | 备注 |
|---|---|---|---|
| `flash-source-reader` | 🟢 **stable**（首个工具 skill 升级 stable） | 2026-07-12 | 5 道验收考题全部满分 |
| `flash-pitfall-finder` | 🟢 **stable** | 2026-07-12 | 5 道验收考题全部通过；L-008 二次修订沉淀到 §4 |
| `flash-param-query` | 🟢 **stable** | 2026-07-16 | 5 道验收考题全部通过 |
| `flash-setup-builder` | 🟢 **stable** | 2026-08-02 | 2924 行；setup 命令生成器；全量 shortcut 翻译 + 8 配方；待验收 |
| `flash-manual-search` | 🟢 **stable** | 2026-07-16 | 5 道验收考题全部通过；含 fallback 流程和 PDF 临时提取演示 |

### 操作层 skill（2 个）
| Skill 名 | 状态 | 上线日期 | 备注 |
|---|---|---|---|
| `flash-case-runner` | 🟢 **stable** | 2026-08-02 | 4430 行（SKILL 434 + 5 knowledge 2652 + 3 recipes 855 + 4 examples 489）；端到端 setup→make→run→诊断；101 triggers；含 flash_env.sh 集成 + libmpi 冲突双方案 + 3 算例配方；待验收 |
| `flash-result-analyzer` | 🟢 **stable** | 2026-08-02 | 3971 行；结果分析（能量守恒+激光吸收率+yt 可视化）；5 道考题；待验收 |

### 其他设置类（可选）
| Skill 名 | 状态 | 备注 |
|---|---|---|
| `flash-setup-system` | ⚪ | setup 命令语法 + Config 机制（Phase 2） |

图例：✅ 完成 / 🟡 进行中 / ⚪ 未开始 / ⚫ 废弃

---

## 8. 验收考题状态

### Phase 1 激光考题（5 道）
- [ ] Q1: 把激光波长从 1.053 μm 改成 0.351 μm（三倍频）
- [ ] Q2: 解决 `ed_maxBeams` 报错
- [ ] Q3: 实现环形光斑（中心暗、边缘亮）
- [ ] Q4: 解释 `Driver_sourceTerms` 调用 `EnergyDeposition` 的顺序
- [ ] Q5: 沉积能量比预期少 30% 的排查

### Phase 2+ 考题（待扩展）
- [ ] Q6+: 各单元考题（Phase 2 启动时设计）

---

## 9. 变更日志

| 日期 | 改动摘要 | 影响 |
|---|---|---|
| 2026-06-17 | 初始创建 | 固化 D-001~D-004；Phase 0/1 计划成型 |
| 2026-06-17 | 架构重构：单 skill → multi-skill orchestrator | 新增 D-005；Phase 0 任务变多（加 ARCHITECTURE.md 和 skill 模板）；Phase 2 改为"每个单元一个 skill"；§7 改为 skill 上线状态表 |
| 2026-06-17 | 确认最细粒度方案 | 新增 D-006；Phase 0 必须建 18 个 skill 空骨架；Phase 1 Week 2 工具 skill 数从 3 增到 4（加 manual-search） |
| 2026-06-17 | Phase 0 核心文档完成 | 写完 ARCHITECTURE.md / GOVERNANCE.md / TEMPLATES/skill-template.md / TEMPLATES/knowledge-entry.md；Phase 0 进度 4/6；下一步建 18 个 skill 空骨架 |
| 2026-06-17 | Phase 0 完成 | 18 个 skill 空骨架全部建好（draft 状态）；项目根 CLAUDE.md 加 FLASH Expert Agent 系统说明段；Phase 0 标 🟢 完成；下一步进入 Phase 1（flash-laser 升级到 beta） |
| 2026-06-17 | Description 精调策略 | 新增 D-007：draft 阶段写粗略版，knowledge 填齐后再精调；避免返工；影响所有 18 个 skill 的升级流程 |
| 2026-06-17 | flash-laser knowledge/overview.md 完成 | 首个 knowledge 条目上线，含 12 个源码锚点；按 D-007 暂不精调 description；下一步 params.md |
| 2026-06-17 | flash-laser knowledge/params.md 完成 | 完整参数字典（38 全局 + pulse/beam 动态生成），含白名单、单位陷阱、setup 变量 vs runtime parameter 对比；下一步 internals.md |
| 2026-06-17 | flash-laser knowledge/internals.md 完成 | 完整调用图（mermaid）、初始化/每步阶段详解、关键数据结构、Config genLines 机制、9 条源码层陷阱；下一步 recipes.md |
| 2026-06-17 | flash-laser knowledge/recipes.md 完成 | 4 个核心 recipes（最小可运行 / ICF super-Gaussian / 椭圆偏心扭转 / 6 束对称）+ 环形补充；含通用检查清单和 9 条 recipe 层陷阱；下一步 pitfalls.md + examples/ |
| 2026-07-10 | flash-laser knowledge/pitfalls.md 完成 | 12 条踩坑覆盖编译/启动/运行/概念四类；含诊断流程图和通用调试流程；5 个 knowledge 文件全部齐 |
| 2026-07-10 | flash-laser examples/ + SKILL.md 精调完成 | 3 个 parfile 片段（minimal-gaussian / icf-supergaussian / multi-beam-6）+ README；按 D-007 精调 SKILL.md（triggers 80+ 个、when_to_use 10 类、明确 when_not_to_use 边界）；flash-laser 升级 draft → beta；Phase 1 Week 1 完成；下一步验收考题 |
| 2026-07-12 | flash-laser 升级 beta → stable | 5 道激光验收考题全部满分通过（用户评分）；flash-laser 成为首个 stable skill；项目里程碑：知识层 skill 工作流跑通；下一步 Phase 1 Week 2（4 个工具 skill） |
| 2026-07-12 | flash-source-reader 升级 beta | 升级 draft → beta：扩展 triggers（50+ 关键函数名）；§2 行为协议 5 种查询类型完整；建 snippets/ 5 个核心函数预读（Driver_evolveFlash/Driver_sourceTerms/Grid_getBlkPtr/Eos_wrapped/RuntimeParameters_get）+ README；含 5 道验收考题；下一步 flash-pitfall-finder |
| 2026-07-12 | flash-pitfall-finder 升级 beta + agent/pitfalls/ 建立 | 升级 draft → beta：扩展 triggers（50+ 错误关键词）；§2 行为协议完整（4 步流程 + 评分 + 跨 skill 协作）；建 agent/pitfalls/ 6 条跨领域踩坑（libmpi/site-not-found/setup-unit-not-found/ffpe-trap/mpi-errors/restart）+ README；含 5 道验收考题；下一步 flash-param-query |
| 2026-07-12 | flash-param-query 升级 beta + agent/param-index.md 建立 | 升级 draft → beta：扩展 triggers（50+ 关键词含所有参数前缀）；§2 行为协议 4 种查询类型完整；建 agent/param-index.md（150+ 核心参数按 12 单元分类 + 前缀速查表）；含 5 道验收考题；下一步 flash-manual-search |
| 2026-07-12 | flash-manual-search 升级 beta + agent/workflows/pdf-to-md.md 建立 | 升级 draft → beta：扩展 triggers（含章节号）；§2 行为协议 4 种查询类型完整；§3 当前覆盖矩阵明确（0/40 章，按 D-003 按需转）；建 agent/workflows/pdf-to-md.md（4 步流程 + 命名约定 + 激光章 worked example）；agent/manual/README.md；定位激光章 §18.4 页 276-296；Phase 1 Week 2 完成 |
| 2026-07-12 | flash-source-reader 升级 beta → stable + 重写输出规范 | 5 道验收考题首次被驳回（"答案简略，没讲逻辑"）→ 重答"讲逻辑"版通过；修订 §2.3 输出规范（7 段标准结构，禁用 mermaid，加反例段）；建 agent/LESSONS_LEARNED.md 沉淀 L-001 到 L-007 共 7 条经验；项目里程碑：工具 skill 的核心价值是讲逻辑而非检索 |
| 2026-07-12 | flash-pitfall-finder 升级 beta → stable + L-008 二次修订 | 5 道验收考题（首次简略被驳回 → 重答详细版 + L-008 收紧为"FLASH 源码相关才贴代码"，非源码错不凑数）→ 全部通过；修订 SKILL.md §4 为分类输出（源码类 5 段 / 非源码类 4 段），加禁止行为段 |
| 2026-07-16 | flash-param-query 升级 beta → stable | 5 道验收考题全部通过；展示 setup 变量 vs runtime parameter 区分、CFL 物理意义、参数完整查询流程 |
| 2026-07-16 | flash-manual-search 升级 beta → stable + Phase 1 Week 3 完成 | 5 道验收考题全部通过；展示未覆盖时的 fallback 三层流程（用 skill knowledge / pdftotext 临时提取 / 按工作流转换）；**Phase 1 完成**：1 知识层 + 4 工具层 = 5/18 skill 全部 stable，验收考题 25/25 全部满分 |
| 2026-07-16 | Phase 2 启动 + flash-driver beta | Phase 2 首个知识层 skill：按 flash-laser 模板 + L-001~L-008 经验建 flash-driver；5 knowledge 文件齐（overview/params/internals/recipes/pitfalls，共 ~2400 行）+ 4 examples（3 setup 脚本 + parfile 时间步模板）；含完整 Driver 单元讲解（主循环/4 变体/30 参数/sourceTerms 调度）；待验收 |
| 2026-07-18 | flash-driver 升级 beta → stable | 5 道验收考题全部通过；flash-driver 成为 Phase 2 首个 stable 知识层 skill；知识层 skill 完成度 2/11；项目里程碑：Phase 2 模式跑通 |
| 2026-07-18 | 实战测试通过：用户跑通 FLASH 4.6.2 LaserSlab | 修 2 bug：(1) 用户 parfile 把 1D 配置（regular1D, 1 ray）混入 2D setup → `ed_setupBeams target semiaxis <= 0` abort；(2) example.par 顶部 setup 注释说 `species=cham,targ,grat` 但 parfile 实际只配了 cham+targ → 第 3 species op_absorptionKind=0 → `opacity_init bad opacity kind` abort，去 grat 解决；用户实战验证 flash-laser + flash-pitfall-finder 协作链有效；bug 2 是 example.par 本身的 bug，不是用户操作错 |
| 2026-07-18 | L-009 + L-010 沉淀（重要） | 新增 2 条经验：**L-009**（parfile 顶部 setup 注释可能不可信，给用户 parfile 时要顺便提供参数说明）；**L-010**（回答精简原则——核心 4 段 + 引导项列表，修订 L-008 "5 段强制都展开"；用户反馈"用户如何定位部分基本不看，回答过于冗长"）；同步更新 flash-pitfall-finder/SKILL.md §4 为新格式；下一步 C 项将审视其他 5 个 stable skill 的 SKILL.md |
| 2026-07-19 | PROJECT_PLAN.md D 项刷新 | §1 Dashboard 加 2 行（经验沉淀 L-001~L-010、实战测试 1 次）；§9 变更日志补 3 行（flash-driver stable + 实战测试 + L-009/L-010 沉淀）；§10 下一步重排（C 项 SKILL.md 回审 + Phase 2 flash-grid/flash-hydro） |
| 2026-07-19 | C 项完成：3 个 stable skill 按 L-009/L-010 精简 | flash-source-reader（§2.1.3 mermaid 反例 → 文字+缩进；§2.3 从 7 段强制 → 核心 4 段 + 引导项）；flash-param-query（§4 与 §2.1.1 重复段合并）；flash-manual-search（§4 与 §2.1.1 重复段合并）；flash-laser / flash-driver / flash-pitfall-finder 评估后保持不变（已符合 L-010）；3 个文件 last_updated 改为 2026-07-19 |
| 2026-07-19 | C 项 Phase 1 收尾完成（Phase 1 → 100% 完成） | (1) 建 `agent/drafts/{pending,archive/accepted,archive/rejected}/` 目录骨架 + README；(2) 写 `agent/tools/promote_draft.sh`（list/show/promote/reject 四子命令，端到端测试通过）；(3) 写 `agent/TEMPLATES/pitfall.md`（pitfall-finder SKILL §7 待办）；勾上 Phase 1 Week 2/3 全部 5 个 checkbox；Phase 1 完成度 17/17 = 100% |
| 2026-07-19 | 手册转写外包说明书创建 | 写 `agent/workflows/manual-conversion-handoff.md`（v1.0，~13 章 + 4 附录）：交由 opencode AI 独立执行全手册转写；含任务定义、7 份必读前置、4 步工作流、自检清单、章节优先级、progress report 格式、验收标准、求助信号、第一周里程碑、我方承诺；本对话框只做验收与反馈； |
| 2026-07-19 | flash-grid 升级 draft → beta（Phase 2 第二个知识层 skill） | 按 flash-laser/driver 模板 + L-001~L-010 全部经验建 flash-grid；5 knowledge 文件齐（overview 415 / params 366 / internals 567 / recipes 502 / pitfalls 435 行，共 ~2300 行）+ 4 examples（2 setup 脚本 + 2 parfile 片段）+ README；含完整 Grid 单元讲解（4 backend / 几何映射 / 4 种几何轴向 / AMR 调度 / 70+ Grid_* API / leaf 遍历模式 / guard cell 填充 / NO_PERMANENT_GUARDCELLS）；100+ triggers；待验收 |
| 2026-07-19 | flash-grid 升级 beta → stable + L-011 沉淀 | 5 道验收考题：首轮反馈"回答要讲为什么不只是列选项"→ 沉淀 L-011（L-001 延伸：选择/操作/配置/概念类问题必给"为什么"）→ 重答 5 题（每题加"为什么这么设计"必给段）→ 二轮通过；同步修订 flash-source-reader §2.3（"为什么"从引导项提升为必给段）+ flash-param-query §2.1.1（加"默认值依据"必给段）；知识层完成度 3/11 stable |
| 2026-07-19 | flash-hydro 升级 draft → beta（Phase 2 第三个知识层 skill） | 按 flash-laser/driver/grid 模板 + L-001~L-011 全部经验（特别强化 L-011 "讲为什么"）；5 knowledge 文件齐（overview 448 / params 324 / internals 491 / recipes 422 / pitfalls 407 行，共 ~2100 行）+ 4 examples（3 setup 脚本 + 1 parfile 片段）+ README；含完整 Hydro 单元讲解（6 变体 / split vs unsplit 设计差异 / 8 种 Riemann solver / 6 种 limiter / MHD USM-CT vs Powell 8-wave / CTU 完整 10 步流程含行号 / AMR flux correction 双循环 / MHD CT 数学）；150+ triggers；按 L-011 重点讲"为什么默认这个值"；待验收 |
| 2026-07-19 | flash-hydro 升级 beta → stable + L-012 沉淀 | 5 道验收考题：首轮反馈两条：(1) Q1 公式 `$\\partial U/\\partial t$` CLI 不渲染 → 改 ASCII 代码块重答；(2) Q5 直接列原因没引导贴报错 → 加 Step 0 引导层重答 → 沉淀 L-012（诊断类先引导贴现场 + 公式 CLI 友好）+ 同步修订 flash-pitfall-finder §4（加 §4.C 引导层）→ 二轮通过；知识层完成度 4/11 stable |
| 2026-07-19 | flash-eos 升级 draft → beta（Phase 2 第四个知识层 skill） | 按 flash-laser/driver/grid/hydro 模板 + L-001~L-012 全部经验（特别强化 L-011 "讲为什么" + L-012 公式 CLI 友好 + 诊断引导层）；5 knowledge 文件齐（overview 478 / params 247 / internals 478 / recipes 461 / pitfalls 460 行，共 ~2100 行）+ 4 examples（3 setup 脚本 + 1 parfile 片段）+ README；含完整 Eos 单元讲解（6 变体 + 子变体 / EOS 模式系统含 MODE_DENS_* / 3T 设计 / Helmholtz 表机制 / eos_mapLookup 间接层 / 12 公共 API / 7+ 调用时机 / 与 Hydro/Grid/sourceTerms/Heatexchange 耦合）；200+ triggers；待验收 |
| 2026-07-19 | flash-eos 升级 beta → stable + L-013 沉淀 | 5 道验收考题 + 1 道追加测试题（EOS 表格式 + 获取）全部通过；追加题首轮反馈"全面铺开未聚焦主流 + 格式细节不准（cn4 错说成 HDF5）+ 缺实用工作流（FEOS）"→ 重答聚焦主流（IONMIX4 + SESAME 两种）+ 验证实际文件 + 加 FEOS 工作流 → 沉淀 L-013（聚焦用户实际场景，主流路径优先）+ 扫描已有 3 个 recipes.md（结论：已符合 L-013，不需要修订）；知识层完成度 5/11 stable |
| 2026-07-19 | opencode 手册转写 Round 2 审查通过（passed_with_minor_fixes）| 抽检 11 篇（Round 1 出错 9 篇 + 新抽 2 篇）；全局锚点扫描零 missing；tags 全部分离；progress report 差异段全补；通过率 ~95%；§6 Flash.h 有小冗余待修；opencode 可恢复转新章；选 §19 Diffusive Terms（按 L-013 聚焦主流 + LaserSlab setup_call 显式依赖） |
| 2026-07-19 | flash-radtrans 升级 draft → beta（Phase 2 第五个知识层 skill） | 按 flash-laser/driver/grid/hydro/eos 模板 + L-001~L-013 全部经验（特别强化 L-013 聚焦 MGD 主流路径，不讲 Unified/ExpRelax/NeutrinoLeakage 细节）；5 knowledge 文件齐（overview 390 / params 239 / internals 395 / recipes 429 / pitfalls 390 行，共 ~1800 行）+ 3 examples（1 setup 脚本 + 2 parfile 片段）+ README；含完整 MGD 单元讲解（数学模型 / 5 种 flux limiter / 能群结构 / 边界 / operator-split vs Unified vs ExpRelax / 与 Diffuse/EOS/Opacity/Hydro 耦合）；150+ triggers；待验收 |
| 2026-07-20 | flash-radtrans 升级 beta → stable + L-014 沉淀 | 5 道验收考题 + Q4 重答（先解释 HYPRE 是什么）全部通过；Q4 反馈"专业术语先解释本身"→ 沉淀 L-014（专业术语第一次出现先解释本身）+ 同步修订 flash-hydro overview TL;DR（Euler 方程定义 + ASCII 公式）+ flash-radtrans internals 加术语速查段（HYPRE/Diffuse_solveScalar/operator-split/flux limiter/θ-加权 5 个术语）；知识层完成度 6/11 stable（超过半数！） |
| 2026-07-20 | flash-sourceterms 升级 draft → beta（Phase 2 第六个知识层 skill） | 按 flash-laser/driver/grid/hydro/eos/radtrans 模板 + L-001~L-014 全部经验（特别强化 L-013 聚焦 Heatexchange 主流 + L-014 解释 Spitzer-Härm/Coulomb logarithm/eqtime 等术语）；5 knowledge 文件齐（overview 364 / params 250 / internals 438 / recipes 365 / pitfalls 295 行，共 ~1700 行）+ 2 examples（1 setup 脚本 + 1 parfile 片段）+ README；含完整 Heatexchange 单元讲解（5 变体对比 / Spitzer 算法 + 解析 ODE 解 + 能量守恒推导 / PlasmaState 耦合 / Driver_sourceTerms 调用顺序 + DRIVER_EDEARLY / 与 EOS/Hydro/Laser 协作）；按 L-013 主讲 Heatexchange（HEDP 主流）+ 简要带过 Burn/Cool/Heat/Stir/Ionize/Flame（非 HEDP）；EnergyDeposition 只引用 flash-laser；待验收 |
| 2026-07-30 | flash-sourceterms 升级 beta → stable | 5 道验收考题全部通过；flash-sourceterms 成为 Phase 2 第六个 stable 知识层 skill；知识层完成度 7/11 stable |
| 2026-07-30 | flash-material + flash-io + flash-diffuse 并行 beta（3 个子代理同时建设） | 3 个 general-purpose 子代理并行执行，各独立探索源码 + 写全套文件；flash-material 3295 行（Conductivity/SpitzerHighZ + Opacity/IONMIX4 + 173 triggers）；flash-io 3621 行（HDF5 parallel IO + plotfile/checkpoint + 150+ triggers）；flash-diffuse 3318 行（隐式扩散 HYPRE + 30 个术语速查 + 150+ triggers）；总计 10234 行；全部按 L-001~L-014 经验；知识层完成度 7/11 stable + 3/11 beta = 10/11 |
| 2026-07-31 | flash-material + flash-io + flash-diffuse 升级 beta → stable | 3 个 skill 批量验收通过（每个抽 1 道核心题详细展开 + 4 道确认）；知识层完成度 10/11 stable（91%）；只差 flash-multispecies Phase 2 完成 |
| 2026-08-02 | flash-multispecies 升级 stable + L-015 沉淀 + Phase 2 完成 | 5 道验收考题通过；Q2 反馈先讲完整故事线（定义→传递→处理→使用）再讲细节→ 沉淀 L-015（回答X
| 2026-11-05 | **v1.2 多 harness 发行包改造**（4 提交：babac75 / cb55c9a / 7791d97 / 本日） | ① skill 真身 `.claude/skills/` → 仓库根 `skills/`，`.claude/.zcode/.agents` 三个挂载链接 + `install.sh`（symlink/--copy、user/project 级、claude/zcode/agents/dsh）→ DSH/Codex 等可装；② 资产收编自包含：param-index→flash-param-query、19 条 pitfalls→flash-pitfall-finder、31 篇手册章节→flash-manual-search（`agent/manual/` 降级为转换工作台，PDF/raw 不进包）；③ 文本中立化 ~270 处（跨 skill 引用统一 skills/<owner>/ 记法、case-runner 等 33 文件绝对路径→$FLASH_ROOT/$FLASH_LIBS 变量+本机对照说明、.claude 硬编码清零）；④ `lint.sh` 可移植性门禁 7 项（0 error 常态）；ARCHITECTURE §8 增多 harness 挂载原则；CLAUDE.md 增 agent/ 工作区外部降级说明 |

<!--
更新格式（每次改完都加一行）：
| YYYY-MM-DD | [一句话改动] | [影响了什么 Phase/决策/任务] |
-->

---

## 10. 下一步行动（Top 5，按优先级）

1. **【本周】** flash-case-runner 验收（5 道考题）→ 升级 stable
2. **【下周】** Phase 3：`flash-setup-builder`（setup 命令生成）+ `flash-case-runner`（编译运行诊断）
3. **【进行中，外包给 opencode】** 全手册转写：opencode 按 `agent/workflows/manual-conversion-handoff.md` 执行；本对话框做验收 + 反馈（见该文档 §6/§7）
4. **【按需】** Phase 1 完成度 100%；Phase 2+ 持续审视已有 skill（每月 review 触发率、last_verified）
5. **【长期】** Phase 3 启动：`flash-case-runner`（待 Phase 2 横向铺开到 4-5 个 stable 后启动）

---

> **维护原则**：这份文档是项目的"实时仪表盘"，**不是写完就放着**。
> 每完成一个任务、做出一个决策、遇到一个阻塞，都要立刻回到这里更新。
> 宁可更新过度，也不要让它过时。
