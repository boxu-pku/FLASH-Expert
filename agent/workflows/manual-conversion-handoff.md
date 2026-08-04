# FLASH 4.8 用户手册转写 — 外包说明书（Handoff Specification）

> **本文件**：交给 opencode AI 独立执行的工作说明书（SOW）。
> **对方角色**：opencode AI 按本说明书完成全手册转写。
> **我方角色**：在另一对话框检查 progress report、验收、反馈。
> **沟通方式**：通过 `agent/manual/.progress/` 下的 progress report 异步沟通。

---

## 0. 启动前置（必读，按顺序）

接到本说明书后，**先按顺序读完以下 7 份文件**再开始动手：

| 序号 | 文件 | 用途 |
|---|---|---|
| 1 | **本文件**（`agent/workflows/manual-conversion-handoff.md`） | 任务定义、约束、流程、验收标准 |
| 2 | `agent/workflows/pdf-to-md.md` | 4 步工作流 SOP（提取/对照源码/改写/审核） |
| 3 | `agent/TEMPLATES/knowledge-entry.md` | 输出 md 文件的强制模板 |
| 4 | `agent/TEMPLATES/pitfall.md` | 如转"陷阱/常见错误"类章节的补充模板 |
| 5 | `agent/GOVERNANCE.md §5 审核清单` | 自检清单（4 类：格式/准确/边界/可维护） |
| 6 | `agent/LESSONS_LEARNED.md` 中的 **L-008 / L-009 / L-010** | 三条关键约束（源码锚点 / parfile 注释不可信 / 核心段精简） |
| 7 | `agent/manual/README.md` | 命名约定 + 已转章节状态 |

**确认读完**：在你的第一个 progress report 里写一句 "已读完 7 份前置文件，理解约束"。

---

## 1. 任务定义

### 1.1 输入

- **PDF**：`agent/manual/flash4_ug_4p8.pdf`（661 页，LaTeX 排版）
- **源码**：`source/` 全树（对照验证用）
- **目标 skill 参考**：`.claude/skills/flash-*/knowledge/`（已有的 stable 知识库）

### 1.2 输出

按 `agent/manual/<chapter>/<section>.md` 结构，把**整本手册**分章节转写为 md。

**注意**：不是把 PDF 原文复制粘贴成 md。是**改写 + 源码对照 + 标注差异**。改写后原文要点保留，但用更清晰的方式表达，并对照实际源码标注"手册 vs 源码差异"。

### 1.3 完成定义（Definition of Done）

**全本完成**的判据（同时满足）：

1. PDF 中**所有章节**（约 40 章，详见 §5）都有对应 md 文件
2. 每个 md 都通过 `agent/tools/promote_draft.sh promote` 流程，status 为 `beta`
3. `agent/manual/README.md` 的"已转换"计数达到全本
4. `agent/PROJECT_PLAN.md §9` 加一行 "全本转写完成"
5. 所有 progress report 都已被我方标 "✅ 通过" 或处理完返工

---

## 2. 关键约束（红线，违反即返工）

### 2.1 必做

- ✅ **每个 md 至少 3 个源码锚点**（`source/path/file.F90:LXX` 形式），且**实际验证过**行号对应内容
- ✅ **frontmatter 字段齐全**（按 `knowledge-entry.md` 模板）
- ✅ **代码片段 ≤ 20 行**，含中文 `! ↑ 中文` 注释
- ✅ **公式用 KaTeX**（行内 `$...$`，块级 `$$...$$`）
- ✅ **中文为主**（代码、公式、变量名保留原文）
- ✅ **用自己话改写**（不复制大段手册原文，可引短句并标页码）
- ✅ **对照源码标注差异**（手册 2024，源码可能已改 → 写到 §"已知陷阱 / 与手册的差异"）
- ✅ **状态字段**：新建文件 `status: draft`；通过自检后改 `status: beta`（不在新建时直接给 stable）
- ✅ **last_verified**：填实际对照源码的日期，不写未来日期
- ✅ **每章完成后写 progress report**（见 §6）

### 2.2 禁做

- ❌ **不要一次性转全本**（D-003 决策）：每章独立完成，提交审核
- ❌ **不要修改 `flash4_ug_4p8.pdf` 原文件**
- ❌ **不要把转写产物放到 `.claude/skills/*/knowledge/`**（那是 skill 自己的；手册转写在 `agent/manual/`）
- ❌ **不要编造源码位置**：必须 `rg`/`grep` 验证；找不到就写"未在源码中找到"或求助
- ❌ **不要把推测写成事实**：不确定时用 "（待确认）" 或写到 progress report 等我方确认
- ❌ **不要省略"对照源码"步骤**（这是 pdf-to-md §2 的 Step 2，最核心的一步）
- ❌ **不要复制大段手册原文**（≥ 3 行连续原文算违规）
- ❌ **不要使用 mermaid 图**（L-002：用文字 + ASCII 缩进表达调用关系）
- ❌ **不要在转写时同时改 PDF 之外的其他项目文件**（如 SKILL.md、PROJECT_PLAN.md）；这些由我方做
- ❌ **不要跳过 progress report**（即使该章很简单）

---

## 3. 4 步工作流（每章按此做）

> 详细版见 `agent/workflows/pdf-to-md.md §2`。本节是精简提示卡。

### Step 1：提取 PDF 文本

```bash
# 例：转 §18.4（页 276-296）
mkdir -p agent/manual/18-local-source-terms

pdftotext -layout -f 276 -l 296 \
    agent/manual/flash4_ug_4p8.pdf \
    agent/manual/18-local-source-terms/18.4-energy-deposition-raw.txt
```

**关键参数**：
- `-layout`：保留排版（表格、公式不乱）
- `-f <N>` / `-l <N>`：起止页（**用 PDF 实际页码，不是手册印刷页码**）

**页码定位**：

如果不知道某章在 PDF 哪页：
```bash
# 看 TOC（PDF 前 30 页）
pdftotext -layout -f 1 -l 30 agent/manual/flash4_ug_4p8.pdf - | grep -i "<章节关键词>"

# 全 PDF 搜
pdftotext agent/manual/flash4_ug_4p8.pdf - | grep -n -i "<关键词>" | head -20
```

### Step 2：对照源码（最核心的一步）

读 raw txt，**每提到**以下任一项就立刻在源码里定位：

| 手册提到的 | 在哪找 | 命令 |
|---|---|---|
| 函数名（如 `ed_setupBeams`） | `source/` | `rg -n "^subroutine ed_setupBeams" source/` |
| 参数名（如 `ed_wavelength`） | `source/**/Config` | `find source -name Config \| xargs grep "ed_wavelength"` |
| 变量索引（如 `TELE_VAR`） | `bin/Flash.h.tpl` | `rg -n "TELE_VAR" bin/Flash.h.tpl` |
| 模块（如 `Driver_interface`） | `source/**/*_interface.F90` | `rg -n "module Driver_interface" source/` |

**记录到 raw txt 旁边**作为 §3 改写的源码锚点。找不到的标注"未在源码中找到"，写到 progress report 求助。

**重要**：手册可能引用了**已经改名/删除**的符号。这是"手册 vs 源码差异"，必须记录。

### Step 3：改写为 knowledge-entry 模板

打开 `agent/TEMPLATES/knowledge-entry.md`，复制"模板正文"，按以下规则填充：

**frontmatter 必须含**：
```yaml
---
title: <章节标题（中文）>
skill: flash-<对应物理单元 skill 名>           # 如 18.4 → flash-laser；找不到对应 skill 写 N/A
category: <overview | params | internals | recipes | pitfalls>
source_anchors:                                # 至少 3 个
  - source/path/file.F90:LXX
  - source/path/Config:LXX
  - source/path/file.F90:LYY
manual_ref: "FLASH 4.8 User Guide §<章节号> 页 <N>-<M>"
created: YYYY-MM-DD                            # 当天日期
last_verified: YYYY-MM-DD                      # = 对照源码完成的当天
verifier: opencode-ai
status: draft                                  # 新建一律 draft
tags:
  - <章节关键词 1>
  - <章节关键词 2>
---
```

**正文 9 段**（按模板）：

1. **TL;DR**（60 字摘要）
2. **物理原理/设计动机**（改写手册原文）
3. **源码实际实现**（含 §2 对照结果，**核心段**）
4. **关键参数**（表格，含默认/单位/源码声明位置）
5. **典型用法**（parfile/setup 片段）
6. **与其他单元的耦合**
7. **常见错误**
8. **已知陷阱 / 与手册的差异**（**重要**：手册老，源码可能改了）
9. **延伸阅读**

**长度参考**（按 `knowledge-entry.md §5 类`）：
- overview 类：200-400 行
- params 类：100-300 行（表格为主）
- internals 类：300-600 行
- recipes 类：50-200 行
- pitfalls 类：每条 30-80 行

**控制原则（L-010）**：核心段（TL;DR / 物理原理 / 源码实现 / 关键参数）必给且详细；其他段按内容有无决定，可以简短或 N/A。

### Step 4：自检 + 放 pending + 写 progress report

**4.1 自检**（按 §4 清单逐条检查）

**4.2 放 pending**：
```bash
mv agent/manual/<chapter>/<section>.md \
   agent/drafts/pending/<section>-<YYYYMMDD>.md

# 同时保留 raw txt 在原目录便于回查（不要删）
```

**4.3 写 progress report**：见 §6 格式。

**4.4 不要自己执行 promote**：promote 由我方做。你只负责自检 + 放 pending + 写 report。

---

## 4. 自检清单（提交前必查）

### 4.1 格式合规（GOVERNANCE.md §5.1）

- [ ] frontmatter 9 字段齐全（title/skill/category/source_anchors/manual_ref/created/last_verified/verifier/status/tags）
- [ ] `source_anchors` 至少 3 项，每项格式 `source/path/file.F90:LXX`
- [ ] 代码片段每段 ≤ 20 行
- [ ] 没有连续 ≥ 3 行的手册原文复制

### 4.2 内容准确（§5.2）

- [ ] **随机抽 1-2 个源码锚点**，用 `sed -n '<行号>p' <file>` 验证行号对内容
- [ ] 参数默认值与 Config 文件一致（`find source -name Config | xargs grep <参数名>`）
- [ ] 公式与源码实现一致（不是手册怎么写就怎么抄）
- [ ] 没有把推测写成事实（含 "可能"、"应该" 的句子标 "(待确认)"）

### 4.3 边界清晰（§5.3）

- [ ] 不与已有 `.claude/skills/*/knowledge/*.md` 内容重复（用 `rg -i <关键词> .claude/skills/*/knowledge/` 查）
- [ ] 如有重叠，在 md 里加 `> 注：本条目与 .claude/skills/flash-X/knowledge/Y.md 互补，前者侧重 ...，后者侧重 ...`

### 4.4 可维护性（§5.4）

- [ ] `last_verified` 是今天
- [ ] `tags` 标签合理（3-7 个，便于检索）
- [ ] §9 变更日志有 "初始创建" 行

---

## 5. 章节清单与优先级

### 5.1 全本章节清单（PDF TOC）

**先做这步**：从 PDF 前 30 页提取完整 TOC，写到 `agent/manual/.progress/00-toc.md`。这是 §1 完成定义的基础。

```bash
pdftotext -layout -f 1 -l 30 agent/manual/flash4_ug_4p8.pdf - > /tmp/toc-raw.txt
# 整理为结构化清单（章号 / 章名 / 节号 / 节名 / 起止页）
```

### 5.2 转写优先级

按 Phase 2 skill 建设计划排序（已 stable 的 skill 对应章节优先）：

| 优先级 | 章节 | 对应 skill | PDF 页范围（参考） |
|---|---|---|---|
| ★★★ | §18.4 Energy Deposition | flash-laser（已 stable） | 276-296 |
| ★★★ | §2 Setup and Build | flash-setup-system（Phase 2） | 30-60 |
| ★★★ | §3-5 Simulation Setup | flash-setup-system | 60-100 |
| ★★ | §18.1 Burn | flash-sourceterms | 264-270 |
| ★★ | §18.2 Ionization | flash-sourceterms | 270-271 |
| ★★ | §18.3 Stir | flash-sourceterms | 272-276 |
| ★★ | §19 Material Properties | flash-material | 300-320 |
| ★★ | §18 其他 sourceTerms | flash-sourceterms | 264-300 |
| ★ | §7-8 Grid | flash-grid | — |
| ★ | §9-12 Hydro | flash-hydro | — |
| ★ | §13-15 EOS | flash-eos | — |
| ★ | §16-17 RadTrans | flash-radtrans | — |
| ★ | §20+ 工具与诊断 | 各 skill | — |
| ★ | §1, §6, 其他 | — | — |

**节奏建议**：每次会话转 1-3 章（视复杂度）。`★★★` 章先做。

### 5.3 章节间依赖

某些章节会引用其他章节。处理规则：

- 引用**已转**章节 → 用相对路径链接：`[详见 ../18-local-source-terms/18.4-energy-deposition.md]`
- 引用**未转**章节 → 标 `(待转)`：`详见 §16.2 Hydro（待转）`
- 不要因为依赖就乱序。先把当前章节做好，链接留 stub。

---

## 6. Progress Report 格式（每章完成时必写）

**文件路径**：`agent/manual/.progress/<chapter>-<YYYYMMDD>.md`

**模板**：

```markdown
---
chapter: "§18.4 Energy Deposition"
pdf_pages: 276-296
opencode_session: <你的会话标识>
date: YYYY-MM-DD
duration_min: <实际耗时，估>
status: ready_for_review                # ready_for_review | needs_help | partial
---

# Progress Report: <章节号 章节名>

## 完成情况

- [x] Step 1 提取 PDF（pdftotext -layout -f 276 -l 296）
- [x] Step 2 对照源码
- [x] Step 3 改写为模板
- [x] Step 4 自检 + 放 pending + 写本 report

## 产物

- **草稿位置**：`agent/drafts/pending/18.4-energy-deposition-YYYYMMDD.md`
- **行数**：XXX 行
- **源码锚点数**：X 个（要求 ≥ 3）
- **raw txt 保留在**：`agent/manual/18-local-source-terms/18.4-energy-deposition-raw.txt`

## 自检结果

- [x] 格式合规
- [x] 内容准确（随机抽 2 个锚点验证通过）
- [x] 边界清晰（查过 `.claude/skills/flash-laser/knowledge/`，无重复或已加互补说明）
- [x] 可维护性

## 不确定的地方（needs_help 时必填）

1. <手册第 X 页提到 Y，但在源码中找不到；可能已改名？>
2. <参数 Z 的单位手册没写，我从源码推断为 W，但不确信>
3. <章节交叉引用 §A.B 但还没转，留了 stub>

## 手册 vs 源码差异（重要发现）

| 手册说 | 源码实际 | 出处 |
|---|---|---|
| <手册原文> | <源码实际> | <文件:行号> |

## 给我方的请求

- [ ] 请 review §X.Y 段，是否准确
- [ ] 请确认 <某个推断>
- [ ] 无请求（status: ready_for_review）

## 下一步计划

- 转下一章：<下一章号>
```

**报告原则**：
- 老实说，不要美化（不知道就写不知道）
- 报告长度 ≤ 100 行（核心信息）
- 如有 raw txt 大段内容需我方看，引用具体行号而不是复制过来

---

## 7. 验收标准（我方判断通过/返工的依据）

我方在当前对话框读你的 progress report + 对应草稿，按以下标准判断：

### 7.1 ✅ 通过条件（同时满足）

1. 4 步流程都有产物（raw txt / 草稿 / report 齐全）
2. 自检清单 4 类全部勾上
3. 源码锚点 ≥ 3 个且**实际验证**（我方会随机抽 1-2 个查）
4. 无 "可能/应该" 这种未确认措辞（除非标 "(待确认)"）
5. progress report 老实标注不确定项（不是漏标）

通过后我方执行 `promote_draft.sh promote`，把草稿从 pending/ 移到 `agent/manual/<chapter>/`，status 改 beta，并在 changelog 加一行。

### 7.2 ⚠️ 小返工

- 个别源码锚点行号偏移（源码改过）→ 退回修订
- 个别段落措辞不准 → 退回修订
- 缺正文字段（如缺"延伸阅读"）→ 退回补全

**返工流程**：我方在 progress report 末尾加 "## 返工要求" 段，列具体问题。你修订后更新 report 顶部 status 为 `ready_for_review_revised`。

### 7.3 ❌ 严重返工

- 自检清单大类（4.1/4.2/4.3/4.4）任一类全不通过
- 编造源码位置（重罚，触发暂停 + 全本审计）
- 大段复制原文

严重返工我方会在 progress report 写 "## 严重返工"，并要求你**先暂停转新章**，回头把已转章节按问题清单全部 review 一遍。

---

## 8. 求助信号（什么时候停下来问）

**遇到以下情况立刻暂停，写 progress report 标 `status: needs_help`，等我方回复**：

| 情况 | 求助方式 |
|---|---|
| 手册某章在源码里完全找不到对应实现 | report 里描述手册说什么，源码里 grep 什么关键词都没命中 |
| 手册公式与源码实现严重不一致（不是小差异） | report 里贴手册公式 + 源码片段，问"哪个对" |
| 章节范围在 PDF 里定位不到（找不到起止页） | 用 `pdftotext` 全文搜后仍找不到 |
| 章节内容涉及多个 skill 跨单元（如 Grid × Hydro 耦合） | report 里问归属哪个 skill |
| 手册引用了已废弃/重命名的 unit | report 里贴 unit 名，问对应现在的什么 |
| 自检 4.1 格式合规不通过（不知道怎么改） | report 里贴当前 frontmatter |
| 同一章被多次返工，仍无法通过 | 暂停该章，转下一章并标 needs_help |

**不要**自己猜、自己编。**老实说"找不到"** 比编造强 100 倍。

---

## 9. 进度跟踪

### 9.1 全局进度文件

**首次启动时创建**：`agent/manual/.progress/00-master.md`

内容：
```markdown
# FLASH 4.8 用户手册转写总进度

> 启动日期：YYYY-MM-DD
> 责任 AI：opencode
> 验收方：用户（在另一对话框）

## 章节状态

| 章节 | 优先级 | 状态 | 草稿位置 | 进度报告 | 我方验收 |
|---|---|---|---|---|---|
| §18.4 Energy Deposition | ★★★ | draft | pending/18.4-...-YYYYMMDD.md | .progress/18.4-YYYYMMDD.md | ⏳ 待审 |
| §2 Setup | ★★★ | not_started | — | — | — |
| ... | | | | | |

## 全局统计

- 已完成（status: beta）：X / 总章数
- 待审核（status: draft in pending）：X
- 返工中：X
- 求助中：X

## 我方汇总反馈

（我方在此段汇总跨章节的反馈）
```

**每完成一章**：更新此文件的对应行。

### 9.2 单次会话节奏

- 一次会话转 1-3 章（视复杂度）
- 每章独立提交 progress report
- 会话结束前更新 `00-master.md` 全局统计

---

## 10. 工具命令速查

### 10.1 PDF 提取

```bash
# 单页（看 TOC）
pdftotext -layout -f 1 -l 1 agent/manual/flash4_ug_4p8.pdf -

# 范围（转某章）
pdftotext -layout -f <起页> -l <止页> \
    agent/manual/flash4_ug_4p8.pdf \
    agent/manual/<chapter-dir>/<section>-raw.txt

# 全 PDF 搜关键词
pdftotext agent/manual/flash4_ug_4p8.pdf - | grep -n -i "<关键词>"

# 提图片（罕见用）
pdfimages -png -f <页> -l <页> agent/manual/flash4_ug_4p8.pdf \
    agent/manual/<chapter-dir>/img/fig
```

### 10.2 源码对照

```bash
# 找函数定义
rg --type-add 'f90:*.{F90,f90}' -tf90 -n "^subroutine\s+<Name>" source/

# 找 call sites
rg --type-add 'f90:*.{F90,f90}' -tf90 -n "call\s+<Name>\b" source/

# 找参数声明
find source -name Config -type f | xargs grep -n "^PARAMETER\s\+<name>" 2>/dev/null

# 找变量索引
rg -n "<NAME>_VAR" bin/Flash.h.tpl

# 大小写不敏感兜底
rg -i -n "<name>" source/
```

### 10.3 已有 skill 知识库（防重复）

```bash
# 查某关键词是否已被 skill 知识库覆盖
rg -i "<关键词>" .claude/skills/*/knowledge/

# 列某 skill 已有的 knowledge 条目
ls .claude/skills/flash-*/knowledge/
```

---

## 11. 附录：常见错误模式

> 这些是过去转写时反复踩的坑（来自 `agent/LESSONS_LEARNED.md`），先看一遍避免重蹈覆辙。

| 教训 | 应用到转写 |
|---|---|
| **L-008**：源码相关才贴代码 | 报错类章节贴 abort 触发代码；非源码内容（链接器错等）不贴凑数代码 |
| **L-009**：parfile/setup 注释不可信 | 转写"典型用法"段时，如引用 parfile/setup 命令，**必须实际验证**注释和实际行为一致 |
| **L-010**：核心段精简 | 改写时核心 4 段（TL;DR/原理/实现/参数）必给且详细；其他段按内容有无决定 |
| **L-002**：不用 mermaid | 调用关系一律用文字 + ASCII 缩进 |

---

## 12. 第一周里程碑（建议节奏）

| 里程碑 | 内容 |
|---|---|
| M1（首会话） | 读 7 份前置文件；建 `.progress/` 目录；写 `00-master.md` 骨架；写 `00-toc.md`（PDF TOC 整理） |
| M2 | 转 §18.4 Energy Deposition（★★★，激光，已 stable skill 参考，最容易验证流程） |
| M3 | 转 §2 Setup and Build（★★★，flash-setup-system） |
| M4 | 转 §18.1-3 三个 sourceTerms 章（★★，flash-sourceterms） |
| M5 | 转 §19 Material Properties（★★，flash-material） |
| M6 | 转 §7-8 Grid、§9-12 Hydro（★，量大，按节拆） |
| ... | 后续章节按 TOC 推进 |

**每完成一个里程碑**：在 `00-master.md` 标记 + 等我方验收。

---

## 13. 我方承诺

- 我方会**在每份 progress report 提交后 24 小时内**回复（通过/返工/求助响应）
- 我方在反馈时会**指出具体问题**（不是"重新做"这种空话）
- 我方不会要求你"完美"，**老实说 + 不编造**就够
- 你写的不确定项我方会优先 review，不会因为你标 "needs_help" 就扣分

---

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（外包说明书 v1.0） | claude |
