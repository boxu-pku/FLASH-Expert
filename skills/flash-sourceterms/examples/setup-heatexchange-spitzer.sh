#!/bin/bash
# ============================================================
# FLASH 4.8 Heatexchange/Spitzer（HEDP 默认）setup 模板
# ============================================================
# 对应知识库：.claude/skills/flash-sourceterms/knowledge/recipes.md §1.1
#
# 适用：HEDP / ICF / 激光等离子体 3T 算例
# LaserSlab +uhd3t 自动 REQUESTS Heatexchange/Spitzer
# ============================================================

# ===== LaserSlab 标准（HEDP 默认，自动选 Spitzer） =====
./setup LaserSlab -2d -auto +cylindrical \
    +laser +mgd +uhd3t \
    species=cham,targ \
    mgd_meshgroups=6 \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab \
    -parfile=example.par

# ===== 自定义算例 + 选 LeeMore（高 Z 物质） =====
./setup <problem> -2d -auto +cylindrical +3t +laser +mgd \
    --with-unit=physics/sourceTerms/Heatexchange/HeatexchangeMain/LeeMore \
    -objdir=cases/<problem>_LeeMore

# ===== 自定义算例 + Immediate（调试，强制 T_ion = T_ele） =====
./setup <problem> -2d -auto +3t \
    --with-unit=physics/sourceTerms/Heatexchange/HeatexchangeMain/Immediate \
    -objdir=cases/<problem>_immediate

# ===== 激光提前（DRIVER_EDEARLY 宏） =====
./setup LaserSlab -2d -auto +cylindrical \
    +laser +mgd +uhd3t +edearly \
    species=cham,targ mgd_meshgroups=6 \
    -objdir=cases/LaserSlab_edearly

# ============================================================
# 参数说明：
#   +uhd3t           自动包含 +3t（multiTemp EOS）+ usm MHD
#                    → LaserSlab Config REQUESTS Heatexchange/Spitzer 自动选
#   --with-unit=...  自定义变体（LeeMore/Immediate/ConstCoulomb/Constant）
#   +edearly         让 EnergyDeposition 从默认第 10 位调到第 0 位
# ============================================================

# 验证：
# cat cases/<case>/setup_call | grep -E "Heatexchange|\\+uhd3t"
# 应看到 Heatexchange/HeatexchangeMain/Spitzer

# 关键 parfile 配置：
# useHeatexchange = .true.
# hx_dtFactor = 1.0e+100     # LaserSlab 标准（禁用 HX dt 限制）
