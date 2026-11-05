---
name: flash-param-query
description: |
  FLASH 参数字典查询工具。给定参数名（如 ed_wavelength、rt_mgdFlMode、hy_cfl、sim_xmin），
  在所有 Config 文件 + skills/flash-param-query/knowledge/param-index.md + 各 skill 的 knowledge/params.md 检索，
  返回类型/默认值/单位/声明位置/含义/典型值/所属 skill 全信息表。
  覆盖：跨单元查参数、通配符匹配（如 ed_*）、按前缀查（如所有 rt_mgd*）。
  触发词：参数, parameter, 默认值, 单位, 这个参数什么意思, 是什么, runtime parameter,
        Config 里声明, parfile 怎么写, 这个值
triggers:
  # 中文
  - 参数
  - 默认值
  - 默认
  - 单位
  - 这个参数什么意思
  - 这个值
  - 是什么意思
  - 怎么用
  - 取多少
  - 设多少
  - 配置项
  - 配置参数
  # 英文
  - parameter
  - parameters
  - default value
  - default
  - unit
  - units
  - runtime parameter
  - RUNTIME_PARAMETER
  - PARAMETER
  - Config
  - "what does"
  - "what is"
  # 参数前缀（catch-all，覆盖核心单元）
  - "ed_"
  - "rt_"
  - "hy_"
  - "eos_"
  - "gr_"
  - "sim_"
  - "dr_"
  - "io_"
  - "mesh_"
  - "diff_"
  - "cool_"
  - "heat_"
  - "burn_"
  - "fl_"
  - "stir_"
  - "turb_"
  - "op_"
  - "cond_"
  - "visc_"
  - "mgd_"
  - "laser_"
  # 高频具体参数
  - useEnergyDeposition
  - useHydro
  - useRadTrans
  - useGravity
  - useDiffuse
  - useBurn
  - useCool
  - wavelength
  - numberOfBeams
  - crossSectionFunctionType
  - mgdFlMode
  - Courant
  - xmin
  - xmax
  - ymin
  - ymax
  - zmin
  - zmax
  - nstep
  - tmax
  - dt
  - dtinit
  - plotFileIntervalStep
  - checkpointFileIntervalStep
  - basenm
  - restart
when_to_use: |
  调用本 skill 的场景：
  1. 用户问某个 parfile 参数的含义（"ed_wavelength 是什么"、"rt_mgdFlMode 怎么用"）
  2. 用户问参数的默认值、单位、类型
  3. 用户问"这个参数怎么设"、"取多少合适"
  4. 用户问"X 开头的参数有哪些"（按前缀查）
  5. 用户问 parfile 里某行参数什么意思
  6. 用户问 setup 命令里的 setup 变量（如 ed_maxBeams）
when_not_to_use: |
  **不调用本 skill 的场景**：
  - 想深入理解物理原理（不只是参数本身）→ 对应 `flash-<physics>`
  - 想看参数对应的源码实现 → `flash-source-reader`
  - 错误信息排查 → `flash-pitfall-finder`
  - 想生成完整 parfile → 对应 `flash-<physics>` 的 recipes
  - 想知道怎么 setup → `flash-setup-builder`（Phase 2）
layer: tool
phase: 1
status: stable
created: 2026-06-17
last_updated: 2026-07-19
owner: user
---

# flash-param-query — 参数字典查询工具

> **状态**：✅ stable（5 道验收考题全部通过，2026-07-16）

## 1. 角色与边界

### 1.1 我是做什么的

**参数字典查询**。给定参数名，返回完整信息表。三个数据源：

| 数据源 | 内容 | 用途 |
|---|---|---|
| `skills/flash-param-query/knowledge/param-index.md` | 核心参数（~100-200 条）的元信息（含单位、含义、典型值） | 高频查询，预解析 |
| `source/**/Config` 文件 | 所有 PARAMETER 的原始声明（类型、默认值） | 权威源，动态搜 |
| `skills/flash-<unit>/knowledge/params.md` | 各单元详细参数字典 | 物理背景、陷阱 |

查询策略：**先 param-index.md → 再 Config → 最后 knowledge/params.md**。

### 1.2 我不做什么

| 用户问题类型 | 归属 skill | 原因 |
|---|---|---|
| 物理原理（不只是参数） | `flash-<physics>` | 参数 ≠ 物理 |
| 源码实现 | `flash-source-reader` | 字典 ≠ 源码 |
| 错误排查 | `flash-pitfall-finder` | 字典 ≠ 诊断 |
| 生成完整 parfile | `flash-<physics>` recipes | 字典 ≠ 模板 |
| 生成 setup 命令 | `flash-setup-builder`（Phase 2） | setup 变量 ≠ runtime parameter |

## 2. 行为协议

### 2.1 标准查询流程（on_query）

#### Step 1：识别查询类型

| 类型 | 示例 | 处理 |
|---|---|---|
| **(a) 精确查** | `ed_wavelength 是什么` | 走 §2.1.1 |
| **(b) 前缀查** | `ed_ 开头的参数有哪些` | 走 §2.1.2 |
| **(c) 单元查** | `激光单元有哪些参数` | 走 §2.1.3 |
| **(d) 模糊查** | `跟波长有关的参数` | 走 §2.1.4 |

#### 2.1.1 精确查询

```bash
# Step A: 先查 param-index（核心参数有预解析信息）
rg -n "^### <name>" skills/flash-param-query/knowledge/param-index.md
rg -n "\| <name> \|" skills/flash-param-query/knowledge/param-index.md

# Step B: 查 Config 原始声明（权威源）
find source -name Config -type f 2>/dev/null | xargs grep -n "^PARAMETER\s\+<name>" 2>/dev/null

# Step C: 查对应 skill 的 params.md（详细解释）
rg -n "<name>" skills/*/knowledge/params.md 2>/dev/null
```

**输出标准格式**：
```
**参数**: <name>

| 属性 | 值 |
|---|---|
| 类型 | REAL / INTEGER / BOOLEAN / STRING |
| 默认值 | <来自 Config> |
| 单位 | <cm/s/W/度/无>（注：来自 param-index 或对应 skill；Config 通常不写单位） |
| 声明位置 | source/<unit>/Config:LXX |
| 所属 skill | flash-<unit> |
| 是否 setup 变量 | 否（运行时）/ 是（编译期，需 setup 命令） |

**含义**: <一句话>

**默认值依据**（L-011 必给）：<为什么默认这个值——物理/数值/工程原因。不要只给数字>
   例：hy_cfl 默认 0.8——CFL 条件数 0.8 是显式 Godunov 类 Hydro 求解器的"安全"上限；
        再高（>0.9）显式不稳定，再低（<0.5）步数过多浪费算力。
   例：ed_maxBeams 默认 6——ICF 直接驱动典型 6 束对称打靶；用户算例 beam 数超 6 时要 setup 加 `ed_maxBeams=N`。

**典型值**: <常见配置；按场景给不同值并说明为什么>

**示例**:
```fortran
<name> = <value>     # <注释>
```

**延伸**: knowledge/params.md §X / recipes.md §Y
```

#### 2.1.2 前缀查询

```bash
# 找所有 ed_ 开头的参数
find source -name Config -type f 2>/dev/null | xargs grep -n "^PARAMETER\s\+ed_" 2>/dev/null | head -20

# 或在 param-index 查
rg -n "ed_\w+" skills/flash-param-query/knowledge/param-index.md
```

按"单元 + 字母顺序"分组输出。

#### 2.1.3 单元查询

```bash
# 列某单元的所有 PARAMETER
find source/<unit-path> -name Config -type f 2>/dev/null | xargs grep "^PARAMETER" 2>/dev/null
```

例：
- 激光：`find source/physics/sourceTerms/EnergyDeposition -name Config`
- EOS：`find source/physics/Eos -name Config`
- Driver：`find source/Driver -name Config`

#### 2.1.4 模糊查询

按描述找参数：

```bash
# 用关键词在 param-index 找
rg -i -n "<描述关键词>" skills/flash-param-query/knowledge/param-index.md

# 在所有 Config 的 D 文档行找
find source -name Config -type f 2>/dev/null | xargs grep -i "^D\s\+.*<关键词>" 2>/dev/null | head -10
```

### 2.2 setup 变量 vs runtime parameter 区分

**易混点**：用户常问"X 参数怎么改"。

| 类型 | 在哪改 | 改完要不要重新 setup+make |
|---|---|---|
| **setup 变量** | `./setup` 命令行 | **要** |
| **runtime parameter** | `flash.par` | 不要 |

**判断规则**：
- 名字以 `max` 开头（`ed_maxBeams`、`ed_maxRayCount` 等）→ 通常 setup 变量
- 名字以 `numberOf` 开头（`ed_numberOfBeams`）→ 通常 runtime parameter
- 在 Config 的 Python `genLines` 里读 setupvars → setup 变量
- 在 Config 的 `PARAMETER` 行 → runtime parameter

详见各 skill 的 knowledge/params.md §"setup 变量 vs runtime parameter"。

### 2.3 找不到时的处理

如果 `find ... xargs grep` 无命中：
1. 检查拼写（大小写敏感！`ed_wavelength` ≠ `ed_Wavelength`）
2. 尝试模糊：`grep -i "<name>"`
3. 检查是否是 setup 变量（去 Config 的 `genLines` Python 段找）
4. 检查是否是 `Flash.h` 里的宏（如 `MAXBLOCKS`）
5. 检查是否是变量索引（如 `TELE_VAR`，在 `bin/Flash.h.tpl`）
6. 都找不到 → 老实说"`<name>` 不是 FLASH 标准参数，可能是拼写错或来自外部"

### 2.4 跨 skill 协作

| 场景 | 协作链 |
|---|---|
| 用户问 ed_wavelength 含义 | `flash-param-query`（基本属性）→ `flash-laser`（物理背景） |
| 用户问"这个参数对应的源码在哪" | `flash-param-query`（声明位置）→ `flash-source-reader`（实现细节） |
| 用户问"为什么这个参数导致 abort" | `flash-param-query`（参数本身）→ `flash-pitfall-finder`（abort 诊断） |

## 3. skills/flash-param-query/knowledge/param-index.md（核心参数索引）

手工维护的核心参数索引，覆盖 FLASH 高频参数（~150 条），按单元分章节。

**作用**：
- 高频查询的快速参考（不必每次扫所有 Config）
- 提供 Config 没明写的**单位**和**典型值**
- 提供**含义**和**陷阱**

**覆盖单元**：
- Driver（时间步、IO、模拟控制）
- Grid（AMR、几何、refinement）
- Hydro（CFL、求解器、限幅器）
- Eos（模式、表格）
- RadTrans（MGD、flux limiter）
- EnergyDeposition（激光，含全部 ed_*）
- Diffuse（扩散、HYPRE）
- materialProperties（电导率、不透明度）
- sourceTerms（Burn/Cool/Heat/Heatexchange）
- Multispecies / Particles / Gravity / IO

详见 `skills/flash-param-query/knowledge/param-index.md`。

## 4. 标准输出格式（按 L-010 精简：与 §2.1.1 合并）

输出格式已统一在 §2.1.1（精确查询）和 §2.1.2-2.1.4（前缀/单元/模糊查询）。

**前缀/单元查询**额外约束：按"单元 + 字母顺序"分组，每组给汇总表格：

```
**前缀 `ed_` 的所有参数** (来自 flash-laser knowledge/params.md)：

| 参数 | 类型 | 默认 | 单位 | 含义 |
|---|---|---|---|---|
| ed_numberOfBeams | INTEGER | -1 | — | 实际用几束 |
| ed_wavelength_<i> | REAL | -HUGE | μm | 波长 |
| ... | | | | |

共 N 条。详见 flash-laser/knowledge/params.md §X。
```

## 5. 关键命令模板

```bash
# 1. 精确查 Config 声明
find source -name Config -type f 2>/dev/null | xargs grep -n "^PARAMETER\s\+<name>" 2>/dev/null

# 2. 在 param-index 找
rg -n "<name>" skills/flash-param-query/knowledge/param-index.md

# 3. 在所有 skill 的 params.md 找
rg -n "<name>" skills/*/knowledge/params.md 2>/dev/null

# 4. 前缀查（如所有 rt_）
find source -name Config -type f 2>/dev/null | xargs grep -h "^PARAMETER\s\+rt_" 2>/dev/null | sort -u

# 5. 模糊查（按描述关键词）
find source -name Config -type f 2>/dev/null | xargs grep -i "^D\s\+.*<关键词>" 2>/dev/null

# 6. 提取所有参数名（建索引用）
find source -name Config -type f 2>/dev/null | xargs grep "^PARAMETER" 2>/dev/null | awk '{print $2}' | sort -u

# 7. 查 Flash.h 变量索引
rg -n "<NAME>_VAR" bin/Flash.h.tpl
```

## 6. 示例问答（验收基准）

### Q1: `ed_wavelength` 是什么参数？
**A**: REAL，默认 -HUGE(1.0)，单位 **μm**（不是 cm/nm！）。激光波长，决定临界密度 N_c。声明在 `source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/Config:296`。详见 `flash-laser/knowledge/params.md §4.1`。

### Q2: `rt_mgdFlMode` 怎么设？
**A**: STRING，默认未定。控制 MGD flux limiter 类型（"fl_harmonic" / "fl_geometric" / "fl_arithmetic" / ...）。声明在 `source/physics/RadTrans/RadTransMain/MGD/Config`。详见 `flash-radtrans` skill（Phase 2）。

### Q3: `ed_maxBeams` 是 runtime parameter 吗？
**A**: **不是**，是 **setup 变量**（编译期）。决定生成多少套 `ed_<prop>_<i>` 参数槽，默认 6。改它要重新 setup+make，不能在 parfile 改。

### Q4: `Courant` 参数怎么取？
**A**: 通常指 `hy_cfl`（CFL 数），REAL，默认 0.8。Hydro 求解器稳定性的核心参数。强激波算例建议 0.4-0.5。详见 `flash-hydro`（Phase 2）。

### Q5: 怎么列出激光单元所有参数？
**A**: `find source/physics/sourceTerms/EnergyDeposition -name Config -type f | xargs grep "^PARAMETER"` → 约 60+ 条（38 全局 + 动态生成的 ed_*_<i>）。详见 `flash-laser/knowledge/params.md`。

## 7. 待办

- [ ] 跑 5 道验收考题，全部通过则升级 stable
- [ ] 持续扩充 `skills/flash-param-query/knowledge/param-index.md`（每次遇到新参数补一条）
- [ ] 写 `skills/flash-param-query/tools/build_param_index.py` 自动扫描脚本（生成完整索引，含 2884+ 条）
- [ ] 跨 skill 协作验证（如 flash-laser 调用本 skill 查参数）

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（draft 骨架） | claude |
| 2026-07-12 | 升级 draft → beta：扩展 triggers（50+ 关键词含所有参数前缀）；§2 行为协议 4 种查询类型完整；建 skills/flash-param-query/knowledge/param-index.md（150+ 核心参数按单元分类）；含 5 道验收考题 | claude |
| 2026-07-19 | **按 L-010 精简**：§4 "标准输出格式" 收缩为引用 §2.1.1，避免重复；前缀/单元查询的分组表格约束保留 | claude |
| 2026-07-19 | **按 L-011 强化"默认值依据"**：§2.1.1 输出格式加必给段"默认值依据"——不只是给数字，要给"为什么默认这个值"；典型值段也要求"按场景给不同值并说明为什么"——flash-grid 验收反馈延伸 | claude |
