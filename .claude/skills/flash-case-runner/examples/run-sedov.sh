#!/bin/bash
# ============================================================
# run-sedov.sh — Sedov 算例一键运行脚本
# ============================================================
# 用法：
#   bash run-sedov.sh
#
# 功能：
#   1. setup Sedov（如 objdir 不存在）
#   2. 处理 libmpi 冲突（编译期 sudo mv）
#   3. make -j4
#   4. source flash_env.sh（运行期 LD_PRELOAD）
#   5. mpirun -np 2 ./flash4
#   6. 检查产物
# ============================================================

set -e  # 任一步失败立即退出

# ===== 配置 =====
FLASH_ROOT=/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
CASE_NAME=Sedov
OBJDIR=$FLASH_ROOT/cases/$CASE_NAME
NP=${1:-2}  # 第一个参数是核数，默认 2

cd $FLASH_ROOT

# ===== 1. setup（如 objdir 不存在）=====
if [ ! -d "$OBJDIR" ]; then
    echo "[1/5] setup $CASE_NAME ..."
    ./setup $CASE_NAME -auto -objdir=$OBJDIR
else
    echo "[1/5] objdir 已存在，跳过 setup"
fi

cd $OBJDIR

# ===== 2. make（含 libmpi 冲突处理）=====
if [ ! -f "./flash4" ]; then
    echo "[2/5] make $CASE_NAME（处理 libmpi 冲突）..."

    # 本机 libmpi 冲突：mv 系统 OpenMPI 让 ld 找不到
    if [ -f /lib/x86_64-linux-gnu/libmpi.so.40 ]; then
        echo "  mv libmpi.so.40 -> .40.bak（需 sudo）"
        sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak
        LIBMPI_MOVED=1
    fi

    # 编译
    make -j4 2>&1 | tee make.log
    MAKE_EXIT=${PIPESTATUS[0]}

    # 恢复 libmpi.so.40（即使 make 失败也恢复）
    if [ "$LIBMPI_MOVED" = "1" ]; then
        echo "  恢复 libmpi.so.40"
        sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40
    fi

    if [ $MAKE_EXIT -ne 0 ]; then
        echo "ERROR: make 失败（exit $MAKE_EXIT）"
        exit 1
    fi
else
    echo "[2/5] flash4 已存在，跳过 make"
fi

ls -lh ./flash4

# ===== 3. source flash_env.sh =====
echo "[3/5] 配置运行环境 ..."
source $FLASH_ROOT/flash_env.sh

# ===== 4. run =====
echo "[4/5] mpirun -np $NP ./flash4 ..."
mpirun -np $NP ./flash4 -parfile=flash.par 2>&1 | tee flash.log

# ===== 5. 检查产物 =====
echo "[5/5] 检查产物 ..."
echo ""
echo "Plotfile 数量："
ls *_hdf5_plt_*.h5 2>/dev/null | wc -l
echo ""
echo "Checkpoint 数量："
ls *_hdf5_chk_*.h5 2>/dev/null | wc -l
echo ""
echo "日志最后 5 行："
tail -5 flash.log

# 检查是否完成
if grep -q "completed successfully\|reached" flash.log; then
    echo ""
    echo "✓ Sedov 跑通"
else
    echo ""
    echo "⚠ Sedov 可能没跑完，检查 flash.log"
fi
