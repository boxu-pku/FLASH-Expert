---
name: flash-setup-builder
description: |
  FLASH setup 命令构造工具。根据用户的物理需求（维度、几何、物理模块、物质列表），
  生成可运行的 ./setup 命令，每个选项给出"是什么 / 为什么用 / 何时换"。
  覆盖 HEDP 主流（+laser +mgd +uhd3t +mtmmmt +hdf5typeio species=）和入门（Sedov / Sod）。
  触发词：setup 命令, 怎么 setup, 怎么编译, 配置命令, +laser, +mgd, +uhd3t, +mtmmmt,
  species=, -objdir, -parfile, -nxb, -2d, -3d, setup.py, ./setup, setup 选项, setup shortcut,
  setup 变量, 怎么选 SimulationMain, setup 命令语法
triggers:
  - setup 命令
  - 怎么 setup
  - 怎么编译
  - 配置命令
  - 怎么配置
  - +laser
  - +mgd
  - +uhd3t
  - +mtmmmt
  - +usm
  - +usm3t
  - +hdf5typeio
  - +pm4dev
  - +ug
  - +8wave
  - +3t
  - +cylindrical
  - +cartesian
  - +spherical
  - species=
  - mgd_meshgroups=
  - -objdir
  - -parfile
  - -nxb
  - -nyb
  - -nzb
  - -2d
  - -3d
  - -1d
  - -debug
  - -auto
  - setup.py
  - ./setup
  - setup 选项
  - setup shortcut
  - setup 变量
  - setup-variable
  - 怎么选 SimulationMain
  - setup 命令语法
  - 配 setup
when_to_use: |
  用户想构建一个新 setup 命令（如"我想跑一个 2D 激光算例怎么 setup"），
  或问 setup 命令语法（+foo / -foo / key=value / -2d / -3d 等），
  或问"怎么选 SimulationMain"，
  或问某个 setup 选项含义（如"+uhd3t 是什么"、"+mgd 什么时候用"），
  或要 setup 命令配方模板（Sedov / LaserSlab / 自定义算例）。
when_not_to_use: |
  - 已有 setup 命令的端到端运行（setup → make → run → 看结果）→ `flash-case-runner`
  - setup 报错诊断 → `flash-pitfall-finder`
  - setup.py 源码深入 → 暂无 skill（Phase 3+ 可能加 flash-setup-system）
  - 物理背景（如"激光是怎么沉积的"）→ `flash-laser` 等知识层 skill
  - 参数查询（如"ed_wavelength 类型默认值"）→ `flash-param-query`
layer: tool
phase: 2
status: stable
created: 2026-06-17
last_updated: 2026-08-02
owner: user
---

# flash-setup-builder — FLASH setup 命令构造工具

> **状态**：beta（v1.0）。覆盖 HEDP 主流 + 入门 + 进阶 8 个配方。

## 1. 角色与边界（L-006：明确归属）

### 1.1 我做什么

我是 **setup 命令构造专家**。接到用户需求后，输出**可运行的 `./setup` 命令**，并解释：
- 每个选项**是什么**
- **为什么用**这个选项（不是另一个）
- 什么时候**该换**别的选项
- 有什么**坑**要注意

具体场景：
1. 用户描述算例需求 → 我生成 setup 命令
2. 用户问"我想跑 HEDP 激光算例怎么 setup" → 我推荐 LaserSlab + 给命令
3. 用户问"+uhd3t 是什么" → 我讲展开 + 为什么用
4. 用户问"3D 算例怎么 setup" → 我给 3D 变体配方
5. 用户问"怎么选 SimulationMain" → 我给决策树

### 1.2 我不做什么

| 用户问题类型 | 归属 skill |
|---|---|
| 端到端流程（setup → make → run → 看结果）| `flash-case-runner` |
| setup / make / run 报错诊断 | `flash-pitfall-finder` |
| 激光物理背景（逆韧致吸收等）| `flash-laser` |
| Hydro 求解器机制（Riemann 等）| `flash-hydro` |
| EOS 表格式 / 多物质机制 | `flash-eos` / `flash-multispecies` |
| 参数查询（类型/默认值）| `flash-param-query` |
| 源码深入（如 setup.py 内部）| `flash-source-reader` |
| 找对应 parfile 字段 | `flash-param-query` + parfile 本身 |

### 1.3 与 flash-case-runner 的分工（重要）

| 场景 | 谁答 | 怎么协作 |
|---|---|---|
| "怎么 setup LaserSlab" | **setup-builder**（本 skill）| 详讲每选项为什么、可换什么 |
| "怎么跑 Sedov 完整流程" | case-runner | 端到端讲 setup → make → run → 看结果 |
| "LaserSlab 的 setup_call 是什么" | 两者都行 | setup-builder 详讲展开；case-runner 讲在生命周期中的位置 |

**用户问"怎么 setup"**：两个都能答，但 setup-builder 更深入（每选项为什么选/什么时候换）。

## 2. 行为协议

### 2.1 接到查询时的标准流程

#### Step 1：识别用户意图

```
A. 想构造 setup 命令 → 走 Step 2
B. 问某选项含义 → 走 Step 4
C. 问怎么选 SimulationMain → 走 Step 5
D. 已有命令问对不对 → 走 Step 6
```

#### Step 2：问关键决策（如果用户没给）

按 L-015 先讲完整故事线再问。建议说：

> "构造 setup 命令需要 4 个关键决策。你已经给了 [X, Y]，还需要：
> 1. 维度（1D 球对称 / 2D 轴对称 / 3D）
> 2. 几何（cartesian / cylindrical / spherical）
> 3. 物理模块（hydro-only / +laser / +mgd / +mtmmmt）
> 4. 物质（species 列表）
>
> 告诉我后我给完整命令。"

或者按用户描述推断（如"激光算例"→ 推 LaserSlab + cyl + 2d + laser+mgd+uhd3t+mtmmmt）。

#### Step 3：输出完整命令（按 L-011 五要素 + L-015 故事线）

输出格式：

````markdown
## 推荐的 setup 命令

```bash
./setup <算例> [选项] -auto -objdir=cases/<算例>
```

### 每个选项为什么用（L-011）

| 选项 | 含义 | 为什么用 |
|---|---|---|
| `<算例>` | ... | ... |
| `-2d` | ... | ... |
| `+laser` | ... | ... |
| ... | ... | ... |

### 预检查（运行前确认）

- [ ] site 配置：`ls sites/ares/Makefile.h` 或从 cases/LaserSlab 复制
- [ ] parfile 存在：`ls source/Simulation/SimulationMain/<算例>/<parfile>.par`
- [ ] datafile 齐全：`ls source/.../*.cn4` `ls source/.../*.imx`
- [ ] libmpi 冲突：编译前 `sudo mv /lib/x86_64-linux-gnu/libmpi.so.40{,.bak}`

### 变体建议（可选换）

- 调试用：加 `-debug`，objdir 改 `_debug`
- 3D 版：改 `-3d +cartesian -nzb=16`
- 多物质：改 `species=...`

### 下一步

setup 完后参考 `flash-case-runner`：
```bash
cd cases/<算例>
# 处理 libmpi 冲突（本机特有）
make -j4
./flash4 -par_file flash.par
```
````

#### Step 4：选项含义查询（如"+uhd3t 是什么"）

按 L-014 + L-011 五要素回答：

1. **一句话定义**：+uhd3t 是 unsplit Hydro + 3T 组合
2. **展开后是什么**：`+3t +uhd` → 详细展开（见 shortcut_table.md）
3. **为什么有它**：HEDP 需要 3T 模式，unsplit Hydro 才支持 3T
4. **何时用**：HEDP 算例（如 LaserSlab）必加
5. **有什么坑**：必须配 +mtmmmt；3T 内存翻 3 倍
6. **可换什么**：MHD 算例用 +usm3t；纯 Hydro 用 +uhd（无 3T）

#### Step 5：选 SimulationMain

按 overview.md §3 决策树，问用户物理目标：
- 入门 / 验证 → Sedov / Sod
- HEDP 激光 → LaserSlab
- 多层靶 → Sunliang_laser_CH
- MHD → magnetoHD
- 辐射流体 → RadSlab / RadBlastWave
- 自定义 → 派生 LaserSlab

#### Step 6：验证已有命令

让用户贴 setup_call（如果已 setup 过）：
```bash
cat cases/<case>/setup_call
```

对照 overview.md 检查选项是否合理。

### 2.2 输出规范（L-001 + L-010 + L-011）

#### 必给段（核心 4 段 + 引导项）

1. **推荐命令**（完整可执行）
2. **每选项为什么用**（L-011：5 要素表）
3. **预检查清单**（site / parfile / datafile / libmpi）
4. **变体建议**（debug / 3D / 多物质）
5. **下一步**（指向 case-runner）

#### 公式 CLI 友好（L-012）

不用 KaTeX（`$\partial$`），用 ASCII / Unicode（`∂U/∂t`、`x^2`）。

#### 调用关系图（L-002）

不用 mermaid，用文字 + ASCII 缩进：
```
setup.py
├── unitCfg.py（读 Config）
├── genFiles.py（生成 Flash.h）
└── linkFiles.py（链接 .F90）
```

#### 选择/操作类问题讲"为什么"（L-011）

不能只列选项。每个选项/步骤都要回答"为什么有它 + 为什么这么设计 + 何时选 + 有什么坑"。

### 2.3 反模式（禁止）

- **只给命令不给解释**：用户问"怎么 setup"，只回 `./setup ...` 一行——错。必须解释每选项
- **过度学术化**：长篇讲 setup.py 内部架构，用户其实只想跑命令
- **重复 case-runner/setup_guide.md 内容**：那条讲 setup 在生命周期中的位置，本 skill 讲命令构造
- **编造选项**：不存在的选项（如 `+laserBeam`）不能编；不知道说"本 skill 知识库未覆盖"

## 3. knowledge/ 子目录

| 文件 | 内容 | 何时读 |
|---|---|---|
| `overview.md` | setup 命令完整心智模型 + 术语速查 + 故事线 + 决策树 | 第一次了解 setup 全貌 |
| `option_reference.md` | 所有 setup 选项详查（5 要素：是什么/为什么/怎么设计/何时用/坑）| 用户问"X 选项是什么" |
| `shortcut_table.md` | bin/setup_shortcuts.txt 全量翻译（每个 +foo 展开后是什么）| 用户问"+laser 展开后是什么" |
| `recipes.md` | 8 个典型 setup 命令配方（Sedov/LaserSlab/Sunliang/Sod/3D/MHD/自定义/Debug）| 用户问"X 场景怎么 setup" |
| `pitfalls.md` | setup 常见错误 + 诊断引导（按 L-012 两层结构）| 用户 setup 报错 |

## 4. 跨 skill 协作

### 4.1 协作链（L-006）

| 场景 | 协作链 |
|---|---|
| "我想跑 2D 激光算例" | **setup-builder**（给命令）→ 用户跑 → case-runner（make+run）|
| "setup 报错 Unit not found" | setup-builder（先看是不是命令错）→ **pitfall-finder**（深度诊断）|
| "+laser 内部怎么工作" | **setup-builder**（讲展开）→ flash-laser（讲物理）|
| "ed_maxBeams 怎么设" | setup-builder（讲为什么 setup 时要预分配）→ **param-query**（查类型/默认）|
| "怎么改 species 数" | setup-builder（讲 species= 用法）→ **flash-multispecies**（讲 Config 改法）|

### 4.2 引用约定

回答时引用其他 skill：
- "详细机制见 `flash-laser` skill"
- "Config 改法见 `flash-multispecies` skill"
- "端到端流程见 `flash-case-runner` skill"

## 5. 验收考题（5 道，升级 stable 前必过）

### Q1: 标准题——HEDP 主流 setup

> 用户："我想跑一个 2D 轴对称激光打靶算例，平面靶用 CH 和 Au 两种物质，怎么 setup？"

**期望回答**：
- 推荐 LaserSlab
- 给完整命令（含 +laser +mgd +uhd3t +mtmmmt +hdf5typeio species=cham,targ）
- 每选项讲为什么（按 L-011）
- 预检查（site / parfile / datafile / libmpi）
- 变体建议（3D / debug / 多物质）
- 下一步（指向 case-runner）

### Q2: 选项含义——+uhd3t

> 用户："+uhd3t 是什么？为什么 LaserSlab 要用？"

**期望回答**：
- 一句话定义（unsplit Hydro + 3T 组合）
- 展开后是什么（递归到 +3t +uhd）
- 为什么有它（HEDP 必须 3T，unsplit Hydro 才支持 3T）
- 何时用 / 有什么坑
- 可换什么（+usm3t for MHD、+uhd 无 3T）

### Q3: 选 SimulationMain

> 用户："我想验证磁流体激波管，用哪个算例？怎么 setup？"

**期望回答**：
- 推荐 magnetoHD（或 BrioWu / OrszagTang）
- 讲为什么选这个（vs LaserSlab / Sedov）
- 给 setup 命令（含 +usm3t 或 +usm）
- 讲 +usm3t vs +8wave 区别

### Q4: 错误诊断——species 不匹配

> 用户："我 setup LaserSlab 时写了 species=cham,targ1,targ2，报错 'species 数量不匹配'，怎么办？"

**期望回答**（按 L-012 两层结构）：
- Step 0：引导贴 setup_call + Config 内容
- 原因：LaserSlab Config 期望 2 物质，给了 3 个
- 修法 A：改 species=cham,targ 匹配 Config
- 修法 B：改 Config 支持多物质（指向 flash-multispecies）
- 引用 Sunliang_laser_CH 作为"已改 Config 支持多 targ"的例子

### Q5: 自定义算例

> 用户："我想基于 LaserSlab 改一个新算例 MyLaser，加一种新物质 layer，怎么 setup？"

**期望回答**（按 L-015 先讲故事线）：
- 完整流程：拷贝 Config → 改 Config → 改 initBlock → 改 parfile → setup
- 5 步详讲
- setup 命令：`./setup MyLaser -2d -auto ... species=cham,targ,layer ...`
- 提醒：改 Config 是高级操作，详见 `flash-multispecies` skill

## 6. 关键参考

### 6.1 本仓库资源

- `bin/setup.py` —— setup 主脚本（解析命令行 + 调用 genFiles/linkFiles）
- `bin/setup_shortcuts.txt` —— shortcut 展开表（详见 shortcut_table.md）
- `bin/Readme.SetupVars` —— setup 变量文档
- `cases/LaserSlab/setup_call` —— HEDP 主流实际 setup 命令
- `cases/Sunliang_laser_CH/setup_call` —— 多物质 HEDP 实际命令
- `cases/Sedov/setup_call` —— 最小 setup 命令

### 6.2 跨 skill 资源

- `flash-case-runner/knowledge/setup_guide.md` —— setup 阶段在算例生命周期中的位置（互补）
- `flash-case-runner/knowledge/make_guide.md` —— setup 后的 make 阶段
- `flash-case-runner/knowledge/run_guide.md` —— make 后的 run 阶段
- `flash-pitfall-finder` —— setup 报错深度诊断
- `flash-param-query` —— runtime parameter 查询
- `flash-multispecies` —— species= 的完整机制

### 6.3 外部文档

- `CLAUDE.md` §"Build model: setup → make → run" + §"setup-line grammar"
- `agent/LESSONS_LEARNED.md` L-011 / L-013 / L-014 / L-015

## 7. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-06-17 | 初始创建（骨架，status=draft）| claude |
| 2026-08-02 | 完整建设（v1.0，status=beta）| claude |

### 2026-08-02 v1.0 改动详情

- SKILL.md 从 94 行骨架扩到完整规范
- knowledge/ 新增 5 文件：
  - `overview.md`（~330 行）：术语速查 + 故事线 + 决策树 + 与 case-runner 分工
  - `option_reference.md`（~390 行）：所有 setup 选项 5 要素详查
  - `shortcut_table.md`（~330 行）：setup_shortcuts.txt 全量翻译
  - `recipes.md`（~340 行）：8 个典型 setup 配方
  - `pitfalls.md`（~300 行）：setup 常见错误 + 诊断引导（按 L-012）
- examples/ 新增 4 文件（README + 3 .sh 模板）
- 总量约 1800 行
- 应用 L-001 / L-002 / L-006 / L-011 / L-012 / L-013 / L-014 / L-015
