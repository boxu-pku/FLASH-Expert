# FLASH 官方手册 PDF → md 转换工作流

> 本文件是 D-003 决策的执行 SOP：用工具辅助 + 人工精读 + 工作流驱动，按需转换 FLASH 4.8 用户手册章节。
> 每次"空了转几章"时照此操作。

---

## 0. 决策依据

- **决策**：D-003（2026-06-17）— 工具辅助 + 人工精读，按需推进，不一次性全转
- **理由**：手册 661 页，一次性转质量难控、周期长（2-3 月）；按章节转跟着实际问题驱动
- **目标产物**：`skills/flash-manual-search/knowledge/manual/<章节路径>/<章节名>.md`，按 `agent/TEMPLATES/knowledge-entry.md` 模板（`-raw.txt` 中间产物留在 `agent/manual/` 工作台）

---

## 1. 输入与工具

### 1.1 输入

| 资源 | 位置 |
|---|---|
| PDF 手册 | `agent/manual/flash4_ug_4p8.pdf` |
| 总页数 | 661 页 |
| 章节 TOC | 见 PDF 第 5-30 页（`pdftotext -layout` 提取） |
| 模板 | `agent/TEMPLATES/knowledge-entry.md` |

### 1.2 本机可用工具（按优先级）

| 工具 | 版本 | 适用 | 安装状态 |
|---|---|---|---|
| `pdftotext`（poppler） | 系统自带 | LaTeX 排版 PDF，**效果好**，保留 layout | ✅ `/usr/bin/pdftotext` |
| `pdfplumber` (Python) | 0.11.9 | 提取表格、精确控制页码 | ✅ |
| `pypdf` (Python) | 6.12.2 | 元信息、页码操作 | ✅ |
| `PyMuPDF` (fitz) | — | — | ❌ 未装 |
| `marker` | — | LaTeX 公式、表格识别 | ❌ 未装 |

**默认用 `pdftotext -layout`**，质量已经很好（FLASH 手册是 LaTeX 生成的）。

### 1.3 备选（如需更高质量）

```bash
# 安装 marker（最强，但重）
pip install marker-pdf

# 或安装 PyMuPDF
pip install pymupdf
```

---

## 2. 转换 4 步流程

每转一章按此 4 步做：

### Step 1：提取 PDF 文本

```bash
# 例：转 §18.4（页 276-296）
mkdir -p agent/manual/18-local-source-terms

pdftotext -layout -f 276 -l 296 \
    agent/manual/flash4_ug_4p8.pdf \
    agent/manual/18-local-source-terms/18.4-energy-deposition-raw.txt
```

**关键参数**：
- `-layout`：保留原文排版（重要！表格、公式不乱）
- `-f <N>` / `-l <N>`：起止页码（含）
- 输出先到 `-raw.txt` 文件（中间产物，便于检查）

### Step 2：对照源码

提取完成后**立刻**对照源码，定位手册提到的每个：

- 函数名 → 在 `source/` 里 grep 找位置
- 参数名 → 在 `source/**/Config` 里找声明
- 变量名 → 在 `bin/Flash.h.tpl` 里找索引

记录到 raw txt 旁边，作为 §3 改写的源码锚点。

```bash
# 例：手册提到 ed_setupBeams → 找源码位置
rg -n "^subroutine ed_setupBeams" source/

# 手册提到 PARAMETER ed_wavelength → 找 Config
find source -name Config | xargs grep "ed_wavelength" 2>/dev/null
```

### Step 3：改写为 knowledge-entry 模板

打开 `agent/TEMPLATES/knowledge-entry.md`，复制模板，按以下规则填充：

**frontmatter 必须含**：
```yaml
---
title: <章节标题>
skill: flash-<对应物理单元 skill 名>     # 如 18.4 → flash-laser
category: <overview | params | internals | recipes | pitfalls>
source_anchors:
  - source/path/file.F90:LXX              # 至少 3 个
  - source/path/Config:LXX
manual_ref: "FLASH 4.8 User Guide §<章节号> 页 <N>"
created: YYYY-MM-DD
last_verified: YYYY-MM-DD                # = 提取日期
verifier: <用户名 or claude>
status: draft                            # 新转的初始 draft
tags:
  - <章节关键词>
---
```

**正文 9 段**（按模板）：

1. **TL;DR**（60 字摘要）
2. **物理原理/设计动机**（改写手册原文，不直接复制）
3. **源码实际实现**（含 §2 对照的结果）
4. **关键参数**（表格，含默认/单位/源码声明位置）
5. **典型用法**（parfile 片段）
6. **与其他单元的耦合**
7. **常见错误**
8. **已知陷阱 / 与手册的差异**（重要！手册老，源码可能改了）
9. **延伸阅读**

**关键约束**（来自模板）：
- 代码片段 ≤ 20 行
- 至少 3 个源码锚点
- 不复制大段手册原文（用自己话改写）
- 中文为主，代码和公式保留原文

### Step 4：审核 + promote

```bash
# 1. 放到 drafts/pending/
mv agent/manual/18-local-source-terms/18.4-energy-deposition.md \
   agent/drafts/pending/

# 2. 用户 review：按 agent/GOVERNANCE.md §5 审核清单检查
#    - 格式合规（frontmatter 字段齐全）
#    - 源码锚点准确（随机抽 1-2 个验证）
#    - 没有把推测写成事实
#    - 没有重复其他 knowledge 内容

# 3. 通过 → 移到正式目录（flash-manual-search 的 knowledge，随包分发）
mv agent/drafts/pending/18.4-energy-deposition.md \
   skills/flash-manual-search/knowledge/manual/18-local-source-terms/

# 4. 改 status: draft → beta
# 5. 在 agent/PROJECT_PLAN.md §9 changelog 加一行
# 6. 删 raw txt
rm agent/manual/18-local-source-terms/18.4-energy-deposition-raw.txt
```

---

## 3. 章节命名约定

按 PDF 实际章节号命名，便于交叉引用：

```
skills/flash-manual-search/knowledge/manual/   # ★ 转换产物（入 git，随包分发）
├── 01-intro/                                # §1
│   ├── 1.1-*.md
│   └── 1.4-*.md
├── 02-quick-start/                          # §2
│   └── ...
├── 18-local-source-terms/                   # §18
│   ├── 18.1-burn-unit.md
│   ├── 18.2-ionization-unit.md
│   ├── 18.3-stir-unit.md
│   └── 18.4-energy-deposition.md            # ★ 激光（优先转）
└── ...                                      # 共 ~40 章

agent/manual/                                # ★ 转换工作台（PDF 源 + raw.txt）
├── flash4_ug_4p8.pdf                        # 原 PDF
├── README.md                                # 工作台索引
└── <chapter>/<section>-raw.txt              # pdftotext 提取（不入 git）
```

**规则**：
- 目录名：`<章号>-<英文短名>`（小写连字符）
- 文件名：`<章号>.<节号>-<英文短名>.md`
- 中文章节名写在 frontmatter `title` 字段

---

## 4. 优先级建议

按 Phase 2 路线图（PROJECT_PLAN §6）的 skill 建设顺序：

| 优先级 | 章节 | 对应 skill | 页数 | 备注 |
|---|---|---|---|---|
| ★★★ | §18.4 Energy Deposition | flash-laser（已 stable） | 276-296 | Phase 1 优先 |
| ★★★ | §2 Setup and Build | flash-setup-system（Phase 2） | ~30-60 | 入门必读 |
| ★★ | §3-5 Simulation setup | flash-setup-system | ~60-100 | |
| ★★ | §18.1 Burn | flash-sourceterms | 264-270 | |
| ★★ | §18.2 Ionization | flash-sourceterms | 270-271 | |
| ★★ | §18.3 Stir | flash-sourceterms | 272-276 | |
| ★★ | §19 Material Properties | flash-material | ~300-320 | |
| ★ | §7-8 Grid | flash-grid | | |
| ★ | §9-12 Hydro | flash-hydro | | |
| ★ | §13-15 EOS | flash-eos | | |
| ★ | §16-17 RadTrans | flash-radtrans | | |
| ★ | §20+ 工具与诊断 | 各 skill | | |

每次转 1-2 章，约 30-90 分钟（视章节复杂度）。

---

## 5. Worked Example：转换激光章 §18.4

完整演示一次。**预计耗时**：60-90 分钟。

### Step 1：提取

```bash
mkdir -p agent/manual/18-local-source-terms

pdftotext -layout -f 276 -l 296 \
    agent/manual/flash4_ug_4p8.pdf \
    agent/manual/18-local-source-terms/18.4-energy-deposition-raw.txt

# 检查提取结果
wc -l agent/manual/18-local-source-terms/18.4-energy-deposition-raw.txt
head -50 agent/manual/18-local-source-terms/18.4-energy-deposition-raw.txt
```

### Step 2：对照源码（边读 raw txt 边做）

raw txt 提到的关键术语 → 在源码定位：

| 手册术语 | 源码位置 |
|---|---|
| EnergyDeposition_init | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/EnergyDeposition_init.F90:80` |
| ed_setupBeams | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserBeams/ed_setupBeams.F90:60` |
| ed_beamCrossSectionWeight | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserBeams/ed_beamCrossSectionFunctions.F90:34` |
| inverse bremsstrahlung | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserUtilities/ed_inverseBremsstrahlungRate.F90:41` |
| ed_updatePlasma | `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserUtilities/ed_updatePlasma.F90:28` |

（实际上 flash-laser skill 的 knowledge/ 已经做了这一步，可以复用。）

### Step 3：改写

复制 `agent/TEMPLATES/knowledge-entry.md`，按 raw txt 内容**改写**（不复制）：

- frontmatter 填好（manual_ref: "FLASH 4.8 UG §18.4 pp.276-296"）
- 物理原理：用 flash-laser/knowledge/overview.md 已有的内容（避免重复）+ 手册独有的内容
- 关键参数：从 raw txt 提取手册列的参数 + 对照 Config 验证
- 已知陷阱：手册 vs 源码差异（如 wavelength 单位、pulse 功率单位）

输出到：`agent/manual/18-local-source-terms/18.4-energy-deposition.md`

### Step 4：审核

```bash
# 临时放 pending
mv agent/manual/18-local-source-terms/18.4-energy-deposition.md \
   agent/drafts/pending/18.4-energy-deposition-20260712.md

# 用户 review
cat agent/drafts/pending/18.4-energy-deposition-20260712.md
# 按 GOVERNANCE.md §5 检查清单审核

# 通过 → 移回正式目录
mv agent/drafts/pending/18.4-energy-deposition-20260712.md \
   skills/flash-manual-search/knowledge/manual/18-local-source-terms/18.4-energy-deposition.md

# 在 PROJECT_PLAN §9 加 changelog
```

---

## 6. 处理特殊情况

### 6.1 公式

手册用 LaTeX 排版公式。提取后是 ASCII：
```
N_c = pi m_e c^2 / (e^2 lambda^2)
```

转 md 时改为 KaTeX：
```
$$N_c = \frac{\pi m_e c^2}{e^2 \lambda^2}$$
```

复杂公式参考：`flash-laser/knowledge/overview.md §1.2、§1.4`。

### 6.2 表格

`pdftotext -layout` 对简单表格保留不错。复杂表格用 pdfplumber：

```python
import pdfplumber
with pdfplumber.open("agent/manual/flash4_ug_4p8.pdf") as pdf:
    page = pdf.pages[280]  # 页索引从 0
    tables = page.extract_tables()
    for t in tables:
        for row in t:
            print(row)
```

转 md 表格：
```markdown
| 列1 | 列2 | 列3 |
|---|---|---|
| ... | ... | ... |
```

### 6.3 图片/图示

PDF 提取不到图。两种处理：
- 略过（多数情况）+ 在 md 注明"原文档含图"
- 用 `pdfimages` 提取（如关键图）：
  ```bash
  pdfimages -png -f 280 -l 280 agent/manual/flash4_ug_4p8.pdf agent/manual/18-local-source-terms/img/fig
  ```

### 6.4 源码片段

手册常含 Fortran 示例。保留原格式：
```fortran
call EnergyDeposition(blockCount, blockList, dt, dr_simTime, pass)
```

但要**对照实际源码**验证片段是否过时。

### 6.5 章节内有交叉引用

手册 §18.4 可能引用 §16（Hydro）等。在 md 里改为本仓库内链接：
```markdown
详见 [[../16-hydro/16.1-overview.md]] 或 skills/flash-hydro/knowledge/overview.md
```

未转的章节标 `(待转)`。

---

## 7. 常见错误

| 错误 | 原因 | 修复 |
|---|---|---|
| 提取后中文乱码 | PDF 编码问题 | 用 `-enc UTF-8` 参数：`pdftotext -enc UTF-8 -layout ...` |
| 表格列对不齐 | `-layout` 没用 | 加 `-layout` |
| 页码偏移 | 封面/目录占用 | 用 `pdfinfo` 查总页数，按 PDF 实际页码（不是手册标的页码） |
| 公式断裂 | 跨行 | 手动改写为 KaTeX |
| 源码片段过时 | 手册 2024，源码 2026 改过 | 对照源码核对，差异写到 §"已知陷阱" |

---

## 8. 与其他工作流的关系

- **flash-manual-search skill**：转换后的 md 就是该 skill 的 knowledge（`skills/flash-manual-search/knowledge/manual/`）
- **skills/flash-param-query/knowledge/param-index.md**：转换时发现的新参数补到这里
- **各 skill 的 knowledge/**：手册内容不散进各物理 skill（避免重复），需要时通过 `[[knowledge/overview#section]]` 链接引用
- **skills/flash-pitfall-finder/knowledge/pitfalls/**：转换时发现的本机特定问题补到这里

---

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-12 | 初始创建（4 步流程 + 命名约定 + 优先级 + 激光章 worked example） | claude |
| 2026-11-05 | v1.2 收编：转换产物目标路径改为 skills/flash-manual-search/knowledge/manual/；agent/manual/ 降级为工作台（PDF + raw.txt）；param-index / pitfalls 同步指向新位置 | claude |
