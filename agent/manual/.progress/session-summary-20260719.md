# FLASH 4.8 手册转写 — 状态总结

**日期**：2026-07-19  
**会话**：opencode-session-001  
**转写引擎**：opencode AI（flash-setup-builder / flash-* 多 skill）

---

## 1. 已完成的工作

采用 `agent/workflows/manual-conversion-handoff.md` 定义的 4 步流程（PDF 提取 → 源码对照 → 模板改写 → 自检归档），共计完成 **16 篇**知识条目转写。

### ★★★ 高优先级（6/6 完成）

| # | 章节 | 印刷页 | skill | 文件 |
|---|---|---|---|---|
| M2 | §18.4 Energy Deposition | 276-318 | flash-laser | `pending/18.4-energy-deposition-20260719.md` |
| M3 | §2 Quick Start | 17-25 | flash-setup-system | `pending/02-quick-start-20260719.md` |
| M4 | §3-5 Simulation Setup | 27-87 | flash-setup-system | `pending/03-05-simulation-setup-20260719.md` |
| M5 | §8 Grid Unit | 107-170 | flash-grid | `pending/08-grid-unit-20260719.md` |
| M6 | §17.4-17.6 Multitemp EOS | 253-260 | flash-eos | `pending/17.4-17.6-multitemp-eos-20260719.md` |
| M7 | §25 RadTrans/MGD | 389-396 | flash-radtrans | `pending/25-radtrans-mgd-20260719.md` |
| M8 | §14 3T HEDP | 213-216 | flash-eos | `pending/14-3t-hedp-20260719.md` |

### ★★ 中优先级（9 篇完成）

| # | 章节 | skill |
|---|---|---|
| M9 | §23 Material Properties | flash-material |
| M10 | §18.1 Burn | flash-sourceterms |
| M11 | §18.2 Ionization | flash-sourceterms |
| M12 | §18.3 Stir | flash-sourceterms |
| M13 | §18.5 Heatexchange | flash-sourceterms |
| M14 | §9 IO Unit | flash-io |
| M15 | §6 Flash.h File | flash-grid |
| M16 | §15.1 PPM + Unsplit Hydro | flash-hydro |

---

## 2. 当前状态

- **pending 目录**：`agent/drafts/pending/` 下 16 个 `.md` 文件
- **raw txt 保留**：各章节对应 `agent/manual/<chapter>/` 目录内含 raw txt
- **进度跟踪**：`agent/manual/.progress/00-master.md`（完整状态表）和 `00-toc.md`（结构化目录）
- **所有条目状态**：`status: draft`，**未经人工 review**

---

## 3. 重要发现

### 3.1 PDF 页码偏移

手册印刷页码与 PDF 页码之间有 **约 18 页的偏移**（前置封面/版权/目录）。handoff 给出的 `-f` 范围（如 `§18.4 -f 276`）实际对应印刷页 258 附近。转写中每个章节都通过 `pdftotext` 搜索标题来验证准确页码。

### 3.2 handoff 编号 vs 手册编号

handoff 使用的章节编号与手册实际编号有差异：
- handoff "§7 Grid Unit" → 手册 **§8** Grid Unit
- handoff "§15.4 PPM / §15.5 USM" → 手册 **§15.1 Gas hydrodynamics** 内部

### 3.3 源码锚点验证

每篇条目含 ≥3 个源码锚点（函数:行号，如 `EnergyDeposition.F90:45`），已通过 `sed` 逐行验证。关键差异记录在"已知陷阱"段。

### 3.4 互补声明

条目与 `.claude/skills/<skill>/knowledge/` 中的已有 beta 知识不重复，在 frontmatter 或首段加注互补声明。

---

## 4. 未完成的工作

### 4.1 未转写的章节

原 book 共 ~50 章。已覆盖约 16 章（含合并）。剩余：

**★★ 待转写**：§16 INS、§21 Particles、§18.6 Flame、§18.7 Turb、§18.8 Circuit  
**★ 低优先级**：§1 Intro、§4 Arch（部分含在 §3-5）、§7 Driver、§10 RPs、§11 Multispecies、§12 PhysConst、§13 Cpp/Python、§15.2-3 RHD/MHD、§17.1-3 basic EOS、§19 Diffuse、§20 PhysConst、§21-22、§24、§26-34、§35-43

### 4.2 待办事项

- [ ] **16 篇 pending 条目需人工 review**（GOVERNANCE §5.2 审核清单）
- [ ] raw txt 可清理（已确认无误后删除，节省空间）
- [ ] PDF 页码偏移记录需统一到 `00-toc.md` 的备注列
- [ ] 源码锚点版本锁定（当前验证基于 v4.8，升级时需重验）

---

## 5. 关键数字

| 指标 | 值 |
|---|---|
| PDF 提取页数 | ~150 页 |
| 源码锚点验证数 | ~100 个 |
| raw txt 行数 | ~15,000 行 |
| 知识条目总行数 | ~4,000 行 |
| 新手册目录数 | 13 个（`agent/manual/<chapter>/`） |

---

## 6. 审查指引

如需 review 某篇条目，建议按以下顺序：

1. 读 `agent/workflows/manual-conversion-handoff.md` §0（7 份前置文件要求）
2. 读 `agent/TEMPLATES/knowledge-entry.md`（格式模板）
3. 读 `agent/GOVERNANCE.md` §5（审核清单）
4. 抽检 1-2 篇 pending 条目

示例抽检命令：
```bash
# 验证前 10 行 frontmatter
head -12 agent/drafts/pending/18.4-energy-deposition-20260719.md

# 验证源码锚点（以行号 45 为例）
sed -n '43,47p' source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/EnergyDeposition.F90

# 验证公式格式（KaTeX）
grep -c '\$\$' agent/drafts/pending/25-radtrans-mgd-20260719.md

# 检查无 ≥3 行连续原文
grep -c '^[a-z].*[a-z]$' agent/drafts/pending/02-quick-start-20260719.md | head -3
```
