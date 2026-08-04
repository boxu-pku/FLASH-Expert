---
title: setup shortcut 全量展开表——每个 +foo 等价于什么 --with-unit
skill: flash-setup-builder
category: reference
source_anchors:
  - bin/setup_shortcuts.txt
---

# setup shortcut 全量展开表

> 本文翻译 `bin/setup_shortcuts.txt` 全部 225 行，**每个 shortcut 给出原始定义 + 展开后命令 + 何时用**。
> 按 L-013 聚焦 HEDP 主流（laser/mgd/uhd3t/mtmmmt/hdf5typeio）详讲，其他简表。

## 1. shortcut 是什么（L-014：先解释）

**shortcut** = `bin/setup_shortcuts.txt` 里定义的、把一串 `--with-unit=...` / `-unit=...` 压缩成单个 `+name` 的别名。

**为什么存在**：一条 setup 命令如果要包含激光，原本要写：
```bash
./setup LaserSlab ... \
  -unit=physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser \
  -without-unit=Particles
```

太长。shortcut 让你写 `+laser` 就等价。

**怎么用**：setup.py 看到 `+foo` 时，去 `setup_shortcuts.txt` 查 `foo`，找到一行：
```
foo:展开1:展开2:...
```
把它替换成 `展开1 展开2 ...`。

**shortcut 可以互相引用**：如 `usm3t` 的定义引用 `+3t +usm`，setup.py 会递归展开。

## 2. default shortcut（永远生效，不用写）

`setup_shortcuts.txt` 第一段：
```
default:--with-library=mpi:+io:+grid:-gridinterpolation=monotonic:FlashAvoidOrrery=True
```

**含义**：每条 setup 命令**自动**加上这 5 个选项（即使用户不写）：

| 自动加的选项 | 作用 |
|---|---|
| `--with-library=mpi` | 链接 MPI 库 |
| `+io` | 包含 IO 单元 |
| `+grid` | 包含 Grid 单元 |
| `-gridinterpolation=monotonic` | 用 monotonic 插值（AMR prolongation）|
| `FlashAvoidOrrery=True` | 跳过 Orrery（旧 Grid 后端兼容）|

**所以** `./setup Sedov -auto` 实际等价于：
```bash
./setup Sedov --with-library=mpi --with-unit=IO --unit=Grid \
  -gridinterpolation=monotonic FlashAvoidOrrery=True --auto
```

这就是为什么 Sedov 命令那么短——靠 default shortcut 隐含加了 IO/Grid/MPI。

## 3. HEDP 主流 shortcut（详讲）

### 3.1 +laser —— 激光沉积

**原始定义**：
```
laser:-unit=physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser:-without-unit=Particles
```

**展开后**：
```bash
-unit=physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser \
-without-unit=Particles
```

**含义**：
- 包含激光能量沉积单元（EnergyDeposition/Laser）
- **移除 Particles 单元**——因为 Laser 单元和 Particles 共用一些 slot，互斥

**何时用**：HEDP 激光打靶算例必加。

**变体**（少用）：
| shortcut | 用途 |
|---|---|
| `+laserCubicInterpolation` | 立方插值 + PPAR Ray Tracing |
| `+laserCubicInterpolationRK` | 立方插值 + Runge-Kutta Ray Tracing |
| `+asyncLaser` | 异步通信（实验性）|

### 3.2 +mgd —— 多群扩散辐射

**原始定义**：
```
mgd:-unit=physics/materialProperties/Opacity:-unit=physics/RadTrans/RadTransMain/MGD
```

**展开后**：
```bash
-unit=physics/materialProperties/Opacity \
-unit=physics/RadTrans/RadTransMain/MGD
```

**含义**：
- 包含 Opacity 单元（不透明度——辐射吸收系数）
- 包含 MGD（MultiGroup Diffusion）辐射输运单元

**注意**：MGD 通过 Diffuse_solveScalar 调 HYPRE 求解大稀疏矩阵。所以 Makefile.h 必须有 `HYPRE_PATH`。

**何时用**：HEDP 辐射流体算例必加（vs flux-limited diffusion 灰体）。

### 3.3 +uhd —— unsplit Hydro

**原始定义**：
```
uhd:--with-unit=physics/Hydro/HydroMain/unsplit/Hydro_Unsplit:-without-unit=physics/Hydro/HydroMain/split
```

**展开后**：
```bash
--with-unit=physics/Hydro/HydroMain/unsplit/Hydro_Unsplit \
-without-unit=physics/Hydro/HydroMain/split
```

**含义**：
- 包含 unsplit Hydro（Hydro_Unsplit——守恒律无分裂求解）
- **移除 split Hydro**（HydroMain/split——老版本分裂求解）

**何时用**：unsplit Hydro 是现代主流（CTU + MUSCL-Hancock）。split Hydro 是老版本（Strang splitting），不能处理 3T。

### 3.4 +3t —— 三温模式

**原始定义**：
```
3t:ThreeT=1:-defines=FLASH_3T
```

**展开后**：
```bash
ThreeT=1 -defines=FLASH_3T
```

**含义**：
- 设 setup-variable `ThreeT=1`
- 加编译宏 `-DFLASH_3T`（让 Fortran 代码 `#ifdef FLASH_3T` 段生效）

**何时用**：3T 算例（Tele/Tion/Trad 独立演化）。HEDP 必加。

**变体**：
| shortcut | 用途 |
|---|---|
| `+3tr` | Radiation-Flux-Limiter-Aware-Hydro 变体的 3t |

### 3.5 +uhd3t —— unsplit + 3T 组合（HEDP 主力）

**原始定义**：
```
uhd3t:+3t:+uhd
```

**展开后**（递归展开）：
```bash
ThreeT=1 -defines=FLASH_3T \
--with-unit=physics/Hydro/HydroMain/unsplit/Hydro_Unsplit \
-without-unit=physics/Hydro/HydroMain/split
```

**含义**：`+3t` + `+uhd` 组合。HEDP 标准组合。

**何时用**：HEDP 主流。LaserSlab / Sunliang 都用。

**变体**：
| shortcut | 用途 |
|---|---|
| `+uhd3tr` | uhd3t + flux-limiter-aware |
| `+usm3t` | 3t + unsplit MHD（MHD 算例）|
| `+usm3tr` | usm3t + flux-limiter-aware |

### 3.6 +mtmmmt —— multi-temp EOS multi-type

**原始定义**：
```
mtmmmt:-unit=physics/Eos/EosMain/multiTemp/Multitype:-unit=physics/Eos/EosMain/Tabulated:Mtmmmt=True
```

**展开后**：
```bash
-unit=physics/Eos/EosMain/multiTemp/Multitype \
-unit=physics/Eos/EosMain/Tabulated \
Mtmmmt=True
```

**含义**：
- 包含 multiTemp/Multitype EOS 单元（让每种物质用不同 EOS 类型）
- 包含 Tabulated EOS（表查找，支持 IONMIX4 / SESAME）
- 设 `Mtmmmt=True`（让其他代码知道 mtmmmt 模式开）

**何时用**：3T 算例必加。和 `+uhd3t` 一起用。

### 3.7 +hdf5typeio —— HDF5 类型化 IO

**原始定义**：
```
hdf5TypeIO:+io:+parallelIO:+hdf5:typeIO=True
```

**展开后**（递归）：
```bash
# 先展开 +io:
--with-unit=IO
# 再展开 +parallelIO:
parallelIO=True
# 再展开 +hdf5:
IO=hdf5
# 最后:
typeIO=True
```

合起来：
```bash
--with-unit=IO parallelIO=True IO=hdf5 typeIO=True
```

**含义**：
- 包含 IO 单元
- 用并行 IO（parallelIO=True）
- 用 HDF5 后端（IO=hdf5）
- 类型化 IO（typeIO=True——每变量单独 HDF5 dataset）

**何时用**：HEDP 主流。后处理用 Visit / h5py 必加。

## 4. Grid backend shortcut

### 4.1 +pm4dev（默认 AMR backend）

**原始定义**：
```
pm4dev_basic:+grid:Grid=PM4DEV
pm4dev:+pm4dev_basic:FlashAvoidOrrery=True
```

**展开后**（递归）：
```bash
# +grid 展开:
-unit=Grid
# pm4dev_basic 加:
Grid=PM4DEV
# pm4dev 加:
FlashAvoidOrrery=True
```

合起来：
```bash
-unit=Grid Grid=PM4DEV FlashAvoidOrrery=True
```

**含义**：
- 包含 Grid 单元
- 用 Paramesh 4 dev backend
- 跳过 Orrery 兼容

**何时用**：99% AMR 算例（HEDP 主流）。

**相关**：
| shortcut | 用途 |
|---|---|
| `+pm4dev_clean` | 接近 sourceforge 原版的 Paramesh |
| `+pm4dev_fixed` | 固定 block 模式 |
| `+pm2` | Paramesh 2（老版本）|
| `+pm40` | Paramesh 4.0 |

### 4.2 +ug —— Uniform Grid

**原始定义**：
```
ug:+grid:Grid=UG:
```

**展开后**：
```bash
-unit=Grid Grid=UG
```

**何时用**：PIC / FFT-Poisson / 不需要 AMR 的算例。

### 4.3 +chombo_amr —— Chombo AMR

**原始定义**：
```
chombo_amr:-unit=Grid/GridMain/Chombo/AMR:-index-reorder:Grid=Chombo:-nofbs:-makefile=chombo:chomboCompatibleHydro=True
```

**何时用**：嵌入式边界（半成熟）。少用。

## 5. 几何 shortcut

```
cartesian:-geometry=cartesian
spherical:-geometry=spherical
polar:-geometry=polar
cylindrical:-geometry=cylindrical
curvilinear:-curvilinear
```

**用法**：`+cylindrical` 等价于 `-geometry=cylindrical`。两种写法都可。

## 6. MHD shortcut（HEDP 不常用）

### 6.1 +usm —— unsplit MHD

**原始定义**：
```
usm:--with-unit=physics/Hydro/HydroMain/unsplit/MHD_StaggeredMesh:--without-unit=physics/Hydro/HydroMain/split/MHD_8Wave:MHD=True
```

**含义**：unsplit staggered mesh MHD（约束传输 CT），移除 8wave MHD。

**何时用**：MHD 算例的主流选择。

### 6.2 +8wave —— Powell 8-wave MHD

**原始定义**：
```
8wave:--with-unit=physics/Hydro/HydroMain/split/MHD_8Wave:+grid:-gridinterpolation=native:MHD=True
```

**含义**：split + Powell 8-wave MHD。强制用 native 插值（8wave 不兼容 monotonic）。

**何时用**：老版本 MHD 算例。新算例用 `+usm`。

### 6.3 +usm3t —— 3T + unsplit MHD

**原始定义**：
```
usm3t:+3t:-without-unit=physics/Hydro/HydroMain/split:+usm
```

**何时用**：MHD + 3T 算例（如磁化激光等离子体）。

## 7. Block 大小 shortcut

```
cube16:-nxb=16:-nyb=16:-nzb=16:
cube32:-nxb=32:-nyb=32:-nzb=32:
cube64:-nxb=64:-nyb=64:-nzb=64:
```

**用法**：3D 算例用 `+cube16` 等价于 `-nxb=16 -nyb=16 -nzb=16`。

## 8. Threading（OpenMP）shortcut

```
threadBL:threadWithinBlock=0:threadBlockList=True:-defines=FLASH_OPENMP=1
threadwB:threadWithinBlock=True:threadBlockList=0:-defines=FLASH_OPENMP=1
threadRT:threadRayTrace=True:-defines=FLASH_OPENMP=1
threadPT:threadProtonTrace=True:-defines=FLASH_OPENMP=1
```

**何时用**：优化算例（OpenMP 多线程）。HEDP 罕见。

## 9. 重力 shortcut

```
mpole:-with-unit=physics/Gravity/GravityMain/Poisson/Multipole
gravPfftNofbs:+ug:+nofbs:-with-unit=physics/Gravity/GravityMain/Poisson/Pfft:
gravMgrid:+pm4dev:-with-unit=physics/Gravity/GravityMain/Poisson/Multigrid:
gravMpole:-with-unit=physics/Gravity/GravityMain/Poisson/Multipole:
newMpole:+noMgrid:+noDefaultMpole:+gravMpole:-with-unit=Grid/GridSolvers/Multipole_new
```

**何时用**：自重力算例（如 CCSN、DustCollapse）。

## 10. 物质相关 shortcut

### 10.1 +multif —— Multifluid（替代 Multispecies）

**原始定义**：
```
multif:--with-unit=Multifluid/MultifluidMain:-without-unit=Multispecies/MultispeciesMain
```

**何时用**：用 Multifluid 替代 Multispecies（少用，主流是 Multispecies）。

### 10.2 +mg —— Multigamma EOS

**原始定义**：
```
mg:--with-unit=physics/Eos/EosMain/Multigamma
```

**何时用**：多种 gamma 气体（如 He + 重气体）。

## 11. IO 相关 shortcut

```
noio:--without-unit=physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserIO:--without-unit=IO:
io:--with-unit=IO:
serialIO:parallelIO=False:
parallelIO:parallelIO=True:
hdf5:IO=hdf5:
pnetcdf:IO=pnetcdf:
hdf5TypeIO:+io:+parallelIO:+hdf5:typeIO=True
pnetTypeIO:+io:+parallelIO:+pnetcdf:typeIO=True
nolog:-without-unit=monitors/Logfile:
```

**主流**：`+hdf5typeio`（HEDP 主力）。其他少用。

## 12. 调试 shortcut

```
mcheck:use_mcheck=True:--defines=MCHECK:--with-unit=source/monitors/Debugger/DebuggerMain/mcheck
dmalloc:use_dmalloc=True:--defines=DMALLOC:--with-unit=source/monitors/Debugger/DebuggerMain/dmalloc
ddt:use_ddt=True:--defines=DDT:--with-unit=source/monitors/Debugger/DebuggerMain/dmalloc
```

**何时用**：内存调试。mcheck 是 glibc 自带；dmalloc/ddt 是 ARM 工具。

## 13. MPI shortcut

```
mpi1:mpi1=True:-defines=FLASH_MPI1
mpi2:mpi2=True:-defines=FLASH_MPI2
mpi3:mpi3=True:-defines=FLASH_MPI3
libnbc:--with-library=libNBC:useLibNBC=True:-defines=FLASH_LIBNBC:+mpi3
```

**何时用**：用 MPI 新功能（如 MPI-3 shared memory）。少用。

## 14. 诊断 shortcut

```
protonImaging:-unit=diagnostics/ProtonImaging:-without-unit=Particles
protonEmission:-unit=diagnostics/ProtonEmission:-without-unit=Particles
xrayImaging:-unit=diagnostics/XrayImaging:-without-unit=Particles
ThomsonScattering:-unit=diagnostics/ThomsonScattering:-without-unit=Particles
ThomsonScatteringNrt:+ThomsonScattering:-unit=diagnostics/ThomsonScattering/ThomsonScatteringMain/NoRayTracing
ThomsonScatteringWrt:+ThomsonScattering:-unit=diagnostics/ThomsonScattering/ThomsonScatteringMain/WithRayTracing
```

**何时用**：HEDP 实验诊断（质子成像、X 射线成像、Thomson 散射）。

## 15. PIC shortcut

```
pic:+ug:-unit=Grid/GridParticles/GridParticlesMove:-without-unit=Grid/GridParticles/GridParticlesMove/UG:-without-unit=Grid/GridParticles/GridParticlesMove/UG/Directional
```

**何时用**：PIC 算例（FLASH 较少）。

## 16. GPU shortcut

```
cuda:CUDA=1:--defines=FLASH_HYPRE_CUDA:--with-unit=source/Grid/GridSolvers/HYPRE/CUDA
```

**何时用**：用 GPU 加速 HYPRE（实验性）。

## 17. API shortcut

```
cppapi:cppAPI=1:-cppapi:--with-unit=source/Cpp/CppMain
python:python=1:-pyflash:--with-unit=source/Python/PythonMain:+cppapi
```

**何时用**：用 C++ / Python API（嵌入 FLASH 到其他程序）。少用。

## 18. 其他 shortcut 速查表

| shortcut | 作用 |
|---|---|
| `+nolog` | 不包含 Logfile 单元 |
| `+tryAltFiles` | 用 alternativeFiles 机制 |
| `+ptdens` | 用 WithDensity 粒子初始化 |
| `+npg` | NO_PERMANENT_GUARDCELLS 模式 |
| `+vof` | Volume of Fluid 方法 |
| `+supportPPMUpwind` | PPM Upwind 重构（需要 nxb ≥ 12）|
| `+supportGP` | GP 重构（需要 LAPACK）|
| `+supportGPdivB` | GP 散度滤波 |
| `+supportAnisoCond` | 各向异性热传导 |
| `+heating3T` | 3T 加热模块 |
| `+pipeline` | 用 Pipeline 多进程工具 |
| `+ptio` | Particles + IO（UG 算例）|
| `+rnf` | 矩形 block 测试（-3d -nxb=8 -nyb=16 -nzb=32）|
| `+nofbs` | no fixed block size（UG 用）|
| `+dynamicmem-pm40` | PM40 运行时分配（实验）|

## 19. 验证 shortcut 展开的命令

想知道你的 `+foo` 展开后是什么，最简单方法：

```bash
# 1. 看 cases/<case>/setup_call ——Expanded Command line 段就是展开后
grep -A 1 "Expanded Command line" cases/LaserSlab/setup_call

# 2. 或者直接 setup 时加 -v 看 verbose 输出
./setup <算例> [opts] -auto -v -objdir=/tmp/test_setup 2>&1 | grep "with-unit\|without-unit"

# 3. 或者直接查 bin/setup_shortcuts.txt
grep "^<shortcut名>:" bin/setup_shortcuts.txt
```

## 20. 速查：HEDP 主流 shortcut 组合

LaserSlab / Sunliang 等标准 HEDP 算例用的 shortcut 集合：

```bash
./setup <HEDP算例> -2d -auto \
  +cylindrical \           # 几何（轴对称）
  -nxb=16 -nyb=16 \        # Block 大小（主流）
  +hdf5typeio \            # IO 后端（HDF5）
  species=cham,targ \      # 物质（HEDP 标准）
  +mtmmmt \                # multi-temp EOS
  +laser \                 # 激光
  +uhd3t \                 # unsplit Hydro + 3T
  +mgd \                   # 多群扩散辐射
  mgd_meshgroups=6 \       # 辐射群数（调试 6 / 生产 70）
  -parfile=example.par \   # parfile
  -objdir=cases/<算例>
```

每个 shortcut 的展开见上文。
