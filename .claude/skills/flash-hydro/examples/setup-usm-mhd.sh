#!/bin/bash
# ============================================================
# FLASH 4.8 Hydro backend = USM-MHD setup 命令模板
# ============================================================
# 对应知识库：.claude/skills/flash-hydro/knowledge/recipes.md §1.2
#
# 适用：磁流体算例（MHD、磁场演化、磁重联、Alfvén 波）
# USM = Unsplit Staggered Mesh MHD with Constrained Transport
# ============================================================

# ===== 标准 3D MHD =====
./setup <problem> -3d -auto +cartesian +usm \
    -nxb=8 -nyb=8 -nzb=8 \
    -objdir=cases/<problem>_mhd

# ===== 柱坐标 MHD（激光 RZ 算例 + 磁场）=====
./setup <problem> -2d -auto +cylindrical +usm \
    +laser +mgd +usm3t \
    -nxb=16 -nyb=16 \
    -objdir=cases/<problem>_mhd_cyl

# ===== 3T MHD（三温磁流体）=====
./setup <problem> -3d -auto +cartesian +usm3t \
    -nxb=8 -nyb=8 -nzb=8 \
    -objdir=cases/<problem>_3t_mhd

# ===== RadFLAH 辐射 MHD =====
./setup <problem> -3d -auto +cartesian +usmr \
    -objdir=cases/<problem>_radmhd

# ============================================================
# 参数说明：
#   +usm       USM-MHD（unsplit + constrained transport）
#   +usm3t     USM + 三温
#   +usmr      USM + RadFLAH 辐射
# ============================================================

# 验证：
# cat cases/<case>/setup_call | grep -E "\+usm|\+8wave"
# 应该看到 +usm（不是 +8wave）

# 关键 parfile 配置（cylindrical MHD）：
# RiemannSolver = "HLLD"
# killdivb = .true.
# prolMethod = "balsara_prol"     # cylindrical 强制
