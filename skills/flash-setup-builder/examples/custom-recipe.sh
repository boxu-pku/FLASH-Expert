#!/bin/bash
# 4 个变体 setup 命令模板
# 详细解释见 .claude/skills/flash-setup-builder/knowledge/recipes.md
#
# 变体：
#   A: 3D 生产级（mgd_meshgroups=70）
#   B: Debug 模式（调 NaN）
#   C: 多物质（Sunliang）
#   D: MHD（usm3t）

FLASH_ROOT=/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
cd "$FLASH_ROOT"

# 选变体（修改下面这行）
RECIPE=${1:-A}

case $RECIPE in
    A|a)
        echo "==== 变体 A: LaserSlab 3D 生产级 ===="
        ./setup LaserSlab -3d -auto +cartesian \
            -nxb=16 -nyb=16 -nzb=16 \
            +hdf5typeio \
            species=cham,targ \
            +mtmmmt +laser +uhd3t +mgd \
            mgd_meshgroups=70 \
            -maxBlocks=10000 \
            -parfile=3Din2D.par \
            -objdir=cases/LaserSlab_3d_prod
        ;;

    B|b)
        echo "==== 变体 B: Debug 模式（调 NaN）===="
        ./setup LaserSlab -2d -auto +cylindrical \
            -nxb=16 -nyb=16 \
            +hdf5typeio \
            species=cham,targ \
            +mtmmmt +laser +uhd3t +mgd \
            mgd_meshgroups=6 \
            -debug \
            -objdir=cases/LaserSlab_debug \
            -parfile=example.par
        ;;

    C|c)
        echo "==== 变体 C: Sunliang 多物质 HEDP ===="
        ./setup Sunliang_laser_CH -2d -auto +pm4dev \
            -geometry=cylindrical -nxb=16 -nyb=16 \
            +mtmmmt +laser +mgd +uhd3t \
            species=cham,targ1,targ2,targ3 \
            mgd_meshgroups=6 \
            -parfile=example_xubo.par \
            -objdir=cases/Sunliang_laser_CH
        ;;

    D|d)
        echo "==== 变体 D: MHD 算例（usm3t）===="
        ./setup magnetoHD -2d -auto +cartesian \
            -nxb=16 -nyb=16 \
            +hdf5typeio \
            +usm3t \
            -objdir=cases/magnetoHD \
            -parfile=default.par
        ;;

    *)
        echo "用法：$0 {A|B|C|D}"
        echo "  A: LaserSlab 3D 生产级"
        echo "  B: Debug 模式"
        echo "  C: Sunliang 多物质"
        echo "  D: MHD 算例"
        exit 1
        ;;
esac

echo ""
echo "==== setup 完成（变体 $RECIPE）===="
echo "查看 setup_call 确认选项生效："
echo "  cat cases/*/setup_call | tail -50"
