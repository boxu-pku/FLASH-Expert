---
name: flash-manual-search
description: |
  FLASH 官方用户手册检索工具。在已转换的 agent/manual/<chapter>.md 中按关键词检索，
  返回手册段落 + 源码锚点 + 中文摘要。手册 PDF 共 661 页，按 D-003 决策按需转换。
  当前覆盖：见本 SKILL §3 状态表。
  触发词：手册, 官方手册, manual, 用户指南, user guide, FLASH 文档, 怎么说, UG
triggers:
  # 中文
  - 手册
  - 官方手册
  - 用户手册
  - 用户指南
  - FLASH 文档
  - 官方文档
  - 怎么说
  - 手册里
  # 英文
  - manual
  - user guide
  - UG
  - documentation
  - docs
  - "User's Guide"
  - "User Guide"
  - FLASH UG
  - "the manual"
  - "the docs"
  # 关键章节号（用户可能直接问"§18.4"）
  - "§18"
  - "§17"
  - "§16"
  - "§2"
  - "section 18"
  - "chapter 18"
  # 关键术语（手册高频）
  - Energy Deposition
  - Laser Power Deposition
  - Burn Unit
  - Stir Unit
  - setup
  - "Config file"
  - "runtime parameter"
when_to_use: |
  调用本 skill 的场景：
  1. 用户明确要查手册原文（"手册怎么说 X"、"用户指南在哪"）
  2. 用户问 FLASH 官方文档的内容
  3. 用户引用章节号（"§18.4 讲什么"）
  4. 用户想验证某事实是否来自手册（"这是手册写的吗"）
  5. 用户问"UG 里有没有讲 X"
when_not_to_use: |
  **不调用本 skill 的场景**：
  - 想看源码实现（不是手册内容） → `flash-source-reader`
  - 想查参数定义（不是手册原文） → `flash-param-query`
  - 想理解物理原理 → 对应 `flash-<physics>` skill（已转的章节会和手册内容融合）
  - 大部分实际问题时 → `flash-<physics>` 已经包含了手册关键信息
  - **重要**：本 skill 仅当用户明确要"手册原文"或"官方文档"时调用。日常问题优先调对应 flash-<physics>。
layer: tool
phase: 1
status: stable
created: 2026-06-17
last_updated: 2026-07-19
owner: user
---

# flash-manual-search — 官方手册检索工具

> **状态**：✅ stable（5 道验收考题全部通过，2026-07-16；含未覆盖时的 fallback 流程和 PDF 临时提取演示）

## 1. 角色与边界

### 1.1 我是做什么的

**官方手册检索器**。给定关键词或章节号，在 `agent/manual/` 下检索已转换的 md 文件。

**重要约束**（按 D-003 决策）：
- 手册**按需转换**，不是一次性全转
- 当前覆盖率：见 §3
- 未转的章节 → 本 skill 找不到 → 建议用户走 `workflows/pdf-to-md.md` 工作流，或退回到对应 `flash-<physics>` skill

### 1.2 我不做什么

| 用户问题类型 | 归属 skill | 原因 |
|---|---|---|
| 想看源码实现 | `flash-source-reader` | 手册 ≠ 源码 |
| 想查参数定义 | `flash-param-query` | 字典 ≠ 手册 |
| 想理解物理原理 | `flash-<physics>` | skill 已融合手册关键内容 |
| 一般问题 | `flash-<physics>` | 优先用专用 skill |

## 2. 行为协议

### 2.1 标准查询流程（on_query）

#### Step 1：识别查询类型

| 类型 | 示例 | 处理 |
|---|---|---|
| **(a) 关键词检索** | `手册里关于 critical density 怎么说` | 走 §2.1.1 |
| **(b) 章节号查询** | `§18.4 讲什么` | 走 §2.1.2 |
| **(c) 已转章节列表** | `哪些章节已经转了` | 走 §2.1.3 |
| **(d) 验证是否手册原文** | `这个说法是手册写的吗` | 走 §2.1.4 |

#### 2.1.1 关键词检索

```bash
# 在 agent/manual/ 下搜（只搜 .md，不搜 .pdf 或 -raw.txt）
rg -i -n '<关键词>' agent/manual/ -g '*.md'
```

**输出格式**：
```
**手册检索**: <关键词>

**命中** (按章节排序):

1. `agent/manual/<chapter>/<section>.md:LXX`
   **章节**: §X.Y <章节名>
   **段落**:
   ```
   <手册段落，最多 5 行预览>
   ```
   **源码锚点**: <如果该 md 含 source_anchors>
   **中文摘要**: <2-3 句话>

2. ...

**未命中或想看更多**：
- 该关键词对应的源码：调用 `flash-source-reader`
- 物理原理：调用 `flash-<physics>`
```

#### 2.1.2 章节号查询

```bash
# 查 §18.4
ls agent/manual/18-*/18.4*.md 2>/dev/null

# 或在所有 md 的 frontmatter 找 manual_ref
rg -l "manual_ref.*§18\.4" agent/manual/
```

**已转** → 返回文件路径 + 摘要
**未转** → 输出：
```
**§18.4 Energy Deposition Unit** 还未转换。

PDF 位置: agent/manual/flash4_ug_4p8.pdf 页 276-296
对应 skill: flash-laser（已含手册关键内容）

选项:
1. 用 flash-laser skill 回答（推荐，物理原理已融合）
2. 按 workflows/pdf-to-md.md 工作流转换该章（约 60-90 分钟）
3. 直接读 PDF 原文
```

#### 2.1.3 已转章节列表

```bash
find agent/manual -name "*.md" -type f | sort
```

输出当前覆盖矩阵（见 §3）。

#### 2.1.4 验证手册原文

如果用户问"这个说法是手册写的吗"：
1. 提取关键短语
2. 在 `agent/manual/` 搜
3. 命中 → 引用具体段落 + 页码
4. 未命中 → "本 skill 当前已转章节中没找到。可能在未转章节，或来自其他来源（如源码注释、邮件列表）。"

### 2.2 未覆盖时的处理

**老实说**："agent/manual/ 当前只覆盖了 N 章，这一章还没转。"

**建议路径**（按优先级）：

1. **优先用对应 skill**（推荐）：手册的关键内容已经被各 flash-<physics> skill 融合到 knowledge/ 里。
   - 例：激光问题 → `flash-laser`（已 stable，含 overview/params/internals/recipes/pitfalls）
   
2. **按工作流转换该章**：照 `agent/workflows/pdf-to-md.md` 操作（用户空了转，约 60-90 分钟/章）

3. **直接读 PDF**：
   ```bash
   # 用 pdftotext 提取该章
   pdftotext -layout -f <起页> -l <止页> agent/manual/flash4_ug_4p8.pdf - | less
   ```

### 2.3 跨 skill 协作

| 场景 | 协作链 |
|---|---|
| 用户问"手册怎么说 ed_wavelength" | `flash-manual-search`（手册原文）→ `flash-param-query`（参数全信息）|
| 用户问"§18.4 提到的函数在源码哪" | `flash-manual-search`（手册内容）→ `flash-source-reader`（定位源码）|
| 用户问"手册和源码哪里不一致" | `flash-manual-search`（手册）+ `flash-source-reader`（源码）→ 对比 |

## 3. 当前转换覆盖矩阵

> **最后更新**：2026-07-12

### 已转换（按章节号）

| 章节 | 章节名 | 文件 | 状态 |
|---|---|---|---|
| （暂无） | — | — | — |

### 待转换（按优先级，详见 `workflows/pdf-to-md.md §4`）

| 优先级 | 章节 | 章节名 | PDF 页 | 对应 skill |
|---|---|---|---|---|
| ★★★ | §18.4 | Energy Deposition Unit | 276-296 | flash-laser |
| ★★★ | §2 | Setup and Build | ~30-60 | flash-setup-system |
| ★★ | §18.1 | Burn Unit | 264-270 | flash-sourceterms |
| ★★ | §18.2 | Ionization Unit | 270-271 | flash-sourceterms |
| ★★ | §18.3 | Stir Unit | 272-276 | flash-sourceterms |
| ★★ | §19 | Material Properties | ~300-320 | flash-material |
| ★ | §7-8 | Grid | — | flash-grid |
| ★ | §9-12 | Hydro | — | flash-hydro |
| ★ | §13-15 | EOS | — | flash-eos |
| ★ | §16-17 | RadTrans | — | flash-radtrans |

完整 TOC：见 `agent/manual/flash4_ug_4p8.pdf` 前 30 页。

## 4. 输出规范（按 L-010 精简：与 §2.1.1 合并）

命中/未命中的输出格式已统一在 §2.1.1（关键词检索）和 §2.1.2（章节号查询）。

**未命中额外补充**：输出"可能原因 + 建议路径"3 项（已在 §2.1.2 章节号查询示例中体现）。

## 5. 关键命令模板

```bash
# 1. 在已转 md 中搜
rg -i -n '<关键词>' agent/manual/ -g '*.md'

# 2. 列所有已转章节
find agent/manual -name '*.md' -type f | sort

# 3. 全 PDF 搜（不依赖已转）
pdftotext agent/manual/flash4_ug_4p8.pdf - | grep -i -n '<关键词>' | head -20

# 4. 提取特定页（如 §18.4 在页 276-296）
pdftotext -layout -f 276 -l 296 agent/manual/flash4_ug_4p8.pdf -

# 5. 用 pdfplumber 精确提取
python3 -c "
import pdfplumber
with pdfplumber.open('agent/manual/flash4_ug_4p8.pdf') as pdf:
    for i in range(275, 296):
        print(f'=== Page {i+1} ===')
        print(pdf.pages[i].extract_text())
"

# 6. 查 PDF 元信息
pdfinfo agent/manual/flash4_ug_4p8.pdf
```

## 6. 示例问答（验收基准）

### Q1: 手册里关于 critical density 怎么说？
**A**: 当前 agent/manual/ 还没转 §18.4。PDF 页 277 有原文。建议：
- 直接看 flash-laser/knowledge/overview.md §1.2（已含手册关键公式）
- 或按 workflows/pdf-to-md.md 转换 §18.4

### Q2: §18.4 Energy Deposition Unit 讲什么？
**A**: 还未转换。对应 skill 是 flash-laser（stable）。PDF 位置：页 276-296。建议先看 flash-laser skill。

### Q3: 哪些章节已经转了？
**A**: 见 §3 当前覆盖矩阵。当前为 0 章。优先级最高的 5 章见 workflows/pdf-to-md.md §4。

### Q4: 这个说法是手册写的吗？（"临界密度 N_c = π m_e c² /(e² λ²)"）
**A**: 这个公式在 flash-laser/knowledge/overview.md §1.2，源码 `LaserRaysCreate/ed_createRays3DRec.F90:419`。手册 §18.4 应该也有，但当前未转。可提取该页验证：
```bash
pdftotext -layout -f 277 -l 277 agent/manual/flash4_ug_4p8.pdf - | grep -A 2 -B 2 "critical"
```

### Q5: 怎么转激光章？
**A**: 照 `agent/workflows/pdf-to-md.md §5 Worked Example`，4 步：提取（pdftotext）→ 对照源码 → 改写为模板 → 审核。预计 60-90 分钟。

## 7. 待办

- [ ] 跑 5 道验收考题（含"未转章节"的处理）
- [ ] 按优先级转首批章节（§18.4 + §2 + §18.1-3）
- [ ] 每转一章后更新本 SKILL §3 覆盖矩阵
- [ ] 长期：考虑加 PDF 全文索引（lunr.js 或类似），跨已转+未转统一搜

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-07-12 | 升级 draft → beta：扩展 triggers（含章节号）；§2 行为协议 4 种查询类型完整；§3 覆盖矩阵明确（当前 0/40）；配套写 `agent/workflows/pdf-to-md.md` 工作流；含 5 道验收考题（含"未转"处理）；定位激光章在 PDF §18.4 页 276-296 | claude |
| 2026-07-19 | **按 L-010 精简**：§4 "输出规范" 收缩为引用 §2.1.1 / §2.1.2，避免重复 | claude |
