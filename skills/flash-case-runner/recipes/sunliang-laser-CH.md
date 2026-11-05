---
title: Sunliang_laser_CH 算例——自定义多物质跑法
skill: flash-case-runner
category: recipe
case: Sunliang_laser_CH
difficulty: 中等-进阶
estimated_time: 30 分钟 - 数小时
physics: 多物质（4 species）+ 3T + 激光 + MGD + CHBr 不透明度表
based_on: LaserSlab（派生）
---

# Sunliang_laser_CH 算例配方
> 路径约定：`$FLASH_ROOT` = FLASH 4.8 仓库根目录（本机 `/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8`）；`$FLASH_LIBS` = 外部库根目录（本机 `/home/ubuntu/local/flash/myFLASH4.8`）。其它机器按实际路径替换。


> Sunliang_laser_CH 是用户**自定义算例**——基于 LaserSlab 派生，扩展为多物质 CH/CHBr 多层靶。
>
> **跑通这个算例的价值**：验证用户研究的实际配置（多 targ 物质 + CHBr 不透明度表 + 自定义 parfile）能跑通。

## 1. 算例物理简介

**Sunliang_laser_CH** = 激光打多层 CH/CHBr 平面靶。

**和 LaserSlab 的区别**：

| 特性 | LaserSlab | Sunliang_laser_CH |
|---|---|---|
| species 数 | 2 (cham, targ) | 4 (cham, targ1, targ2, targ3) |
| 靶结构 | 单层 | 多层（CH / CHBr / CH）|
| Grid backend | paramesh (默认) | PM4DEV（明确指定）|
| parfile | example.par | example_xubo.par（用户实测）|
| 不透明度表 | al/he-imx（铝/氦）| chBr-hyades.cn4 + CHBr-opacity.cn4（CHBr 自定义表）|

**物理**：和 LaserSlab 相同（多物质 + 3T + 激光 + MGD + Heatexchange）。

**几何**：2D 圆柱 (r, z)。

```
     z 轴
     ↑
     │   cham（腔体）
     │
─────┼─────────── targ1 (CH 外层)
     │              targ2 (CHBr 中层)  ← 高 Z 含 Br
     │              targ3 (CH 内层)
─────┼───────────→ r 轴
     │
     │   cham
     ↓
```

## 2. 完整跑法

### 步骤 1: setup

```bash
cd $FLASH_ROOT

./setup Sunliang_laser_CH -2d -auto +pm4dev \
  -geometry=cylindrical -nxb=16 -nyb=16 \
  +mtmmmt +laser +mgd +uhd3t \
  species=cham,targ1,targ2,targ3 mgd_meshgroups=6 \
  -parfile=example_xubo.par \
  -objdir=cases/Sunliang_laser_CH
```

**和 LaserSlab 的差异**（L-011 讲为什么）：

| 差异 | LaserSlab | Sunliang | 为什么 |
|---|---|---|---|
| Grid backend | 默认 paramesh | `+pm4dev`（明确）| PM4DEV 是 Paramesh 4 dev，更稳定 |
| 几何选项 | `+cylindrical` | `-geometry=cylindrical` | 等价（两种语法） |
| species | `species=cham,targ` | `species=cham,targ1,targ2,targ3` | 多层靶要 4 species |
| parfile | `example.par` | `example_xubo.par` | 用户实测 parfile（xubo=许博，用户名）|
| hdf5typeio | `+hdf5typeio` | 不需要 | 默认就是 HDF5（用户已固化）|

**注意**：Sunliang_laser_CH 的 Config 已修改支持 4 个 species（不像 LaserSlab 只支持 2 个）。

### 步骤 2: make

```bash
cd cases/Sunliang_laser_CH

# libmpi 冲突处理
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak

# 编译
make -j4 2>&1 | tee make.log

# 恢复
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40

# 验证
ls -lh flash4
```

**典型编译时间**：4-6 分钟（4 核，比 LaserSlab 稍慢——多物质开销）。

### 步骤 3: run

> **硬约束**：在 `cases/Sunliang_laser_CH/01-data/` 里启动——输出全落 01-data，objdir 根目录只留编译产物。

```bash
cd $FLASH_ROOT
source flash_env.sh

cd cases/Sunliang_laser_CH
mkdir -p 01-data && cd 01-data

# 后台跑（flash4 和 flash.par 在上一级，用 ../ 引用）
nohup mpirun -np 2 ../flash4 -par_file ../flash.par > flash.log 2>&1 &
tail -f flash.log
```

### 步骤 4: 看结果

```bash
cd cases/Sunliang_laser_CH/01-data

# 看进度
tail -20 flash.log

# 看 species 是否正确初始化
grep -A4 "Multispecies_init" flash.log | head -10
# 应该看到 cham/targ1/targ2/targ3 4 个物质

# 看激光束配置
grep "ed_.*beam" flash.log | head -10

# 看 plotfile / checkpoint
ls *_hdf5_plt_* | tail -5
ls *_hdf5_chk_* | tail -5
```

## 3. example_xubo.par 关键段

`example_xubo.par` 是用户实测 parfile（在 `source/Simulation/SimulationMain/Sunliang_laser_CH/`）。关键段：

```fortran
# 几何
geometry = "cylindrical"

# 物质配置（4 个 species 自动从 setup 触发）
# ms_chamA/Z/eos_chamEosType/...
# ms_targ1A/Z/eos_targ1EosType/... (CH)
# ms_targ2A/Z/eos_targ2EosType/... (CHBr)
# ms_targ3A/Z/eos_targ3EosType/... (CH)

# EOS 表
# cham: al-imx-003 (铝，作腔体)
# targ1/3: polystyrene-imx-008 (CH)
# targ2: chBr-hyades.cn4 (CHBr，含 Br 的不透明度)

# 激光
useLaser = .true.
# 详见 parfile
```

**注意**：parfile 顶部注释可能含 setup 命令提示，但**以 setup_call 为准**（L-009）。

## 4. 多物质算例的特殊坑

### 4.1 species 名不一致

**症状**：setup 成功但跑时 abort `Multispecies: species X not found`。

**原因**：parfile 里写的物质名和 setup 给的 species= 不一致。

**修复**：
```bash
# 看 parfile 用的物质名
grep -E "^ms_|^eos_" cases/Sunliang_laser_CH/flash.par | head -10
# 应该是 ms_cham, ms_targ1, ms_targ2, ms_targ3（小写）

# 看 setup 给的
cat cases/Sunliang_laser_CH/setup_call | grep species
# species=cham,targ1,targ2,targ3

# 名字要完全一致（大小写敏感）
```

### 4.2 EOS 表路径错

**症状**：跑时 abort `cannot open EOS table: chBr-hyades.cn4`。

**原因**：表文件没复制到 objdir。

**修复**：
```bash
# 1. 看 setup_datafiles 列出哪些表
cat cases/Sunliang_laser_CH/setup_datafiles

# 2. 看实际表文件
ls cases/Sunliang_laser_CH/*.cn4

# 3. 如果缺，从源码复制
cp source/Simulation/SimulationMain/Sunliang_laser_CH/chBr-hyades.cn4 cases/Sunliang_laser_CH/
```

### 4.3 物质比例 Xfluid 不为 1

**症状**：跑时 abort `Sum of mass fractions != 1`。

**原因**：初始条件里每个 cell 的物质比例和不为 1。

**修复**：看 `Simulation_initBlock.F90` 的物质初始化逻辑。

### 4.4 AMR refine 时物种边界处理

**症状**：在物质边界（cham-targ 接触面）出现 NaN。

**原因**：AMR 加密时不同物种比例插值不稳。

**修复**：
- 调 parfile AMR 阈值
- 用 `conserve_mass_fractions = .true.`（如可用）
- 详见 `flash-multispecies` skill

## 5. 一键脚本（参考 LaserSlab）

Sunliang 算例没有专门的一键脚本（参考 `examples/run-laser-slab.sh` 修改）：

```bash
#!/bin/bash
# 自定义 run-sunliang.sh（参考 run-laser-slab.sh）
cd $FLASH_ROOT
source flash_env.sh
cd cases/Sunliang_laser_CH
mkdir -p 01-data && cd 01-data   # 硬约束：在 01-data/ 里跑
nohup mpirun -np 2 ../flash4 -par_file ../flash.par > flash.log 2>&1 &
tail -f flash.log
```

## 6. 验证标准

跑通后应该：
- [ ] `flash4` 生成
- [ ] 4 个 species 正确初始化（cham, targ1, targ2, targ3）
- [ ] EOS 表全部能读（`chBr-hyades.cn4` 等）
- [ ] 至少 5+ plotfile 生成
- [ ] 没有 NaN / abort
- [ ] 物质边界（cham-targ / targ1-targ2 / targ2-targ3）清晰可见

## 7. 关联

- 详细操作：本 skill 的 5 个 knowledge 文件
- 激光物理：`flash-laser` skill
- MGD 物理：`flash-radtrans` skill
- 3T/EOS：`flash-eos` skill
- Heatexchange：`flash-sourceterms` skill
- Multispecies：`flash-multispecies` skill
- 不透明度表（Conductivity/Opacity）：`flash-material` skill
- 源码：`source/Simulation/SimulationMain/Sunliang_laser_CH/`
- LaserSlab 基础（本算例派生自）：`recipes/laser-slab-2d.md`

## 8. 自定义算例怎么加（参考）

如果用户要加自己的算例（如 Sunliang_v2），参考 `setup_guide.md §6`：

```bash
# 1. 拷贝模板（推荐 LaserSlab 或 Sunliang）
cp -r source/Simulation/SimulationMain/Sunliang_laser_CH \
      source/Simulation/SimulationMain/<NewProblem>

# 2. 改 Config（如果改 species 数 / 物理选项）
vi source/Simulation/SimulationMain/<NewProblem>/Config

# 3. 改初始化代码
vi source/Simulation/SimulationMain/<NewProblem>/Simulation_initBlock.F90

# 4. 加 parfile 模板
cp source/Simulation/SimulationMain/Sunliang_laser_CH/example_xubo.par \
   source/Simulation/SimulationMain/<NewProblem>/example.par

# 5. 加新物质表（如需要）
cp <new_eos_table>.cn4 source/Simulation/SimulationMain/<NewProblem>/

# 6. setup + make + run
./setup <NewProblem> -2d -auto +pm4dev ... -objdir=cases/<NewProblem>
```

详细：见 `flash-setup-builder` skill（构造辅助）。
