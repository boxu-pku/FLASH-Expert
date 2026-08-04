# Phase 1 经验沉淀（LESSONS_LEARNED）

> 本文件记录 Phase 1（flash-laser + 工具 skill 建设）过程中遇到的关键经验教训。
> **目的**：Phase 2 复制 flash-laser 模板时避免重蹈覆辙，把"隐性知识"显性化。
> **维护**：每次有大反馈或踩坑后追加一条；每月 review 看是否仍适用。

---

## 目录

- [L-001: 工具 skill 的价值是"讲逻辑"，不是"检索"](#l-001-工具-skill-的价值是讲逻辑不是检索)
- [L-002: 调用关系图用文字+缩进，不用 mermaid](#l-002-调用关系图用文字缩进不用-mermaid)
- [L-003: 知识层 skill 的 description 按 D-007 "先粗后精"](#l-003-知识层-skill-的-description-按-d-007-先粗后精)
- [L-004: knowledge 文件结构按"教学顺序"而非"功能顺序"](#l-004-knowledge-文件结构按教学顺序而非功能顺序)
- [L-005: examples/ 用纯 parfile 格式，不用 markdown 包裹](#l-005-examples-用纯-parfile-格式不用-markdown-包裹)
- [L-006: 跨 skill 协作要明确归属，避免重复回答](#l-006-跨-skill-协作要明确归属避免重复回答)
- [L-007: 验收考题不只是检验，是迭代 SKILL.md 的核心机制](#l-007-验收考题不只是检验是迭代-skillmd-的核心机制)
- [L-008: 报错类回答必须贴出"触发代码字段"（FLASH 源码相关）](#l-008-报错类回答必须贴出触发代码字段flash-源码相关)
- [L-009: parfile 顶部 setup 注释可能不可信](#l-009-parfile-顶部-setup-注释可能不可信)
- [L-010: 回答精简原则——核心 4 段 + 引导项列表（修订 L-008）](#l-010-回答精简原则核心-4-段--引导项列表修订-l-008)
- [L-011: 回答选择/操作类问题要讲"为什么"，不只是"怎么做"](#l-011-回答选择操作类问题要讲为什么不只是怎么做)
- [L-012: 诊断类回答先引导贴现场，再展开通用原因（+ 公式 CLI 友好）](#l-012-诊断类回答先引导贴现场再展开通用原因--公式-cli-友好)
- [L-013: 回答聚焦用户实际场景，主流路径优先（不全面铺开）](#l-013-回答聚焦用户实际场景主流路径优先不全面铺开)
- [L-014: 专业术语第一次出现时先解释本身（一句话定义 + 为什么存在）](#l-014-专业术语第一次出现时先解释本身一句话定义--为什么存在)
- [L-015: 回答"X 做了什么"先讲完整故事线（定义→传递→处理→使用），再讲细节](#l-015-回答x-做了什么先讲完整故事线定义传递处理使用再讲细节)
- [L-016: FLASH species 名有长度限制——多物质算例用短名避免 HDF5 冲突](#l-016-flash-species-名有长度限制多物质算例用短名避免-hdf5-冲突)
- [L-017: 解决报错后自主询问是否沉淀到报错库](#l-017-解决报错后自主询问是否沉淀到报错库)

---

## L-001: 工具 skill 的价值是"讲逻辑"，不是"检索"

**首次发现日期**：2026-07-12（flash-source-reader 验收）
**影响范围**：所有工具层 skill（5 个）
**严重度**：高（设计错误会导致 skill 没价值）

### 问题

最初设计 `flash-source-reader` 时，把它的核心职责定为"用 grep/rg 定位源码 + 显示代码片段"。SKILL.md §2.3 输出规范只要求 4 项：位置、代码、中文注释、延伸。

验收时用户反馈：
> "当前的回答缺少详细的解释和说明，最关键的是没有帮我捋清楚程序的逻辑，**如果只是检索，那 grep 也能做而且做的更好**"

这是设计层面的根本错误——**如果 skill 只做检索，它没有存在价值**。

### 根因

- 把"工具 skill"理解为"自动化 grep"，忽略了 LLM 的真正优势（理解 + 讲解）
- SKILL.md 输出规范没有强制要求"讲逻辑"
- 早期 demo 回答照搬输出规范，自然变简略

### 解决

修订 SKILL.md §2.3，强制要求 7 段输出结构：
1. **它是什么**（一句话讲角色，不只是"是个 subroutine"）
2. **定义位置**（多变体对照表）
3. **它做什么 / 怎么工作**（**核心段**：控制流 + 数据流 + 关键操作 + 实际运作）
4. **为什么这样设计**（设计动机）
5. **关键代码片段**（≤ 20 行 + 中文注释）
6. **完整调用链**（文字+缩进，禁用 mermaid，见 L-002）
7. **延伸**

并加反例段，明确避免"纯检索型"、"过度学术型"、"缺逻辑型"、"复杂 mermaid"。

### 推广到其他工具 skill

同样的原则适用于：
- `flash-pitfall-finder`：不只是匹配错误信息，要讲清楚**为什么**会触发、**为什么**这么修
- `flash-param-query`：不只是给类型/默认值，要讲参数的**物理含义**、**典型值的选择依据**
- `flash-manual-search`：不只是返回手册段落，要**对比手册和源码**的差异、解释为什么

### Phase 2 应用

每个新 skill 建设时，SKILL.md §2.3 输出规范必须先想清楚"**这个 skill 能做的、grep 做不到的是什么**"。如果答不上来，重新设计。

---

## L-002: 调用关系图用文字+缩进，不用 mermaid

**首次发现日期**：2026-07-12（flash-source-reader 验收）
**影响范围**：所有含调用关系图的 skill / knowledge / snippet

### 问题

回答里用了 mermaid `flowchart TD` 图表达调用关系。用户反馈：
> "你的程序结构图我看不懂"

### 根因

- mermaid 图节点过多时信息密度高，阅读负担大
- 节点之间用箭头连接，但箭头语义不明确（"调用"？"包含"？"修改"？）
- 没有注释，用户不知道哪些是核心、哪些是次要
- 用户在不同环境看 mermaid 渲染效果不一致（CLI / Web / IDE）

### 解决

**强制规则**：调用关系一律用**文字 + ASCII 缩进**，不用 mermaid。

✅ 推荐：
```
Driver_evolveFlash (主循环)
├── Grid_getListOfBlocks
├── Hydro
├── RadTrans
├── Diffuse
├── Driver_sourceTerms ★ (含激光)
│   ├── Polytrope
│   ├── ...
│   └── EnergyDeposition (激光，第 10 位)
├── Particles_advance
└── IO_output
```

优势：
- 阅读无门槛（任何环境都能看）
- 用 `★` 等符号标重点
- 用注释（`含激光`、`第 10 位`）补充语义
- 用户复制粘贴友好

**例外**：调用关系确实**很复杂**且**层次清晰**时（如完整物理流程），可用极简 mermaid。但默认不用。

### Phase 2 应用

- 所有 knowledge 文件、snippets、回答里默认用文字+缩进
- 修订旧文件（flash-laser/internals.md 含 mermaid）时考虑替换

---

## L-003: 知识层 skill 的 description 按 D-007 "先粗后精"

**首次发现日期**：2026-06-17（Phase 0 → Phase 1 过渡）
**影响范围**：所有 11 个知识层 skill

### 问题

draft 阶段强行精写 description 容易覆盖过宽/过窄、边界不准、后续返工。

### 解决（D-007 决策）

- **draft 阶段**：写粗略版（一句话主题 + 5-10 触发词）
- **knowledge 填齐过程中**：每完成一个 knowledge 文件回头审视 description
- **升级 beta 前**：必须精调一次（含实际填入的参数前缀、源码文件、与其他 skill 的真实边界）
- **stable 阶段**：内容大改才重审

### 应用成果

flash-laser 在 beta 升级时按这条精调 description，最终 5 道验收考题全部通过。triggers 从初始 13 个扩到 80+。

---

## L-004: knowledge 文件结构按"教学顺序"而非"功能顺序"

**首次发现日期**：2026-06-17（flash-laser recipes.md 设计）
**影响范围**：所有 knowledge/recipes.md、examples/

### 问题

recipes.md 如果按"功能顺序"组织（高斯/平顶/椭圆/环形/多束），用户第一次配置会困惑"我该从哪开始"。

### 解决

按"教学顺序"组织：
1. **最小可运行配置**（最少参数，能跑通）
2. **典型用例**（ICF super-Gaussian，主力配置）
3. **特殊用例**（椭圆、偏心）
4. **进阶**（多束对称）

每个 recipe 标"适用场景"，让用户**按需选**而不是**按顺序读**。

### Phase 2 应用

每个新 skill 的 recipes.md 都按这个顺序：最小 → 典型 → 特殊 → 进阶。

---

## L-005: examples/ 用纯 parfile 格式，不用 markdown 包裹

**首次发现日期**：2026-07-10（flash-laser examples/ 建设）

### 问题

如果 examples/ 里的 `.par` 文件用 markdown 包裹代码块，用户没法直接 `cp` 到 case 目录使用。

### 解决

`.par` 文件就是**纯 parfile 格式**，只在开头用 `#` 注释（这是 FLASH parfile 支持的注释语法）。用户可以直接：
```bash
cp .claude/skills/flash-laser/examples/minimal-gaussian.par cases/<my_case>/flash.par
```

并在 parfile 顶部用注释写明：setup 命令、单位速查、使用方法。注释是 parfile 原生支持的，不影响解析。

---

## L-006: 跨 skill 协作要明确归属，避免重复回答

**首次发现日期**：2026-07-12（工具 skill 协作设计）

### 问题

工具 skill 容易和知识层 skill 职责重叠。例：
- 用户问"ed_wavelength 是什么"
- `flash-param-query`（字典）和 `flash-laser`（物理背景）都能答
- 如果两者都答，重复；如果都不答，遗漏

### 解决

每个 skill 的 SKILL.md 必须明确：
- **§1.1 我做什么**（含具体场景）
- **§1.2 我不做什么**（含归属 skill 表）

并在 §2.4 加"跨 skill 协作"段，描述典型协作链：
- 谁先答（深度小）
- 谁补充（深度大）
- 协作顺序

例：
| 场景 | 协作链 |
|---|---|
| 用户问 ed_wavelength 含义 | `flash-param-query`（基本属性）→ `flash-laser`（物理背景） |
| 用户问"这个参数对应的源码在哪" | `flash-param-query`（声明位置）→ `flash-source-reader`（实现细节） |

### Phase 2 应用

每个新 skill 都要写跨 skill 协作表。`agent/ARCHITECTURE.md §5` 描述了通用协作模式。

---

## L-007: 验收考题不只是检验，是迭代 SKILL.md 的核心机制

**首次发现日期**：2026-07-12（flash-source-reader 验收）

### 问题

最初把验收考题当成"通过/不通过"的二值判定。flash-source-reader 首次答完被驳回，发现回答风格有问题。

### 解决

把验收考题升级为**迭代 SKILL.md 的核心机制**：
1. 写完 skill → 跑 5 道验收考题
2. 用户评分 + 反馈
3. **如果反馈指出了 SKILL.md 设计问题（不只是答案问题）** → 修订 SKILL.md
4. 重答考题验证修订生效
5. 全部满分才升级 stable

### 应用成果

flash-source-reader 通过这个机制发现了 L-001（"讲逻辑"）和 L-002（不用 mermaid），修订后通过。

### Phase 2 应用

每个新 skill 升级 stable 前必须过 5 道验收考题。考题答案要详细（不只是"知道位置"），覆盖典型场景。**用户的反馈不只是评分，是改进 skill 的金矿**。

---

## 待补充（后续遇到时追加）

- [ ] Phase 2 启动 flash-driver 时观察到的经验
- [ ] 跨 skill 协作实战中的问题（如调度顺序、上下文丢失）
- [ ] 自动扩写机制（D-004）实际效果评估
- [ ] 工具脚本（如 build_param_index.py）的实现经验

---

## L-008: 报错类回答必须贴出"触发代码字段"（FLASH 源码相关）

**首次发现日期**：2026-07-12（flash-pitfall-finder 验收）
**最后修订**：2026-07-12（用户二次反馈，明确范围 = FLASH 源码相关，不限 if）
**影响范围**：所有报错诊断类回答（pitfall-finder、case-runner、各 skill 的 pitfalls.md）
**严重度**：高（信息架构问题，影响用户理解速度）

### 问题

第一次答 flash-pitfall-finder 5 道题时，每题详细讲了：
- 错误的本质（什么类型错）
- 为什么会触发（机制层面）
- 怎么修、怎么预防

但**没贴出 abort 触发的源码字段**。用户反馈（首次）：

> "报错触发的代码字段位于什么位置这个信息也很重要，比如如果是某个 if 判断触发的报错，实际上你把相关代码一贴用户就明白怎么回事了"

修订时我收紧为"只对 if 触发的 abort 才贴"，用户反馈（二次）：

> "L-008 不是只对 if 呀，而是源码相关的，有的报错不是 if 触发的"

### 根本规则

**所有错误，只要根因能在 FLASH 源码（`.F90` 文件）里定位到具体代码，都贴那段代码。**

"源码相关"包括（不限 if）：

| 源码形式 | 例子 | 贴什么 |
|---|---|---|
| **if 判断触发 abort** | `if (X > MAX) call Driver_abortFlash(...)` | 完整 if 块含 abort 调用 |
| **具体运算产生 NaN/Inf** | `xf = (x-Cx)/Rx`、`result = exp(...)` | 那行运算 + 上下文 |
| **参数读取** | `call RuntimeParameters_get("ed_x", val)` | 调用 + 后续使用 |
| **变量赋值/初始化** | `frequency = c / wavelength` | 赋值行 + 上下文 |
| **数组访问越界** | `solnData(TELE_VAR, i, j, k)` | 那行 + 数组维度声明 |
| **子程序调用链出问题** | `call Hydro(...)` 后某个变量变 NaN | 调用 + 该变量在被调用方怎么算的 |

**不属于源码的不贴**（编译/链接器错、Python 脚本错、系统配置错）：

| 错误类型 | 例子 | 不贴代码，但要详细讲机制 |
|---|---|---|
| 链接器错 | `undefined reference to X` | 讲 ld 找符号的机制、为什么符号不存在 |
| 链接器警告 | `libmpi conflict` | 讲 MPI 实现差异、ABI 兼容性、loader 搜索路径 |
| 编译器运行时 | `forrtl: error` | 讲 FFLAGS 编译选项机制、浮点异常原理 |
| Python 脚本错 | `SetupError: Unit not found` | 讲 setup.py 查找算法 |
| 系统库错 | HDF5 IO 失败 | 讲 HDF5 接口、文件系统问题 |

### 解决

**强制规则**：报错类回答必须含以下两段之一：

1. **触发代码字段**（如果错误根因在 FLASH 源码）：贴出 `.F90` 文件里的具体代码段，含源码路径和行号
2. **机制解释**（如果错误根因不在 FLASH 源码）：用文字详细讲为什么会触发、用户怎么定位

**反模式（禁止）**：
- ❌ 为了凑数，把"机制涉及但不是根因"的代码硬贴上去（如 ld 错误贴 Makefile.h 配置段，给用户错觉这是"触发代码"）
- ❌ 把 Python 脚本错（如 setup.py）当作"FLASH 源码"贴
- ❌ 只贴代码不解释（用户看不懂）

### 推广到所有 skill

- `flash-pitfall-finder`：报错诊断时按上述规则
- `flash-source-reader`：讲函数时如有 abort 逻辑或运算，贴相关代码
- `flash-laser/knowledge/pitfalls.md`：每个 abort 都贴对应 FLASH 源码
- `agent/pitfalls/*.md`：跨领域踩坑，按错误类型决定贴不贴
- Phase 2+ 新 skill 的 pitfalls：写的时候就含触发代码（如适用）

### 操作流程（Agent 实际怎么做）

接到报错查询时：

**Step 1：判断错误类型**

```
错误信息含 Driver_abortFlash、含 [...] 前缀的 routine 名
   → FLASH 源码触发，走 Step 2

错误信息含 /usr/bin/ld、forrtl、SetupError 等
   → 非源码错，走 Step 3
```

**Step 2：源码类 — 定位触发代码**

```bash
# 1. 从错误信息提取 routine 名（[...] 前缀）和错误字符串关键词
# 例：错误 "ed_setupBeams: Not enough beam runtime parameters"
# → routine = ed_setupBeams
# → 关键词 = "Not enough beam runtime parameters"

# 2a. 如果是 abort：在源码找该 routine 内 abort 调用
rg -n "Driver_abortFlash.*<关键词>" source/

# 2b. 如果是 NaN/数值异常：找该 routine 内可能出问题的运算
rg -n "^subroutine\s+<routine>" source/
# 然后读 routine 找除法、指数、数组访问等

# 3. 读出代码段含上下文
sed -n '<行号-10>,<行号+5>p' source/<文件>
```

贴到回答里。

**Step 3：非源码类 — 详细机制解释**

不贴"凑数代码"，详细讲：
- 错误是什么意思（逐行翻译错误信息）
- 为什么会触发（编译/链接器/MPI/HDF5 等机制）
- 用户怎么自己定位
- 怎么修

### 示例

**源码类（贴代码）**：

错误：`ed_setupBeams: Not enough beam runtime parameters`

贴：
```fortran
! source/.../ed_setupBeams.F90:107-115
if (ed_numberOfBeams > ED_MAXBEAMS) then                ! ★ 触发条件
    call Driver_abortFlash("ed_setupBeams: Not enough beam runtime parameters...")
end if
```

**源码类（非 if）**：

错误：`forrtl: error (65): floating invalid`，发生在 `ed_beamCrossSectionFunctions.F90`

贴：
```fortran
! source/.../ed_beamCrossSectionFunctions.F90:188-194
real function ed_gauss1D (x, Cx, Rx, alpha)
   ...
   xf = (x - Cx) / Rx                       ! ★ Rx 可能是 -HUGE(1.0) → xf ≈ 0
   ed_gauss1D = exp( - (xf * xf) ** alpha ) ! 后续可能在 gridWeight 累加时不稳
end function
```

**非源码类（不贴代码）**：

错误：`/usr/bin/ld: warning: libmpi.so.40 may conflict with libmpi.so.12`

**不贴 Makefile.h 配置或 ldd 输出作为"触发代码"**——这些不是根因。详细讲：
- ld 警告的含义
- 系统库 vs 用户库的搜索顺序
- MPI 实现差异（OpenMPI vs MPICH，ABI 不兼容）
- 用 `ldd flash4 | grep mpi` 诊断
- 修复方案（mv / rpath / LD_LIBRARY_PATH）

---

## 待补充（后续遇到时追加）

- [ ] Phase 2 启动 flash-driver 时观察到的经验
- [ ] 跨 skill 协作实战中的问题（如调度顺序、上下文丢失）
- [ ] 自动扩写机制（D-004）实际效果评估
- [ ] 工具脚本（如 build_param_index.py）的实现经验

---

## L-011: 回答选择/操作类问题要讲"为什么"，不只是"怎么做"

**首次发现日期**：2026-07-19（flash-grid 验收）
**影响范围**：所有 skill 的输出规范（特别是工具层 skill 和 knowledge 层的 recipes/params）
**严重度**：高（设计原则问题，影响用户能否真正理解）

### 问题

flash-grid 验收时，用户问"怎么选 backend"，我答了 4 个 backend 名字 + 默认是 paramesh。用户反馈：

> "Q1 的解释不清楚，提问是怎么选，那么你除了列出选项，更应该告诉用户的是选择原因和依据；其余几个问题也是类似的，事实上用户提问最想知道的是原因，因此针对困惑要尽量详细一点解答，而不是像现在这样给几个词，这样看完还是云里雾里的"

这是 L-001（"讲逻辑不是检索"）的延伸——L-001 解决了"不只是给位置"，L-011 解决"不只是给选项/操作步骤"。

### 根因

- 把"怎么选/怎么做"理解为"列选项 + 给命令"，忽略了用户真正想要的是**判断依据**
- 选项列表是 grep 也能做的事；讲清楚"为什么这么选"才是知识
- 用户面对没遇到过的场景时，没有"为什么"就无法自己判断

### 根本规则

**回答选择/操作类问题时，每个选项或步骤都要回答**：

1. **它是什么**（一句话定义）
2. **为什么有这个选项/步骤**（设计动机：解决什么问题、应对什么场景）
3. **为什么这样设计**（背后的物理/数值/工程约束）
4. **什么场景该选它**（具体判断依据）
5. **有什么坑**（限制、副作用、不适用的情况）

第 2、3 项是核心，**不能省**。

### 典型例子

**问"怎么选 backend"**：

❌ 差（仅列选项）：
```
4 个 backend：paramesh（默认）/ UG / Chombo / Samrai。
默认是 paramesh 4 dev。setup 用 +pm4dev。
```

✅ 好（讲为什么）：
```
为什么有 4 个 backend？因为不同物理问题对网格需求根本不同：
- 激波算例需要 AMR（局部加密）→ paramesh
- PIC 需要 uniform（粒子权重依赖均匀网格）→ UG
- FFT-Poisson 数学上要 uniform → UG
- 嵌入式边界 → Chombo（半成熟）

为什么默认 paramesh？因为 99% 的 FLASH 算例是 AMR 类，
UG 用户知道自己要 UG 会主动写 +ug。
```

### 应用到 5 类回答

| 回答类型 | L-011 要求 |
|---|---|
| **选择类**（怎么选 backend/几何/维度） | 每个选项给"为什么有它"+"何时选" |
| **操作类**（怎么遍历 leaf block） | 每个步骤给"为什么这么写"+"不这么写会怎样" |
| **配置类**（怎么配 AMR） | 每个参数给"物理含义"+"数值选择经验" |
| **诊断类**（为什么报这个错） | 不只是"怎么修"，要讲"为什么会触发"（这个 L-008 已覆盖） |
| **概念类**（什么是 leaf block） | 不只是定义，要讲"为什么这么设计"+"解决了什么问题" |

### 与 L-001 / L-010 的关系

- **L-001**（讲逻辑）：适用于所有回答，强调"不只是检索"
- **L-008**（贴源码）：适用于报错类回答
- **L-010**（核心 4 段 + 引导项）：控制回答长度，避免冗长
- **L-011**（讲为什么）：适用于选择/操作/配置/概念类回答，强调"不只是列选项/步骤"

四个经验互补：L-001 是总纲，L-008/L-010/L-011 是不同场景的具体落实。

### Phase 2+ 应用

写新 skill 的 knowledge 文件时：

- `recipes.md`：每个 recipe 不只是 parfile 片段，要给"为什么这么配"
- `params.md`：每个参数不只是默认值，要给"为什么默认这个值"
- `pitfalls.md`：每个错误不只是修复步骤，要给"为什么这么修"（L-008 已覆盖）
- `overview.md`：每个概念不只是定义，要给"为什么这么设计"
- `internals.md`：每个 API 不只是签名，要给"为什么这么用"

写 SKILL.md 时，在 §2 行为协议段加一行：
> 选择/操作/配置/概念类问题，按 L-011 讲清楚"为什么"——选项、步骤、参数都要回答"为什么有它/为什么这么设计/什么场景该选"。

### 已有 skill 的回审

按 L-011 扫描已有 6 个 skill 的输出规范：

| Skill | 主要问题 | 修订建议 |
|---|---|---|
| `flash-source-reader` | §2.3 核心 4 段含"做什么/怎么工作"但缺"为什么这么设计"作为必给段 | 加 1 句强调："源码相关讲解时，必给'为什么这么设计'（设计动机）" |
| `flash-pitfall-finder` | §4 "原因+解释"段已经强调讲机制 | ✓ 已符合 L-011 |
| `flash-param-query` | §2.1.1 输出格式偏字典式（类型/默认/单位/位置），缺"为什么默认这个值" | 输出格式加 1 行："**默认值依据**：<为什么默认这个值>"（可选） |
| `flash-laser` / `flash-driver` / `flash-grid` | knowledge skill，输出格式灵活，已含"为什么"讲解 | ✓ 已符合 L-011 |
| `flash-manual-search` | 检索型，"为什么"不太适用 | ✓ 不需要改 |

---

## L-012: 诊断类回答先引导贴现场，再展开通用原因（+ 公式 CLI 友好）

**首次发现日期**：2026-07-19（flash-hydro 验收）
**影响范围**：所有诊断类回答（pitfall-finder、各 skill 的 pitfalls.md 段、错误排查类查询）
**严重度**：中（影响诊断效率）

### 问题 1：诊断类回答直接列原因，没引导用户贴报错

flash-hydro 验收 Q5"算例跑出 NaN，可能原因"，我直接列了 5 类原因。用户反馈：

> "NaN 本身有很多可能的原因，像这种你要在最开始引导用户粘贴报错部分的源码，然后再讲解，很多时候用户看到你的引导就会去找报错了，如果他只是想看这5类原因也可以看下去"

**根因**：诊断问题原因可能 10+ 种，直接列"通用原因"会：
- 用户读 5 类原因后还要自己对照（效率低）
- 没看到具体报错，回答只能泛泛而谈（不准确）
- 用户可能不知道要提供什么信息

### 解决 1：诊断类两层结构

**所有诊断类回答按两层结构**：

#### 第一层（Step 0，必给，放在最前）：**引导用户贴现场**

明确告诉用户"贴什么"，给具体命令模板：

```
请贴以下信息以便诊断：

1. 日志关键段（找 NaN 第一次出现）：
   grep -B 2 -A 5 "NaN\|below floor\|abort" 01-data/<basenm>.log | head -40

2. Hydro_init 打印的参数（确认 parfile 生效）：
   grep "Hydro_init\|cfl\|RiemannSolver" 01-data/<basenm>.log | head -20

3. setup 命令：
   cat cases/<case>/setup_call

4. parfile Hydro 段
```

**关键点**：
- **放最前**（核心 4 段之前）——用户看到立刻去收集
- **给具体命令**——用户复制粘贴就行
- **告诉用户为什么需要这些**——"贴完后能给出针对性诊断"

#### 第二层（按需展开）：**通用原因列表**

放在引导之后，作为"参考库"：
- **用户如果只看引导就会去贴报错**（节省时间）
- **用户如果想自己排查可继续读**（按概率排序的 5 类原因）
- **每类原因给"快速验证"步骤**（如降 CFL、换 Riemann）

### 应用范围

- `flash-pitfall-finder` §4 输出规范：加 Step 0 引导层
- 各 knowledge skill 的 `pitfalls.md`：每个错误条目开头加"诊断命令"
- 任何含"为什么会出错"、"怎么诊断"、"怎么排查"的查询

### 与 L-008 的关系

- L-008：贴源码相关代码（错误触发位置）——**Agent 主动找**
- L-012：先要用户贴现场（日志、parfile、setup 命令）——**用户被动提供**
- 两者互补：L-012 让用户提供上下文，L-008 让 Agent 深入源码

---

### 问题 2：公式 CLI 不渲染

flash-hydro 验收 Q1，我用了 `$\\partial U/\\partial t$` 和 `$$...$$` 公式。用户反馈：

> "Q1 反馈的公式都没有被成功渲染"

**根因**：Claude Code CLI 终端环境对 KaTeX/MathJax 支持有限。用户在 CLI 看到 `$\\partial U/\\partial t$` 是原始字符（`$\\partial U/\\partial t$`），不是渲染后的 `∂U/∂t`。

### 解决 2：公式用代码块 + ASCII

**默认**：公式用代码块 + ASCII 表达：

✅ 好：
```
∂U/∂t + ∇·F(U) = 0
```

```
U^{n+1} = U^n - (Δt/ΔV) · Σ_faces [F · A]
```

❌ 避免（CLI 不渲染）：
- `$\\partial U/\\partial t$`（行内 KaTeX）
- `$$\\frac{\\partial U}{\\partial t}$$`（块级 KaTeX）

**例外**（用 KaTeX）：
- **手册转写产物**（`agent/manual/*.md`）——这些会被 Markdown 渲染器看（如 Visit、网页），KaTeX 有效
- **明确要在网页展示的文档**——同上

**ASCII 数学符号速查**：

| 数学 | ASCII |
|---|---|
| 偏导 ∂U/∂t | `∂U/∂t` 或 `dU/dt`（用 Unicode 字符或纯 ASCII） |
| 梯度 ∇·F | `∇·F` 或 `div(F)` |
| 求和 Σ | `Σ` 或 `Sum` |
| 平方根 √x | `sqrt(x)` |
| 积分 ∫ | `integral` 或省略 |
| 上标 x² | `x^2` 或 `x**2` |
| 下标 x_i | `x_i` 或 `x[i]` |
| 约等于 ≈ | `≈` 或 `~=` |
| 小于等于 ≤ | `<=` 或 `≤` |

**Unicode 字符可用**（∂, ∇, Σ, √, ≤, ≥, ≈, → 等），CLI 能正常显示。**避免 LaTeX 命令**（`\\partial`、`\\sum`、`\\frac` 等）。

### 推广到所有 skill

- 写 knowledge 文件时：公式默认 ASCII / 代码块
- 回答用户时：同上
- 手册转写（agent/manual/）：可用 KaTeX（会被渲染）
- SKILL.md 输出规范段：加"公式 CLI 友好"约束

---

## L-013: 回答聚焦用户实际场景，主流路径优先（不全面铺开）

**首次发现日期**：2026-07-19（flash-eos 验收后追加测试）
**影响范围**：所有"列选项/格式/工具/方法"类回答；新写 knowledge/recipes.md 时
**严重度**：中（影响用户能否快速找到有用信息）

### 问题

flash-eos 验收后用户问"FLASH 用的 EOS 表格式 + 获取方式"。我第一次答：
- 列了 5 种格式（Helmholtz 自由能表 / IONMIX v2 / IONMIX v4 / SESAME / OPACPLOT）
- 说 `.cn4` 是 HDF5（错）
- 没提 FEOS（HEDP 实际最常用的工作流）
- 没看 LaserSlab 算例实际带什么

用户反馈：
> "实际上据我了解，现在 FLASH 用户上手基本上都是从 LaserSlab 算例，状态方程表通常是 IONMIX4 和 Sesame，早期版本已经被淘汰就不必详细展开，并且我询问了格式，你对格式的展开也并不详细准确。获取方式上，我应当列举一些更常使用的途径，例如通过 FEOS 计算状态方程，转换成 IONMIX4 格式，这类才是真正有用的经验"

### 根因

- **把"全面"当成"专业"**：列了 5 种格式显得专业，但用户实际只用 2 种
- **没先搞清楚用户场景**：用户问的是"FLASH 用的表"——默认场景是 LaserSlab，主流是 IONMIX4 + SESAME
- **格式细节流于表面**：列扩展名和来源，没展开 HDF5 vs ASCII、群数、数据块结构
- **工作流缺失**：用户实际需要"怎么搞到表"，而不是"有哪些表"

### 根本规则

回答"列选项/格式/工具/方法"类问题时：

1. **先搞清楚用户场景**（隐含的）
   - 用户从哪个算例上手？（LaserSlab 是 HEDP 标准）
   - 用户在国内还是国外？（决定 SESAME/FEOS 获取难度）
   - 用户是新还是老？（新用户不需要看历史遗留格式）

2. **主流路径优先 + 详细展开**
   - 列 2-3 个主流选项（不是 5+）
   - 每个详细展开（结构、单位、典型例子、实际文件验证）
   - 边缘 / 淘汰格式简要不带过（或不提）

3. **实用工作流 > 格式细节**
   - 不只列"有哪些"，要讲"怎么获取/生成"（如 FEOS 工作流）
   - 包括工具链（OpacPlot2 转换）、获取渠道（学术合作、IAPCM）
   - 用真实算例验证（看 LaserSlab 实际带什么表）

4. **用实际文件验证**
   - 说"格式是 HDF5"前先 `file *.cn4` 验证（我犯了这错）
   - 说"结构是 X"前先 `head -20` 看实际

### 与其他经验的关系

| 经验 | 解决的问题 |
|---|---|
| L-001（讲逻辑） | 不只是检索 |
| L-008（贴源码） | 报错类回答 |
| L-010（核心 4 段 + 引导项） | 控制长度 |
| L-011（讲为什么） | 深度——为什么这么设计 |
| L-012（诊断引导 + 公式 CLI） | 诊断类 + 公式渲染 |
| **L-013（聚焦主流）** | **聚焦——不要全面铺开** |

**L-011 vs L-013**：
- L-011 解决"**深度**"（讲为什么，不只是怎么做）
- L-013 解决"**聚焦**"（聚焦主流，不全面铺开）
- 互补：L-013 让你聚焦主流 + L-011 让你讲透主流

### 应用范围

**新写 knowledge 文件时**：
- `recipes.md` 列 setup 变体 / parfile 配置时，**聚焦用户常用的 2-3 种**
- `params.md` 列参数时，**主流参数详细 + 边缘参数简表**
- `pitfalls.md` 列常见错误时，**按概率排序**（高频在前）

**回答用户问题时**：
- 列格式 / 工具 / 方法 / 选项前，先问自己"用户从哪个场景上手？主流是什么？"
- 全面 ≠ 专业；**聚焦主流 + 详细展开 > 全面铺开 + 表面信息**
- 实用工作流（怎么获取 / 怎么生成）比格式细节更重要

**SKILL.md 输出规范**：
- 工具 skill（如 flash-param-query）：列参数时主流在前 + 详细
- knowledge skill：recipes 不要"5 种变体都讲"，主流 2-3 种详细 + 边缘简要

### 已有 skill 回审

按 L-013 扫描已有 skill：

| Skill | 主要问题 | 修订建议 |
|---|---|---|
| `flash-grid` recipes.md | 4 backend 都详讲（含 Chombo/Samrai） | 简要带过 Chombo/Samrai（用户 99% 用 paramesh/UG）|
| `flash-hydro` recipes.md | 6 变体都列 | 主流 3 种详讲 + 其他简要 |
| `flash-eos` recipes.md | 6 变体都详讲 | 主流 3-4 种详讲 + 边缘简要 |
| `flash-laser` recipes.md | 已按教学顺序，OK | 不改 |
| `flash-driver` recipes.md | 4 变体都列但已聚焦 | 不改 |
| `flash-pitfall-finder` | 不适用（按错误信息匹配，无选项列） | 不改 |
| `flash-param-query` | 跨单元查参数，无法聚焦 | 不改 |
| `flash-source-reader` | 按函数名查源码，无选项列 | 不改 |
| `flash-manual-search` | 按章节检索，无选项列 | 不改 |

---

## L-014: 专业术语第一次出现时先解释本身（一句话定义 + 为什么存在）

**首次发现日期**：2026-07-20（flash-radtrans 验收 Q4）
**影响范围**：所有含专业术语的回答（库名、算法名、概念、缩写）
**严重度**：中（影响用户理解门槛）

### 问题

flash-radtrans 验收 Q4 "为什么用 HYPRE"，我直接讲"MGD 通过 Diffuse_solveScalar 调 HYPRE"，但**没解释 HYPRE 是什么**。用户反馈：

> "我建议还是先简单解释一下基本概念，比如什么是 HYPRE，用户很多提问可能是因为本身对概念有误解导致的"

**根因**：

- 默认用户懂术语（"HYPRE = 一个数学库"对我来说显而易见，对用户不一定）
- 直接讲"怎么用"而不讲"是什么"，用户对术语的误解会让后续解释无的放矢
- 用户问"为什么用 X"可能源于对 X 的误解（如以为 HYPRE 是 FLASH 内部组件）

### 根本规则

**每个专业术语第一次出现时**，给：

1. **一句话定义**（"X 是什么"）
2. **为什么存在**（"X 解决什么问题"）
3. 再讲怎么用

### 适用术语类型

| 类型 | 例子 | 解释模板 |
|---|---|---|
| **库名** | HYPRE、MPI、HDF5、Paramesh | "X 是一个 [做什么的] 数学/通信/IO 库" |
| **算法名** | BoomerAMG、Newton-Raphson、Runge-Kutta、Crank-Nicolson | "X 是一种 [做什么的] 算法" |
| **概念** | CFL、guard cell、flux limiter、operator-split、AMR | "X 是 [一句话定义]，[为什么需要]" |
| **缩写** | MGD、HEDP、ICF、USM、CT | "X = 全称，意思是 [一句话]" |
| **物理量** | 临界密度、Coulomb 修正、Planck 积分 | "X 是 [物理含义]，[单位/典型值]" |

### 例子

**❌ 差**（直接讲怎么用）：

```
MGD 通过 Diffuse_solveScalar 调用 HYPRE 求解扩散方程...
```

**✅ 好**（先解释 HYPRE）：

```
HYPRE 是美国 LLNL 开发的解大稀疏线性方程组 Ax=b 的数学库。
用来处理百万级未知数的稀疏矩阵（如 MGD 离散后的扩散方程）。

MGD 通过 Diffuse_solveScalar 调用 HYPRE 求解...
```

### 与其他经验的关系

| 经验 | 解决的问题 |
|---|---|
| L-001（讲逻辑） | 不只是检索 |
| L-008（贴源码） | 报错类回答 |
| L-010（核心 4 段 + 引导项） | 控制长度 |
| L-011（讲为什么） | **深度**——为什么这么设计 |
| L-012（诊断引导 + 公式 CLI） | 诊断类 + 公式渲染 |
| L-013（聚焦主流） | **聚焦**——不全面铺开 |
| **L-014（术语先解释）** | **门槛**——降低用户理解门槛 |

**L-011 vs L-014**：
- L-011 解决"为什么这么设计"（深度）
- L-014 解决"X 是什么"（门槛）
- 互补：L-014 让用户先理解概念 + L-011 让用户理解深度

**L-013 vs L-014**：
- L-013 解决"聚焦主流不全面铺开"
- L-014 解决"主流也要先解释术语"
- 不冲突：聚焦主流后，主流的内容仍要按 L-014 解释术语

### 应用范围

**写 knowledge 文件时**：
- `overview.md` 开头先解释单元名缩写（如 "MGD = MultiGroup Diffusion，多群扩散"）
- 第一次提到 HYPRE、CFL、AMR 等术语时加一句话定义
- TL;DR 段是解释术语的好位置

**回答用户问题时**：
- 用户问"为什么用 X"——先确认 X 是什么（一句话），再讲为什么用
- 用户问"X 怎么工作"——先讲 X 是什么 + 解决什么问题，再讲机制
- 用户问"X 和 Y 区别"——先分别一句话定义 X 和 Y，再对比

**SKILL.md 输出规范**：
- description 字段含术语时，可以在 description 末尾或 frontmatter 加简短术语表
- knowledge/overview.md 开头加"术语速查"段（可选）

### 何时不需要解释（例外）

- 用户消息已显示懂术语（如"我用了 HYPRE 的 BoomerAMG 求解器，但收敛慢"）
- 术语已在同 skill 前文解释过（不要重复）
- 通用编程术语（如"数组"、"循环"）

### 推广到已有 skill

按 L-014 扫描已有 skill（见下 §"已有 skill 回审"），重点看：
- `overview.md` 开头有没有解释单元名缩写
- 第一次提到 HYPRE/CFL/AMR 时有没有加定义
- TL;DR 段是否纯术语堆砌

### 已有 skill 回审

| Skill | 主要问题 | 修订建议 |
|---|---|---|
| `flash-grid` overview.md | TL;DR 用了 "block-AMR" 没解释 | 开头加 "AMR = Adaptive Mesh Refinement 自适应网格细化" |
| `flash-hydro` overview.md | "Godunov 方法"、"Riemann 问题" 没解释 | §1 加术语速查 |
| `flash-eos` overview.md | "电子简并"、"Fermi 气体" 物理术语密集 | §1 加物理术语速查 |
| `flash-radtrans` overview.md | "MGD" 缩写在 TL;DR 第一次出现已解释 ✓；但 "HYPRE" 在 internals 第一次出现没解释 | internals.md 加 HYPRE 定义段 |
| `flash-laser` overview.md | "几何光学"、"逆韧致吸收" 物理术语 | 已含一定解释，可加术语速查 |
| `flash-driver` overview.md | "sourceTerm"、"CFL" 相对常见，但新手可能不懂 | 加术语速查段 |

**优先修订**：flash-grid / flash-hydro / flash-eos / flash-radtrans（HEDP 主链路，用户接触最多）

---

## L-015: 回答"X 做了什么"先讲完整故事线（定义→传递→处理→使用），再讲细节

**首次发现日期**：2026-08-02（flash-multispecies 验收 Q2）
**影响范围**：所有"X 做了什么 / X 是什么作用 / X 怎么工作"类回答
**严重度**：中（影响用户能否建立完整心智模型）

### 问题

flash-multispecies 验收 Q2 问"`species=cham,targ` setup 变量做了什么"，我直接跳到"setup 看到 species=cham,targ → Python genLines 自动生成 → 编译宏 + Flash.h + UNK + 参数族"——这是**机制细节**。

用户反馈：

> "以 Q2 为例，问的是 species 这个赋值做了什么，你更应该先帮助用户解释清楚这个变量的含义和用途，用自然的语言描述清楚其在何处定义，经过哪些步骤被调用，回答完这些之后再补充更细节的东西"

**根因**：

- 跳过了"species 是什么"（一句话定义）直接讲"它触发了什么"
- 没讲 species 变量从用户命令行到最终被 EOS/Hydro 使用**经历了哪些步骤**
- 用户缺的不是"自动生成了哪些文件"（细节），而是"这个变量从哪来、到哪去、为什么需要"（故事线）

### 根本规则

**回答"X 做了什么 / X 是什么作用 / X 怎么工作"类问题时，先讲 X 的完整故事线**：

1. **X 是什么**（一句话定义——L-014 已覆盖）
2. **X 在何处定义**（用户写的？源码声明的？自动生成的？）
3. **X 经过哪些步骤被传递和处理**（端到端旅程：从定义到使用）
4. **X 最终怎么被使用**（哪个单元读它、用来做什么）

**然后**才补充"具体机制细节"（生成了什么文件、怎么解析、参数列表等）。

### 为什么先讲故事线

- **建立心智模型**：用户需要先理解"species 变量从命令行走到 EOS 查询"的完整链路，才能理解为什么需要 Python genLines
- **避免信息碎片**：直接列"自动生成了 X/Y/Z"是一堆碎片，用户不知道它们之间的关系
- **自然语言叙述**：用"species 从你的终端出发，经过 setup.py，进入 Config Python..."的故事性叙述，比功能列表更容易记住

### 典型例子

**问"`species=cham,targ` 做了什么"**：

❌ 差（直接跳细节）：
```
setup 看到 species=cham,targ 后自动生成：
编译宏 FLASH_MULTISPECIES + NSPECIES=2
Flash.h: CHAM_SPEC=1, TARG_SPEC=2
UNK: SPECIES_VAR
参数族: ms_chamA/Z/..., eos_chamEosType/..., op_chamAbsorbKind/...
```

✅ 好（先讲故事线）：
```
第一步：species 是什么
  ——setup 命令行的一个用户变量，告诉 FLASH"我要模拟 cham 和 targ 两种物质"

第二步：它从哪来、经过谁
  ——终端 → setup.py 解析 → Multispecies Config Python 读取 → genFiles 生成 → make 编译 → runtime 读 parfile → Hydro/EOS 使用

第三步：为什么需要
  ——避免用户手写 60+ 行 Config；换个算例只需改 setup 命令

第四步：细节（自动生成了什么）
  ——编译宏 + Flash.h + UNK + 参数族...
```

### 应用范围

**写 knowledge 文件时**：
- `overview.md` 讲一个概念时，先讲它的"生命旅程"再讲内部机制
- `internals.md` 讲一个函数时，先讲它"被谁调、调了谁"再讲内部算法
- `recipes.md` 讲一个配置时，先讲"这个配置从哪来到哪去"再讲具体参数

**回答用户问题时**：
- 用户问"X 做了什么"——先讲 X 的故事线（定义→传递→处理→使用），再讲细节
- 用户问"X 怎么工作"——先讲 X 在整个系统中的位置和旅程，再讲内部机制
- 用户问"为什么用 X"——先讲 X 解决什么问题（故事背景），再讲 X 的具体方案

### 与 L-014 的关系

| 经验 | 解决的问题 |
|---|---|
| L-014（术语先解释本身） | "X 是什么"——一句话定义 |
| **L-015（先讲故事线）** | **"X 怎么走完它的生命周期"——端到端叙述** |

互补：L-014 让用户先理解概念定义 → L-015 让用户看到概念的完整旅程 → L-011 让用户理解为什么这样设计。

**L-014 + L-015 组合模板**：
```
[先解释术语——L-014]
X 是......

[讲故事线——L-015]
X 从 [定义位置] 出发，经过 [步骤 1] → [步骤 2] → ...，最终被 [使用方] 用于 [目的]。

[讲为什么——L-011]
为什么需要 X：......

[讲细节]
具体机制：......
```

### 推广到已有 skill

按 L-015 扫描已有 skill，重点看 `overview.md` 和 `internals.md` 是否有"直接跳细节没讲故事线"问题：

| Skill 文件 | 评估 | 修订 |
|---|---|---|
| flash-multispecies overview.md | Q2 对应段落（§3）需加故事线 | 后续优化 |
| flash-eos overview.md §3（EOS 模式系统） | 已含"为什么有 3 种"（手里有的变量不同）——接近故事线 | 基本符合 |
| flash-radtrans overview.md §4（CTU 流程） | 已含完整流程图——符合 L-015 | 不改 |
| flash-hydro overview.md §2（split vs unsplit） | 已含设计差异叙述——符合 L-015 | 不改 |
| 其他 skill | 大多数 overview 已含故事性叙述 | 不改 |

**结论**：已有 skill 大体符合 L-015，不需要批量修订。L-015 主要约束**未来回答和新 skill 建设**。

---

## L-016: FLASH species 名有长度限制——多物质算例用短名避免 HDF5 冲突

**首次发现日期**：2026-08-02（Sunliang_laser_CH 实战调试）
**影响范围**：所有 3+ 种物质的算例（如多层靶 HEDP）
**严重度**：高（导致 HDF5 写入 abort）

### 问题

Sunliang_laser_CH 算例用 4 种物质：`species=cham,targ1,targ2,targ3`。编译、初始化、AMR 细化全部成功，但**写 plotfile 时 HDF5 abort**：

```
HDF5-DIAG: Error detected in HDF5 (1.14.3)
H5Dcreate1(): unable to create dataset
H5L__create_real(): can't insert link
H5L__link_cb(): name already exists
DRIVER_ABORT: Error: H5Dcreate io_h5write_unk
```

### 根因

FLASH 的 species 名在多个环节被用作**变量名 / dataset 名**：

1. **Flash.h 预处理宏**：`species=cham,targ1` → `#define TARG1_SPEC 36`
2. **unk 变量名**：species 质量分数在 unk 数组中存为 `TARG1_SPEC` 对应的槽位，IO 写入时用 species 名作为 HDF5 dataset 名
3. **parfile 参数前缀**：`ms_targ1A` / `eos_targ1EosType` / `op_targ1Absorb` 等

当 species 名**过长**（如 `targ1` 5 字符），HDF5 dataset 名（由 species 名 + 后缀拼接）可能：
- 超过 HDF5 的内部名长度限制
- 或与另一个 species 的 dataset 名**截断后冲突**（`targ1` 和 `targ2` 的某些派生名可能截断后相同）

导致 HDF5 写入时报 "name already exists"。

### 解决

**用短 species 名**（不超过 4 字符），避免 HDF5 dataset 名冲突：

```
# ❌ 危险（targ1 5 字符，HDF5 冲突）
species=cham,targ1,targ2,targ3

# ✅ 安全（tar1 4 字符，HDF5 正常）
species=cham,tar1,tar2,tar3
```

用户（Sunliang）原本就用 `tar1` / `tar2` / `tar3`（短名），是有意为之。调试过程中我曾误改成长名 `targ1`，导致 HDF5 abort。

### 连锁影响

改 species 名会影响 3 处必须一致：

| 位置 | `targ1`（长名）| `tar1`（短名）|
|---|---|---|
| **setup 命令** | `species=cham,targ1,...` | `species=cham,tar1,...` |
| **Flash.h 常量** | `#define TARG1_SPEC 36` | `#define TAR1_SPEC 36` |
| **parfile 参数前缀** | `ms_targ1A` / `op_targ1Absorb` | `ms_tar1A` / `op_tar1Absorb` |
| **Simulation_initBlock** | `species = TARG1_SPEC` | `species = TAR1_SPEC` |

**4 处必须用同一套名字**。不一致会导致：
- parfile 参数 "ignoring unknown parameter"（前缀不匹配）
- Simulation_initBlock 物种判断失败（常量值不匹配）
- HDF5 写入 abort（名字过长）

### 命名建议（按 L-011 讲为什么）

| 物质 | 推荐短名（≤4 字符）| 不推荐 |
|---|---|---|
| chamber 气体 | `cham`（4）✓ | `chamber`（7）✗ |
| target 1 | `tar1`（4）✓ | `targ1`（5）✗ |
| target 2 | `tar2`（4）✓ | `targ2`（5）✗ |
| target 3 | `tar3`（4）✓ | `targ3`（5）✗ |
| 氢 | `h`（1）或 `hyd`（3）✓ | `hydro`（5）✗ |
| 氦 | `he`（2）✓ | `heli`（4）✓ |
| 铝 | `al`（2）✓ | `alum`（4）✓ |
| 金 | `au`（2）✓ | `gold`（4）✓ |
| CH 塑料 | `ch`（2）✓ | `plas`（4）✓ |

**规则**：species 名 ≤ 4 字符。如果要更多区分，用数字后缀（`tar1` / `tar2`），不要加字母（`targ1`）。

### 沉淀位置

本经验同时写入：
- `agent/LESSONS_LEARNED.md` L-016（此处）
- `agent/pitfalls/` 建议新建 `species-name-length.md`（如需要独立踩坑条目）

### 实战验证

```
species=cham,tar1,tar2,tar3 → 275 步跑通，14 个 plotfile 正常输出 ✓
species=cham,targ1,targ2,targ3 → HDF5 abort "name already exists" ✗
```

---

## L-017: 解决报错后自主询问是否沉淀到报错库

**首次发现日期**：2026-08-03（用户反馈）
**影响范围**：所有实战调试场景
**严重度**：中

### 问题

用户解决了一个报错后，Agent 没有主动询问是否要把经验沉淀到报错库。用户需要手动提醒才做，导致实战经验可能丢失。

### 根本规则

**每次成功解决一个报错后，Agent 应自主询问**：

> "这个问题已解决。要不要把它沉淀到报错库（`agent/pitfalls/`）？"

**触发条件**（满足任一即触发）：
1. abort 修复后算例跑通
2. parfile 参数修改解决了数值问题
3. setup/编译错误修复
4. 用户确认"搞定了"/"跑通了"

**不触发**：用户只是问问题（没报错）；报错还没解决；经验已覆盖。

### 沉淀流程（用户同意后）

1. 按 `agent/TEMPLATES/pitfall.md` 模板写新条目到 `agent/pitfalls/<topic>.md`
2. 更新 `agent/pitfalls/README.md` 文件清单
3. 简短报告："已沉淀到 `agent/pitfalls/<file>.md`"

### 为什么自主询问而不是自动写

- 用户可能认为某报错太琐碎不值得记
- 自主询问让用户有控制权（同意/不同意/改内容）

---

## 待补充（后续遇到时追加）

- [ ] Phase 2 启动 flash-driver 时观察到的经验
- [ ] 跨 skill 协作实战中的问题（如调度顺序、上下文丢失）
- [ ] 自动扩写机制（D-004）实际效果评估
- [ ] 工具脚本（如 build_param_index.py）的实现经验

---

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-12 | 初始创建（L-001 到 L-007，含 flash-laser + flash-source-reader 的全部经验） | claude |
| 2026-07-12 | 加 L-008（报错类回答必须贴触发代码字段）—— flash-pitfall-finder 验收反馈 | claude |
| 2026-07-12 | L-008 二次修订（用户反馈）：从"只对 if 触发"收紧为"对 FLASH 源码相关（含 if、运算、参数读取、数组访问等）"，明确"非源码错（链接器/Python/系统配置）不贴凑数代码" | claude |
| 2026-07-18 | 加 L-009（parfile 顶部 setup 注释不可信）+ L-010（回答精简原则——核心 4 段 + 引导项列表，取代 L-008 的"5 段强制"）—— 用户实战 LaserSlab 4.6.2 example.par bug 反馈 | claude |
| 2026-07-19 | 加 L-011（回答选择/操作类问题讲"为什么"）—— flash-grid 验收反馈"L-001 的延伸" | claude |
| 2026-07-19 | 加 L-012（诊断类先引导贴现场 + 公式 CLI 友好）—— flash-hydro 验收反馈两条 | claude |
| 2026-07-19 | 加 L-013（聚焦用户实际场景，主流路径优先）—— flash-eos 验收后追加测试"EOS 表格式 + 获取方式"反馈 | claude |
| 2026-07-20 | 加 L-014（专业术语第一次出现时先解释本身）—— flash-radtrans 验收 Q4 反馈"先解释 HYPRE 是什么" | claude |
| 2026-08-02 | 加 L-015（回答"X 做了什么"先讲完整故事线再讲细节）—— flash-multispecies 验收 Q2 反馈"先解释变量的含义和用途、何处定义、经过哪些步骤" | claude |
| 2026-08-02 | 加 L-016（FLASH species 名有长度限制）—— Sunliang_laser_CH 实战调试发现 `targ1`（5 字符）导致 HDF5 "name already exists" abort；用户原有设计用 `tar1`（4 字符）就是为了绕过 | claude |
| 2026-08-03 | 加 L-017（解决报错后自主询问是否沉淀到报错库）—— 用户反馈"报错库更新需要自主触发" | claude |
