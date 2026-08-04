#!/bin/bash
# ============================================================
# FLASH 4.8 Diffuse = Unsplit + HYPRE setup 模板
# ============================================================
# 对应知识库：.claude/skills/flash-diffuse/knowledge/recipes.md §2
#
# 适用：HEDP / ICF / 激光等离子体三温算例
# LaserSlab 是 HEDP 标准参考算例（含电子热传导 + MGD + 激光）
# ============================================================

# ===== LaserSlab 标准配置（HEDP 默认） =====
# 自动 REQUESTS physics/Diffuse/DiffuseMain/Unsplit（通过 +mgd）
./setup LaserSlab -2d -auto +cylindrical \
    +hdf5typeio \
    species=cham,targ \
    +mtmmmt \
    +laser +uhd3t +mgd \
    mgd_meshgroups=6 \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab \
    -parfile=example.par

# ===== 多物质精细（CH + targ1/2/3） =====
./setup Sunliang_laser_CH -2d -auto +cylindrical +pm4dev \
    +laser +mgd +uhd3t species=cham,targ1,targ2,targ3 \
    mgd_meshgroups=6 \
    -nxb=16 -nyb=16 \
    -parfile=example_xubo.par \
    -objdir=cases/Sunliang_laser_CH

# ===== 1T 教学算例（简单热传导测试） =====
# 注意：不用 +uhd3t / +mgd（1T 不需要 3T）
./setup <myThermProblem> -2d -auto +cartesian +ug \
    -nxb=16 -nyb=16 \
    -objdir=cases/<myThermProblem>

# ===== 3D 大规模生产 =====
./setup <myProblem> -3d -auto +cartesian +pm4dev \
    +laser +uhd3t +mgd \
    mgd_meshgroups=10 \
    -nxb=8 -nyb=8 -nzb=8 \
    maxblocks=2000 \
    -objdir=cases/<myProblem>_3d \
    -parfile=big.par

# ===== MHD 各向异性扩散（强磁场算例） =====
./setup <myMHDProblem> -2d -auto +cartesian +pm4dev \
    +mhd +laser +uhd3t +mgd \
    SupportAnisoCond \
    species=cham,targ \
    -objdir=cases/<myMHDProblem>

# ============================================================
# 参数说明（setup 期变量）：
#   +mgd               启用 MGD（多群扩散），隐式 REQUIRES DiffuseMain/Unsplit
#   +laser             启用激光沉积（flash-laser）
#   +uhd3t             启用 3T EOS（flash-eos）
#   +mtmmmt            multi-temp multi-material EOS（3T 多物质）
#   +pm4dev            PARAMESH 4 dev（AMR 网格）
#   +ug                Uniform Grid（教学用）
#   +mhd               MHD（磁场，启动各向异性扩散需要）
#   SupportAnisoCond  开启 CND1/CND2/CND3 变量（编译期）
#   species=...        Multispecies 声明（关联 IONMIX 表）
#   mgd_meshgroups=N   setup 期变量，编译期分配 N 个 MGDR 槽
# ============================================================

# 验证 setup 是否生效：
# cat cases/<case>/setup_call | grep -E "\+mgd|\+uhd3t|SupportAnisoCond"
# 应看到 +mgd / +uhd3t（自动 REQUIRES DiffuseMain/Unsplit）

# 关键 parfile 配置（Diffuse 必须）：
# useDiffuse      = .true.
# diff_useEleCond = .true.
# diff_thetaImplct = 1.0          # 后向 Euler，无条件稳定
# diff_eleFlMode  = "fl_larsen"   # HEDP 标准 flux limiter
# diff_eleFlCoef  = 0.06          # 6% 自由流（HEDP 经验）
# dt_diff_factor  = 1.0e+100      # 禁用显式 dt 限制（隐式不需要）
# gr_hypreSolverType = "HYPRE_AMG"  # BoomerAMG（LaserSlab 标准）
