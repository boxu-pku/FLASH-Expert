# FLASH Expert Agent — 架构规范

> 本文件是 multi-skill 架构的权威定义。所有 skill 必须遵循此处的结构和协议。
> 修改本文件需要同步更新 `PROJECT_PLAN.md` 的 §5 决策记录。

---

## 0. 设计哲学

**核心原则**：主 Agent 不写业务逻辑，业务逻辑全部下沉到 skill。

| 角色 | 谁来扮演 | 职责 |
|---|---|---|
| **Orchestrator（主控）** | Claude Code 本身 | 理解用户意图、选择 skill、组合结果、维护对话 |
| **Skill（专家）** | `skills/<name>/`（真身；各 harness 目录为挂载链接） | 单一领域的全部知识 + 行为协议 |
| **Knowledge Base（知识库）** | 每个 skill 内部的 `knowledge/` | 该领域结构化的 md，带源码锚点 |
| **Tools（工具脚本）** | 操作层 skill 内部的 `tools/` | 可独立运行的 Python/Bash 脚本 |

**反模式**（禁止）：
- ❌ 写一个"大 skill"装所有知识
- ❌ Skill 之间直接互相调用（必须经 Orchestrator）
- ❌ Knowledge md 跨 skill 共享（必须各自维护）
- ❌ Knowledge md 不带源码锚点
- ❌ Skill 之间职责重叠

---

## 1. 整体架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                    用户对话层（Claude Code 主上下文）                │
│                                                                     │
│  • 项目 CLAUDE.md 描述整个 skill 系统                                │
│  • Claude Code 看到所有 skill 的 description 字段                    │
│  • 根据用户意图自动选 1 个或多个 skill                               │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               │ 通过 Skill 工具调用
                               │
        ┌──────────────────────┴──────────────────────┐
        │                                             │
        ▼                                             ▼
┌──────────────────────┐                  ┌──────────────────────┐
│  知识层 skill (11)   │                  │  工具层 skill (5)    │
│  按物理单元切        │                  │  按功能切            │
│                      │                  │                      │
│  flash-laser         │                  │  flash-source-reader │
│  flash-driver        │                  │  flash-pitfall-finder│
│  flash-grid          │                  │  flash-param-query   │
│  flash-hydro         │                  │  flash-setup-builder │
│  flash-eos           │                  │  flash-manual-search │
│  flash-radtrans      │                  └──────────────────────┘
│  flash-material      │
│  flash-sourceterms   │                  ┌──────────────────────┐
│  flash-io            │                  │  操作层 skill (2)    │
│  flash-multispecies  │                  │  端到端任务          │
│  flash-diffuse       │                  │                      │
└──────────────────────┘                  │  flash-case-runner   │
                                          │  flash-result-analyzer│
                                          └──────────────────────┘
```

---

## 2. 18 个 Skill 完整清单

### 2.1 知识层 skill（11 个）

每个对应一个 FLASH 物理单元。**职责单一：回答该单元的"是什么/为什么/怎么用"问题**。

| Skill | 对应源码单元 | 核心职责 | Phase |
|---|---|---|---|
| `flash-laser` | `physics/sourceTerms/EnergyDeposition/` | 激光设置、参数、自定义截面、调试 | 1 |
| `flash-driver` | `Driver/` | 主循环、时间步进、sourceTerms 调用顺序 | 2 |
| `flash-grid` | `Grid/` | AMR、paramesh/UG/Chombo 后端、guard cells | 2 |
| `flash-hydro` | `physics/Hydro/` | split/unsplit 求解器、Riemann、限幅器 | 2 |
| `flash-eos` | `physics/Eos/` | multiTemp/Multitype/Tabulated、状态方程 | 2 |
| `flash-radtrans` | `physics/RadTrans/` | MGD 多群扩散、辐射-物质耦合 | 2 |
| `flash-material` | `physics/materialProperties/` | Conductivity/Opacity/Viscosity | 2 |
| `flash-sourceterms` | `physics/sourceTerms/`（除 Laser） | Burn/Cool/Heat/Heatexchange/Flame/Stir | 2 |
| `flash-io` | `IO/` | HDF5 plotfile/checkpoint、flash.par 解析 | 2 |
| `flash-multispecies` | `Multispecies/` | 物种定义、质量分数、abundance | 2 |
| `flash-diffuse` | `physics/Diffuse/` | 扩散求解器、HYPRE 调用 | 2 |

**额外**（不属于物理单元，但必要）：
| `flash-setup-system` | `bin/setup.py` + Config 文件 | setup 命令语法、Config 机制、单元 DAG | 2 |

### 2.2 工具层 skill（5 个）

**跨单元复用的小工具，纯功能性**。

| Skill | 职责 | 输入 → 输出 |
|---|---|---|
| `flash-source-reader` | 给定函数/参数/变量名，定位源码并解释 | 名字 → 源码路径:行号 + 上下文 + 中文注释 |
| `flash-pitfall-finder` | 给定错误信息，匹配踩坑库 | 错误字符串 → 原因 + 修复步骤 |
| `flash-param-query` | 跨单元查参数定义 | 参数名 → 类型/默认/单位/声明位置 |
| `flash-setup-builder` | 根据需求生成 setup 命令 | 物理需求 → 完整 `./setup ...` 命令 |
| `flash-manual-search` | 在转好的手册 md 里检索 | 关键词 → 手册段落 + 源码锚点 |

### 2.3 操作层 skill（2 个）

**端到端任务，自带 tools/ 目录**。

| Skill | 职责 | 自带工具 |
|---|---|---|
| `flash-case-runner` | setup → make → run，含错误恢复 | setup_runner.py / make_runner.py / run_runner.py / flash_log_parser.py |
| `flash-result-analyzer` | 跑工具脚本，输出 markdown 报告 | energy_balance.py / laser_coupling.py / plot_summary.py / compare_to_benchmark.py |

### 2.4 Skill 总数

```
11（知识层） + 5（工具层） + 2（操作层） = 18 个
```

---

## 3. Skill 内部统一结构

每个 skill 严格按下面结构组织（用 `flash-laser` 演示）：

```
skills/flash-laser/
├── SKILL.md                    # ★ 必需：frontmatter + 行为协议
├── knowledge/                  # 该领域结构化知识
│   ├── overview.md             # 物理原理 + 设计动机（必含源码锚点）
│   ├── params.md               # 参数字典（表格形式）
│   ├── internals.md            # 源码调用图（mermaid 图）
│   ├── recipes.md              # 典型 parfile 配置
│   └── pitfalls.md             # 该领域踩坑集
├── examples/                   # 可直接复用的 parfile 片段
│   ├── gaussian-spot.par
│   ├── ring-shape.par
│   └── multi-beam.par
└── tools/                      # 仅操作层和部分工具层 skill 需要
    └── (Python 脚本)
```

**强制规则**：
- 知识层 skill 的 `knowledge/` 必须 5 个文件齐全（即使初期为占位）
- 每个 md 文件必须按 `TEMPLATES/knowledge-entry.md` 格式
- `SKILL.md` 必须按 `TEMPLATES/skill-template.md` 格式
- 不得在 skill 根目录直接放 md（一律进 `knowledge/`）

---

## 4. SKILL.md 的关键字段

详细模板见 `TEMPLATES/skill-template.md`。这里列必须字段：

```yaml
---
name: flash-laser                  # 全局唯一，与目录名一致
description: |                     # ★ 决定 Claude Code 是否调用本 skill
  FLASH 4.8 激光（EnergyDeposition）
  单元专家。处理激光设置、parfile 参数、自定义截面函数、调试 abort。
  触发词：激光 / laser / ed_ / EnergyDeposition / 光斑 / 脉冲
triggers:                          # 显式触发关键词
  - 激光
  - laser
  - EnergyDeposition
  - ed_numberOfBeams
  - ed_wavelength
  - 光斑
when_to_use: |                     # 何时应该用本 skill
  用户问到激光相关参数、parfile 中 ed_* 段、激光物理机制、
  EnergyDeposition 单元的源码时调用本 skill。
when_not_to_use: |                 # 何时**不**该用（避免误触发）
  涉及辐射传输（rt_*）、流体（hy_*）等问题时不调用本 skill，
  即使问题里出现 "ed_" 前缀也只是参数名引用。
layer: knowledge                   # knowledge / tool / operator
phase: 1                           # 该 skill 在哪个 Phase 上线
status: draft                      # draft / beta / stable / deprecated
last_updated: 2026-06-17
---
```

**关键点**：
- `description` 字段是 Claude Code 用来匹配用户意图的——**写得越精准，越不会被错误触发**
- `when_not_to_use` 字段同等重要——避免和其他 skill 重叠
- `status` 字段：draft 表示骨架、beta 表示可测试、stable 表示验收通过、deprecated 表示废弃中

---

## 5. 调度协议

### 5.1 Claude Code 如何选 skill

Claude Code 在每次用户提问时：

1. **读取所有 skill 的 `description` 字段**（系统自动，无需手动操作）
2. **根据用户问题语义**匹配最相关的 skill
3. **如果命中**，调用 `Skill` 工具传入 skill 名
4. **如果未命中**，回退到主上下文，可能建议生成草稿

### 5.2 多 skill 协作

Orchestrator 可以在**一个对话回合内**调用多个 skill。典型协作模式：

| 场景 | 协作链 |
|---|---|
| 用户问"为什么我的激光沉积比预期少 30%" | `flash-laser`（排查思路）→ `flash-pitfall-finder`（匹配错误）→ `flash-source-reader`（验证源码） |
| 用户问"帮我跑 Sedov 并检查结果" | `flash-case-runner`（跑）→ `flash-result-analyzer`（分析） |
| 用户问"ed_laser3Din2D 是什么" | `flash-param-query`（查参数）→ `flash-laser`（详细解释） |
| 用户问"怎么改 setup 加新单元" | `flash-setup-system`（机制）→ `flash-setup-builder`（生成命令） |

### 5.3 Skill 之间禁止直接调用

skill A 不能在 SKILL.md 里写"调用 skill B"。需要协作时由 Orchestrator 串起来。这样保证：
- 每个 skill 单独可测试
- Orchestrator 可以重新编排
- skill 失效不影响其他

---

## 6. 命名约定

| 类型 | 规则 | 示例 |
|---|---|---|
| Skill 目录名 | `flash-<unit>` 全小写连字符 | `flash-laser`, `flash-source-reader` |
| Knowledge 文件 | 全小写下划线 | `overview.md`, `params.md` |
| 工具脚本 | 全小写下划线 `.py` | `setup_runner.py`, `flash_log_parser.py` |
| Examples | 小写下划线 `.par` | `gaussian-spot.par` |

---

## 7. Skill 生命周期

```
draft → beta → stable → (deprecated → archived)
  ↑       ↑       ↑          ↑
建骨架  内测可用  验收通过   长期不用
```

| 状态 | 判据 | 行动 |
|---|---|---|
| `draft` | 仅有 SKILL.md 骨架 | 不被 Orchestrator 优先选择 |
| `beta` | knowledge 文件齐 + 通过基本问答测试 | 可被调用，但回答标注"测试中" |
| `stable` | 通过验收考题 | 正式使用 |
| `deprecated` | 3 个月触发率 < 5% | 标记废弃，下个 review 周期归档 |
| `archived` | 移到仓库根 `skills.archived/`（脱离挂载） | 不再加载 |

**状态变更流程**：
1. 修改 SKILL.md 的 `status` 字段
2. 在 PROJECT_PLAN.md §7 更新该 skill 行
3. 在 §9 变更日志加一行

---

## 8. 与 `agent/` 目录的关系

`skills/` 和 `agent/` 是**两个不同的目录**：

```
仓库根/
├── skills/                  # ★ 18 个 skill 真身（自包含，可独立分发）
│   ├── flash-laser/
│   ├── flash-driver/
│   └── ...
├── .claude/skills  -> ../skills   # 挂载链接（Claude Code）
├── .zcode/skills  -> ../skills    # 挂载链接（ZCode）
├── .agents/skills -> ../skills    # 挂载链接（DSH / Codex 等，Agent Skills 标准目录）
├── install.sh               # 外部用户安装器（挂载到任意 harness / 任意项目）
└── agent/                   # ★ 开发工作台：治理 + 方法论（不被 harness 自动加载）
    ├── PROJECT_PLAN.md      # 项目指挥塔
    ├── ARCHITECTURE.md      # 本文件
    ├── GOVERNANCE.md        # 决策与维护规范
    ├── TEMPLATES/           # skill 和 knowledge 的模板
    ├── workflows/           # 跨 skill 共享的 SOP（如 pdf-to-md）
    ├── exam/                # 验收考题库
    ├── drafts/              # ★ 待审核的草稿（pending/archive）
    └── shared-tools/        # 跨 skill 复用的辅助脚本
```

**多 harness 挂载原则**（2026-11 起，v1.2）：skill 真身只有 `skills/` 一份，所有 harness 目录都是指向它的符号链接；新增 harness 支持 = 加一条挂载链接 + `install.sh` 表里加一行，**不复制内容、不分叉维护**。SKILL.md 正文不得硬编码 `.claude/` 等具体挂载路径。

**关键区别**：
- `skills/`（经挂载链接）里的东西会被 harness 自动加载到上下文
- `agent/` 里的东西是"项目管理/开发流程"，agent 通过 Read 工具按需读取；对外分发时 skill 不依赖它也能工作（治理类引用一律写成"若项目配有 agent/ 工作区则……"的条件式）

**为什么这样分**：
- 避免每个 skill 都重复一份模板
- 让 PROJECT_PLAN 这种"元文档"不污染 skill 上下文
- 草稿区 (`drafts/`) 不被自动加载，避免未审核内容影响回答质量

---

## 9. CLAUDE.md 的角色

项目根目录的 `CLAUDE.md` 是 Claude Code 的入口提示。必须包含：

```markdown
## FLASH Skill 系统

本项目包含 18 个专门 skill（11 物理 + 5 工具 + 2 操作），
全部位于 `skills/`（`.claude/skills` 等挂载链接指向它）。架构和完整清单见 `agent/ARCHITECTURE.md`。

### 调用规则
- 用户提问时，**优先**匹配最相关的 skill 而不是从主上下文回答
- 跨领域问题可以调用多个 skill
- 不知道答案时，**老实说**并建议生成草稿到 `agent/drafts/pending/`

### 项目状态
当前进度见 `agent/PROJECT_PLAN.md` §1 Dashboard。
用户问"做到哪了"或"下一步是什么"时，先读 PROJECT_PLAN.md。
```

---

## 10. 版本与变更

本架构文档版本：v1.0（2026-06-17，初始版本）

变更必须同步更新：
1. 本文件
2. `PROJECT_PLAN.md` §5 加新决策（D-XXX）
3. `PROJECT_PLAN.md` §9 变更日志
4. 受影响的 skill 的 SKILL.md（如有）

---

## 附录：架构决策溯源

| 决策 | 来源 | 状态 |
|---|---|---|
| 单 skill vs multi-skill | D-005（2026-06-17） | multi-skill |
| Skill 粒度（最细 vs 合并） | D-006（2026-06-17） | 最细，18 个全独立 |
| Orchestrator 身份 | 本文 §0 | Claude Code 本身 |
| Skill 之间能否互调 | 本文 §5.3 | 禁止 |
| Knowledge md 是否跨 skill 共享 | 本文 §0 | 禁止 |
