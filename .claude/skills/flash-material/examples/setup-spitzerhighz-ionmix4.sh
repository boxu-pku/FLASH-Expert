#!/bin/bash
# setup-spitzerhighz-ionmix4.sh
#
# LaserSlab 标准 HEDP setup 命令（含 Conductivity/SpitzerHighZ + Opacity/Multispecies/IONMIX4）
#
# 来源：参考 cases/LaserSlab/setup_call 和 CLAUDE.md 中的 setup 命令
#
# 使用方法：
#   cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
#   bash .claude/skills/flash-material/examples/setup-spitzerhighz-ionmix4.sh
#
# 或直接复制粘贴命令到 shell 运行

set -e  # 任一命令失败立即退出

FLASH_ROOT="/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8"
cd "$FLASH_ROOT"

# LaserSlab HEDP 标准配置
# 关键 setup 变量说明：
#   -2d               : 2 维
#   +cylindrical      : 圆柱几何（r-z）
#   -nxb=16 -nyb=16   : 每 block 16x16 cell
#   +hdf5typeio       : HDF5 IO 后端
#   species=cham,targ : 两个物质（cham=He chamber, targ=Al target）
#                       → 自动生成 op_cham*/op_targ* 参数
#   +mtmmmt           : multi-temp multi-species EOS（3T 必需）
#   +laser            : EnergyDeposition 激光单元
#   +uhd3t            : unsplit hydro + 3T（启用 TELE/TION/TRAD）
#   +mgd              : Multigroup Diffusion（启用 RadTrans/MGD）
#   mgd_meshgroups=6  : 6 个能群
#   -objdir           : 构建目录
#   -parfile          : 复制 example.par 到 objdir/flash.par

./setup LaserSlab -2d -auto +cylindrical \
    -nxb=16 -nyb=16 \
    +hdf5typeio \
    species=cham,targ \
    +mtmmmt +laser +uhd3t +mgd \
    mgd_meshgroups=6 \
    -objdir=cases/LaserSlab \
    -parfile=example.par

echo ""
echo "Setup 完成。下一步："
echo "  cd cases/LaserSlab"
echo "  make -j4"
echo "  ./flash4 -par_file=flash.par"
