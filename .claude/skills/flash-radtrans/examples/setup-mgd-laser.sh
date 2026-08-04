#!/bin/bash
# ============================================================
# FLASH 4.8 RadTrans = MGD（多群扩散）+ Laser HEDP setup 模板
# ============================================================
# 对应知识库：.claude/skills/flash-radtrans/knowledge/recipes.md §1.1
#
# 适用：HEDP / ICF / 激光等离子体三温算例
# LaserSlab 是 HEDP 标准参考算例
# ============================================================

# ===== LaserSlab 标准配置（HEDP 默认） =====
./setup LaserSlab -2d -auto +cylindrical \
    +laser +mgd +uhd3t \
    species=cham,targ \
    mgd_meshgroups=6 \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab \
    -parfile=example.par

# ===== 多物质精细（CH + Au + CHBr） =====
./setup Sunliang_laser_CH -2d -auto +cylindrical +pm4dev \
    +laser +mgd +uhd3t species=cham,targ1,targ2,targ3 \
    mgd_meshgroups=6 \
    -nxb=16 -nyb=16 \
    -parfile=example_xubo.par \
    -objdir=cases/Sunliang_laser_CH

# ===== 单群测试（gray，教学用） =====
./setup <problem> -2d -auto +cartesian +mgd \
    mgd_meshgroups=1 \
    -objdir=cases/<problem>_gray

# ============================================================
# 参数说明：
#   +mgd               启用 MGD（多群扩散）
#   +laser             启用激光沉积（flash-laser）
#   +uhd3t             启用 3T EOS（flash-eos）
#   species=...        Multispecies 声明（关联 IONMIX 表）
#   mgd_meshgroups=N   setup 期变量，编译期分配 N 个 MGDR 槽
# ============================================================

# 验证：
# cat cases/<case>/setup_call | grep -E "\+mgd|\+laser|\+uhd3t"
# 应该看到 +mgd

# 关键 parfile 配置（MGD 必须）：
# rt_useMGD = .true.
# rt_mgdNumGroups = 6
# rt_mgdBounds_1..7 = 1e-1, 1e0, 1e1, 1e2, 1e3, 1e4, 1e5   # eV！
# rt_mgdFlMode = "fl_harmonic"      # ★ 必须显式设（默认 fl_none 危险）
