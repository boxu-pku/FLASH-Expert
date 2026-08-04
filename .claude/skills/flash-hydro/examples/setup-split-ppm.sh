#!/bin/bash
# ============================================================
# FLASH 4.8 Hydro backend = split PPM setup 命令模板
# ============================================================
# 对应知识库：.claude/skills/flash-hydro/knowledge/recipes.md §1.3
#
# 适用：燃烧 / 火焰算例（SN Ia、XRB、detonation）
#       或从 FLASH 2/3 移植的旧算例
#
# 注意：新算例如不需要燃烧，仍推荐 unsplit（默认）
# ============================================================

# ===== 燃烧算例 =====
./setup <problem> -2d -auto +cartesian +splitHydro +flame +burn \
    -nxb=8 -nyb=8 \
    -objdir=cases/<problem>_flame

# ===== 8-wave MHD（旧 MHD 算例移植）=====
./setup <problem> -3d -auto +cartesian +8wave \
    -nxb=8 -nyb=8 -nzb=8 \
    -objdir=cases/<problem>_8w

# ============================================================
# 参数说明：
#   +splitHydro   Split PPM（Strang 维度分裂 + PPM 重构）
#   +8wave        Powell 8-wave MHD（split）
#   +flame        火焰 sourceTerm
#   +burn         燃烧 sourceTerm
# ============================================================

# 验证：
# cat cases/<case>/setup_call | grep -E "\+splitHydro|\+8wave"

# 关键 parfile 配置（split PPM 燃烧）：
# cfl = 0.5
# RiemannSolver = "HLLC"     # split 也用 RiemannSolver 参数
# nriem = 10                  # PPM 迭代 Riemann 次数
# cvisc = 0.1                 # 人工粘性
