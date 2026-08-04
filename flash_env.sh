#!/bin/bash
# ============================================================
# FLASH 4.8 运行环境配置（本机 ares 专用）
# ============================================================
# 用法：
#   source flash_env.sh
#
# 然后就可以直接跑：
#   cd cases/LaserSlab
#   mpirun -np 2 ./flash4 -parfile=flash.par
#
# 不需要 sudo mv libmpi.so.40 了！
# ============================================================

# ===== 1. 库根路径（从 CLAUDE.md / Makefile.h 提取）=====
FLASH_LIBS=/home/ubuntu/local/flash/myFLASH4.8
MPI_PATH=$FLASH_LIBS/mpich
HDF5_PATH=$FLASH_LIBS/hdf5
HYPRE_PATH=$FLASH_LIBS/hypre

# ===== 2. PATH：让 mpirun/mpicc 用 mpich 的，不是系统 OpenMPI =====
export PATH=$MPI_PATH/bin:$PATH

# 这一步做了什么：
# 系统 PATH 里有 /usr/bin/mpirun（OpenMPI），和我们编译 FLASH 用的
# mpich mpirun 不是同一个。把 mpich/bin 放前面，shell 输入 mpirun
# 时就会找到 mpich 的版本，避免 "两套 MPI 打架"。

# ===== 3. LD_LIBRARY_PATH：让 loader 优先找 mpich/hdf5/hypre 库 =====
export LD_LIBRARY_PATH=$MPI_PATH/lib:$HDF5_PATH/lib:$HYPRE_PATH/lib:${LD_LIBRARY_PATH:-}

# 这一步做了什么：
# flash4 启动时，loader 按以下顺序找 libmpi.so：
#   1. LD_PRELOAD（见下方）
#   2. RPATH（编译时写进可执行文件的路径，如果有）
#   3. LD_LIBRARY_PATH（这里设的）
#   4. /lib/x86_64-linux-gnu/（系统库——libmpi.so.40 在这里！）
# 把 mpich/lib 放前面，loader 先找到 libmpi.so.12（mpich）而不是
# libmpi.so.40（系统 OpenMPI）。

# ===== 4. LD_PRELOAD：终极保险，强制最先加载 mpich 的 libmpi =====
export LD_PRELOAD=$MPI_PATH/lib/libmpi.so

# 这一步做了什么：
# LD_PRELOAD 是 loader 的"最高优先级"——程序启动时最先加载这里指定的库。
# 即使 LD_LIBRARY_PATH 没设对，libmpi.so.40 仍残留在系统路径里，
# LD_PRELOAD 也能确保 flash4 拿到的是 mpich 的 libmpi.so.12（不是 OpenMPI 的 .40）。
#
# 为什么需要这层保险：
# libHYPRE.so 内部也依赖 libmpi——如果它先加载了 .40 再加载 .12，
# 两个 MPI 实现的符号冲突会导致段错误（SIGSEGV in Driver_initParallel.F90:92）。
# LD_PRELOAD 在任何其他库之前就把 .12 塞进去，杜绝冲突。
#
# 验证（2026-08-02 LaserSlab 4.8 实战通过）：
#   env LD_PRELOAD=$MPI_PATH/lib/libmpi.so mpirun -np 2 ./flash4 -parfile=flash.par
#   → 66 步跑完，零 MPI 错误

# ===== 5. 验证输出 =====
echo "============================================"
echo " FLASH 4.8 运行环境已配置"
echo "============================================"
echo ""
echo " MPI:  $($MPI_PATH/bin/mpirun --version 2>&1 | head -1)"
echo " PATH: mpirun → $(which mpirun)"
echo ""
echo " LD_PRELOAD:    $LD_PRELOAD"
echo " LD_LIBRARY_PATH 前 3 项:"
echo "$LD_LIBRARY_PATH" | tr ':' '\n' | head -3 | sed 's/^/   /'
echo ""
echo " 验证 libmpi 链接:"
ldd $(which mpirun) 2>/dev/null | grep libmpi || echo "   (mpirun 静态链接，无 libmpi 依赖)"
echo ""
echo " 现在可以直接跑："
echo "   cd cases/LaserSlab"
echo "   mpirun -np 2 ./flash4 -parfile=flash.par"
echo "============================================"
