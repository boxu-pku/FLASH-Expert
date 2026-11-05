#!/bin/bash
# ============================================================
# FLASH 4.8 EOS = multiTemp/Multitype（3T 生产级）setup 命令模板
# ============================================================
# 对应知识库：.claude/skills/flash-eos/knowledge/recipes.md §1.4 + §3
#
# 适用：HEDP / ICF 三温算例（电子+离子+辐射温度分离）
# Multitype = Helmholtz 电子 + Tabulated 离子 + 黑体辐射
# ============================================================

# ===== 完整 LaserSlab 3T 配置 =====
./setup LaserSlab -2d -auto +cylindrical \
    +usm3t +laser +mgd \
    species=cham,targ \
    mgd_meshgroups=6 \
    -nxb=16 -nyb=16 \
    -objdir=cases/LaserSlab_3t

# +usm3t 自动展开为：
#   +3t +usm +mgd
# +3t 自动选 multiTemp（默认 Multitype 子变体）

# ===== 3T + Hydro unsplit（不要 MHD）=====
./setup <problem> -2d -auto +cartesian \
    +3t +uhd +laser \
    -objdir=cases/<problem>_3t_uhd

# ===== 3T Multitype 显式指定 =====
./setup <problem> -2d -auto +cartesian \
    +3t +eos=Multitype \
    -objdir=cases/<problem>_3t_mtype

# ============================================================
# 参数说明：
#   +3t           启用 3T（multiTemp 变体）
#   +usm3t        +3t + usm MHD
#   +uhd3t        +3t + uhd pure hydro
#   +eos=Multitype 显式选 Multitype（混合 EOS）
# ============================================================

# 验证：
# cat cases/<case>/setup_call | grep -E "\+3t|\+eos|\+usm"
# 应该看到 +3t（可能含 +usm3t 或 +uhd3t）

# 关键 parfile 配置（3T）：
# eosMode = "dens_ie_recal_gather"      # +3t 默认
# gammaIon = 1.6667                      # 离子 γ
# gammaEle = 1.6667                      # 电子 γ
# gammaRad = 1.3333                      # 辐射 γ（必须 4/3）
# useHeatexchange = .true.               # 3T 平衡
# eos_combinedTempRule = 2               # TEMP_VAR 表示 T_ele

# 3T UNK 变量（plotfile 可看）：
# TEION_VAR  T_ion
# TELE_VAR   T_ele
# TERAD_VAR  T_rad
# EION_VAR   离子内能
# EELE_VAR   电子内能
# ERAD_VAR   辐射内能
# TITE       T_ion / T_ele 诊断比值
# PIPE       P_ion / P_ele 诊断比值
