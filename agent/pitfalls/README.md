# agent/pitfalls/ — 跨领域踩坑库

存放**不属于任何单一单元**的踩坑条目。每条按"错误信息 → 原因 → 修复 → 预防"四段式组织。

## 文件清单

| 文件 | 错误类别 | 状态 |
|---|---|---|
| `libmpi-conflict.md` | 编译/链接（本机特定） | stable |
| `site-not-found.md` | setup 期 | beta |
| `setup-unit-not-found.md` | setup 期 | beta |
| `ffpe-trap-and-nan.md` | 运行期数值 | beta |
| `mpi-errors.md` | 运行期 MPI | beta |
| `restart-incompatibility.md` | 运行期 restart | beta |
| `eos-newton-convergence.md` | 运行期 EOS 不收敛（实战） | stable |
| `species-name-and-hdf5.md` | species 命名 + HDF5 + parfile 一致性（实战） | stable |
| `xray-imaging-setup.md` | X 射线诊断模块配置陷阱（实战） | stable |
| `missing-datafiles.md` | Config DATAFILES 声明遗漏（实战） | stable |
| `negative-3t-internal-energy.md` | 3T 内能变负（ICF 启动数值崩溃） | stable |
| `h5py-flash-plotfile-index-order.md` | h5py 直接读 plotfile 索引错位（后处理） | stable |
| `mpi-romio-null-comm-allreduce.md` | 长跑后 ROMIO 集合写 Allreduce on MPI_COMM_NULL（实战） | beta |
| `restart-plotfilenumber-overwrite.md` | restart 未设 plotFileNumber → 覆盖旧 plotfile（实战） | stable |
| `plotfile-interval-too-dense.md` | plotFileIntervalTime < dt → 每步一个 plotfile（实战） | stable |
| `restart-skeleton-plotfiles.md` | restart 后定时 plotfile 是空壳（无物理场数据集）（实战） | beta |
| `parfile-flag-ignored.md` | flash4 的 -parfile=X 静默忽略（正确：-par_file X）（实战） | stable |

## 与单元内 pitfalls 的关系

| 类型 | 位置 | 内容 |
|---|---|---|
| **跨领域踩坑**（本目录） | `agent/pitfalls/` | 编译、链接、setup、MPI、本机特定、数值通用问题 |
| **单元内踩坑** | `.claude/skills/flash-<unit>/knowledge/pitfalls.md` | 该单元特定的 abort、参数陷阱、概念错误 |

`flash-pitfall-finder` skill 会**同时搜两处**：
```bash
rg -i '<关键词>' agent/pitfalls/ .claude/skills/*/knowledge/pitfalls.md
```

## 单元内踩坑库现状

| skill | 文件 | 条目数 |
|---|---|---|
| `flash-laser` | `knowledge/pitfalls.md` | 12 条 |
| 其他 skill | 待 Phase 2+ | — |

## 标准条目格式

每条踩坑用以下 frontmatter：

```yaml
---
title: <一句话标题>
category: 编译期 | setup 期 | 运行期 | restart | MPI | 数值 | 本机特定
severity: warning | fatal | cosmetic
first_seen: YYYY-MM-DD
last_verified: YYYY-MM-DD
verifier: <用户名 or agent>
status: draft | beta | stable
tags:
  - <关键词1>
  - <关键词2>
---
```

正文 6 段：
1. **错误信息**（含多种形式）
2. **原因**（详细解释 + 源码机制）
3. **修复**（多种方案，标注推荐）
4. **源码锚点**
5. **预防**
6. **延伸**（相关条目）

## 维护规则

- **每次遇到新 abort**：按 D-004 决策（agent 自动扩写 + 用户审核）生成新草稿到 `agent/drafts/pending/`，审核通过后 promote 到本目录
- **last_verified 每 6 个月重审**：对照源码核对
- **跨领域 vs 单元**：决定位置——能放单元内的尽量放单元内（更精准），跨多个单元的才放这里

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-12 | 初始创建（6 条跨领域踩坑 + README） | claude |
| 2026-08-03 | 加 4 条实战踩坑：EOS Newton 不收敛 + species 名/HDF5 + X 射线诊断配置 + DATAFILES 遗漏（来自 Sunliang_laser_CH / Sunliang_Xray 实战调试） | claude |
| 2026-08-10 | 加 3 条实战踩坑：ROMIO 集合写 NULL comm 崩溃（MPI-IO 层，含完整取证链）+ restart 覆盖旧 plotfile（plotFileNumber 未设）+ plotfile 间隔过密（IO 频率配置）—— Sunliang_Xray 崩溃排查 + 续跑实战 | claude |
| 2026-08-10 | 加 restart-skeleton-plotfiles.md（restart 后定时 plotfile 空壳）—— 可视化实战中发现；同时修正 restart-plotfilenumber-overwrite.md 覆盖数 22→70 | claude |
| 2026-08-11 | 加 parfile-flag-ignored.md（-parfile=X 静默忽略，正确是 -par_file X，源码 RuntimeParameters_init.F90:86）—— X 光重放验证跑抓出；全库 62 处错误写法（含 CLAUDE.md + 7 个 skill）修正 | claude |
