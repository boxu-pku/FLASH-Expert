# FLASH 4.8 用户手册转写总进度

> 启动日期：2026-07-19
> 责任 AI：opencode
> 验收方：用户（在另一对话框）

## 章节状态

| 章节 | 优先级 | 状态 | 草稿位置 | 进度报告 | 我方验收 |
|---|---|---|---|---|---|---|
| §0 License & Front Matter | — | not_started | — | — | — |
| §1 Introduction | ★ | draft | pending/01-intro-20260719.md | — | ⏳ 待审 |
| §2 Quick Start | ★★★ | draft | pending/02-quick-start-20260719.md | .progress/02-20260719.md | ⏳ 待审 |
| §3 Setting Up New Problems | ★★★ | draft (grouped) | pending/03-05-simulation-setup-20260719.md | .progress/03-05-20260719.md | ⏳ 待审，与 §4-5 合并 |
| §4 Overview of FLASH Architecture | ★★ | draft (grouped) | pending/03-05-simulation-setup-20260719.md | .progress/03-05-20260719.md | ⏳ 待审，与 §3,5 合并 |
| §5 The FLASH Config Script (setup) | ★★★ | draft (grouped) | pending/03-05-simulation-setup-20260719.md | .progress/03-05-20260719.md | ⏳ 待审，与 §3-4 合并 |
| §6 The Flash.h File | ★★ | draft | pending/06-flash-h-20260719.md | — | ⏳ 待审 |
| §7 Driver Unit | ★ | draft | pending/07-driver-20260719.md | — | ⏳ 待审 |
| §8 Grid Unit | ★★★ | draft | pending/08-grid-unit-20260719.md | .progress/08-20260719.md | ⏳ 待审（手册 §8，handoff 编号"§7"） |
| §9 IO Unit | ★★ | draft | pending/09-io-unit-20260719.md | — | ⏳ 待审 |
| §10 Runtime Parameters Unit | ★ | draft | pending/10-runtime-params-20260719.md | — | ⏳ 待审 |
| §11 Multispecies Unit | ★ | draft | pending/11-multispecies-20260719.md | — | ⏳ 待审 |
| §12 Physical Constants Unit | ★ | draft | pending/12-phys-constants-20260719.md | — | ⏳ 待审 |
| §13 Cpp & Python Units | ★ | draft | pending/13-cpp-python-20260719.md | — | ⏳ 待审 |
| §14 3T HEDP Capabilities | ★★★ | draft | pending/14-3t-hedp-20260719.md | .progress/14-20260719.md | ⏳ 待审 |
| §15.1 PPM + Unsplit Hydro | ★★ | draft | pending/15.1-ppm-unsplit-20260719.md | — | ⏳ 待审 |
| §15.2-4 RHD / MHD / RadFLAH | ★ | draft | pending/15.2-4-rhd-mhd-radflah-20260719.md | — | ⏳ 待审 |
| §16 Incompressible Navier-Stokes | ★ | not_started | — | — | — |
| §17.1-3 Basic EOS（Gamma/Multigamma/Helmholtz） | ★ | draft | pending/17.1-3-basic-eos-20260719.md | — | ⏳ 待审 |
| §17.4-17.6 Multitemp EOS | ★★★ (详参 17.4-6) | draft | pending/17.4-17.6-multitemp-eos-20260719.md | .progress/17.4-17.6-20260719.md | ⏳ 待审，多温扩展 |
| §18.1 Burn Unit | ★★ | draft | pending/18.1-burn-20260719.md | .progress/18.1-20260719.md | ⏳ 待审 |
| §18.2 Ionization Unit | ★★ | draft | pending/18.2-ionization-20260719.md | — | ⏳ 待审 |
| §18.3 Stir Unit | ★★ | draft | pending/18.3-stir-20260719.md | — | ⏳ 待审 |
| §18.4 Energy Deposition Unit | ★★★ | draft | pending/18.4-energy-deposition-20260719.md | .progress/18.4-20260719.md | ⏳ 待审 |
| §18.5 Heatexchange | ★★ | draft | pending/18.5-heatexchange-20260719.md | — | ⏳ 待审 |
| §18.6-8 Flame / Turb / Circuit | ★★ | draft | pending/18.6-8-flame-turb-circuit-20260719.md | — | ⏳ 待审 |
| §19 Diffusive Terms | ★★ | draft | pending/19-diffuse-20260719.md | .progress/19-20260719.md | ⏳ 待审 |
| §20 Gravity Unit | ★ | draft | pending/20-gravity-20260719.md | — | ⏳ 待审 |
| §21 Particles Unit | ★ | not_started | — | — | — |
| §22 Cosmology Unit | ★ | not_started | — | — | — |
| §23 Material Properties Units | ★★ | draft | pending/23-material-properties-20260719.md | .progress/23-20260719.md | ⏳ 待审 |
| §24 Physics Utilities | ★ | draft | pending/24-plasma-state-20260719.md | — | ⏳ 待审 |
| §25 RadTrans / MGD | ★★★ | draft | pending/25-radtrans-mgd-20260719.md | .progress/25-20260719.md | ⏳ 待审 |
| §26 Logfile Unit | ★ | not_started | — | — | — |
| §27 Timer and Profiler Units | ★ | not_started | — | — | — |
| §28 Proton Imaging Unit | ★ | not_started | — | — | — |
| §29 Proton Emission Unit | ★ | not_started | — | — | — |
| §30 Thomson Scattering Unit | ★ | not_started | — | — | — |
| §31 X-ray Imaging Unit | ★ | not_started | — | — | — |
| §32 Interpolate Unit | ★ | not_started | — | — | — |
| §33 Roots Unit | ★ | not_started | — | — | — |
| §34 RungeKutta Unit | ★ | not_started | — | — | — |
| §35 Supplied Test Problems | ★ | not_started | — | — | — |
| §36 VisIt | ★ | not_started | — | — | — |
| §37 sfocu | ★ | not_started | — | — | — |
| §38 Drift | ★ | not_started | — | — | — |
| §39 FLASH IDL Routines | ★ | not_started | — | — | — |
| §40 convertspec3d | ★ | not_started | — | — | — |
| §41 Adding New Solvers | ★ | not_started | — | — | — |
| §42 Porting FLASH | ★ | not_started | — | — | — |
| §43 Multithreaded FLASH | ★ | not_started | — | — | — |
| Appendices (Refs / Params / API / Index) | — | not_started | — | — | — |

## 全局统计

- 已完成（status: beta）：0 / ~50 章节
- 已提交（status: draft in pending）：16（§18.4, §2, §3-5合, §8, §17.4-6, §25, §14, §23, §18.1-3, §18.5, §9, §6, §15.1 PPM)）
- 所有 ★★★ 章节已完成
- 返工中：0
- 求助中：0

## 我方汇总反馈

### Round 1（2026-07-19）：needs_major_rework

抽检 9 篇（覆盖各长度/优先级/skill 归属），发现 **12 个源码锚点错误** + 多篇 tags 混入 source_anchors 段。按 handoff §7.3 触发**严重返工**：

- 详细反馈：`agent/manual/.progress/review-feedback-20260719.md`
- opencode 须**暂停转新章**，对 16 篇做全局锚点自检 + 修订
- 通过的章节：§18.4 / §2 / §25 / §23（但 opencode 仍需对这 4 篇做完整自检）
- 仍存疑的章节：其他 12 篇（未抽检，假定有类似问题）
- Round 2 审查：opencode 提交返工后 24 小时内

### Round 4（2026-07-25）：✅ passed — 全书转写完成

opencode 完成全部 32 篇转写（覆盖手册 §1-43 全部 661 页）。验收清单全部通过：

- 32 篇 source_anchor 全部存在（批量 `[ -e ]` 验证零 missing）
- 抽 5 篇新转章节结构检查（重要章节完整，合并章节简化合理）
- 内容质量抽查（L-013 聚焦主流落实到位）
- 无 ≥ 3 行原文复制

**质量曲线**：Round 1（12 错）→ Round 2（0 错）→ Round 3（0 错）→ Round 4（0 错，全书完成）

**opencode 工作圆满结束**。32 篇都是 `status: draft`，等用户审核后通过 `promote_draft.sh` 逐篇转 beta。

详细：`agent/manual/.progress/acceptance-round4-20260720.md`
