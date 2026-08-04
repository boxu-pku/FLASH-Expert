#!/bin/bash
# ============================================================
# FLASH 4.8 setup 命令 - multithreaded Driver（OpenMP 并行）
# ============================================================
# 对应知识库：.claude/skills/flash-driver/knowledge/recipes.md §4
#
# 适用：单机多核、3D 大算例、充分利用 CPU
# 注意：编译期启用，运行时还要设 OMP_NUM_THREADS
#
# 工作目录：/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
# ============================================================

# 方案 A：threadBlockList（每个线程处理一个 block，简单）
./setup Sedov -3d -auto \
    threadBlockList=true \
    -objdir=cases/sedov_3d_mt

# 方案 B：threadWithinBlock（block 内多线程，更复杂）
# ./setup Sedov -3d -auto threadWithinBlock=true -objdir=cases/sedov_3d_mt

# 激光算例多线程（Driver + ray tracing 都多线程）
./setup laser_CH -2d -auto +pm4dev -geometry=cylindrical \
    -nxb=16 -nyb=16 +mtmmmt +laser +mgd +uhd3t \
    species=cham,targ1,targ2,targ3 mgd_meshgroups=6 \
    threadBlockList=true \
    threadRayTrace=true \
    -parfile=flash.par \
    -objdir=cases/laser_mt

# 编译
cd cases/<your_case>
make -j4

# 运行（设 OpenMP 线程数）
export OMP_NUM_THREADS=8       # 每 MPI process 8 个线程
mpirun -np 4 ./flash4 -parfile=flash.par
# → 4 × 8 = 32 核并行

# 验证 OpenMP 启用
grep "FLASH_OPENMP" cases/<your_case>/setup_defines
# 应输出 #define FLASH_OPENMP 1
