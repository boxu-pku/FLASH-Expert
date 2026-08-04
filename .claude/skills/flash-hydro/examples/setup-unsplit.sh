#!/bin/bash
# ============================================================
# FLASH 4.8 Hydro backend = unsplit pure hydro（默认）setup 命令模板
# ============================================================
# 对应知识库：.claude/skills/flash-hydro/knowledge/recipes.md §1.1
#
# 适用：99% 流体算例（激波管、ICF、激光沉积、外爆）
# 不写 +uhd 也是 unsplit（默认），写了更明确
# ============================================================

# ===== Sedov 爆炸（2D 直角，标准测试）=====
./setup Sedov -2d -auto +cartesian +uhd \
    -nxb=8 -nyb=8 \
    -objdir=cases/Sedov

# ===== 激光算例（2D 柱坐标 R-Z）=====
./setup LaserSlab -2d -auto +cylindrical +uhd \
    +laser +mgd +uhd3t \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab

# ===== 3D ICF 直角 =====
./setup <problem> -3d -auto +cartesian +uhd \
    -nxb=16 -nyb=16 -nzb=16 \
    -objdir=cases/<problem>_3d

# ============================================================
# 参数说明：
#   +uhd / +unsplitHydro   Unsplit Hydro_Unsplit（默认）
#   -2d / -3d              维度
#   +cartesian 等          几何
#   +laser +mgd +uhd3t     其他 setup 变量（按算例需求）
#   -nxb=N -nyb=N -nzb=N   每 block cell 数（默认 8）
# ============================================================

# 验证实际变体：
# cat cases/<case>/setup_call | grep -E "\+uhd|\+usm|\+split|\+8wave"
# 应该看到 +uhd（或什么都没有，默认就是 unsplit）
