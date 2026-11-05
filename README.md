# FLASH-Expert — FLASH 4.8 AI 专家 Agent 系统

> 多 harness 通用的多 skill 架构（Claude Code / ZCode / DSH / Codex CLI），为 FLASH 4.8 用户提供**物理问答、算例运行、结果分析**的一站式 AI 辅助。
>
> 项目路径：`/path/to/FLASH4.8/`（你的 FLASH 安装目录）

---

## 1. 这是什么

FLASH-Expert 是一套**文件化的 AI 知识库系统**，由 18 个专门 skill 组成，覆盖 FLASH 4.8 的全部核心单元。Claude Code 自动根据你的问题匹配 skill，给出**带源码锚点、带为什么、带诊断流程**的专业回答。

**它不是**：一个需要联网的 Web 服务、一个 RAG 数据库、一个需要训练的模型。

**它是**：一组精心组织的 markdown 知识文件，真身在 `skills/` 目录下，用 `./install.sh` 挂载到各 harness 的 skills 目录，agent 启动时自动加载。

---

## 2. 包含什么

### 知识层（11 个）— 回答"FLASH 怎么工作"

| Skill | 覆盖单元 | 行数 |
|---|---|---|
| `flash-laser` | 激光（EnergyDeposition）| ~2900 |
| `flash-driver` | 主循环（Driver_evolveFlash）| ~2600 |
| `flash-grid` | 网格 / AMR / 几何 | ~2850 |
| `flash-hydro` | 流体（Hydro split/unsplit）| ~2700 |
| `flash-eos` | 状态方程（Helmholtz / 3T）| ~2750 |
| `flash-radtrans` | 辐射传输（MGD 多群扩散）| ~2400 |
| `flash-sourceterms` | 源项（Heatexchange 等）| ~2200 |
| `flash-material` | 物质属性（Conductivity / Opacity）| ~3300 |
| `flash-io` | IO（HDF5 plotfile / checkpoint）| ~3600 |
| `flash-diffuse` | 隐式扩散（HYPRE）| ~3300 |
| `flash-multispecies` | 多物质追踪 | ~3400 |

### 工具层（5 个）— 跨单元查询工具

| Skill | 功能 |
|---|---|
| `flash-source-reader` | 源码定位 + 中文解释（不只是 grep） |
| `flash-pitfall-finder` | 错误信息 → 踩坑匹配 + 修复步骤 |
| `flash-param-query` | 参数字典（跨单元查定义/默认值/单位） |
| `flash-manual-search` | 官方手册检索（31 篇已转写） |
| `flash-setup-builder` | setup 命令生成器 |

### 操作层（2 个）— 端到端操作

| Skill | 功能 |
|---|---|
| `flash-case-runner` | setup → make → run → 诊断 |
| `flash-result-analyzer` | 结果分析（能量守恒 / 激光吸收率 / yt 可视化） |

### 配套知识资产（已收编进对应 skill，随包分发）

| 内容 | 说明 |
|---|---|
| 20 条经验沉淀（L-001~L-020，`agent/LESSONS_LEARNED.md`） | 项目建设过程中的设计经验，指导 skill 回答风格 |
| 19 条报错库（`skills/flash-pitfall-finder/knowledge/pitfalls/`） | 实战踩坑：libmpi 冲突 / EOS 不收敛 / species 命名 / X 射线诊断配置等 |
| 31 篇手册转写（`skills/flash-manual-search/knowledge/manual/`） | FLASH 4.8 用户手册全本转写（661 页 → markdown） |
| 参数索引（`skills/flash-param-query/knowledge/param-index.md`） | 150+ 核心参数按 12 单元分类 |
| 工具脚本 | `promote_draft.sh`（草稿审核）/ `flash_env.sh`（运行环境配置） |

---

## 3. 安装指南

### 前提条件

| 条件 | 说明 |
|---|---|
| FLASH 4.8 | 已编译安装（含 mpich / hdf5 / hypre） |
| Claude Code | 已安装（`npm install -g @anthropic-ai/claude-code`） |
| Python 3 + yt | 用于结果可视化（`pip install yt matplotlib`） |

> **FLASH 安装教程**：如果你还没有安装 FLASH，可以参考笔者写的详细安装指南（以 FLASH 4.6.2 为例，4.8 安装步骤类似）：
> [FLASH 4.6.2 安装教程（知乎）](https://zhuanlan.zhihu.com/p/1936822984418496779)
>
> 涵盖：mpich 编译、HDF5 编译、HYPRE 编译、Makefile.h 配置、libmpi 冲突处理等完整流程。

### 安装步骤

```bash
# 1. clone 本仓库（放在任意位置，如 ~/tools/）
git clone git@github.com:boxu-pku/FLASH-Expert.git
cd FLASH-Expert

# 2. 安装 skill（符号链接模式，默认装 claude + zcode + agents 三个 harness）
./install.sh                                      # 用户级：~/.claude/skills 等
./install.sh --harness claude,agents              # 只装部分 harness
./install.sh --scope project --project /path/to/FLASH4.8    # 项目级：装进 FLASH 仓库
./install.sh --copy                               # 复制模式（Windows / 不支持符号链接时）

# harness → 目录映射：claude→.claude（Claude Code）、zcode→.zcode（ZCode）、
# agents→.agents（Agent Skills 跨 harness 标准目录，DSH / Codex CLI 等都读这里）、dsh→.dsh

# 3. 配置 FLASH 项目的运行环境（可选，跑算例需要）
cp flash_env.sh /path/to/FLASH4.8/
vim /path/to/FLASH4.8/flash_env.sh
# 改这 3 行路径为你自己的 mpich / hdf5 / hypre 安装位置：
#   FLASH_LIBS=/your/path/to/libs
#   MPI_PATH=$FLASH_LIBS/mpich
#   HDF5_PATH=$FLASH_LIBS/hdf5
#   HYPRE_PATH=$FLASH_LIBS/hypre

# 4. （可选，项目级安装时）把行为协议和治理工作台也放进 FLASH 项目
cp AGENTS.md /path/to/FLASH4.8/          # skill 调用规则（Claude Code 用户复制 CLAUDE.md）
cp -r agent/  /path/to/FLASH4.8/         # 经验沉淀 / 踩坑流程 / 模板（完整工作台）

# 5. 在 FLASH 项目目录启动你的 harness
cd /path/to/FLASH4.8/
claude        # 或 zcode / dsh 等
```

启动后 harness 自动加载 18 个 skill（靠 SKILL.md 的 description 匹配你的问题），你可以直接提问。

> **符号链接模式的好处**：以后 `git pull` 更新本仓库，所有 harness 里的 skill 立即生效，无需重装。
> **卸载**：`./install.sh --uninstall`（只移除本包安装的链接/副本，不动你自己的 skill）。
> **交叉引用说明**：skill 文本里 `skills/<skill>/...` 形式的路径相对开发仓库根；安装到其它环境后对应 flash-<skill> 内的同名文件（如 `skills/flash-pitfall-finder/knowledge/pitfalls/x.md` → flash-pitfall-finder skill 的 `knowledge/pitfalls/x.md`）。`agent/...`（治理工作台）和原 PDF 不随包分发，外部环境按 skill 内标注的 fallback 处理。

---

## 4. 使用指南

### 4.1 问物理问题

直接用自然语言提问，Claude 会自动匹配 skill：

```
> 激光波长改成 0.351 μm 怎么改？
  → flash-laser

> Riemann solver 选哪个？
  → flash-hydro

> rt_mgdFlMode 默认是什么？为什么？
  → flash-radtrans

> 电子和离子温度怎么平衡的？
  → flash-sourceterms
```

### 4.2 跑算例

```
> 帮我跑一个 Sedov 算例
  → flash-case-runner（自动 setup → make → run）

> LaserSlab 编译报 libmpi 冲突怎么办？
  → flash-pitfall-finder（匹配 skills/flash-pitfall-finder/knowledge/pitfalls/libmpi-conflict.md）

> 从 checkpoint 续跑
  → flash-case-runner（restart 流程）
```

### 4.3 分析结果

```
> 跑完了，帮我看看密度分布
  → flash-result-analyzer（用 yt 画图）

> 激光吸收率怎么算？
  → flash-result-analyzer（读 LaserEnergyProfile.dat）

> 能量守恒吗？
  → flash-result-analyzer（检查 .dat 文件）
```

### 4.4 每次跑算例前

```bash
source flash_env.sh    # 配置 MPI 环境（解决 libmpi 冲突）
```

---

## 5. 快速验证安装

安装后，用以下问题测试 skill 是否正常工作：

| 测试问题 | 应触发 skill |
|---|---|
| "什么是 leaf block？" | flash-grid |
| "dens_ie 和 dens_temp 区别？" | flash-eos |
| "HYPRE 是什么？" | flash-diffuse |
| "ed_wavelength 是什么参数？" | flash-param-query / flash-laser |

如果 Claude 没用 skill 直接从主上下文答，提醒：

```
> 请优先调用对应的 flash-* skill（见 CLAUDE.md）
```

---

## 6. 运行环境配置（`flash_env.sh`）

本机（ares）的 MPI 库冲突问题已内置解决方案。每次跑算例前：

```bash
source flash_env.sh
```

它做了 3 件事：
1. `PATH`：mpich/bin 放最前 → mpirun 用 mpich 的
2. `LD_LIBRARY_PATH`：mpich/hdf5/hypre/lib 优先
3. `LD_PRELOAD`：强制最先加载 mpich 的 libmpi → 杜绝 libmpi.so.40 冲突

**换机器后需要改**：`FLASH_LIBS` 路径指向你的库安装位置。

---

## 7. skill 架构

真身只有一份，各 harness 通过符号链接挂载（`.claude/skills`、`.zcode/skills`、`.agents/skills` 均指向 `skills/`）：

```
skills/                        ← 真身（install.sh 的安装源）
├── flash-laser/           知识层
│   ├── SKILL.md           触发词 + 行为协议 + 验收考题
│   ├── knowledge/
│   │   ├── overview.md    物理原理 + 设计动机
│   │   ├── params.md      参数字典
│   │   ├── internals.md   调用图 + 源码流程
│   │   ├── recipes.md     典型配置
│   │   └── pitfalls.md    单元内踩坑
│   └── examples/          可抄的 parfile 片段
│
├── flash-driver/
├── flash-grid/
├── ...（共 11 个知识层）
│
├── flash-source-reader/   工具层
├── flash-pitfall-finder/
├── ...（共 5 个工具层）
│
├── flash-case-runner/     操作层
└── flash-result-analyzer/

.claude/skills -> ../skills   （Claude Code）
.zcode/skills -> ../skills    （ZCode）
.agents/skills -> ../skills   （DSH / Codex CLI 等，Agent Skills 标准目录）
```

每个 skill 自包含——有自己的 knowledge/ + examples/，不依赖其他 skill 的内部文件。

---

## 8. 项目统计

| 指标 | 值 |
|---|---|
| 总 skill 数 | 18 |
| 总文件数 | 207（skills/ 目录）
| 总行数 | ~48,000（skills/ 目录 md）
| 经验沉淀 | 20 条（L-001~L-020）
| 报错库 | 19 条跨领域踩坑（随 flash-pitfall-finder 分发）|
| 手册转写 | 31 篇（覆盖 661 页，随 flash-manual-search 分发）|
| 实战验证 | 4 个算例（LaserSlab 4.6.2/4.8 + Sunliang_laser_CH + Sunliang_Xray） |
| 验收考题 | 75 道全部通过 |

---

## 9. 更新方式

本仓库会持续更新（新增踩坑、优化 skill、补充手册章节）。获取最新版：

```bash
cd /path/to/FLASH-Expert/
git pull
```

符号链接模式下所有 harness 立即生效；`--copy` 模式安装的需重新运行 `./install.sh`。

---

## 10. 联系

- 仓库：[FLASH-Expert](https://github.com/boxu-pku/FLASH-Expert)
- 问题反馈：GitHub Issues

---

## License

仅供学术研究使用。FLASH 4.8 本身遵循 [FLASH Code License](https://flash.uchicago.edu/site/license/)。
