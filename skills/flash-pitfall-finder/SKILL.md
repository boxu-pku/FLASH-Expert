---
name: flash-pitfall-finder
description: |
  FLASH 踩坑库查询工具。给定错误信息或异常现象，从 skills/flash-pitfall-finder/knowledge/pitfalls/ 和各 skill 的 knowledge/pitfalls.md
  匹配踩坑条目，给出原因 + 修复步骤 + 预防方法。
  覆盖：编译/链接错误、setup 报错、make 报错、运行 abort（Driver_abortFlash）、
  MPI 错误、NaN/ffpe-trap、性能问题、restart 失败、本机特定问题（libmpi 冲突等）。
  触发词：错误, error, abort, 报错, 失败, 崩溃, 不能编译, traceback, segment fault, ffpe-trap,
        NaN, 段错误, 卡住, 超时, 慢, Driver_abortFlash, undefined reference, MPI, restart
triggers:
  # 中文
  - 错误
  - 报错
  - 失败
  - 崩溃
  - 不能编译
  - 不能跑
  - 段错误
  - 段错误
  - 卡住
  - 超时
  - 跑得慢
  - 重新开始
  - 重启失败
  - 异常
  - 不对
  - 没反应
  # 英文
  - error
  - errors
  - abort
  - aborted
  - failed
  - failure
  - crash
  - crashed
  - exception
  - traceback
  - backtrace
  - segment fault
  - segfault
  - sigsegv
  - sigbus
  - sigfpe
  - ffpe-trap
  - floating point
  - NaN
  - nan
  - infinity
  - overflow
  - underflow
  - undefined reference
  - unresolved symbol
  - MPI
  - mpi
  - mpich
  - openmpi
  - restart
  - checkpoint
  - timeout
  - hang
  - slow
  # 具体错误信息（高频）
  - Driver_abortFlash
  - SetupError
  - "Unit not found"
  - "No rule to make target"
  - "Not enough"
  - "Wrong time order"
  - "Negative pulse"
  - "invalid"
  - "out of order"
  - "too many"
  - "Too many rays"
  - "unknown parameter"
  - "libmpi"
  - "libhdf5"
  - "libHYPRE"
  - "FACE_PEC"
when_to_use: |
  调用本 skill 的场景：
  1. 用户报告错误信息字符串（"Driver_abortFlash: ..."、"undefined reference ..."、"MPI_..."）
  2. 用户报告异常现象（NaN、超慢、卡住、结果为 0、步数不前进）
  3. 用户报告编译/链接失败（make 时）
  4. 用户报告 setup 失败（./setup 时）
  5. 用户报告运行 abort（flash4 启动后或运行中）
  6. 用户问"为什么 X 不工作"、"X 怎么错了"、"X 怎么修"
when_not_to_use: |
  **不调用本 skill 的场景**：
  - 没报错，只是问参数含义 → `flash-param-query`
  - 没报错，只是想看源码 → `flash-source-reader`
  - 没报错，想了解物理原理 → 对应 `flash-<physics>`
  - 想跑算例（不是诊断错误） → `flash-case-runner`
  - 想分析结果（不是诊断错误） → `flash-result-analyzer`
  - 单元特定问题且已知道是哪个单元 → 直接调用对应 `flash-<unit>` skill（如激光问题 → flash-laser，flash-laser 内部的 pitfalls.md 更详细）
layer: tool
phase: 1
status: stable
created: 2026-06-17
last_updated: 2026-07-12
owner: user
---

# flash-pitfall-finder — 踩坑库查询工具

> **状态**：✅ stable（5 道验收考题全部通过，2026-07-12；L-008 二次修订沉淀到 §4 分类输出规范）

## 1. 角色与边界

### 1.1 我是做什么的

**错误信息 → 踩坑条目匹配器**。给定：
- 错误字符串（如 `Driver_abortFlash: Not enough beam runtime parameters`）
- 或异常现象描述（如 "depo 全是 NaN"、"跑得超慢"）

在两个踩坑库中找匹配条目：
- `skills/flash-pitfall-finder/knowledge/pitfalls/` — 跨领域踩坑（编译/MPI/本机/数值等）
- `skills/flash-<unit>/knowledge/pitfalls.md` — 各单元内部踩坑

输出标准化的：**错误原因 + 修复步骤 + 预防方法**。

### 1.2 我不做什么

| 用户问题类型 | 归属 skill | 原因 |
|---|---|---|
| 参数含义（不是错误） | `flash-param-query` | 那是字典，不是踩坑 |
| 源码实现（不是错误） | `flash-source-reader` | 那是阅读，不是诊断 |
| 物理原理 | `flash-<physics>` | 错误≠物理 |
| 跑算例（不是诊断） | `flash-case-runner` | 操作≠诊断 |
| 已知是某单元特定问题 | 对应 `flash-<unit>` | 单元 pitfalls 更细（如 flash-laser） |

## 2. 行为协议

### 2.1 标准查询流程（on_query）

#### Step 1：错误信息预处理

把用户给的错误信息拆成**搜索关键词**：

```python
# 伪代码：实际由 Agent 用文本处理做
def extract_keywords(error_message):
    # 1. 提取 [routine_name] 前缀（如 "Driver_abortFlash:"、"ed_setupBeams:"）
    routines = re.findall(r'\[?(\w+)\]?:', error_message)
    
    # 2. 提取引号内的关键短语（如 "Not enough beam runtime parameters"）
    quoted = re.findall(r'"([^"]+)"', error_message)
    
    # 3. 去除噪声（文件路径、行号、内存地址）
    noise_patterns = [r'/\S+/\S+\.\w+', r':\d+', r'0x[0-9a-f]+']
    cleaned = remove_patterns(error_message, noise_patterns)
    
    # 4. 分词、去停用词
    return routines + quoted + tokenize(cleaned)
```

**示例**：
- 输入：`Driver_abortFlash ("ed_setupBeams: Not enough beam runtime parameters. See Log File!") at source/.../Driver_abortFlash.F90:L23`
- 输出关键词：`["Driver_abortFlash", "ed_setupBeams", "Not enough beam runtime parameters"]`

#### Step 2：搜索踩坑库

```bash
# 在跨领域踩坑库搜
rg -i -n '<关键词1>|<关键词2>' skills/flash-pitfall-finder/knowledge/pitfalls/

# 在各 skill 的单元内踩坑库搜
rg -i -n '<关键词1>|<关键词2>' skills/*/knowledge/pitfalls.md
```

#### Step 3：匹配度评分

| 信号 | 加分 |
|---|---|
| 错误信息中的 [routine] 前缀出现在条目里 | +3 |
| 引号内的完整短语出现 | +5 |
| 单元名出现（如 ed_ → flash-laser） | +2 |
| 错误类别匹配（编译/链接/运行/MPI/数值） | +1 |
| 多个关键词同时命中 | +2 |

→ 按总分排序，输出前 3 个。

#### Step 4：输出（标准格式）

```
**错误信息**: <用户提供的>

**匹配的踩坑** (Top N):

1. ★★★ 高匹配: `skills/flash-pitfall-finder/knowledge/pitfalls/<file>.md` 或 `flash-<unit>/knowledge/pitfalls.md §X.Y`
   **匹配度**: 8/10（关键短语 + routine 名双命中）
   
   **原因**: <来自条目 §原因>
   **修复步骤**:
   1. <来自条目 §修复>
   2. ...
   **预防**: <来自条目 §预防>
   **源码锚点**: source/.../file.F90:LXX

2. ★★ 中匹配: ...
3. ★ 低匹配: ...

**如果都不像**：告诉我你的具体场景，我帮你写一条新草稿到 `agent/drafts/pending/`。
```

### 2.2 异常现象（无具体错误字符串）

如果用户只描述现象（"跑得超慢"、"depo 是 NaN"），按**现象关键词**搜索：

| 现象 | 搜索关键词 |
|---|---|
| NaN / Inf | `NaN`, `not-a-number`, `infinity`, `ffpe-trap` |
| 卡住 / 不前进 | `hang`, `deadlock`, `stuck`, `loop` |
| 超慢 | `slow`, `performance`, `bottleneck` |
| 结果为 0 | `zero`, `null`, `empty` |
| 步数不增加 | `nstep`, `timestep`, `dt=0` |

### 2.3 找不到匹配时

1. **老实说**："skills/flash-pitfall-finder/knowledge/pitfalls/ 和各 skill 的 knowledge/pitfalls.md 都没匹配到这条错误。"
2. **建议路径**：
   - 调用 `flash-source-reader` 看错误对应的源码位置
   - 用 `grep` 在 FLASH 邮件列表/论坛搜错误原文
3. **生成草稿**：询问用户"要不要我生成一条新踩坑草稿到 `agent/drafts/pending/`？"用户同意 → 按 `agent/TEMPLATES/pitfall.md`（待建）格式生成

### 2.4 跨 skill 协作

flash-pitfall-finder 经常需要和其他 skill 配合：

| 场景 | 协作链 |
|---|---|
| 激光 abort | `flash-pitfall-finder`（定位条目）→ `flash-laser`（详细解释） |
| 错误指向某源码行 | `flash-pitfall-finder`（给修复方案）→ `flash-source-reader`（看上下文） |
| 错误涉及参数 | `flash-pitfall-finder`（给方向）→ `flash-param-query`（查具体参数） |
| 修复后重跑 | `flash-pitfall-finder`（确认修复完成）→ `flash-case-runner`（重跑） |

## 3. 踩坑库结构

### 3.1 跨领域踩坑（skills/flash-pitfall-finder/knowledge/pitfalls/）

| 文件 | 错误类别 | 状态 |
|---|---|---|
| `libmpi-conflict.md` | 编译/链接（本机特定） | beta |
| `site-not-found.md` | setup 期 | beta |
| `setup-unit-not-found.md` | setup 期 | beta |
| `ffpe-trap-and-nan.md` | 运行期数值 | beta |
| `mpi-errors.md` | 运行期 MPI | beta |
| `restart-incompatibility.md` | 运行期 restart | beta |

### 3.2 单元内踩坑（各 skill 的 knowledge/pitfalls.md）

| skill | 文件 | 条目数 |
|---|---|---|
| `flash-laser` | `knowledge/pitfalls.md` | 12 条（编译 2 + 启动 5 + 运行 3 + 概念 2） |

**未上线的 skill**（Phase 2+）：每个 skill 建成后会同步建 `knowledge/pitfalls.md`。

## 4. 标准输出格式（**先引导贴现场 + 核心 4 段 + 引导项** — 2026-07-19 L-012 修订）

按 L-010 + L-012，回答分三部分：**Step 0 引导贴现场（条件性）+ 核心 4 段（必给）+ 引导项（按需展开）**。

### Step 0a：判断要不要先引导贴现场（L-012）

```
用户的消息里已经含完整错误信息（含 abort 原文 + 日志段 + setup 命令 + parfile 段）？
   → 是：直接走 Step 0b 判断错误类型
   → 否：先输出"请贴以下信息"引导段（见 §4.C），等用户补充
```

**触发条件**（任一满足就先引导）：
- 用户只说"我跑出 NaN" / "算例崩了" / "报错了"，没贴具体信息
- 用户贴了错误截图但没贴文本（要求文本）
- 用户描述了现象但缺关键上下文（setup 命令、parfile 段、日志关键行）

**不触发**（直接走 Step 0b）：
- 用户贴了完整错误信息原文（含 [routine] 前缀 + abort message）
- 用户从日志复制了完整 traceback
- 上一轮已贴过，本轮是追问

### Step 0b：判断错误类型

```
错误信息含 Driver_abortFlash、含 [...] 前缀的 routine 名（如 "ed_setupBeams: ..."）
   → FLASH 源码相关 → 走 §4.A（核心 4 段含触发代码字段）

错误信息含 /usr/bin/ld、forrtl、SetupError、MPI_、HDF5 等非源码标识
   → 非源码错 → 走 §4.B（核心 4 段，不贴"凑数代码"）
```

### §4.C 引导贴现场输出格式（L-012 新增，Step 0a 触发时用）

```markdown
**先贴以下信息以便诊断**（贴完后我能给出针对性建议）：

1. **错误信息原文**（从日志复制，含 [routine] 前缀）：
   grep -B 2 -A 5 "abort\|NaN\|error" 01-data/<basenm>.log | head -40

2. **setup 命令**（验证变体选择）：
   cat cases/<your_case>/setup_call

3. **parfile 关键段**（与错误相关的部分）

4. **dt 历史**（如果是数值问题）：
   grep "dt = " 01-data/<basenm>.log | tail -20

---

如果你想先自己看通用原因，下面是常见原因列表（按概率排序）：

<简短列 3-5 类常见原因 + 一句话机制 + 快速验证命令>

详细诊断请贴完上述信息后继续。
```

**关键约束**：
- 引导段**放最前**（核心 4 段之前）
- 给**具体命令**（用户复制粘贴就行）
- 引导后**仍可附简短通用原因**（用户可选读）
- 不要因为加了引导就让回答变冗长（控制 ≤ 50 行）

### §4.A 源码类错误输出格式

```markdown
**错误信息**: <用户原文，简短引用>

**触发代码字段**:（按 L-008，贴 .F90 路径行号 + 代码段 + 中文注释）

\`\`\`fortran
! source/path/file.F90:LXX-LYY
<代码段>
! ↑ 中文注释
\`\`\`

**原因 + 解释**: <为什么触发，机制层面。讲清楚 if 条件/运算为什么产生异常>

**解决方案**: <具体步骤，含命令/parfile 修改。多方案标注推荐>

---
**想深入了解？告诉我你想看哪项，我接着展开**：
- [ ] 用户怎么自己定位（诊断流程、命令）
- [ ] 怎么预防
- [ ] 源码层面的详细机制
- [ ] 延伸阅读（相关 knowledge、跨 skill 引用）
```

### §4.B 非源码类错误输出格式

```markdown
**错误信息**: <用户原文>

**错误类型**: <链接器错 / Python 脚本错 / MPI 错 / 系统配置错 / 编译器运行时>

**原因 + 解释**: <错误信息逐行翻译 + 为什么触发（讲 ld/loader/MPI/HDF5/setup.py 机制）>

**解决方案**: <具体步骤。多方案时标注推荐>

---
**想深入了解？告诉我你想看哪项，我接着展开**：
- [ ] 用户怎么自己定位
- [ ] 怎么预防
- [ ] 详细的工具机制（ldd、mpirun、pdftotext 等）
- [ ] 延伸阅读
```

### 关键约束（保留自 L-008）

✅ **源码相关才贴代码**：if 块、运算行、参数读取、数组访问、变量赋值
❌ **凑数代码禁止**：非源码错（链接器/Python/系统配置）不硬贴 Makefile.h、ldd、Python 脚本

✅ **面向新手**：术语要解释（如 `[<routine>]` 前缀含义、`-HUGE(1.0)` 哨兵机制）
❌ **过度冗长**：核心 4 段控制在 100-150 行内，引导项只列名

### 引导项的展开规则

用户**明确选某项**时再展开。例如用户说"我想看怎么自己定位"：
- 把诊断流程详细写出（具体命令 + 文件路径）
- 仍保持精简，不堆砌

### 触发代码字段获取流程（仅源码类）

```bash
# 1. 提取 routine 名（[...] 前缀）和关键词
# 2a. abort：rg -n "Driver_abortFlash.*<关键词>" source/
# 2b. NaN/数值：rg -n "^subroutine\s+<routine>" source/，找运算
# 3. 读代码段：sed -n '<行号-10>,<行号+5>p' source/<文件>
```

## 5. 关键命令模板

```bash
# 1. 在跨领域踩坑库搜（核心命令）
rg -i -n '<关键词>' skills/flash-pitfall-finder/knowledge/pitfalls/

# 2. 在所有 skill 的单元踩坑库搜
rg -i -n '<关键词>' skills/*/knowledge/pitfalls.md

# 3. 提取所有 abort 信息（建索引用）
rg -n 'Driver_abortFlash\s*\(' source/ | head -100

# 4. 搜 FLASH 邮件列表（外部）
# 用 WebSearch 工具搜 "<错误原文> site:flash.uchicago.edu" 或 "flash-users mailing list"
```

## 6. 示例问答（验收基准）

### Q1: 启动报 `ed_setupBeams: Not enough beam runtime parameters`
**A**: 命中 `flash-laser/knowledge/pitfalls.md §B.1`（高匹配，routine + 完整短语双命中）。原因：`ed_numberOfBeams > ed_maxBeams`。修复：setup 加 `ed_maxBeams=N` 重新 setup+make。

### Q2: make 时报 `undefined reference to 'ed_wavelength_7'`
**A**: 命中 `flash-laser/knowledge/pitfalls.md §A.2`（高匹配）。原因：parfile 引用了 `ed_*_7` 但 setup 期 ed_maxBeams 默认 6。修复同 Q1。

### Q3: 编译时报 `ld: warning: libmpi.so.40 may conflict with libmpi.so.12`
**A**: 命中 `skills/flash-pitfall-finder/knowledge/pitfalls/libmpi-conflict.md`（高匹配，关键短语命中）。本机特定问题，需 sudo mv 临时 workaround。

### Q4: 跑几步后日志显示 `forrtl: error (65): floating invalid` 或 ffpe-trap 触发
**A**: 命中 `skills/flash-pitfall-finder/knowledge/pitfalls/ffpe-trap-and-nan.md`（中匹配）。可能原因：除零、`gaussianRadius=0`、自定义函数发散。诊断流程见条目。

### Q5: 启动报 `[SetupError] Unit not found: Sedov`
**A**: 命中 `skills/flash-pitfall-finder/knowledge/pitfalls/setup-unit-not-found.md`（高匹配）。可能原因：拼写错（注意大小写）、不在 `source/Simulation/SimulationMain/`、setup 命令位置错。

## 7. 待办

- [ ] 跑 5 道验收考题，全部通过则升级 stable
- [ ] 持续累积：每次遇到新 abort 都生成草稿到 `agent/drafts/pending/`
- [ ] 写 `agent/TEMPLATES/pitfall.md` 模板（统一踩坑条目格式）
- [ ] 长期：建 `skills/flash-pitfall-finder/tools/build_pitfall_index.py` 索引脚本

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-07-12 | 升级 draft → beta：扩展 triggers（50+ 错误关键词）；§2 行为协议完整（4 步流程 + 评分 + 协作）；建 skills/flash-pitfall-finder/knowledge/pitfalls/ 6 条初始跨领域踩坑；含 5 道验收考题 | claude |
| 2026-07-12 | §4 输出规范修订（4 段 → 5 段，L-008）：加"触发代码字段"为强制第 2 段；加定位流程（rg + sed 提取 if 块）；验收反馈"贴 abort 触发代码比文字解释直观" | claude |
| 2026-07-12 | §4 二次修订（L-008 收紧）：从"必须贴代码"改为"分类强制"——源码类错误（FLASH .F90 触发）才贴触发代码，非源码类（链接器/Python/系统配置）不贴凑数代码，只做详细机制解释；加禁止行为段（凑数代码、跳过定位、简略回答） | claude |
| 2026-07-18 | §4 三次修订（L-010）：从"5 段强制都展开"改为"核心 4 段 + 引导项列表"——核心段（错误信息/触发代码/原因解释/解决方案）必给且详细，引导项（用户定位/预防/详细机制/延伸）只列名让用户按需选；控制核心段 100-150 行；用户实战反馈"用户定位部分基本不看，回答过于冗长" | claude |
| 2026-07-19 | §4 四次修订（L-012）：加 Step 0a"判断要不要先引导贴现场"+ §4.C 引导输出格式——诊断类问题先要用户贴日志/setup/parfile/dt 历史，再展开通用原因；同步沉淀"公式 CLI 友好"约束到 LESSONS_LEARNED L-012；flash-hydro 验收反馈两条 | claude |
