#!/bin/bash
# ============================================================
# FLASH 4.8 Grid backend = Paramesh 4 dev (默认) setup 命令模板
# ============================================================
# 对应知识库：.claude/skills/flash-grid/knowledge/recipes.md §1.1
#
# 适用：99% 算例（AMR 激光、激波管、ICF、燃烧、MHD）
# 不写 +pm4dev 也是它（默认），写了更明确
# ============================================================

# ===== 激光算例（2D 柱坐标 R-Z 平面）=====
./setup LaserSlab -2d -auto +cylindrical +pm4dev \
    +laser +mgd +uhd3t \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab

# ===== Sedov 爆炸（2D 直角）=====
./setup Sedov -2d -auto +cartesian +pm4dev \
    -nxb=8 -nyb=8 \
    -objdir=cases/Sedov

# ===== 3D ICF（球坐标）=====
./setup <problem> -3d -auto +spherical +pm4dev \
    -nxb=16 -nyb=16 -nzb=16 \
    -objdir=cases/<problem>_3d

# ============================================================
# 参数说明：
#   -2d / -3d / -1d       维度
#   +cartesian/cylindrical/spherical/polar   几何
#   +pm4dev               Paramesh 4 dev backend（默认，可省略）
#   +laser / +mgd / +uhd3t   其他 setup 变量（按算例需求）
#   -nxb=N -nyb=N -nzb=N  每 block cell 数（默认 8）
#   -objdir=PATH          setup 输出目录
# ============================================================

# 验证实际 backend：
# cat cases/<case>/setup_call
# 应该看到 Grid=PM4DEV
