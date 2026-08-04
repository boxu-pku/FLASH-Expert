# SKILL.md 统一模板

> 本文件是所有 `.claude/skills/<skill-name>/SKILL.md` 的强制模板。
> 新建 skill 时复制本文件的"模板正文"部分到 SKILL.md，按注释填充。
> **不要删 section**，没用的填 "N/A"。

---

## 使用流程

1. 创建目录 `.claude/skills/<skill-name>/`
2. 复制下方"模板正文"到 `SKILL.md`
3. 把所有 `<...>` 占位符替换为实际内容
4. 删除所有 `> [说明]` 注释行
5. 在 `agent/PROJECT_PLAN.md` §7 更新该 skill 的状态
6. 在 `agent/PROJECT_PLAN.md` §9 变更日志加一行

---

## 模板正文（复制下面 ``` 包围的内容到 SKILL.md）

```markdown
---
name: <skill-name>                          # 全局唯一，与目录名一致
description: |                              # ★ Claude Code 用此字段匹配用户意图
  <一句话总结：本 skill 是什么、做什么、何时用>
  触发词：<关键词列表，逗号分隔>
triggers:                                   # 显式触发关键词列表（至少 5 个）
  - <关键词1>
  - <关键词2>
  - <关键词3>
  - <关键词4>
  - <关键词5>
when_to_use: |                              # 何时应该调用本 skill
  <列出适用场景，要具体>
when_not_to_use: |                          # 何时**不**该调用（避免误触发）
  <列出易混淆但不属于本 skill 的场景>
layer: <knowledge | tool | operator>        # skill 层级
phase: <1 | 2 | 3 | 4 | 5>                  # 在哪个 Phase 上线
status: <draft | beta | stable | deprecated>
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
owner: <用户名 or agent>
---

# <Skill 标题>

## 1. 角色与边界

### 1.1 我是做什么的
<2-3 句话说明本 skill 的核心职责>

### 1.2 我不做什么
<列出会推给其他 skill 的事>

| 用户问题类型 | 归属 skill |
|---|---|
| <示例问题1> | <其他 skill 名> |
| <示例问题2> | <其他 skill 名> |

## 2. 行为协议

### 2.1 接到查询时（on_query）

按以下步骤处理：

1. **理解意图**：明确用户问的是什么（参数含义/源码细节/调试/配置）
2. **检索本 skill 的 knowledge/**：
   - 用 `grep` / `rg` 在 `knowledge/*.md` 找相关段落
   - 命中 → 基于内容回答，**必须引用源码路径:行号**
   - 未命中 → 进入 2.3
3. **回答格式**：
   ```
   <直接答案>

   > **源码锚点**: source/path/file.F90:LXX
   > **手册出处**: <对应章节或"N/A">
   > **相关参数**: <列出相关 runtime parameters>
   ```

### 2.2 接到执行任务时（on_run / on_analyze）

<如果本 skill 是 operator/tool 层，描述执行流程；
knowledge 层 skill 此节填 "N/A"。>

### 2.3 知识库未覆盖时（on_unknown）

**严格禁止**编造答案。按下面流程：

1. 老实告诉用户："本 skill 当前知识库未覆盖此问题"
2. 给出可能的解决路径：
   - 调用 `flash-source-reader` 看源码（如果问题涉及代码）
   - 调用 `flash-manual-search` 查手册（如果问题涉及物理原理）
   - 调用 `flash-pitfall-finder` 查踩坑库（如果问题涉及错误）
3. **询问用户**："要不要我生成一份草稿到 `agent/drafts/pending/`，下次审核后加入知识库？"
4. 用户同意 → 按 `knowledge-entry` 模板生成草稿

## 3. 自动扩写规则（D-004 决策）

### 3.1 触发时机

满足任一条件就**自动生成草稿**到 `agent/drafts/pending/`：

- [ ] 用户问题在 `knowledge/` 中检索不到（且无法用其他 skill 解决）
- [ ] 解读了 ≥ 50 行源码
- [ ] 解决了一个新的 abort / 编译错误
- [ ] 跑通了一个新的配置组合

### 3.2 草稿生成规则

- 文件名：`<topic>-<YYYYMMDD>.md`（如 `laser-wavelength-20260617.md`）
- 严格按 `agent/TEMPLATES/knowledge-entry.md` 格式
- frontmatter 必须含 `draft: true` 和 `parent_skill: <skill-name>`
- 至少 3 个源码锚点
- 在草稿末尾追加 "## 审核备注" 段，列出可能的问题点

### 3.3 草稿内容禁令

- 不要把推测写成事实（用"待验证"标注）
- 不要复制大段源码（引用片段 + 路径:行号）
- 不要包含会过时的信息（如"当前进度"）

## 4. knowledge/ 子目录索引

> 完整内容在各 md 文件里。这里只放导航。

| 文件 | 内容 | 当前状态 |
|---|---|---|
| `knowledge/overview.md` | 物理原理 + 设计动机 | <draft/beta/stable> |
| `knowledge/params.md` | 参数字典 | <draft/beta/stable> |
| `knowledge/internals.md` | 源码调用图 | <draft/beta/stable> |
| `knowledge/recipes.md` | 典型配置 | <draft/beta/stable> |
| `knowledge/pitfalls.md` | 踩坑集 | <draft/beta/stable> |

## 5. 示例问答（至少 3 个，作为基准）

### Q1: <典型问题1>
**A**: <答案摘要，含源码锚点>

### Q2: <典型问题2>
**A**: <答案摘要，含源码锚点>

### Q3: <典型问题3>
**A**: <答案摘要，含源码锚点>

## 6. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| YYYY-MM-DD | 初始创建 | <name> |

## 7. 待办与已知问题

- [ ] <待补充的知识点>
- [ ] <已知但不完美的地方>
- [ ] <未来想加的功能>
```

---

## 使用示例：`flash-laser` 的 SKILL.md frontmatter（参考）

下面是按本模板填充后的 frontmatter 样例：

```yaml
---
name: flash-laser
description: |
  FLASH 4.8 激光（EnergyDeposition）单元专家。
  处理激光 parfile 参数（ed_*）、自定义截面函数、3D-in-2D 模式、调试 abort。
  触发词：激光, laser, ed_, EnergyDeposition, 光斑, 脉冲, 临界密度, 逆韧致
triggers:
  - 激光
  - laser
  - EnergyDeposition
  - ed_numberOfBeams
  - ed_wavelength
  - ed_gaussianExponent
  - 光斑
  - 脉冲
  - 临界密度
when_to_use: |
  用户问 laser 相关的 parfile 参数、激光物理机制、EnergyDeposition 源码、
  或在调试激光算例时调用本 skill。
when_not_to_use: |
  涉及 rt_*（辐射传输）、hy_*（流体）、mgd_*（多群扩散）参数时
  即使问题中提到 "laser" 也不调用本 skill——这些属于其他单元。
  如 "激光和 MGD 怎么耦合" 应优先调用 flash-radtrans。
layer: knowledge
phase: 1
status: draft
created: 2026-06-17
last_updated: 2026-06-17
owner: user
---
```

---

## 关键设计点

### `description` 字段是关键

Claude Code 主要靠这个字段决定是否调用本 skill。写法：

- **第一句**：本 skill 是什么 + 做什么（10-20 字）
- **第二句**：典型用例（10-20 字）
- **第三句**：触发关键词列表（逗号分隔）

❌ 反例：`"FLASH 助手"`（太泛，会被各种问题误触发）
✅ 正例：`"FLASH 4.8 激光单元专家。处理 ed_* 参数和 EnergyDeposition 源码。触发词：激光, laser, ed_"`

### `when_not_to_use` 同样重要

避免 skill 之间职责重叠。例如：
- `flash-laser` 不该被"激光和 MGD 耦合"触发——推给 `flash-radtrans`
- `flash-source-reader` 不该被"这个参数什么意思"触发——推给 `flash-param-query`

### `status` 字段控制可见性

- `draft` 阶段：Orchestrator 可以调用，但回答会标注"测试中"
- `beta`：可被调用，回答正常
- `stable`：默认状态
- `deprecated`：警告但仍可调用（用于过渡期）

---

## 模板版本

v1.0（2026-06-17）

任何对本模板的修改必须：
1. 更新本文件
2. 同步更新所有已存在的 SKILL.md（如有 breaking change）
3. 在 `agent/PROJECT_PLAN.md` §9 加 changelog
