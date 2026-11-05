#!/bin/bash
# ============================================================
# run-laser-slab.sh — LaserSlab 2D 圆柱 HEDP 算例一键运行脚本
# ============================================================
# 用法：
#   bash run-laser-slab.sh           # 默认 -np 2
#   bash run-laser-slab.sh 4         # 用 4 核
#   bash run-laser-slab.sh 4 background  # 后台跑
#
# 功能：
#   1. setup LaserSlab（含 HEDP 全套：laser/mgd/uhd3t/mtmmmt/3T）
#   2. 处理 libmpi 冲突（编译期 sudo mv）
#   3. make -j4
#   4. source flash_env.sh（运行期 LD_PRELOAD，关键！）
#   5. 在 01-data/ 里 mpirun ../flash4（硬约束：输出只落 01-data/）
#   6. 检查产物（在 01-data/ 里）
#
# 2026-08-02 实战验证：本脚本流程跑通 66 步，零 MPI 错误。
# ============================================================

set -e

# ===== 配置 =====
FLASH_ROOT=/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
CASE_NAME=LaserSlab
OBJDIR=$FLASH_ROOT/cases/$CASE_NAME
DATADIR=$OBJDIR/01-data   # 运行输出目录（硬约束：plt/chk/dat/log 全落这里）
NP=${1:-2}
MODE=${2:-foreground}  # foreground 或 background

cd $FLASH_ROOT

# ===== 1. setup（如 objdir 不存在）=====
if [ ! -d "$OBJDIR" ]; then
    echo "[1/5] setup $CASE_NAME（HEDP 全套）..."
    ./setup $CASE_NAME -2d -auto +cylindrical \
        -nxb=16 -nyb=16 +hdf5typeio \
        species=cham,targ +mtmmmt +laser +uhd3t +mgd \
        mgd_meshgroups=6 \
        -objdir=$OBJDIR -parfile=example.par
else
    echo "[1/5] objdir 已存在，跳过 setup"
fi

cd $OBJDIR

# 验证 setup_call（L-009：以 setup_call 为准，不看 parfile 顶部注释）
echo "setup 命令（来自 setup_call）："
cat setup_call | head -2

# ===== 2. make（含 libmpi 冲突处理）=====
if [ ! -f "./flash4" ]; then
    echo ""
    echo "[2/5] make $CASE_NAME（处理 libmpi 冲突）..."

    # 本机 libmpi 冲突：mv 系统 OpenMPI 让 ld 找不到
    if [ -f /lib/x86_64-linux-gnu/libmpi.so.40 ]; then
        echo "  mv libmpi.so.40 -> .40.bak（需 sudo）"
        sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak
        LIBMPI_MOVED=1
    fi

    # 编译（HEDP 算例 4 核约 3-5 分钟）
    echo "  make -j4（HEDP 算例需要 3-5 分钟）..."
    make -j4 2>&1 | tee make.log
    MAKE_EXIT=${PIPESTATUS[0]}

    # 恢复 libmpi.so.40（即使 make 失败也恢复）
    if [ "$LIBMPI_MOVED" = "1" ]; then
        echo "  恢复 libmpi.so.40"
        sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40
    fi

    if [ $MAKE_EXIT -ne 0 ]; then
        echo "ERROR: make 失败（exit $MAKE_EXIT）"
        echo "看 make.log 找错误："
        grep -B2 -A5 -i "error" make.log | head -40
        exit 1
    fi

    # 检查 libmpi warning（预期会有，因为 ld 可能缓存）
    if grep -q "libmpi.so.40 may conflict" make.log; then
        echo "  （ld libmpi warning 是预期的，已通过 mv 处理）"
    fi
else
    echo "[2/5] flash4 已存在，跳过 make"
fi

ls -lh ./flash4

# 验证链接的 libmpi 是 mpich（.12）不是 OpenMPI（.40）
echo "ldd flash4 | grep mpi:"
ldd flash4 | grep -i "mpi"

# ===== 3. source flash_env.sh（关键！）=====
echo ""
echo "[3/5] 配置运行环境（LD_PRELOAD 防 SIGSEGV）..."
source $FLASH_ROOT/flash_env.sh

# 验证 LD_PRELOAD
if [ -z "$LD_PRELOAD" ]; then
    echo "ERROR: LD_PRELOAD 未设！source flash_env.sh 失败"
    exit 1
fi

# ===== 4. run（在 01-data/ 里，硬约束）=====
mkdir -p $DATADIR && cd $DATADIR
echo ""
if [ "$MODE" = "background" ]; then
    echo "[4/5] 后台 mpirun -np $NP（CWD=01-data）..."
    nohup mpirun -np $NP ../flash4 -par_file ../flash.par > flash.log 2>&1 &
    FLASH_PID=$!
    echo "  FLASH PID: $FLASH_PID"
    echo "  日志：tail -f $DATADIR/flash.log"
    echo "  停止：kill $FLASH_PID"
else
    echo "[4/5] 前台 mpirun -np $NP（CWD=01-data）..."
    mpirun -np $NP ../flash4 -par_file ../flash.par 2>&1 | tee flash.log
fi

# ===== 5. 检查产物（CWD 已是 01-data/）=====
echo ""
echo "[5/5] 检查产物（$DATADIR）..."

# 日志关键事件
echo ""
echo "=== 初始化是否完成（找 Hydro/RadTrans/EnergyDeposition）==="
grep -E "init.*complete\|Hydro_init\|RadTrans_init\|EnergyDeposition_init" flash.log | head -10

echo ""
echo "=== 是否有 SIGSEGV / abort / NaN ==="
grep -i "sigsegv\|abort\|nan\|forrtl: error" flash.log | head -10

echo ""
echo "=== Plotfile 数量 ==="
ls *_hdf5_plt_* 2>/dev/null | wc -l

echo ""
echo "=== Checkpoint 数量 ==="
ls *_hdf5_chk_* 2>/dev/null | wc -l

echo ""
echo "=== 最新 plotfile ==="
ls -lht *_hdf5_plt_* 2>/dev/null | head -3

echo ""
echo "=== 日志最后 10 行 ==="
tail -10 flash.log

# 完成判断
if grep -q "completed successfully\|reached" flash.log; then
    echo ""
    echo "✓ LaserSlab 跑通"
elif grep -q "SIGSEGV\|abort\|forrtl: error" flash.log; then
    echo ""
    echo "✗ LaserSlab 跑出错——看上面诊断信息"
    echo "  详细见：knowledge/pitfalls.md + knowledge/run_guide.md"
else
    echo ""
    echo "... 算例可能仍在跑（后台模式）"
fi
