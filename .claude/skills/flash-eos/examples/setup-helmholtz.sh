#!/bin/bash
# ============================================================
# FLASH 4.8 EOS = Helmholtz（HEDP 默认）setup 命令模板
# ============================================================
# 对应知识库：.claude/skills/flash-eos/knowledge/recipes.md §1.2
#
# 适用：HEDP / ICF / 激光等离子体 / 白矮星 / 超新星
# Helmholtz = 电子简并 + 离子（理想气体）+ 黑体辐射 + Coulomb
# ============================================================

# ===== Helmholtz + 激光（生产级配置）=====
./setup LaserSlab -2d -auto +cylindrical \
    +eos=Helmholtz +laser +mgd +uhd3t \
    species=cham,targ \
    mgd_meshgroups=6 \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab_helm

# ===== 简单 Helmholtz 测试（无 3T，1T）=====
./setup Sedov -2d -auto +cartesian +eos=Helmholtz \
    -nxb=8 -nyb=8 \
    -objdir=cases/Sedov_helm

# ===== Helmholtz + Ye（核合成跟踪 Ye）=====
./setup <problem> -3d -auto +eos=Helmholtz species=He,C,O +eosYe \
    -objdir=cases/<problem>_ye

# ============================================================
# 参数说明：
#   +eos=Helmholtz       选 Helmholtz（默认 SpeciesBased 子变体）
#   +laser +mgd +uhd3t   其他 setup 变量（按算例需求）
#   species=...          Multispecies 声明（用于 Abar/Zbar）
# ============================================================

# 验证实际变体：
# cat cases/<case>/setup_call | grep -E "\+eos|\+3t"
# 应该看到 +eos=Helmholtz

# 关键 parfile 配置：
# eosMode = "dens_ie"
# eos_coulombMult = 1.0
# eos_tolerance = 1.e-8
# eos_maxNewton = 50

# 第一次启动会读 helm_table.dat（7.7 MB ASCII，慢）
# 后续启动读 helm_table.bdat（二进制缓存，快）
