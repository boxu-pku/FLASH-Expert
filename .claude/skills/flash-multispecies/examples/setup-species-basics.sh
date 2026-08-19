#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────
# setup-species-basics.sh
#
# Multispecies 多物质算例的典型 setup 命令。
# 含：LaserSlab 双物质 + Sunliang_laser_CH 多层靶 + 多元素物质（CH 塑料）。
# ──────────────────────────────────────────────────────────────────────────
#
# 使用方法：
#   cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
#   bash .claude/skills/flash-multispecies/examples/setup-species-basics.sh [case_name]
#
#   case_name 可选：laserslab | sunliang | multi-element
#     不传 = 跑全部（顺序）
#
# 关键 setup 变量：
#   species=<spec1>,<spec2>,...    必填！触发 Multispecies 参数族自动生成
#   ms_maxelems=N                  可选（默认 6），多元素物质元素数上限
#
# ──────────────────────────────────────────────────────────────────────────

set -e
FLASH_ROOT="/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8"
cd "$FLASH_ROOT"

CASE="${1:-all}"

# ════════════════════════════════════════════════════════════════════════
# Case 1: LaserSlab 双物质（HEDP 标准）
# ════════════════════════════════════════════════════════════════════════
setup_laserslab() {
    echo "==> [1/3] setup LaserSlab (species=cham,targ)"
    ./setup LaserSlab -2d -auto +cylindrical \
        -nxb=16 -nyb=16 \
        +hdf5typeio \
        species=cham,targ \
        +mtmmmt \
        +laser \
        +uhd3t \
        +mgd mgd_meshgroups=6 \
        -objdir=cases/LaserSlab \
        -parfile=example.par
    echo "==> 完成：cd cases/LaserSlab && make -j4 && ./flash4 -par_file flash.par"
}

# ════════════════════════════════════════════════════════════════════════
# Case 2: Sunliang_laser_CH 多层靶（4 种物质）
# ════════════════════════════════════════════════════════════════════════
setup_sunliang() {
    echo "==> [2/3] setup Sunliang_laser_CH (species=cham,targ1,targ2,targ3)"
    ./setup Sunliang_laser_CH -2d -auto +pm4dev \
        -geometry=cylindrical \
        -nxb=16 -nyb=16 \
        +mtmmmt \
        +laser \
        +mgd \
        +uhd3t \
        species=cham,targ1,targ2,targ3 \
        mgd_meshgroups=6 \
        -parfile=example_xubo.par \
        -objdir=cases/Sunliang_laser_CH
    echo "==> 完成：cd cases/Sunliang_laser_CH && make -j4 && ./flash4 -par_file flash.par"
}

# ════════════════════════════════════════════════════════════════════════
# Case 3: 多元素物质（CH 塑料 = C + H，演示 NumElems+ZElems/AElems/Fractions）
# 注意：这是 setup 命令模板，parfile 里要配 ms_chNumElems=2 + ZElems/AElems/Fractions
# ════════════════════════════════════════════════════════════════════════
setup_multi_element() {
    echo "==> [3/3] setup LaserSlab 多元素物质演示（species=cham,targ + ms_maxelems=4）"
    echo "    （parfile 里 targ 配 NumElems=2 + ZElems_1=6/AElems_1=12 + ZElems_2=1/AElems_2=1）"
    ./setup LaserSlab -2d -auto +cylindrical \
        -nxb=16 -nyb=16 \
        +hdf5typeio \
        species=cham,targ \
        ms_maxelems=4 \
        +mtmmmt \
        +laser \
        +uhd3t \
        +mgd mgd_meshgroups=6 \
        -objdir=cases/LaserSlabMultiElem \
        -parfile=example.par
    echo "==> 完成：编辑 cases/LaserSlabMultiElem/flash.par 加多元素 ms_targ* 段"
}

case "$CASE" in
    laserslab)    setup_laserslab ;;
    sunliang)     setup_sunliang ;;
    multi-element) setup_multi_element ;;
    all)
        setup_laserslab
        setup_sunliang
        setup_multi_element
        ;;
    *)
        echo "未知 case: $CASE"
        echo "用法: $0 [laserslab | sunliang | multi-element | all]"
        exit 1
        ;;
esac

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Multispecies setup 完成。"
echo ""
echo "下一步："
echo "  1. 检查 setup 生成的参数族："
echo "     grep -E 'FLASH_MULTISPECIES|NSPECIES|CHAM_SPEC|TARG_SPEC' cases/<case>/setup_defines"
echo ""
echo "  2. 确认 parfile 物种段："
echo "     grep -E '^ms_|^eos_|^op_' cases/<case>/flash.par"
echo ""
echo "  3. 编译 + 运行："
echo "     cd cases/<case> && make -j4 && ./flash4 -par_file flash.par"
echo ""
echo "  4. 验证物种初始化（看日志）："
echo "     grep -A 20 'Initially defined values of species' 01-data/<basenm>.log"
echo "════════════════════════════════════════════════════════════════"
