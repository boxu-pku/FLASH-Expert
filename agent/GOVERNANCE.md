# FLASH Expert Agent — 治理规范

> 本文件是项目治理的权威源：决策记录、维护规范、审核流程、上下架规则。
> 与 `PROJECT_PLAN.md`（进度追踪）和 `ARCHITECTURE.md`（架构定义）构成"宪法三件套"。

---

## 0. 文档分工

| 文件 | 作用 | 谁来读 |
|---|---|---|
| `PROJECT_PLAN.md` | 项目进度、任务清单、当前状态 | 用户每周看、Agent 每次进入项目看 |
| `ARCHITECTURE.md` | 18 个 skill 架构、调度协议、命名约定 | 设计新 skill 时读 |
| `GOVERNANCE.md`（本文件） | 决策、维护流程、审核规则 | 做任何变更前必读 |
| `TEMPLATES/skill-template.md` | SKILL.md 模板 | 新建 skill 时读 |
| `TEMPLATES/knowledge-entry.md` | knowledge md 模板 | 写任何 knowledge 条目前读 |

---

## 1. 决策记录（权威源）

> 这些决策在 PROJECT_PLAN.md §5 也有记录，但本文件是**权威源**。
> 修改决策必须先改本文件，再同步到 PROJECT_PLAN.md。

### D-001: Agent 形态 = Claude Code Skill
- **决策日期**：2026-06-17
- **决策**：用 Claude Code Skill，不建外部 RAG 后端。
- **状态**：✅ 生效（被 D-005 扩展为 multi-skill，但形态仍是 Skill）

### D-002: Phase 1 主题 = 激光
- **决策日期**：2026-06-17
- **决策**：先打通激光领域完整知识链路。
- **状态**：✅ 生效

### D-003: 手册转换 = 工具辅助 + 人工精读，工作流驱动
- **决策日期**：2026-06-17
- **决策**：用 marker / pdfplumber 等工具批量转初稿，再人工按模板改写。按需推进。
- **状态**：✅ 生效

### D-004: 维护模式 = Agent 自动扩写 + 用户审核
- **决策日期**：2026-06-17
- **决策**：Agent 在遇到未覆盖问题时自动生成草稿到 `agent/drafts/pending/`，用户定期 review。
- **状态**：✅ 生效

### D-005: 架构模式 = Multi-Skill Orchestrator
- **决策日期**：2026-06-17
- **决策**：FLASH Agent 由约 18 个专门 skill 组成。Claude Code 本身作为 orchestrator。
- **状态**：✅ 生效（部分推翻 D-001 的"单 skill"理解）

### D-006: Skill 切分粒度 = 最细粒度（18 个独立 skill）
- **决策日期**：2026-06-17
- **决策**：
  1. 11 个物理单元各自独立 skill（不合并）
  2. 5 个工具 skill 全部独立（不作为知识层 helper）
  3. Phase 1 Week 2 一次性做 4 个工具 skill
- **状态**：✅ 生效

### D-007: Description 字段采用"先粗后精"策略
- **决策日期**：2026-06-17
- **决策**：SKILL.md 的 `description` / `triggers` / `when_to_use` / `when_not_to_use` 字段在 skill 处于 `draft` 阶段时只写粗略版，等内容（`knowledge/` 5 个文件）填齐并升到 `beta` 后再依据**实际覆盖范围**精调。
- **理由**：description 的精确度直接依赖对源码和手册的深入理解。在 knowledge 未填齐时强行精写 description 容易：
  - 把不属于本 skill 的内容写进 `when_to_use`（覆盖过宽）
  - 漏写实际该覆盖的内容（覆盖过窄）
  - `when_not_to_use` 的边界判断不准
  - 后续填 knowledge 时再回头大改 description，浪费返工成本
- **执行规则**：
  1. **draft 阶段**：description 写粗略版（一句话主题 + 5-10 个核心触发词），不追求精确边界
  2. **knowledge 填齐过程中**：在每个 knowledge 文件完成后，回头审视 description 是否准确反映内容
  3. **升级 beta 前**：description 必须经过一次精调，覆盖：
     - 实际填入的参数前缀
     - 实际涉及的源码文件
     - 与其他 skill 的真实边界（基于实际内容，不是猜测）
  4. **stable 阶段**：description 视为稳定，每次内容大改后才需要重审
- **回溯条件**：如果某 skill 在 beta 阶段持续被错误触发或漏触发（每月 > 2 次），即使内容稳定也要回头精调 description。
- **影响**：Phase 1 Week 3 升级 flash-laser 到 beta 时必须做 description 精调；后续每个 skill 同理。

### 决策修改流程

要推翻或修改已有决策：
1. 在本文件追加 `D-XXX` 新决策，**显式声明**"推翻 D-YYY" 或 "扩展 D-YYY"
2. 把旧决策的"状态"改为 `⚠️ 已被 D-XXX 修改`
3. 同步更新 `PROJECT_PLAN.md` §5
4. 在 `PROJECT_PLAN.md` §9 变更日志加一行
5. 评估影响范围，更新所有受影响的 skill 或文档

---

## 2. 角色分工

| 角色 | 谁 | 主要任务 |
|---|---|---|
| **决策者** | 用户 | 做架构决策、审核草稿、判断回答质量 |
| **执行者** | Agent（Claude Code） | 写代码、写草稿、跑测试、检索知识 |
| **审核者** | 用户 | review `drafts/pending/`，决定 promote 或 reject |
| **维护者** | 用户 + Agent | 用户负责重大变更；Agent 负责日常 freshness 检查 |

### Agent 不能做的事

- ❌ 修改决策记录（D-XXX）—— 必须用户来做
- ❌ 修改 GOVERNANCE.md / ARCHITECTURE.md / TEMPLATES/ —— 必须用户来做
- ❌ 把 `drafts/pending/` 的内容直接 promote 到 skill —— 必须用户审核
- ❌ 删除 stable 状态的 skill —— 必须用户决定
- ❌ 推翻之前已经做出的回答（除非用户提出疑问）

### Agent 必须做的事

- ✅ 每次回答前在 `knowledge/` 检索
- ✅ 回答时引用源码锚点
- ✅ 遇到未覆盖问题时主动提议生成草稿
- ✅ 解读 ≥ 50 行源码后自动生成草稿
- ✅ 跑通新算例后自动生成 recipe 草稿

---

## 3. 知识库生命周期

### 3.1 一个 knowledge 条目的生命周期

```
[draft] ──审核通过──> [beta] ──验证后──> [stable] ──过期──> [beta/draft]
   ↑                                                ↓
   └───────────────修订────────────────────────────┘
```

| 状态 | 判据 | 谁来改 |
|---|---|---|
| `draft` | 刚写完，未审核 | Agent 写，用户审 |
| `beta` | 审核通过，初步验证 | 用户审过后改 |
| `stable` | 通过实际使用验证 + 源码锚点准确 | 用户主动改 |
| 降级 | `last_verified` 超 6 月 → beta；超 1 年 → draft | Agent 定期检查 |

### 3.2 新增 knowledge 条目流程

```
1. Agent 检测到知识缺口
   ↓
2. 询问用户："要不要生成草稿？"
   ↓
3. 用户同意
   ↓
4. Agent 按 knowledge-entry 模板生成
   输出到 agent/drafts/pending/<topic>-<date>.md
   ↓
5. 用户定期 review drafts/pending/
   ↓
6. 决定：
   - 接受 → 移到对应 skill 的 knowledge/ 目录
            改 status: beta
            在 PROJECT_PLAN §9 加 changelog
   - 拒绝 → 移到 drafts/archive/rejected/
            写拒绝原因
   - 待定 → 留在 pending/，加 review_notes
```

### 3.3 修订已有条目流程

```
1. 用户或 Agent 发现条目过时/有错
   ↓
2. 在条目的 §9 变更日志记录问题
   ↓
3. 修订内容，更新 last_verified
   ↓
4. 如修订较大，临时降级为 beta
   ↓
5. 通过使用验证后再升回 stable
```

---

## 4. Skill 生命周期

### 4.1 状态转换

```
draft → beta → stable → deprecated → archived
                  ↑                    ↓
                  └─── 复活 ───────────┘
```

| 状态 | 判据 | 行动 |
|---|---|---|
| `draft` | 仅 SKILL.md 骨架，knowledge 文件不齐 | 不被优先选择 |
| `beta` | knowledge 齐 + 基本问答测试通过 | 可调用，回答标"测试中" |
| `stable` | 通过验收考题 | 正式使用 |
| `deprecated` | 3 月触发率 < 5% 或被新 skill 替代 | 标记废弃，给用户迁移提示 |
| `archived` | 移到 `.claude/skills.archived/` | 不再加载 |

### 4.2 新建 skill 流程

```
1. 确认该领域确实需要独立 skill（参考 ARCHITECTURE §2）
   ↓
2. 在 .claude/skills/ 创建目录
   ↓
3. 复制 TEMPLATES/skill-template.md 到 SKILL.md
   按 frontmatter 填充（name, description, triggers 等）
   ↓
4. 创建 knowledge/ 目录，按 knowledge-entry.md 模板写 5 个文件（可先占位）
   ↓
5. 在 PROJECT_PLAN §7 添加该 skill 行
   ↓
6. status 设为 draft
   ↓
7. 内容补齐 + 测试 → 升级到 beta
   ↓
8. 通过验收 → 升级到 stable
```

### 4.3 废弃 skill 流程

```
1. 确认废弃（连续 3 个月触发率 < 5%）
   ↓
2. SKILL.md status 改为 deprecated
   description 字段加 "[DEPRECATED]"
   ↓
3. 在 PROJECT_PLAN §7 标记，§9 加 changelog
   ↓
4. 观察 1 个月，确认无用户依赖
   ↓
5. 移到 .claude/skills.archived/<skill-name>/
   ↓
6. 在 PROJECT_PLAN §7 该行改为 "⚫ archived"
```

---

## 5. 审核清单

用户审核 `agent/drafts/pending/` 草稿时，按此清单检查：

### 5.1 格式合规
- [ ] frontmatter 字段齐全（title, skill, category, source_anchors, status=draft 等）
- [ ] 至少 3 个源码锚点
- [ ] 代码片段不超过 20 行
- [ ] 没有"复制大段源码"

### 5.2 内容准确
- [ ] 源码锚点的行号确实对应所说内容（**随机抽 1-2 个验证**）
- [ ] 参数默认值、单位与 Config 文件一致
- [ ] 物理公式与源码实现一致
- [ ] 没有把推测写成事实

### 5.3 边界清晰
- [ ] 不与其他 skill 的 knowledge 内容重复
- [ ] 不包含跨单元的复杂耦合（应放在双方各自的条目里）

### 5.4 可维护性
- [ ] `last_verified` 日期准确
- [ ] tags 标签合理（便于检索）
- [ ] §9 变更日志有"初始创建"行

### 审核决策

- 全部通过 → 移到 skill 的 knowledge/，改 status: beta
- 有小问题 → 退回 Agent 修订，留在 pending/
- 严重错误或重复 → 移到 drafts/archive/rejected/，附拒绝原因

---

## 6. 维护节奏

### 6.1 日常（每次会话）

Agent 自动做：
- 检测知识缺口 → 提议生成草稿
- 解读源码 → 自动沉淀
- 跑通算例 → 自动加 recipe 草稿

用户做：
- 决定是否接受草稿
- 重要问题回答后快速 review Agent 的引用是否准确

### 6.2 每周

用户做（约 30 分钟）：
- 看 PROJECT_PLAN.md §1 Dashboard
- review `agent/drafts/pending/` 积压的草稿
- 更新 PROJECT_PLAN.md §10 下一步行动

### 6.3 每月

用户做（约 2 小时）：
- 用 5-10 道新考题测试 Agent（考题库见 `agent/exam/`）
- 答错的题转化为新 knowledge 草稿
- 检查 skill 触发率：哪些没被触发？是否该合并/废弃？

### 6.4 每季度

用户做（约半天）：
- Freshness 检查：跑 `agent/tools/check_freshness.py`（待开发）
  找出 `last_verified` 超 6 个月的条目，对照源码核对
- 决策复盘：D-XXX 是否还合理？要不要推翻？
- Skill 大盘点：废弃长期不用的，合并职责重叠的

---

## 7. 变更类型与流程

| 变更类型 | 影响 | 流程 |
|---|---|---|
| **修复错别字 / 小修正** | 单个文件 | 直接改，changelog 加一行 |
| **修订 knowledge 条目** | 单个 skill 的单文件 | 改 + 更新 last_verified + 临时降级 beta |
| **新增 knowledge 条目** | 单个 skill | 草稿流程（见 §3.2） |
| **新增 / 修订 skill** | 一个或多个 skill | §4 流程 + PROJECT_PLAN §7 更新 |
| **架构变更** | 全局 | 必须有 D-XXX 决策 + 全文 changelog |
| **推翻已有决策** | 全局 | §1 决策修改流程 |

---

## 8. 紧急情况处理

### 8.1 Agent 给出错误答案被用户发现

1. 立即在 `agent/drafts/pending/` 生成 "纠错" 草稿
2. 草稿里记录：原答案、错误点、正确答案、源码锚点
3. 用户审核后，要么修订对应 knowledge 条目，要么新增纠错条目

### 8.2 源码大改导致 knowledge 失效

1. 跑 `agent/tools/check_freshness.py` 找出受影响条目
2. 受影响条目批量降级为 `draft`
3. 重新核对源码，逐个修订
4. 完成后升级回 `stable`

### 8.3 Skill 误触发 / 不触发

调整该 skill 的 SKILL.md：
- **误触发**（不该被调用却调用了）：强化 `when_not_to_use` 字段
- **不触发**（该被调用却没调用）：扩展 `description` 和 `triggers`

调整后必须做 5 道相关测试题验证。

---

## 9. 度量指标

定期跟踪这些指标，判断项目健康度：

| 指标 | 健康范围 | 异常处理 |
|---|---|---|
| Skill 覆盖率 | ≥ 80% 物理 unit 有 stable skill | Phase 2 加速 |
| Knowledge 条目数 | 持续增长 | 停滞 → 提示用户提问 |
| 草稿积压数 | pending/ < 10 | 用户加紧审核 |
| 验收考题通过率 | ≥ 80% | 失败题目转 knowledge |
| 源码锚点有效性 | ≥ 95% | 跑 check_freshness.py |
| 月度 skill 触发率 | 各 skill > 5% | < 5% 考虑废弃 |

---

## 10. 版本

v1.0（2026-06-17，初始版本）

修改本文件必须：
1. 更新版本号
2. 在 PROJECT_PLAN §9 加 changelog
3. 通知所有 stakeholder（即用户自己）
