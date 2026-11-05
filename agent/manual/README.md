# agent/manual/ — FLASH 4.8 用户手册转换工作台

> 本目录是手册转换的**工作台**：存放原 PDF、pdftotext 原始提取（-raw.txt）和转换进度。
> **转换产物（章节 md）已移至 `skills/flash-manual-search/knowledge/manual/`**（v1.2 收编，见下"架构变更"）。
> 转换按 D-003 决策：工具辅助 + 人工精读，**按需推进**，不一次性全转。

## 内容

| 文件 | 类型 | 状态 |
|---|---|---|
| `flash4_ug_4p8.pdf` | 原 PDF（661 页，25 MB） | 永久保存（不修改） |
| `<chapter>/<section>-raw.txt` | pdftotext 原始提取（不入 git） | 转换中间产物 |
| `.progress/*.md` | 转换进度笔记 | 工作日志 |
| ~~`<chapter>/<section>.md`~~ | 转换后的章节 | → `skills/flash-manual-search/knowledge/manual/` |

## 架构变更（2026-11-05，v1.2）

- 章节md 真身：`skills/flash-manual-search/knowledge/manual/`（flash-manual-search skill 自包含、随包分发）
- 本目录降级为工作台：只留 PDF + raw.txt + .progress/，25 MB 不进 skill 包（`--copy` 安装不带源书）
- **取代旧规则**"不要把转换的 md 放到 skill knowledge"——该规则针对的是散进各物理 skill；现在手册语料统一归**手册检索 skill** 所有，符合单一归属原则

## 当前转换覆盖

详细优先级和已转章节列表见 `skills/flash-manual-search/SKILL.md §3`。

## 转换工作流

照 `agent/workflows/pdf-to-md.md` 操作，4 步：

1. **提取**：`pdftotext -layout -f <N> -l <M> flash4_ug_4p8.pdf -raw.txt`（在本目录）
2. **对照源码**：手册提到的每个函数/参数/变量在 `source/` 里定位
3. **改写为模板**：按 `agent/TEMPLATES/knowledge-entry.md` 改写
4. **审核 + promote**：放 `agent/drafts/pending/`，用户审核后移到 `skills/flash-manual-search/knowledge/manual/<chapter>/`

## 章节命名约定

```
skills/flash-manual-search/knowledge/manual/     # ★ 转换产物（入 git）
├── 01-intro/
├── 02-quick-start/
├── ...
├── 18-local-source-terms/
│   ├── 18.1-burn-unit.md
│   ├── 18.2-ionization-unit.md
│   ├── 18.3-stir-unit.md
│   └── 18.4-energy-deposition.md           # 激光
└── ...

agent/manual/                                     # ★ 工作台（本目录）
├── flash4_ug_4p8.pdf                             # 原 PDF
├── README.md                                     # 本文件
├── .progress/                                    # 转换进度
└── <chapter>/<section>-raw.txt                   # 提取中间产物（不入 git）
```

规则：
- 目录名：`<章号>-<英文短名>`（小写连字符）
- 文件名：`<章号>.<节号>-<英文短名>.md`
- 中文章节名写在 md 的 frontmatter `title` 字段

## 优先级（前 5 章）

详见 `workflows/pdf-to-md.md §4`。

| 优先级 | 章节 | 对应 skill | PDF 页 |
|---|---|---|---|
| ★★★ | §18.4 Energy Deposition | flash-laser（已 stable） | 276-296 |
| ★★★ | §2 Setup and Build | flash-setup-builder | 30-60 |
| ★★ | §18.1 Burn | flash-sourceterms | 264-270 |
| ★★ | §18.2 Ionization | flash-sourceterms | 270-271 |
| ★★ | §18.3 Stir | flash-sourceterms | 272-276 |

## 使用规则

### 查询已转章节

用 `flash-manual-search` skill：
```bash
rg -i '<关键词>' skills/flash-manual-search/knowledge/manual/ -g '*.md'
```

### 查询未转章节

两种选择：
1. **优先用对应 skill**（推荐）：手册关键内容已被各 flash-<physics> skill 融合
2. **直接读 PDF**：
   ```bash
   # 全 PDF 搜
   pdftotext agent/manual/flash4_ug_4p8.pdf - | grep -i '<关键词>'

   # 提取特定页
   pdftotext -layout -f 276 -l 296 agent/manual/flash4_ug_4p8.pdf -
   ```

## 不要做的事

- ❌ 不要把整个 PDF 一次性转 md（质量难控，2-3 个月才完，D-003 明确禁止）
- ❌ 不要修改 `flash4_ug_4p8.pdf` 原文件
- ❌ 不要把章节 md 散进各物理 skill 的 knowledge/（手册语料统一归 flash-manual-search）
- ❌ 不要在 md 里直接复制大段手册原文（用自己话改写 + 引用页码）

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始：放入 PDF | user |
| 2026-07-12 | 创建 README，明确按需转换策略和命名约定 | claude |
| 2026-11-05 | v1.2 收编：31 篇章节 md 移至 skills/flash-manual-search/knowledge/manual/，本目录降级为转换工作台；取代"md 不进 skill knowledge"旧规则（见"架构变更"） | claude |
