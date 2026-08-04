# flash-source-reader snippets/

预读的常用函数代码片段库。**用户问这些函数时**，Agent 直接读 snippets/ 而不用每次重新 grep+read，加速响应。

## 文件清单

| 文件 | 函数 | 行数 |
|---|---|---|
| `driver-evolve-flash.md` | `Driver_evolveFlash`（主循环） | ~120 |
| `driver-source-terms.md` | `Driver_sourceTerms`（sourceTerms 调度） | ~90 |
| `grid-get-blk-ptr.md` | `Grid_getBlkPtr` / `Grid_releaseBlkPtr` | ~110 |
| `eos-wrapped.md` | `Eos_wrapped`（EOS 包装） | ~120 |
| `runtime-parameters-get.md` | `RuntimeParameters_get`（泛型接口） | ~100 |

## 每个 snippet 的标准结构

- frontmatter（status / 最后核对日期 / 源码版本）
- 定义位置（多实现/变体的完整表）
- 函数签名
- 工作机制 / 关键逻辑（代码片段 + 中文注释）
- 典型用法（来自真实源码）
- 常被问到的问题
- 相关条目（跨 snippet 和跨 skill 的链接）
- 变更日志

## 维护规则

- 每个片段顶部 `最后核对` 日期；超过 6 个月需要对照源码重审
- 源码大改后必须更新对应 snippet
- 添加新 snippet 时在此 README 表格追加

## 何时加新 snippet

当某个函数**被查询频率 ≥ 3 次/月**时，加进 snippets/。否则让 Agent 当场 grep+read。

候选片段（按可能优先级）：
- `Grid_fillGuardCells` — guard cell 填充（高频）
- `Grid_getBlkIndexLimits` — block 索引边界（高频）
- `Hydro` — 流体主入口（高频）
- `Eos_getData` / `Eos_putData` — EOS 数据收集/写回（中频）
- `Grid_getCellCoords` — 取 cell 坐标（中频）
- `Driver_computeDt` — 时间步计算（中频）
- `Opacity_getAbsorb` — 不透明度查询（低频）

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-12 | 初始创建（5 个核心 snippet + README） | claude |
