#!/bin/bash
# ============================================================
# FLASH 4.8 setup 命令 - Unsplit Driver（默认，最常用）
# ============================================================
# 对应知识库：.claude/skills/flash-driver/knowledge/recipes.md §2
#
# 适用：90% 算例（Sedov / Sod / 激光烧蚀 / CCSN / WindTunnel 等）
#
# 工作目录：/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
# ============================================================

# 基础 hydro 算例（Sedov）
./setup Sedov -auto -objdir=cases/sedov_unsplit

# 或：2D RZ 激光算例（laser_CH）
./setup laser_CH -2d -auto +pm4dev -geometry=cylindrical \
    -nxb=16 -nyb=16 +mtmmmt +laser +mgd +uhd3t \
    species=cham,targ1,targ2,targ3 mgd_meshgroups=6 \
    -parfile=flash.par -objdir=cases/my_laser

# 编译运行
cd cases/<your_case>
make -j4
./flash4 -parfile=flash.par
