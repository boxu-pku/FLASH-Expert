#!/bin/bash
# ============================================================
# FLASH 4.8 Grid backend = UG (Uniform Grid) setup 命令模板
# ============================================================
# 对应知识库：.claude/skills/flash-grid/knowledge/recipes.md §1.2
#
# 适用：无 AMR 算例
#   - PIC 粒子模拟
#   - FFT-based Poisson（Pfft）
#   - nofbs MHD
#   - 基准对比（固定网格分辨率）
# ============================================================

# ===== PIC 粗网格 =====
./setup <problem> -3d -auto +ug +pm4dev \
    -nxb=32 -nyb=32 -nzb=32 \
    -objdir=cases/<problem>_ug

# ===== nofbs MHD =====
./setup <problem> -3d -auto +ug +nofbs \
    -nxb=32 -nyb=32 -nzb=32 \
    -objdir=cases/<problem>_nofbs

# ============================================================
# 参数说明：
#   +ug       Uniform Grid backend（无 AMR）
#   注意：UG 算例 lrefine_max 等参数无效
# ============================================================

# 验证 backend：
# cat cases/<case>/setup_call
# 应该看到 Grid=UG

# 总 cell 数计算：
# total_cells = nblockx * NXB × nblocky * NYB × nblockz * NZB
# (固定不变，不受时间影响)
