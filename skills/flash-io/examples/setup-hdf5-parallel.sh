#!/bin/bash
# setup-hdf5-parallel.sh
# LaserSlab + hdf5typeio (type-based parallel HDF5) 的标准 HEDP setup 命令
# 详见 .claude/skills/flash-io/knowledge/recipes.md §1, §2

set -e

# 路径（按需修改）
FLASH_DIR=/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
CASE_NAME=LaserSlab
CASE_DIR=$FLASH_DIR/cases/$CASE_NAME

cd $FLASH_DIR

# 标准 LaserSlab setup（HEDP 主流）
# -2d: 2 维（HEDP slab 几何）
# +cylindrical: 柱坐标（r-z）
# -nxb=16 -nyb=16: 块大小 16x16（HEDP 标准）
# +hdf5typeio: 选 PM_argonne（type-based parallel HDF5）
#   - 设 setup 变量 typeIO=True
#   - 触发 IO/IOMain/hdf5/parallel/PM_argonne
#   - 比 PM 标准 parallel 快 5-10x
# species=cham,targ: cham (CH) + targ (CHBr) 物质
# +mtmmmt: multi-temp EOS（3T 必需）
# +laser: 激光（EnergyDeposition）
# +uhd3t: unsplit hydrodynamics 3T
# +mgd mgd_meshgroups=6: 多群扩散辐射（6 群）
# -parfile=example.par: 用 example.par 作模板
# -objdir=cases/LaserSlab: 输出目录
./setup LaserSlab \
    -2d -auto +cylindrical -nxb=16 -nyb=16 \
    +hdf5typeio \
    species=cham,targ +mtmmmt +laser +uhd3t +mgd mgd_meshgroups=6 \
    -objdir=$CASE_DIR \
    -parfile=example.par

cd $CASE_DIR

# 本机 libmpi 冲突 workaround（参考 note.txt）
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak 2>/dev/null || true

make -j4

# 恢复 libmpi
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40 2>/dev/null || true

echo ""
echo "==== Setup 完成 ===="
echo "可执行文件: $CASE_DIR/flash4"
echo "运行: cd $CASE_DIR && ./flash4 -par_file=flash.par"
