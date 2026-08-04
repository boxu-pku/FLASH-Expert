---
title: LaserSlab 2D 圆柱 HEDP 算例——完整跑法（主流）
skill: flash-case-runner
category: recipe
case: LaserSlab
difficulty: 中等
estimated_time: 30 分钟 - 数小时（取决于 sim_maxTime 和 -np N）
physics: 多物质 + 3T + 激光 + MGD + Heatexchange + IONMIX/SESAME 表
machine_verified: ares (2026-08-02 实战通过 66 步)
---

# LaserSlab 2D 圆柱 HEDP 算例配方

> LaserSlab 是 FLASH 的 **HEDP 主流算例**——激光打平面靶，含激光沉积 + 3T EOS + MGD 辐射 + 多物质。
>
> **2026-08-02 实战验证**：本配方在本机 ares 跑通 66 步，零 MPI 错误，plotfile/checkpoint 正常写入。
>
> 按 L-013，这是用户实际工作场景，本文是本 skill 的**主推 recipe**。

## 1. 算例物理简介

**LaserSlab** = 激光打平面靶，2D 圆柱 (r, z) 几何。

**物理**：
- 多物质（cham 腔体 + targ 靶）
- 3T（Tele/Tion/Trad 分别演化）
- 激光沉积（EnergyDeposition，几何光学 + 逆韧致吸收）
- 多群扩散辐射（MGD，6 群默认）
- 电子-离子平衡（Heatexchange/Spitzer）
- Spitzer-Härm 电子热传导
- IONMIX4 不透明度表 + SESAME EOS 表

**几何**：
```
     z 轴（激光方向）
     ↑
     │   cham（低 Z 腔体材料，如塑料泡沫）
     │
─────┼──────────────────→ r 轴
     │
     │   targ（高 Z 靶材料，如金/铜）
     │
     ↓
     激光从顶部入射
```

## 2. 完整跑法（5 步）

### 步骤 1: setup（关键参数选择）

```bash
cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8

./setup LaserSlab -2d -auto +cylindrical \
  -nxb=16 -nyb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 \
  -objdir=cases/LaserSlab -parfile=example.par
```

**每个 setup 参数为什么（L-011）**：

| 参数 | 作用 | 为什么这么用 |
|---|---|---|
| `LaserSlab` | 选算例 | HEDP 平面靶标准 |
| `-2d` | 二维 | HEDP 平面靶轴对称，2D 足够；3D 太贵 |
| `-auto` | 跳过交互 | 自动用 Config DEFAULT |
| `+cylindrical` | 圆柱 (r, z) | 平面靶轴对称，圆柱比笛卡尔省一半 CPU |
| `-nxb=16 -nyb=16` | block 16×16 | Paramesh 标准块，AMR 单元 |
| `+hdf5typeio` | HDF5 IO | 默认非 HDF5；HEDP 后处理要 HDF5 |
| `species=cham,targ` | 2 物质 | cham=腔体（低 Z），targ=靶（高 Z）|
| `+mtmmmt` | multi-temp EOS | HEDP 必须 3T（Tele/Tion/Trad 分开）|
| `+laser` | 激光沉积 | HEDP 核心物理 |
| `+uhd3t` | unsplit Hydro + 3T | 主流 Hydro（vs split，不适用 3T）|
| `+mgd` | 多群扩散辐射 | HEDP 辐射传输主流 |
| `mgd_meshgroups=6` | 6 群辐射 | 调试用（生产用 70+ 群）|
| `-objdir=cases/LaserSlab` | 构建目录 | 本机约定 |
| `-parfile=example.par` | 复制 example.par 作 flash.par | LaserSlab 的标准 parfile |

**注意 L-009**：不要相信 `example.par` 顶部 setup 注释，看 `cases/LaserSlab/setup_call`。

### 步骤 2: 检查 setup 产物

```bash
cd cases/LaserSlab

# 1. 验证 setup_call 记录正确
cat setup_call

# 2. 看 setup_flags 展开后的选项
cat setup_flags | head -20

# 3. 看 setup_defines 编译宏
cat setup_defines | head -10
# 应该看到 -DFLASH_3T、-DNXB=16 等

# 4. 看 Makefile.h 的 site 配置
grep -E "MPI_PATH|HDF5_PATH|HYPRE_PATH" Makefile.h
# 应该是 /home/ubuntu/local/flash/myFLASH4.8/*

# 5. 看 flash.par 是否复制过来
ls flash.par
```

### 步骤 3: make（含 libmpi 冲突处理）

```bash
cd cases/LaserSlab

# 本机 libmpi 冲突处理（关键，否则 ld warning + 运行时 SIGSEGV）
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak

# 编译（4 核约 3-5 分钟）
make -j4 2>&1 | tee make.log

# 恢复 libmpi.so.40
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40

# 验证 flash4 生成
ls -lh flash4
# 应该看到 -rwxrwxr-x ... 50M+ ... flash4

# 验证链接
ldd flash4 | grep -E "mpi|hdf5|HYPRE"
# 应该看到 mpich 的 libmpi.so.12（不是 libmpi.so.40）
```

**典型编译时间**：3-5 分钟（4 核）。

**make.log 应该看到**：
- 大量 `gfortran ... .F90 -o .o` 行
- 末尾一行 `mpif90 ... -o flash4`
- 可能有 `libmpi.so.40 may conflict` warning（**这是预期的**，因为我们 mv 了 .40 但 ld 缓存可能仍找到——只要能生成 flash4 就 OK）

### 步骤 4: run（关键：source flash_env.sh）

```bash
cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8

# 必须先 source flash_env.sh（设 LD_PRELOAD 避免 libmpi 冲突）
source flash_env.sh

# 应该看到：
# MPI:  MPICH ...
# LD_PRELOAD:    /home/ubuntu/local/flash/myFLASH4.8/mpich/lib/libmpi.so

cd cases/LaserSlab

# 后台跑（推荐——长算例）
nohup mpirun -np 2 ./flash4 -parfile=flash.par > flash.log 2>&1 &
FLASH_PID=$!
echo "FLASH PID: $FLASH_PID"

# 跟踪进度
tail -f flash.log
# Ctrl-C 退出 tail（不杀 flash4）

# 检查是否还在跑
ps -p $FLASH_PID
```

**前台跑（短测试用）**：
```bash
source /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/flash_env.sh
cd cases/LaserSlab
mpirun -np 2 ./flash4 -parfile=flash.par 2>&1 | tee flash.log
```

**2026-08-02 实战验证结果**：
- `mpirun -np 2` 正常启动（之前不 source flash_env.sh 会 SIGSEGV in Driver_initParallel.F90:92）
- 66 步跑完
- checkpoint + plotfile 正常写入
- 零 MPI 错误

### 步骤 5: 看结果

```bash
cd cases/LaserSlab

# 1. 看日志最后几行
tail -10 flash.log
# 应该看到："Simulation completed successfully" 或仍在跑

# 2. 看 simTime 推进
grep -i "simTime" flash.log | tail -10

# 3. 看 dt 演化（应该缓慢变化）
grep -E "^\s*dt" flash.log | tail -10

# 4. 看 block 数（AMR 加密情况）
grep -i "leaf block\|total block" flash.log | tail -10

# 5. 看 plotfile / checkpoint 写入次数
ls *_hdf5_plt_*.h5 | wc -l
ls *_hdf5_chk_*.h5 | wc -l

# 6. 看 NaN（应该没有）
grep -i "nan\|below floor" flash.log | head
```

**用 examples/flash_log_parser.sh 自动解析**：
```bash
bash /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/.claude/skills/flash-case-runner/examples/flash_log_parser.sh cases/LaserSlab/flash.log
```

## 3. LaserSlab parfile 关键参数

`example.par` 关键段（详见 `flash-laser` / `flash-eos` / `flash-radtrans` / `flash-sourceterms` skill）：

```fortran
# 几何 & domain
geometry = "cylindrical"
xmin = 0.0
xmax = 0.03    # 3 cm
ymin = 0.0
ymax = 0.05    # 5 cm

# AMR
lrefine_min = 1
lrefine_max = 4
nblockx = 1
nblocky = 2

# 物质（自动从 species=cham,targ 来）
# Multispecies 自动生成 ms_chamA/Z/eos_chamEosType/...

# 激光
useLaser = .true.
ed_maxPulseSections = 50
ed_numberOfBeams = 1
ed_beamEdgeOffset = ...
# 详见 flash-laser skill

# MGD
useRadTrans = .true.
mgd_meshgroups = 6
# 详见 flash-radtrans skill

# Heatexchange
useHeatexchange = .true.
hx_dtFactor = 1e100    # 禁用 HX dt 限制（详见 flash-sourceterms）
# 详见 flash-sourceterms skill

# 时间步
hydro_cfl = 0.4
sim_maxTime = 1.0e-9   # 跑到 1 ns
sim_maxSteps = 100000  # 上限保险

# IO
plot_plotFileIntervalTime = 1.0e-11  # 每 10 ps 写 plotfile
chk_checkpointFileIntervalTime = 5.0e-11  # 每 50 ps 写 checkpoint
basenm = "LaserSlab"
```

## 4. 常见坑

### 4.1 libmpi 冲突（核心痛点）

**症状**：编译时 ld warning，运行时 SIGSEGV in Driver_initParallel.F90:92。

**修复**：
- 编译期：sudo mv libmpi.so.40（步骤 3 已做）
- 运行期：source flash_env.sh（步骤 4 已做）

**详细**：见 `knowledge/make_guide.md §3` + `agent/pitfalls/libmpi-conflict.md`。

### 4.2 example.par 顶部 setup 注释错（L-009）

**症状**：按 `example.par` 顶部注释 setup，跑出来不对。

**修复**：以 `cases/LaserSlab/setup_call` 为准（本 recipe 步骤 1 的命令就是从 setup_call 提取的）。

### 4.3 EOS 表超范围 abort

**错误**：`[Multitype]: requested EOS point is outside of the table bounds`

**原因**：算例某处密度/温度超过 EOS 表（`.cn4` 文件）的范围。

**修复**：
```bash
# 看哪一步炸
grep -B5 "Multitype" cases/LaserSlab/flash.log | head -20

# 调 parfile 的 floor
# sim_rhoMin = 1.0e-3  # 物理单位
# sim_teleMin = 1.0    # K
```

### 4.4 激光参数错（ed_xxx abort）

**错误**：`[ed_setupBeams]: Not enough beam runtime parameters`

**修复**：见 `flash-laser` skill。

### 4.5 dt 太小，跑不完

**症状**：dt 持续变小，simTime 推进慢。

**可能原因**：
- 激光沉积过强（功率太高）→ 降 ed_laserPower
- AMR 加密太多 → 降 lrefine_max
- CFL 太保守 → hydro_cfl 升到 0.5（但不要超过 0.8）

### 4.6 plotfile 太大，磁盘满

**症状**：写到一半磁盘满，后续 IO 失败。

**修复**：
```bash
# 看磁盘
df -h .

# 减少 plotfile 频率
# parfile: plot_plotFileIntervalTime = 1.0e-10  # 每 100 ps
```

### 4.7 跑出 NaN

**修复**：见 `knowledge/pitfalls.md §3.8` + `flash-pitfall-finder`。

## 5. 一键脚本

见 `examples/run-laser-slab.sh`：
```bash
bash /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/.claude/skills/flash-case-runner/examples/run-laser-slab.sh
```

## 6. 验证标准（2026-08-02 实战）

跑通后应该：
- [ ] `flash4` 生成（50+ MB）
- [ ] `mpirun -np 2` 启动正常（不 SIGSEGV）
- [ ] `flash.log` 含初始化信息（beam setup / species / MGD groups）
- [ ] 至少 5+ plotfile 生成
- [ ] 至少 1+ checkpoint 生成
- [ ] 没有 NaN / abort
- [ ] simTime 单调递增

## 7. 变体（简要）

### 3D 算例

```bash
./setup LaserSlab -3d -auto +cartesian \
  -nxb=16 -nyb=16 -nzb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 \
  -objdir=cases/LaserSlab_3d -parfile=example3d.par
```

注意：3D 比 2D 慢 10-20 倍。

### 3Din2D（旋转 2D 算例模拟 3D）

```bash
./setup LaserSlab -2d -auto +cylindrical ... -parfile=3Din2D.par
```

### Coldstart（冷启动，从低能量 ramp up）

```bash
./setup LaserSlab -2d ... -parfile=coldstart_pm_rz.par
```

### 多物质（如 Sunliang）

```bash
./setup Sunliang_laser_CH -2d -auto +pm4dev \
  -geometry=cylindrical -nxb=16 -nyb=16 \
  +mtmmmt +laser +mgd +uhd3t \
  species=cham,targ1,targ2,targ3 mgd_meshgroups=6 \
  -parfile=example_xubo.par \
  -objdir=cases/Sunliang_laser_CH
```

见 `recipes/sunliang-laser-CH.md`。

## 8. 关联

- 详细操作：`knowledge/overview.md` + `setup_guide.md` + `make_guide.md` + `run_guide.md` + `pitfalls.md`
- 一键脚本：`examples/run-laser-slab.sh`
- 激光物理：`flash-laser` skill
- MGD 物理：`flash-radtrans` skill
- 3T/EOS：`flash-eos` skill
- Heatexchange：`flash-sourceterms` skill
- Multispecies（species= 触发什么）：`flash-multispecies` skill
- LaserSlab 源码：`source/Simulation/SimulationMain/LaserSlab/`
