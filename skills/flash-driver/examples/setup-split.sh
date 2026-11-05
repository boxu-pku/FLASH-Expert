#!/bin/bash
# ============================================================
# FLASH 4.8 setup 命令 - Split Driver（燃烧/火焰算例）
# ============================================================
# 对应知识库：.claude/skills/flash-driver/knowledge/recipes.md §3
#
# 适用：燃烧算例（FlamChannel / RTFlame / 含 Burn 单元）
# 工作机制：Strang splitting（Hydro 半步 → sourceTerm 整步 → Hydro 半步）
#
# 工作目录：/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
# ============================================================

# 火焰面算例
./setup FlamChannel -2d -auto +flame +burn \
    SplitDriver=true \
    -parfile=flash.par \
    -objdir=cases/flame_split

# 或用 +split（部分版本支持）
# ./setup FlamChannel -2d -auto +flame +burn +split -objdir=cases/flame_split

# 验证 Split 生效
grep "SplitDriver\|DEFAULT Split" cases/flame_split/setup_call

# 编译运行
cd cases/flame_split
make -j4
./flash4 -par_file flash.par
