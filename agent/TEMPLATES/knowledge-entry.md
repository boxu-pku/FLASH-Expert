# Knowledge Entry 统一模板

> 本文件是所有 `knowledge/*.md` 文件的强制模板。
> 每个 skill 的 knowledge 目录下的 5 个 md 文件都按这个格式写。

---

## 使用流程

1. 在 skill 的 `knowledge/` 目录下创建 md 文件
2. 复制下方"模板正文"部分
3. 替换 `<...>` 占位符
4. 删除 `> [说明]` 注释
5. 更新本 skill 的 SKILL.md §4 索引表状态

---

## 模板正文（复制到 knowledge/*.md）

```markdown
---
title: <条目标题>
skill: <所属 skill 名，如 flash-laser>
category: <overview | params | internals | recipes | pitfalls>
source_anchors:                              # 本条目引用的所有源码位置
  - source/path/file.F90:LXX-LYY
  - source/path/Config:LZZ
manual_ref: "<手册章节或 N/A>"
created: YYYY-MM-DD
last_verified: YYYY-MM-DD                    # 最后一次对照源码核对的日期
verifier: <用户名 or agent>
status: <draft | beta | stable>
tags:                                        # 便于检索的标签
  - <tag1>
  - <tag2>
---

# <条目标题>

> **TL;DR**：<60 字以内说清楚这是什么、做什么>

## 1. 物理原理 / 设计动机

<为什么存在这个东西，解决什么问题。
物理背景 + 数学公式（如有）。
不要复制手册原文，用自己的话改写。>

## 2. 源码实际实现

### 2.1 关键代码位置

| 功能 | 文件:行号 | 说明 |
|---|---|---|
| <功能1> | `source/path/file.F90:LXX` | <一句话> |
| <功能2> | `source/path/file.F90:LYY` | <一句话> |

### 2.2 核心代码片段

\`\`\`fortran
! source/path/file.F90:LXX-LYY
<代码片段，最多 20 行>
! ↑ 中文注释解释关键逻辑
\`\`\`

> **注意**：代码片段必须**严格匹配源码当前状态**。
> 源码改动后必须更新这里，并在 frontmatter 更新 `last_verified`。

## 3. 关键参数

| 参数 | 类型 | 默认 | 单位 | 含义 | 声明位置 |
|---|---|---|---|---|---|
| `<param1>` | <REAL/INT/BOOL/STRING> | <默认值> | <单位或无> | <一句话> | `Config:LXX` |
| `<param2>` | ... | ... | ... | ... | ... |

## 4. 典型用法

### 4.1 parfile 片段

\`\`\`fortran
# <场景描述>
<param1> = <value1>
<param2> = <value2>
\`\`\`

### 4.2 配套 setup 命令

\`\`\`bash
./setup <problem> <opts> -objdir=<path>
\`\`\`

## 5. 与其他单元的耦合

| 方向 | 关联单元 | 关系 |
|---|---|---|
| 上游 | <单元名> | <谁调用谁> |
| 下游 | <单元名> | <影响什么变量> |

## 6. 常见错误

| 错误信息 | 原因 | 修复 |
|---|---|---|
| `<错误字符串>` | <原因> | <修复步骤> |

## 7. 已知陷阱 / 与手册的差异

<手册这么说，但源码实际是那样。
或者：参数看似 X，实际是 Y。
**没有就写 "N/A"**。>

## 8. 延伸阅读

- 相关条目：`<其他 knowledge 文件路径>`
- 手册章节：<章节号>
- 外部资料：<论文 / 教程链接，如有>

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| YYYY-MM-DD | 初始创建 | <name> |
```

---

## 5 类 knowledge 文件的侧重点

不同 category 的条目，重点不同：

| category | 重点 | 长度参考 |
|---|---|---|
| `overview` | 物理原理 + 设计动机，少代码 | 200-400 行 |
| `params` | 参数字典，表格为主 | 100-300 行 |
| `internals` | 调用图 + 关键代码片段 | 300-600 行 |
| `recipes` | 可直接抄的 parfile/setup | 50-200 行 |
| `pitfalls` | 错误 → 原因 → 修复三段式 | 每条 30-80 行 |

## 关键规则

### 源码锚点是硬性要求

每个条目**必须**至少有 3 个 `source/path/file.F90:LXX` 形式的引用。
没有源码锚点的条目**不能**进入 stable 状态。

### `last_verified` 必须真实

每次对照源码核对后更新这个日期。
**超过 6 个月未验证的条目**自动降级为 `status: beta`。
**超过 1 年未验证**降级为 `draft`。

### 不要复制大段源码

引用代码片段**不超过 20 行**。完整代码让用户去看源文件，我们只引关键段 + 加中文注释。

### 公式用 KaTeX

行内：`$N_c = \pi m_e c^2 / (e^2 \lambda^2)$`
块级：
$$
P_{\text{ray}} = P_{\text{beam}} \times \frac{w_i}{\sum_j w_j}
$$

---

## 草稿模式（draft）

写完草稿时 frontmatter 设：
```yaml
status: draft
draft: true
parent_skill: <skill-name>
created_by: agent                # 或 user
review_notes: |
  <可能的疑问点、需用户确认的地方>
```

草稿放 `agent/drafts/pending/`，审核通过后：
1. 移到对应 skill 的 `knowledge/` 目录
2. 改 frontmatter：`status: beta`、删 `draft: true`
3. 在 PROJECT_PLAN §9 加 changelog

---

## 模板版本

v1.0（2026-06-17）
