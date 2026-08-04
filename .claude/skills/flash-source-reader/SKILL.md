---
name: flash-source-reader
description: |
  FLASH 4.8 源码阅读专家。给定函数名/参数名/变量名，定位源码位置并加中文注释解释上下文。
  覆盖：函数定义/调用关系、参数在 Config 文件的声明、Flash.h 中的变量索引、call chain 分析。
  预读 snippets/ 含主循环/Grid/EOS/RuntimeParameters 等 5 个核心函数。
  触发词：源码, source code, 在哪里定义, 函数定义, 行号, 找代码, call chain, 调用图,
        subroutine, function, Flash.h, interface, use ..._interface
triggers:
  # 中文
  - 源码
  - 源代码
  - 在哪定义
  - 在哪实现
  - 函数定义
  - 函数实现
  - 行号
  - 找代码
  - 调用图
  - 调用关系
  - 调用链
  - 谁调用
  - 谁调
  # 英文
  - source code
  - source file
  - definition
  - implementation
  - call chain
  - call graph
  - call site
  - caller
  - callee
  - subroutine
  - function
  - interface
  - use .*_interface
  - grep
  - rg
  - Flash.h
  # 关键函数（高频被查）
  - Driver_evolveFlash
  - Driver_initFlash
  - Driver_sourceTerms
  - Driver_computeDt
  - Grid_getBlkPtr
  - Grid_releaseBlkPtr
  - Grid_fillGuardCells
  - Grid_getBlkIndexLimits
  - Eos_wrapped
  - Eos_getData
  - RuntimeParameters_get
  - RuntimeParameters_set
  - Simulation_initBlock
  - Simulation_init
  - EnergyDeposition
  - Hydro
  - opacity_getAbsorb
  # 通配模式
  - _VAR
  - _interface
when_to_use: |
  调用本 skill 的场景：
  1. 用户问"X 函数在哪定义"、"X 的源码在哪"、"X 在哪个文件"
  2. 用户问"X 怎么实现的"、想看具体代码逻辑
  3. 用户问"谁调用 X"、"X 调用了谁"、call chain / call graph
  4. 用户问"X_VAR" 在 Flash.h 里的索引值
  5. 用户问"X 参数在 Config 里怎么声明的"
  6. 用户问"use X_interface" 中 X 是什么
  7. 用户复制了一段代码问"这是什么"
when_not_to_use: |
  **不调用本 skill 的场景**：
  - 参数含义（"ed_wavelength 是什么"）→ `flash-param-query`
  - 物理原理（"为什么需要临界密度"）→ `flash-<physics>`
  - abort 信息匹配（"Driver_abortFlash: ... 什么意思"）→ `flash-pitfall-finder`
  - 想跑代码（不是读代码）→ `flash-case-runner`
  - 想改源码（不是看源码）→ 用户自己改或建议方案
layer: tool
phase: 1
status: stable
created: 2026-06-17
last_updated: 2026-07-19
owner: user
---

# flash-source-reader — 源码阅读工具

> **状态**：✅ stable（5 道验收考题全部满分通过，2026-07-12）

## 1. 角色与边界

### 1.1 我是做什么的

**源码定位 + 中文解释**。给定名字（函数/参数/变量），用 `rg` / `Read` 在 `source/` 下定位，读出关键片段，加中文注释解释。

支持的查询类型：

| 查询类型 | 示例 | 工具组合 |
|---|---|---|
| 函数定义 | `Driver_evolveFlash 在哪` | `rg "^subroutine Driver_evolveFlash"` → Read |
| 函数实现细节 | `Eos_wrapped 内部怎么算` | Read 完整函数体 |
| call sites | `谁调 EnergyDeposition` | `rg "call EnergyDeposition"` |
| 调用链 | `Driver 怎么调到 Hydro` | 多次 rg + 拼接 mermaid |
| Config 参数声明 | `ed_maxBeams 在哪声明` | `rg "PARAMETER ed_maxBeams"` |
| Flash.h 变量索引 | `TELE_VAR 的值` | `rg "TELE_VAR" bin/Flash.h.tpl source/` |
| interface 模块 | `Grid_interface 含什么` | Read `Grid_interface.F90` |

### 1.2 我不做什么

| 用户问题类型 | 归属 skill | 原因 |
|---|---|---|
| 参数含义（不是位置） | `flash-param-query` | 含义靠字典，位置靠 grep |
| 物理原理 | `flash-<physics>` | 源码解释 ≠ 物理解释 |
| abort 信息 | `flash-pitfall-finder` | 错误匹配走踩坑库 |
| 跑代码 | `flash-case-runner` | 运行 ≠ 阅读 |
| 改源码 | 用户自己 | 本 skill 只读不改 |

## 2. 行为协议

### 2.1 标准查询流程（on_query）

按以下步骤处理：

#### Step 1：识别查询类型

判断用户问的是：
- **(a) 函数定义在哪** → 走 §2.1.1
- **(b) 函数实现细节** → 走 §2.1.2
- **(c) call sites / 调用图** → 走 §2.1.3
- **(d) 参数声明位置** → 走 §2.1.4
- **(e) Flash.h 变量索引** → 走 §2.1.5

#### 2.1.1 函数定义查询

```bash
# 找 subroutine/function 定义
rg --type-add 'f90:*.{F90,f90}' -tf90 -n "^\s*(subroutine|function)\s+<Name>\b" source/
```

**多个命中的处理**：
- 一个名字常被多个实现/变体定义（如 `Driver_evolveFlash` 在 Split/Unsplit/INSfracstep 都有）
- 按"真实实现 vs interface 声明 vs 单元测试"分类
- 优先返回**主实现**（在 `*Main/<variant>/` 下），interface 文件单独列出

**输出格式**：
```
**<Name> 的定义位置**

主实现: `source/<unit>/<unit>Main/<variant>/<Name>.F90:LXX`
interface 声明: `source/<unit>/<unit>_interface.F90:LYY`
其他变体: ...

```fortran
! source/.../<Name>.F90:LXX-LYY
<代码片段>
! ↑ 中文注释解释关键逻辑
```
```

#### 2.1.2 函数实现细节

定位后用 Read 读完整函数（或前 50-100 行）：
- 标出**关键调用**（call ...）
- 标出**关键变量**（intent in/out）
- 标出**关键分支**（if/select case）

#### 2.1.3 call sites / 调用图

```bash
# 找谁调 X
rg --type-add 'f90:*.{F90,f90}' -tf90 -n "call\s+<Name>\b" source/

# 找 X 调谁（先读 X 的源码，再 grep 内部 call）
rg -n "^\s*call\s+\w+" source/<X 文件>.F90
```

**输出调用关系图用文字+缩进**（按 L-002，不用 mermaid）：

```
Driver_evolveFlash
├── Driver_computeDt
├── Driver_stepSee
│   ├── Hydro
│   └── Driver_sourceTerms
│       ├── ...
│       └── EnergyDeposition ★（激光，第 10 位）
```

#### 2.1.4 参数声明位置

```bash
# 找 PARAMETER 声明（在 Config 文件）
rg -n "PARAMETER\s+<name>" source/

# 找动态生成的参数（Config 里 Python genLines）
rg -n "<name>" source/**/Config
```

注意：`ed_*_<i>`、`ed_time_<p>_<s>` 等是动态生成的，要 grep `Config` 文件里的 Python 代码（详见 `flash-laser/knowledge/internals.md §6`）。

#### 2.1.5 Flash.h 变量索引

```bash
# Flash.h 是 setup 期生成的，模板在 bin/
rg -n "<VARNAME>_VAR\s+" bin/Flash.h.tpl source/

# 或直接看已 build 的 case 的 Flash.h
rg -n "<VARNAME>_VAR\s+" cases/<case>/Flash.h
```

### 2.2 推荐先查 snippets/

**5 个常用函数已经在 `snippets/` 预读**，先查 snippets/ 提速：

| Snippet | 函数 | 何时查 |
|---|---|---|
| `snippets/driver-evolve-flash.md` | `Driver_evolveFlash` | 主循环结构 |
| `snippets/driver-source-terms.md` | `Driver_sourceTerms` | sourceTerms 调度顺序 |
| `snippets/grid-get-blk-ptr.md` | `Grid_getBlkPtr` / `Grid_releaseBlkPtr` | 取/放 block 数据指针 |
| `snippets/eos-wrapped.md` | `Eos_wrapped` | EOS 包装接口 |
| `snippets/runtime-parameters-get.md` | `RuntimeParameters_get` | 读 runtime parameter（泛型接口） |

如果用户问的函数在 snippets/ 里，直接返回 snippet 内容（不再 rg）。

### 2.3 输出规范（**核心** — 按 L-001 + L-010 + L-011 修订）

**这个 skill 的价值不是 grep** —— grep 找位置比这个 skill 快得多。**核心价值是讲清楚代码逻辑**：是什么 / 做什么 / 实际怎么运作 / **为什么这么设计**。

按 L-010 精简原则，回答分两部分：**核心 4 段（必给，详细但不冗长）+ 引导项（列表，按需展开）**。

#### §2.3.1 核心 4 段（必给）

**1. 它是什么**（一句话）

用人话总结这个东西在 FLASH 里的**角色**。不要只说"是个 subroutine"，要说它在整个系统里起什么作用。

✅ 好："`Driver_evolveFlash` 是整个 FLASH 的时间推进引擎——所有事都从这里发起。"
❌ 坏："`Driver_evolveFlash` 是 Driver 单元的一个 subroutine。"

**2. 定义位置**（带变体对照）

`source/path/file.F90:LXX` + 多变体/接口的对照表。要让用户知道"哪个是主实现、哪些是变体、哪些是 stub/interface"。

**3. 它做什么 / 怎么工作**（核心段 — 讲逻辑）

这是回答的**主体**。要讲清楚：
- **控制流**：从入口到出口，主要分支怎么走
- **数据流**：什么数据进来、被怎么处理、什么数据出去
- **关键操作**：每个核心步骤在做什么（用人话，不照搬代码）
- **实际运作**：实际跑起来是什么样

**用文字 + 缩进列表表达调用关系，不要用 mermaid 图**（L-002）。

✅ 好（文字+缩进）：
```
Driver_sourceTerms
├── Polytrope
├── Stir
├── ...
└── EnergyDeposition ★ (激光，第 10 位)
    ├── ed_createRays
    ├── ed_traceRays
    │   └── 循环每个 block、每根 ray
    └── ed_updatePlasma
```

**4. 关键代码片段**（≤ 20 行 + 中文注释）

引用关键代码，每行加 `! ↑ 中文` 注释。**不复制大段代码**——只引核心段。

```fortran
! source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90:131-138
do dr_nstep = dr_nBegin, dr_nend              ! ★ 时间步主循环
   call Grid_getListOfBlocks(LEAF, blockList, blockCount)  ! 拿 block 列表
   call Hydro(blockCount, blockList, ...)                  ! 算流体
   call Driver_sourceTerms(blockCount, blockList, dr_dt)   ! ★ sourceTerms（含激光）
   ...
end do
```

---

#### §2.3.2 为什么这么设计（L-011 必给段）

按 L-011，源码讲解必须含**设计动机**段——为什么这个函数/参数/数据结构存在、解决什么问题、应对什么场景。**不只是"是什么"和"做什么"**。

✅ 例：讲 `Grid_getBlkPtr` 时，不只是说"拿 block 数据指针"，要讲"为什么用指针不用 copy"（性能：避免拷贝整个 block）+"为什么必须配对 releaseBlkPtr"（资源管理：Paramesh 引用计数）。

✅ 例：讲 `Driver_sourceTerms` 调用顺序时，讲"为什么激光排第 10 位"（数值稳定性：等所有热损失和能量交换算完再加激光，避免同一步内多次迭代的不稳定）。

如果实在讲不出"为什么"（罕见），老实说"设计动机不明，可能只是历史习惯"。

---

#### §2.3.3 引导项（按需展开，不强制）

用户**明确选某项**时再展开。例如用户说"我想看完整调用链"，把 main 到目标的路径详细写出。

- [ ] **完整调用链**（从 main 到目标函数的完整路径，让用户看到"在系统哪个位置"）
- [ ] **延伸**（相关函数、对应 knowledge 条目、实际怎么验证）

#### §2.3.3 反例（避免的输出风格）

以下风格**不要**出现：

❌ **纯检索型**（grep 也能做，没价值）：
```
位置：source/X.F90:42
代码：<片段>
```

❌ **过度学术型**（不接地气）：
```
该 subroutine 实现了显式时间推进的 abstraction layer...
```

❌ **缺逻辑型**（只列代码不讲做什么）：
```
subroutine X(a, b, c)
  ! 这里有一段代码
  ...
end subroutine
```

❌ **复杂 mermaid 图**（L-002：看不懂）

✅ **正确风格**：把代码当**故事**讲——它是什么角色、做什么、怎么运作、和谁有关系。核心 4 段控制在 100-150 行内。

### 2.4 找不到时的处理

如果 `rg` 无命中：
1. 检查名字拼写（大小写敏感！Fortran 不区分但 grep 区分）
2. 尝试模糊匹配：`rg -i "<name>" source/`
3. 检查是否是宏/常量（去 `bin/Flash.h.tpl` 找）
4. 检查是否是 setup 期生成（去 `Config` 文件找 Python）
5. 都找不到 → 老实说"`<name>` 在源码中未找到，可能是拼写错或来自外部库"

## 3. 关键命令模板

```bash
# 1. 找 subroutine 定义（注意大小写）
rg --type-add 'f90:*.{F90,f90}' -tf90 -n "^\s*subroutine\s+<Name>" source/

# 2. 找 function 定义
rg --type-add 'f90:*.{F90,f90}' -tf90 -n "^\s*(real|integer|logical)\s+function\s+<Name>" source/

# 3. 找 call sites
rg --type-add 'f90:*.{F90,f90}' -tf90 -n "call\s+<Name>\b" source/

# 4. 找 PARAMETER 声明（在 Config）
rg -n "^PARAMETER\s+<name>" source/

# 5. 找动态生成参数（在 Config 的 Python genLines）
rg -n "<name>" source/**/Config

# 6. 找 Flash.h 变量索引（模板）
rg -n "<NAME>_VAR" bin/Flash.h.tpl

# 7. 找 interface 模块声明
rg -n "subroutine\s+<Name>" source/**/*_interface.F90

# 8. 找 use 语句（谁依赖某模块）
rg -n "use\s+<ModuleName>" source/

# 9. 大小写不敏感（兜底）
rg -i -n "<name>" source/
```

## 4. snippets/ 子目录

5 个常用函数预读，避免每次都 grep：

| 文件 | 函数 | 行数 |
|---|---|---|
| `snippets/driver-evolve-flash.md` | `Driver_evolveFlash`（主循环） | ~100 |
| `snippets/driver-source-terms.md` | `Driver_sourceTerms`（sourceTerms 调度） | ~80 |
| `snippets/grid-get-blk-ptr.md` | `Grid_getBlkPtr` / `Grid_releaseBlkPtr` | ~60 |
| `snippets/eos-wrapped.md` | `Eos_wrapped`（EOS 包装） | ~80 |
| `snippets/runtime-parameters-get.md` | `RuntimeParameters_get`（泛型接口） | ~60 |

## 5. 示例问答（验收基准）

### Q1: `Driver_evolveFlash` 在哪定义？怎么实现？
**A**: 见 `snippets/driver-evolve-flash.md`，主实现 `source/Driver/DriverMain/Unsplit/Driver_evolveFlash.F90:37`（unsplit 模式）。

### Q2: 谁调用 `EnergyDeposition`？
**A**: `rg "call EnergyDeposition" source/` → 唯一 call site 是 `source/Driver/DriverMain/Driver_sourceTerms.F90:56,68`。

### Q3: `TELE_VAR` 在 Flash.h 里的索引？
**A**: 在 `bin/Flash.h.tpl` 里由 setup.py 根据 Simulation 声明的变量动态生成；查 `cases/<case>/Flash.h`（已 build 的）能看实际值。

### Q4: `use Driver_interface` 含什么？
**A**: Read `source/Driver/Driver_interface.F90`，列出所有 `subroutine` 声明。

### Q5: `RuntimeParameters_get` 是 subroutine 吗？
**A**: 不是单个 subroutine，是**泛型接口**（generic interface），dispatch 到 `RuntimeParameters_getReal/Int/Str/Log`。见 `snippets/runtime-parameters-get.md`。

## 6. 待办

- [ ] 跑 5 道验收考题，全部通过则升级 stable
- [ ] 根据实际触发情况持续微调 description
- [ ] 长期：累积更多 snippets（如 `Grid_fillGuardCells`、`Hydro`、`Eos_getData` 等）

## 7. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-07-12 | 升级 draft → beta：扩展 triggers（含 50+ 关键函数名）；补全 §2 行为协议（5 种查询类型 + 标准输出格式）；建 snippets/ 5 个核心函数预读；加 5 道验收考题 | claude |
| 2026-07-12 | **升级 beta → stable** + 重写 §2.3 输出规范：5 道验收考题全部满分通过（首次答简略被驳回 → 重答"讲逻辑"版通过）；新增 7 段标准输出结构（是什么/位置/做什么/为什么/代码/调用链/延伸）；明确禁用 mermaid 图（验收反馈"看不懂"），改用文字+缩进；加反例段说明避免风格 | claude |
| 2026-07-19 | **按 L-009/L-010 精简**：§2.1.3 mermaid 反例段改为文字+缩进示例；§2.3 从"7 段强制"改为"核心 4 段（必给）+ 引导项（按需展开）"——核心段（是什么/位置/做什么/代码片段）必给且详细，引导项（为什么/完整调用链/延伸）只列名让用户按需选；保留反例段但收紧措辞 | claude |
| 2026-07-19 | **按 L-011 强化"为什么"**：§2.3 把"为什么这么设计"从引导项提升为**必给段**（§2.3.2）；明确"不只是讲是什么和做什么，必须讲设计动机"；引导项收紧为完整调用链 + 延伸两项——flash-grid 验收反馈"L-001 的延伸" | claude |
