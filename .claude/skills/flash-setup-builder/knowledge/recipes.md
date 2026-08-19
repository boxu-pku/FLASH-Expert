---
title: setup 命令配方——典型场景的完整命令 + 选项解释 + 变体建议
skill: flash-setup-builder
category: recipes
source_anchors:
  - cases/Sedov/setup_call
  - cases/LaserSlab/setup_call
  - cases/Sunliang_laser_CH/setup_call
---

# setup 命令配方

> 按 L-004 教学顺序组织：**最小可运行 → 典型 HEDP → 多物质 → 进阶/特殊**。
> 每个配方给：完整命令 + 每选项为什么用 + 变体建议 + 预检查。

## 目录

1. [Recipe 1: Sedov 最小可运行（验证环境）](#recipe-1-sedov-最小可运行验证环境)
2. [Recipe 2: LaserSlab HEDP 主流](#recipe-2-laserslab-hedp-主流)
3. [Recipe 3: Sunliang 多物质 HEDP](#recipe-3-sunliang-多物质-hedp)
4. [Recipe 4: Sod 1D 激波管](#recipe-4-sod-1d-激波管)
5. [Recipe 5: LaserSlab 3D（生产级）](#recipe-5-laserslab-3d生产级)
6. [Recipe 6: MHD 算例（usm3t）](#recipe-6-mhd-算例usm3t)
7. [Recipe 7: 自定义算例（从 LaserSlab 派生）](#recipe-7-自定义算例从-laserslab-派生)
8. [Recipe 8: Debug 模式（调 NaN）](#recipe-8-debug-模式调-nan)

---

## Recipe 1: Sedov 最小可运行（验证环境）

### 适用场景
- 第一次跑 FLASH，验证编译环境
- 学习 FLASH 最小工作流（setup → make → run）
- 不需要 MPI / HDF5 / HYPRE 任何外部库

### 完整命令

```bash
./setup Sedov -auto -objdir=cases/Sedov
```

### 命令拆解

| 部分 | 含义 | 为什么用 |
|---|---|---|
| `Sedov` | 位置参数，指定算例 | 球面对称爆炸，最小 Hydro 算例 |
| `-auto` | 跳过交互式提示 | 不写会进菜单，新手麻烦 |
| `-objdir=cases/Sedov` | 构建目录 | 本机约定 `cases/<算例>/` |

**为什么这么短**：
- default shortcut 自动加了 `--with-library=mpi +io +grid -gridinterpolation=monotonic FlashAvoidOrrery=True`
- Sedov 的 Config 默认用 paramesh（不用显式 `+pm4dev`）
- 默认 IO 是非 HDF5（不用显式 `+hdf5typeio`）—— 因为只验证编译，不后处理
- 默认 EOS 是 Gamma（单温，不用 `+3t +mtmmmt`）

### 预检查（运行前确认）

```bash
# 1. 确认源码在
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/Sedov/

# 2. 确认 sites/ares/ 存在（或 cases/Sedov/Makefile.h 已存在）
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/sites/ 2>/dev/null
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/cases/Sedov/Makefile.h
```

### 变体建议

```bash
# 1D 球对称版本（更快）
./setup Sedov -1d +spherical -auto -objdir=cases/Sedov_1d

# 3D 版本（更慢但更真实）
./setup Sedov -3d +cartesian -auto -objdir=cases/Sedov_3d

# 加 HDF5 输出（用于 Visit 后处理）
./setup Sedov -auto +hdf5typeio -objdir=cases/Sedov
```

### 后续步骤

```bash
cd cases/Sedov
make -j4
./flash4 -par_file flash.par
```

---

## Recipe 2: LaserSlab HEDP 主流

### 适用场景
- HEDP 激光打靶的标准算例
- 学习 HEDP 完整物理集（激光 + MGD + 3T + 多物质）
- 验证 MPI / HDF5 / HYPRE 全套环境

### 完整命令

```bash
./setup LaserSlab -2d -auto +cylindrical \
  -nxb=16 -nyb=16 \
  +hdf5typeio \
  species=cham,targ \
  +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 \
  -objdir=cases/LaserSlab \
  -parfile=example.par
```

### 命令拆解（每选项讲为什么）

| 选项 | 含义 | 为什么用 |
|---|---|---|
| `LaserSlab` | 位置参数 | HEDP 标准算例 |
| `-2d` | 2 维 | 平面靶轴对称——2D 圆柱 (r, z) 等价 3D 但省 CPU 一个量级 |
| `-auto` | 跳过交互 | HEDP 算例 Config 复杂，必加 |
| `+cylindrical` | 圆柱坐标 | 轴对称（平面靶旋转对称）—— `+cylindrical` 和 `-geometry=cylindrical` 等价 |
| `-nxb=16 -nyb=16` | Block 16×16 | 16 是 AMR 主流（边界损耗可接受 + AMR 灵活）|
| `+hdf5typeio` | HDF5 IO | HEDP 后处理用 Visit/h5py 必加 |
| `species=cham,targ` | 2 物质 | cham=腔体材料（如 CH）+ targ=靶材料（如 Au）|
| `+mtmmmt` | multi-temp EOS | 3T 算例必备（让每种物质用不同 EOS 类型）|
| `+laser` | 激光沉积 | HEDP 核心——激光逆韧致吸收 |
| `+uhd3t` | unsplit Hydro + 3T | unsplit Hydro 才支持 3T（split 不行）|
| `+mgd` | 多群扩散辐射 | HEDP 辐射输运主流（vs 灰体）|
| `mgd_meshgroups=6` | 辐射 6 群 | 调试用 6（生产用 70）|
| `-objdir=cases/LaserSlab` | 构建目录 | 本机约定 |
| `-parfile=example.par` | parfile | 复制 example.par → flash.par |

### 预检查（HEDP 必做）

```bash
# 1. 确认 HEDP 三件套（MPI / HDF5 / HYPRE）路径在 Makefile.h
grep -E "MPI_PATH|HDF5_PATH|HYPRE_PATH" cases/LaserSlab/Makefile.h
# 应输出（本机典型）:
# MPI_PATH = /home/ubuntu/local/flash/myFLASH4.8/mpich
# HDF5_PATH = /home/ubuntu/local/flash/myFLASH4.8/hdf5
# HYPRE_PATH = /home/ubuntu/local/flash/myFLASH4.8/hypre

# 2. 确认 parfile 在 source 下
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/LaserSlab/example.par

# 3. 确认 datafile 在（EOS 表 / Opacity 表）
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/LaserSlab/*.cn4
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/LaserSlab/*.imx
```

### 已知坑（必看）

1. **libmpi.so.40 冲突**（本机特有）：编译前要 `sudo mv /lib/x86_64-linux-gnu/libmpi.so.40{,.bak}`，编完再 mv 回——详见 `cases/NOTE.txt` 和 `pitfalls.md`
2. **example.par 在 4.6.2 版本有 bug**（L-009）：以 `setup_call` 为准验证 parfile，parfile 顶部 setup 注释可能过时
3. **`+laser` 需配 `ed_maxBeams` / `ed_maxPulses` 参数**：setup 不报错，运行时才报——parfile 必须有

### 变体建议

```bash
# 变体 A: 生产级辐射分辨率（mgd_meshgroups=70）
./setup LaserSlab -2d -auto +cylindrical \
  -nxb=16 -nyb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=70 \
  -objdir=cases/LaserSlab_prod \
  -parfile=example.par

# 变体 B: 3D 算例（极耗 CPU，生产用）
./setup LaserSlab -3d -auto +cartesian \
  -nxb=16 -nyb=16 -nzb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 \
  -objdir=cases/LaserSlab_3d \
  -parfile=3Din2D.par

# 变体 C: Coldstart（先跑等温初始化再加激光）
./setup LaserSlab -2d -auto +cylindrical \
  -nxb=16 -nyb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 \
  -objdir=cases/LaserSlab_coldstart \
  -parfile=coldstart.par
```

### 后续步骤

```bash
cd cases/LaserSlab
# 处理 libmpi 冲突（本机特有，详见 pitfalls.md）
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak
make -j4
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40

# 跑（单进程验证）
./flash4 -par_file flash.par

# 多进程
mpirun -np 4 ./flash4 -par_file flash.par
```

---

## Recipe 3: Sunliang 多物质 HEDP

### 适用场景
- 用户自定义算例（CH / CHBr 多层平面靶）
- 学习如何 setup 4 物质算例
- 学习 +pm4dev 显式声明（不依赖默认）

### 完整命令

```bash
./setup Sunliang_laser_CH -2d -auto +pm4dev \
  -geometry=cylindrical -nxb=16 -nyb=16 \
  +mtmmmt +laser +mgd +uhd3t \
  species=cham,targ1,targ2,targ3 \
  mgd_meshgroups=6 \
  -parfile=example_xubo.par \
  -objdir=cases/Sunliang_laser_CH
```

### 和 LaserSlab 的关键差异

| 差异点 | LaserSlab | Sunliang | 为什么 |
|---|---|---|---|
| Grid backend | 默认 paramesh | 显式 `+pm4dev` | 用户为明确不依赖默认 |
| 几何写法 | `+cylindrical` | `-geometry=cylindrical` | 两种等价，看个人偏好 |
| species 数 | 2（cham,targ）| 4（cham,targ1,targ2,targ3）| 多层靶 |
| parfile | example.par | example_xubo.par | 用户自定义 parfile |

**重要**：species 数从 2 改到 4 **不能只改 setup 命令**——必须改 Config 让它支持 4 物质。Sunliang_laser_CH 是改过 Config 的版本。

### 为什么用 4 物质

HEDP 多层靶的典型设计：
- `cham`：腔体材料（如 CH 低密度泡沫）
- `targ1`：第一层靶（如 CH 外层）
- `targ2`：掺杂层（如 CHBr——Br 增强辐射吸收）
- `targ3`：第二层靶（如 CH 内层）

每层有独立 EOS 表 + 不透明度表。

### 预检查

```bash
# 确认 Config 支持 4 species
grep -i "USESETUPVARS\|species" source/Simulation/SimulationMain/Sunliang_laser_CH/Config

# 确认 4 套 EOS 表 / Opacity 表都在
ls source/Simulation/SimulationMain/Sunliang_laser_CH/*.cn4
ls source/Simulation/SimulationMain/Sunliang_laser_CH/*.imx
```

### 后续步骤

同 Recipe 2（libmpi 冲突 + make + mpirun）。

---

## Recipe 4: Sod 1D 激波管

### 适用场景
- 验证 Hydro 求解器（Riemann 问题解析解对比）
- 不需要 EOS/辐射/激光，纯 Hydro
- 快（1D + 小域）

### 完整命令

```bash
./setup Sod -1d +cartesian -auto \
  +hdf5typeio \
  -objdir=cases/Sod \
  -parfile=default.par
```

### 命令拆解

| 选项 | 含义 | 为什么用 |
|---|---|---|
| `Sod` | 位置参数 | 经典 Sod 激波管 |
| `-1d` | 1 维 | Sod 本质是 1D Riemann 问题 |
| `+cartesian` | 直角坐标 | 平面一维 |
| `-auto` | 自动 | 标准 |
| `+hdf5typeio` | HDF5 IO | 后处理 |
| `-parfile=default.par` | 默认 parfile | 注意不是 example.par |

### 变体

```bash
# SodSpherical（球对称 Sod，验证球坐标 Hydro）
./setup SodSpherical -1d +spherical -auto -objdir=cases/SodSpherical

# Sod 2D（验证横向稳定性）
./setup Sod -2d +cartesian -auto +hdf5typeio -objdir=cases/Sod_2d
```

---

## Recipe 5: LaserSlab 3D（生产级）

### 适用场景
- 真实 3D 物理模拟（非轴对称现象，如激光打靶的 3D 不稳定性）
- 生产级辐射分辨率（mgd_meshgroups=70）
- 大算例（多节点 MPI）

### 完整命令

```bash
./setup LaserSlab -3d -auto +cartesian \
  -nxb=16 -nyb=16 -nzb=16 \
  +hdf5typeio \
  species=cham,targ \
  +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=70 \
  -maxBlocks=10000 \
  -parfile=3Din2D.par \
  -objdir=cases/LaserSlab_3d_prod
```

### 和 2D 主流版本的关键差异

| 差异点 | 2D 主流 | 3D 生产 | 为什么 |
|---|---|---|---|
| 维度 | `-2d` | `-3d` | 真实 3D 物理 |
| 几何 | `+cylindrical` | `+cartesian` | 3D 直角坐标（圆柱 3D 极少用）|
| `-nzb` | 不写（默认 1）| `-nzb=16` | 3D 必须显式 |
| `mgd_meshgroups` | 6（调试）| 70（生产）| 频率分辨率 |
| `-maxBlocks` | 默认 1000 | 10000+ | 大算例需要更多 block |

### 为什么 3D 极耗 CPU

- 维度从 2 到 3：cell 数 ×（N_z/N_block）= ×16
- mgd_meshgroups 从 6 到 70：辐射方程数 ×12
- 总耗时：2D 调试 → 3D 生产，~200 倍

### 预检查（生产级必做）

```bash
# 1. 确认 parfile 适配 3D（网格、边界、激光方向）
grep -E "N轴向|laser|ed_crossSectionFunction" cases/LaserSlab_3d_prod/flash.par | head -20

# 2. 估算内存
python -c "
nblocks = 10000
cells_per_block = 16**3
vars_per_cell = 20  # 估算
bytes = nblocks * cells_per_block * vars_per_cell * 8
print(f'每进程内存约 {bytes/1e9:.1f} GB（粗略估算）')
"

# 3. 测试小规模跑通
mpirun -np 4 ./flash4 -par_file flash.par  # 先 4 进程验证
```

---

## Recipe 6: MHD 算例（usm3t）

### 适用场景
- 磁化等离子体（如磁化激光等离子体、Z 箍缩）
- 需要约束传输（CT）保持 ∇·B = 0
- 配合 3T 模式

### 完整命令（magnetoHD 算例）

```bash
./setup magnetoHD -2d -auto +cartesian \
  -nxb=16 -nyb=16 \
  +hdf5typeio \
  +usm3t \
  -objdir=cases/magnetoHD \
  -parfile=default.par
```

### 命令拆解（重点讲 +usm3t）

**`+usm3t` 展开**（来自 shortcut_table.md）：
```
usm3t:+3t:-without-unit=physics/Hydro/HydroMain/split:+usm
```

递归展开为：
```bash
ThreeT=1 -defines=FLASH_3T \
-without-unit=physics/Hydro/HydroMain/split \
--with-unit=physics/Hydro/HydroMain/unsplit/MHD_StaggeredMesh \
--without-unit=physics/Hydro/HydroMain/split/MHD_8Wave \
MHD=True
```

含义：
- `+3t` 开 3T 模式
- 用 unsplit MHD（StaggeredMesh 约束传输）
- 移除 split Hydro 和 8wave MHD

### 变体

```bash
# 不带 3T（纯 MHD）
./setup magnetoHD -2d -auto +cartesian -nxb=16 -nyb=16 +hdf5typeio +usm \
  -objdir=cases/magnetoHD_pure

# 用 8wave（老版本 MHD）
./setup magnetoHD -2d -auto +cartesian -nxb=16 -nyb=16 +hdf5typeio +8wave \
  -objdir=cases/magnetoHD_8wave
```

### 注意

`+8wave` 用 Powell 8-wave 方法，强制 `-gridinterpolation=native`（不兼容 monotonic）。新算例推荐 `+usm`。

---

## Recipe 7: 自定义算例（从 LaserSlab 派生）

### 适用场景
- 用户要做 HEDP 算例但 LaserSlab 不满足（如不同物质、不同几何、不同激光配置）
- 学习如何新建算例

### 完整流程（5 步）

#### Step 1: 拷贝模板

```bash
cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
cp -r source/Simulation/SimulationMain/LaserSlab source/Simulation/SimulationMain/MyLaser
```

#### Step 2: 改 Config（如果改 species 数）

```bash
vi source/Simulation/SimulationMain/MyLaser/Config
# 找 USESETUPVARS 或 species 相关段，按需改
```

#### Step 3: 改初始化代码

```bash
vi source/Simulation/SimulationMain/MyLaser/Simulation_initBlock.F90
# 改初始密度、温度、物质分布
```

#### Step 4: 改 parfile 模板

```bash
cp source/Simulation/SimulationMain/MyLaser/example.par \
   source/Simulation/SimulationMain/MyLaser/my.par
vi source/Simulation/SimulationMain/MyLaser/my.par
# 改激光参数、网格、边界
```

#### Step 5: setup

```bash
./setup MyLaser -2d -auto +cylindrical \
  -nxb=16 -nyb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 \
  -objdir=cases/MyLaser \
  -parfile=my.par
```

### 详细教程

见 `CLAUDE.md` §"Adding a new problem (short version)" 和 `flash-case-runner/knowledge/setup_guide.md` §6。

---

## Recipe 8: Debug 模式（调 NaN）

### 适用场景
- 算例跑出 NaN，需要 `-O0 -g -ffpe-trap=... -fbounds-check` 立刻暴露问题
- 验证 parfile 改动正确
- 调 guard cell 越界

### 完整命令

```bash
./setup LaserSlab -2d -auto +cylindrical \
  -nxb=16 -nyb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 \
  -debug \
  -objdir=cases/LaserSlab_debug \
  -parfile=example.par
```

### 关键差异

| 选项 | 主流版本 | Debug 版本 | 为什么 |
|---|---|---|---|
| `-debug` | 不加 | **必加** | 切换 FFLAGS_OPT → FFLAGS_DEBUG（-O0 + 检查）|
| `-objdir` | `cases/LaserSlab` | `cases/LaserSlab_debug` | **分开 objdir**，不污染生产版 |

### -debug 加了什么

`Makefile.h` 里 `FFLAGS_DEBUG` 典型值（本机）：
```
-O0 -g -fbacktrace -ffpe-trap=invalid,zero,overflow -fbounds-check -fcheck=all
```

含义：
- `-O0`：不优化（避免优化掩盖 NaN）
- `-g`：调试符号
- `-fbacktrace`：崩溃时打印调用栈
- `-ffpe-trap=invalid,zero,overflow`：浮点异常立刻崩溃（NaN / 除零 / 溢出）
- `-fbounds-check`：数组越界立刻崩溃
- `-fcheck=all`：所有运行时检查

### 注意

- **`-debug` 必须重新 setup + make**：只 make 不行（因为 Makefile.h 的 FFLAGS 选择在 setup 时定）
- **慢 5-10 倍**：调试完记得去掉重 setup
- **objdir 分开**：建议 `cases/<case>_debug`，和生产版 `cases/<case>` 并存

---

## 速查：8 个配方对应的 setup 命令一行版

```bash
# R1 Sedov（最小）
./setup Sedov -auto -objdir=cases/Sedov

# R2 LaserSlab（HEDP 主流）
./setup LaserSlab -2d -auto +cylindrical -nxb=16 -nyb=16 +hdf5typeio species=cham,targ +mtmmmt +laser +uhd3t +mgd mgd_meshgroups=6 -objdir=cases/LaserSlab -parfile=example.par

# R3 Sunliang（多物质）
./setup Sunliang_laser_CH -2d -auto +pm4dev -geometry=cylindrical -nxb=16 -nyb=16 +mtmmmt +laser +mgd +uhd3t species=cham,targ1,targ2,targ3 mgd_meshgroups=6 -parfile=example_xubo.par -objdir=cases/Sunliang_laser_CH

# R4 Sod 1D
./setup Sod -1d +cartesian -auto +hdf5typeio -objdir=cases/Sod -parfile=default.par

# R5 LaserSlab 3D 生产
./setup LaserSlab -3d -auto +cartesian -nxb=16 -nyb=16 -nzb=16 +hdf5typeio species=cham,targ +mtmmmt +laser +uhd3t +mgd mgd_meshgroups=70 -maxBlocks=10000 -parfile=3Din2D.par -objdir=cases/LaserSlab_3d_prod

# R6 MHD
./setup magnetoHD -2d -auto +cartesian -nxb=16 -nyb=16 +hdf5typeio +usm3t -objdir=cases/magnetoHD -parfile=default.par

# R7 自定义（流程见 Recipe 7）

# R8 Debug
./setup LaserSlab -2d -auto +cylindrical -nxb=16 -nyb=16 +hdf5typeio species=cham,targ +mtmmmt +laser +uhd3t +mgd mgd_meshgroups=6 -debug -objdir=cases/LaserSlab_debug -parfile=example.par
```
