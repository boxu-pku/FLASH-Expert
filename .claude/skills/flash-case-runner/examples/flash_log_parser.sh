#!/bin/bash
# ============================================================
# flash_log_parser.sh — FLASH 运行日志关键信息提取
# ============================================================
# 用法：
#   bash flash_log_parser.sh cases/LaserSlab/flash.log
#
# 功能：从 flash.log 提取：
#   1. setup 信息（命令、版本）
#   2. 初始化是否完成
#   3. dt 演化（最后 20 步）
#   4. simTime 推进
#   5. AMR block 数变化
#   6. NaN / abort / SIGSEGV 错误
#   7. plotfile / checkpoint 写入次数
#   8. 完成状态
# ============================================================

LOG_FILE=${1:-flash.log}

if [ ! -f "$LOG_FILE" ]; then
    echo "ERROR: 日志文件不存在: $LOG_FILE"
    echo "用法: bash $0 <flash.log>"
    exit 1
fi

echo "============================================================"
echo " FLASH 日志分析: $LOG_FILE"
echo "============================================================"
echo ""

# ===== 1. setup 信息 =====
echo "=== 1. Setup 信息 ==="
grep -E "^FLASH|^setup|setup_call" $LOG_FILE | head -5
echo ""

# ===== 2. 初始化完成检查 =====
echo "=== 2. 初始化完成检查 ==="
INIT_MARKERS="Driver_initFlash|Grid_init|Hydro_init|Eos_init|RadTrans_init|Multispecies_init|EnergyDeposition_init|Simulation_init"
INIT_COUNT=$(grep -cE "$INIT_MARKERS" $LOG_FILE)
echo "初始化 routine 调用次数: $INIT_COUNT"
echo ""
echo "初始化 routine（前 10 个）:"
grep -E "$INIT_MARKERS" $LOG_FILE | head -10
echo ""

# ===== 3. dt 演化 =====
echo "=== 3. dt 演化（最后 20 步）==="
# dt 通常在 "[Hydro]" 等段，或在 "starting step" 行
grep -E "^\s*dt\s*=\|dt = |^dt " $LOG_FILE | tail -20
echo ""

# ===== 4. simTime 推进 =====
echo "=== 4. simTime 推进（最后 10 条）==="
grep -iE "simTime|simulation time|t_sim" $LOG_FILE | tail -10
echo ""

# ===== 5. AMR block 数 =====
echo "=== 5. AMR block 数（最后 10 条）==="
grep -iE "leaf block|total block|number of block" $LOG_FILE | tail -10
echo ""

# ===== 6. 错误检测 =====
echo "=== 6. 错误检测 ==="
echo ""
echo "--- NaN / Inf ---"
grep -iE "nan|inf|infinity" $LOG_FILE | head -10
echo ""
echo "--- abort ---"
ABORT_COUNT=$(grep -ciE "abort|Driver_abortFlash" $LOG_FILE)
echo "abort 出现次数: $ABORT_COUNT"
if [ "$ABORT_COUNT" -gt 0 ]; then
    echo "abort 段（前 30 行上下文）:"
    grep -B5 -A30 -iE "abort|Driver_abortFlash" $LOG_FILE | head -50
fi
echo ""
echo "--- SIGSEGV / 段错误 ---"
SIGSEGV_COUNT=$(grep -ciE "sigsegv|segmentation|段错误" $LOG_FILE)
echo "SIGSEGV 出现次数: $SIGSEGV_COUNT"
if [ "$SIGSEGV_COUNT" -gt 0 ]; then
    grep -B2 -A20 -iE "sigsegv|segmentation" $LOG_FILE | head -40
fi
echo ""
echo "--- forrtl error（Fortran 运行时错）---"
FORRTL_COUNT=$(grep -ciE "forrtl:" $LOG_FILE)
echo "forrtl error 出现次数: $FORRTL_COUNT"
if [ "$FORRTL_COUNT" -gt 0 ]; then
    grep -A10 -iE "forrtl:" $LOG_FILE | head -30
fi
echo ""
echo "--- MPI error ---"
MPIERR_COUNT=$(grep -ciE "MPI_ERRORS|mpi_abort|mpi error" $LOG_FILE)
echo "MPI error 出现次数: $MPIERR_COUNT"
if [ "$MPIERR_COUNT" -gt 0 ]; then
    grep -B2 -A10 -iE "MPI_ERRORS|mpi_abort|mpi error" $LOG_FILE | head -30
fi
echo ""

# ===== 7. plotfile / checkpoint =====
echo "=== 7. IO 写入 ==="
echo ""
echo "--- Plotfile 写入次数 ---"
grep -ciE "writing.*plotfile|plot_plotFileNumber" $LOG_FILE
echo ""
echo "--- Checkpoint 写入次数 ---"
grep -ciE "writing.*checkpoint|chk_checkpointFileNumber" $LOG_FILE
echo ""

# ===== 8. 完成状态 =====
echo "=== 8. 完成状态 ==="
if grep -qiE "completed successfully|simulation finished|reached.*max" $LOG_FILE; then
    echo "✓ 算例正常完成"
    grep -iE "completed successfully|simulation finished|reached.*max" $LOG_FILE | head -3
elif [ "$ABORT_COUNT" -gt 0 ] || [ "$SIGSEGV_COUNT" -gt 0 ] || [ "$FORRTL_COUNT" -gt 0 ]; then
    echo "✗ 算例运行出错（看上面诊断）"
else
    echo "... 算例可能仍在跑或被中断"
    echo ""
    echo "最后 10 行日志："
    tail -10 $LOG_FILE
fi

echo ""
echo "============================================================"
echo " 分析完毕"
echo "============================================================"
