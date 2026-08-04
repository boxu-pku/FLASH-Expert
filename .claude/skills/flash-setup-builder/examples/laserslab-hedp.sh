#!/bin/bash
# LaserSlab HEDP 主流 setup 命令模板
# 适用场景：HEDP 激光打靶标准算例
# 详细解释见 .claude/skills/flash-setup-builder/knowledge/recipes.md Recipe 2

set -e

FLASH_ROOT=/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
cd "$FLASH_ROOT"

# 预检查（HEDP 必做）
echo "==== 预检查 ===="

# 1. 确认 Makefile.h 已配置好（如果第一次 setup，需要先有 sites/ares/）
if [ ! -f cases/LaserSlab/Makefile.h ] && [ ! -f sites/ares/Makefile.h ]; then
    echo "警告：cases/LaserSlab/Makefile.h 不存在且 sites/ares/ 不存在"
    echo "建议先创建 sites/ares/Makefile.h（从 cases/LaserSlab/Makefile.h 拷贝）"
    echo "详见 .claude/skills/flash-setup-builder/knowledge/pitfalls.md §2"
fi

# 2. 确认 parfile 存在
if [ ! -f source/Simulation/SimulationMain/LaserSlab/example.par ]; then
    echo "错误：source/Simulation/SimulationMain/LaserSlab/example.par 不存在"
    exit 1
fi

echo "==== 预检查通过，开始 setup ===="

# LaserSlab HEDP 主流 setup 命令
./setup LaserSlab -2d -auto +cylindrical \
    -nxb=16 -nyb=16 \
    +hdf5typeio \
    species=cham,targ \
    +mtmmmt +laser +uhd3t +mgd \
    mgd_meshgroups=6 \
    -objdir=cases/LaserSlab \
    -parfile=example.par

echo ""
echo "==== setup 完成 ===="
echo ""
echo "验证："
echo "  cat cases/LaserSlab/setup_call"
echo "  grep -E 'ThreeT|Laser|Mgd|Mtmmmt' cases/LaserSlab/setup_call"
echo ""
echo "下一步（处理 libmpi 冲突 + make + run）："
echo "  cd cases/LaserSlab"
echo "  # 处理 libmpi.so.40 冲突（本机特有）："
echo "  sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak"
echo "  make -j4"
echo "  sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40"
echo "  ./flash4 -parfile=flash.par"
