# agent/manual/ — FLASH 4.8 用户手册

> 本目录存放 FLASH 4.8 官方用户手册（UG）的 md 转换版本。
> 转换按 D-003 决策：工具辅助 + 人工精读，**按需推进**，不一次性全转。

## 内容

| 文件 | 类型 | 状态 |
|---|---|---|
| `flash4_ug_4p8.pdf` | 原 PDF（661 页，25 MB） | 永久保存（不修改） |
| `<chapter>/<section>.md` | 转换后的章节 | 按需添加 |

## 当前转换覆盖

**最后更新**：2026-07-12

```
已转换: 0 / 约 40 章
```

详细优先级和已转章节列表见 `.claude/skills/flash-manual-search/SKILL.md §3`。

## 转换工作流

照 `agent/workflows/pdf-to-md.md` 操作，4 步：

1. **提取**：`pdftotext -layout -f <N> -l <M> flash4_ug_4p8.pdf -raw.txt`
2. **对照源码**：手册提到的每个函数/参数/变量在 `source/` 里定位
3. **改写为模板**：按 `agent/TEMPLATES/knowledge-entry.md` 改写
4. **审核 + promote**：放 `agent/drafts/pending/`，用户审核后移到本目录

## 章节命名约定

```
agent/manual/
├── flash4_ug_4p8.pdf                       # 原 PDF
├── README.md                               # 本文件
├── 01-introduction/
├── 02-setup-and-build/
├── ...
├── 18-local-source-terms/
│   ├── 18.1-burn-unit.md
│   ├── 18.2-ionization-unit.md
│   ├── 18.3-stir-unit.md
│   └── 18.4-energy-deposition.md           # 激光
├── 19-material-properties/
└── ...
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
| ★★★ | §2 Setup and Build | flash-setup-system（Phase 2） | 30-60 |
| ★★ | §18.1 Burn | flash-sourceterms | 264-270 |
| ★★ | §18.2 Ionization | flash-sourceterms | 270-271 |
| ★★ | §18.3 Stir | flash-sourceterms | 272-276 |

## 使用规则

### 查询已转章节

用 `flash-manual-search` skill：
```bash
rg -i '<关键词>' agent/manual/ -g '*.md'
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
- ❌ 不要把转换的 md 放到 `.claude/skills/*/knowledge/`（那是 skill 的，手册是参考）
- ❌ 不要在 md 里直接复制大段手册原文（用自己话改写 + 引用页码）

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始：放入 PDF | user |
| 2026-07-12 | 创建 README，明确按需转换策略和命名约定 | claude |
