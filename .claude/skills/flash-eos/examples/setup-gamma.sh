#!/bin/bash
# ============================================================
# FLASH 4.8 EOS = Gamma（理想气体）setup 命令模板
# ============================================================
# 对应知识库：.claude/skills/flash-eos/knowledge/recipes.md §1.1
#
# 适用：教学、Sod 激波管、单元测试、快速验证
# 不写 +eos 也是 Gamma（默认）
# ============================================================

# ===== Sedov 激波管（标准测试）=====
./setup Sedov -2d -auto +cartesian \
    -nxb=8 -nyb=8 \
    -objdir=cases/Sedov

# ===== 1D Sod 激波管 =====
./setup Sod -1d -auto +cartesian \
    -objdir=cases/Sod

# ============================================================
# 参数说明：
#   不指定 +eos 时默认 Gamma
#   也可以明确写 +eos=Gamma
# ============================================================

# parfile 关键配置：
# gamma = 1.6667           # 单原子理想气体（5/3）
# eosMode = "dens_ie"      # 默认

# 验证实际变体：
# cat cases/<case>/setup_call | grep -E "\+eos|\+3t"
# 应该看到什么都没有（默认 Gamma），或 +eos=Gamma
