#!/bin/bash
# Sedov 最小 setup 命令模板
# 适用场景：第一次跑 FLASH，验证编译环境
# 详细解释见 .claude/skills/flash-setup-builder/knowledge/recipes.md Recipe 1

set -e

# 必须在 FLASH 根目录运行
FLASH_ROOT=/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
cd "$FLASH_ROOT"

# setup 命令（最短可运行版本）
./setup Sedov -auto -objdir=cases/Sedov

echo "==== setup 完成 ===="
echo "下一步："
echo "  cd cases/Sedov"
echo "  make -j4"
echo "  ./flash4 -parfile=flash.par"
echo ""
echo "验证 setup 是否成功："
echo "  cat cases/Sedov/setup_call"
echo "  cat cases/Sedov/setup_defines"
