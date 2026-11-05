---
title: setup 常见错误与诊断引导
skill: flash-setup-builder
category: pitfalls
source_anchors:
  - bin/setup.py
  - cases/LaserSlab/setup_call
---

# setup 常见错误与诊断引导

> 按 L-012 两层结构组织：每个错误先**引导贴现场**，再展开**通用原因**。
> 按 L-013 聚焦高频错误（HEDP 主流路径遇到的）详讲，边缘错误简列。
> 报错根因不在 FLASH 源码（在 setup.py / 编译器 / 系统库）的，按 L-008 **不贴凑数代码**，详细讲机制。

## 目录

1. [SetupError: Unit not found / Ambiguous](#1-setuperror-unit-not-found--ambiguous)
2. [SetupError: Site '<hostname>' not found](#2-setuperror-site-hostname-not-found)
3. [SetupError: parfile 'X.par' not found](#3-setuperror-parfile-xpar-not-found)
4. [species 数量不匹配](#4-species-数量不匹配)
5. [setup_flags 里没看到期望的 -DFLASH_3T 等](#5-setup_flags-里没看到期望的--dflash_3t-等)
6. [libmpi.so.40 冲突警告](#6-libmpiso40-冲突警告)
7. [setup 过了但 make 失败（缺库）](#7-setup-过了但-make-失败缺库)
8. [边缘错误速查](#8-边缘错误速查)

---

## 1. SetupError: Unit not found / Ambiguous

### 错误形式

```
SetupError: Could not find Unit 'X' requested by 'Y'
```

或

```
SetupError: Ambiguous unit 'X' matches: [X1, X2, X3]
```

### Step 0：贴什么现场（按 L-012）

```bash
# 1. 完整错误信息
./setup <算例> [你的选项] -auto -objdir=<PATH> 2>&1 | tee /tmp/setup_err.log

# 2. 你指定的 setup-variables（看 setup.py 解析了什么）
grep -A 50 "Defined Setup Variables" /tmp/setup_err.log

# 3. 你想引用的 unit 在不在 source 下
find /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/ -name "Config" | xargs grep -l "<unit名>"
```

### 通用原因（按概率排序）

#### 原因 1：单元名拼错（最常见）

setup 区分大小写。例：`+Laser` 不行（shortcut 名小写），必须 `+laser`。

**验证**：
```bash
# 确认 shortcut 名在 setup_shortcuts.txt
grep "^laser:" /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/bin/setup_shortcuts.txt
```

#### 原因 2：setup-variable 没开

例：要激光但没加 `+laser`，setup 不会自动包含 Laser 单元。

**验证**：
```bash
# setup 后看 setup_flags 有没有相关 --with-unit=
grep -i "laser\|energydeposition" cases/<case>/setup_flags
```

#### 原因 3：算例 Config 路径错（少见）

算例目录被改名/移动后，setup 找不到 `SimulationMain/<算例>/Config`。

**验证**：
```bash
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/<算例>/Config
```

#### 原因 4：前缀匹配歧义（Ambiguous）

例：`./setup S` 能匹配 Sod / Sedov / SedovSelfGravity 等十几个——setup 报 Ambiguous。

**修**：写完整算例名 `./setup Sedov`。

### 怎么修

按上面 4 个原因对照修复。如果是 shortcut 名错，参考 `shortcut_table.md`。

---

## 2. SetupError: Site '<hostname>' not found

### 错误形式

```
SetupError: Site '<hostname>' not found in sites/ directory
```

### Step 0：贴什么现场

```bash
# 1. hostname
echo "Hostname: $(hostname)"

# 2. sites/ 目录有什么
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/sites/ 2>/dev/null || echo "sites/ 不存在"

# 3. 算例 Config 期望什么 site
grep -i "site\|hostname" /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/<算例>/Config
```

### 通用原因

**本机 ares 没有 `sites/ares/`**：FLASH 默认机制要求 `sites/<hostname>/Makefile.h`，本机不存在这个目录。

### 怎么修（按优先级）

#### 方案 A：创建 `sites/ares/`（一劳永逸）

```bash
mkdir -p /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/sites/ares
cp /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/cases/LaserSlab/Makefile.h \
   /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/sites/ares/Makefile.h
```

以后所有 setup 自动用这个 site。

#### 方案 B：从已有 case 手动复制（每次 setup）

```bash
./setup <NewCase> -auto -objdir=cases/<NewCase>  # 可能失败
cp /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/cases/LaserSlab/Makefile.h \
   /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/cases/<NewCase>/Makefile.h
./setup <NewCase> -auto -objdir=cases/<NewCase>  # 重 setup
```

### 详细原因

**site 是什么**（L-014）：一台机器的编译器/库路径配置，存为 `Makefile.h`。FLASH 编译时需要知道：
- 用哪个 Fortran 编译器
- MPI/HDF5/HYPRE 库在哪
- 编译选项

**为什么需要 site**：不同超算配置差异大；同一份源码要能在不同机器编译。

**本机特殊性**：site 配置已 baked in 各 `cases/<case>/Makefile.h`（用户从其他机器拷贝 cases 时 Makefile.h 跟着过来）。但新 setup 时如果 `sites/ares/` 不存在，setup.py 会报错。

详见 `skills/flash-pitfall-finder/knowledge/pitfalls/site-not-found.md`（如存在）和 `flash-case-runner/knowledge/setup_guide.md` §4。

---

## 3. SetupError: parfile 'X.par' not found

### 错误形式

```
SetupError: parfile 'X.par' not found
```

### Step 0：贴什么现场

```bash
# 1. 你写的 -parfile=
echo "你写的 -parfile=<X>"

# 2. 在 source 下找
find /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/<算例>/ -name "<X>*"

# 3. 列算例所有 parfile
ls /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/<算例>/*.par
```

### 通用原因

#### 原因 1：parfile 名拼错

`-parfile=example_xubo` 找 `example_xubo.par`（自动加 `.par` 后缀）。如果你写 `-parfile=example_xubo.par` 找 `example_xubo.par.par`——找不到。

**修**：`-parfile=` 后面**不带 `.par`**。

#### 原因 2：parfile 在别的算例目录

每个算例的 parfile 在 `source/Simulation/SimulationMain/<该算例>/`。不能跨算例引用。

**修**：把 parfile 拷到当前算例目录：
```bash
cp /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/<其他算例>/<X>.par \
   /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/<当前算例>/<X>.par
```

#### 原因 3：parfile 还没创建（自定义算例）

新建算例时还没创建 parfile，但 setup 命令引用了。

**修**：先创建 parfile（从相似算例拷贝）。

### 怎么修

按上面 3 个原因对照修复。

---

## 4. species 数量不匹配

### 错误形式

```
SetupError: Number of species in 'species=' variable does not match Config
```

或运行时报：
```
ed_init: ERROR: Number of species (4) does not match simulation parameters
```

### Step 0：贴什么现场

```bash
# 1. 你写的 species=
echo "你写的 species=<X,Y,Z,...>"

# 2. 算例 Config 期望几个
grep -i "USESETUPVARS\|species\|nspec" /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/<算例>/Config

# 3. setup 后实际生成几个
grep "NSPECIES" /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/cases/<case>/setup_defines
```

### 通用原因

**算例 Config 期望 N 种物质，但 species= 给的数量不对**。

例：LaserSlab Config 期望 2 种（cham + targ），给 `species=cham,targ1,targ2,targ3` 会失败（如果 Config 没扩展）。

### 怎么修

#### 方案 A：改 species 数量匹配 Config

```bash
# LaserSlab 用 2 物质
species=cham,targ
```

#### 方案 B：改 Config 支持更多 species（如 Sunliang_laser_CH）

修改 `source/Simulation/SimulationMain/<算例>/Config`，找 `USESETUPVARS` 段，扩展 species 列表。

详细 Config 改法见 `flash-multispecies` skill。

---

## 5. setup_flags 里没看到期望的 -DFLASH_3T 等

### 症状

setup 跑通了，但 `cases/<case>/setup_defines` 里没看到期望的编译宏（如 `-DFLASH_3T`）。

### Step 0：贴什么现场

```bash
# 1. setup_defines 实际内容
cat /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/cases/<case>/setup_defines

# 2. setup_vars 看 setup-variables 实际值
grep -E "ThreeT|Mtmmmt|Laser|Mgd" /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/cases/<case>/setup_call

# 3. setup_call 看原始命令
cat /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/cases/<case>/setup_call
```

### 通用原因

#### 原因 1：setup-variable 名拼错

`+uhd3t` 不是 `+uhd-3t` 也不是 `+UHD3T`。shortcut 名严格按 `setup_shortcuts.txt`。

#### 原因 2：setup-variables 顺序冲突

如果先写 `+3t` 再写 `-3t`，最终是 False。检查 setup_call 看有没有冲突。

#### 原因 3：算例 Config 覆盖

有些算例 Config 用 `REQUIRES` 强制某些 setup-variable。例：LaserSlab Config 可能强制 `ThreeT=1`，命令行写 `-3t` 无效。

**验证**：
```bash
grep -i "REQUIRES\|threeT\|setupvar" /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/source/Simulation/SimulationMain/<算例>/Config
```

### 怎么修

按上面 3 个原因对照修复。如果是 Config 强制覆盖，要改 Config（高级操作）。

---

## 6. libmpi.so.40 冲突警告

### 错误形式（编译时）

```
/usr/bin/ld: warning: libmpi.so.40 may conflict with libmpi.so.12
```

### Step 0：贴什么现场

```bash
# 1. ldd flash4（如果已编译）
ldd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/cases/<case>/flash4 2>/dev/null | grep mpi

# 2. 系统库 vs 用户库
ls /lib/x86_64-linux-gnu/libmpi.so* 2>/dev/null
ls /home/ubuntu/local/flash/myFLASH4.8/mpich/lib/libmpi.so* 2>/dev/null
```

### 通用原因

**本机特有问题**：系统提供 `libmpi.so.40`（OpenMPI），但 FLASH 编译用 mpich（提供 `libmpi.so.12`）。两者 ABI 不兼容，链接器警告。

**详细机制**：
- `libHYPRE.so` 链接 mpich 的 `libmpi.so.12`
- 系统 `/lib/x86_64-linux-gnu/libmpi.so.40`（OpenMPI）也在 loader 搜索路径
- ld 看到两个 libmpi 不同版本，警告冲突
- 警告通常不致命，但运行时如果加载错的 libmpi 会崩溃

### 怎么修（按优先级）

#### 方案 A：临时隐藏系统 libmpi（推荐）

```bash
# 编译前
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak

# 编译
cd cases/<case> && make -j4

# 编完后恢复
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40
```

#### 方案 B：设 LD_LIBRARY_PATH

```bash
export LD_LIBRARY_PATH=/home/ubuntu/local/flash/myFLASH4.8/mpich/lib:$LD_LIBRARY_PATH
mpirun -np 4 ./flash4 -par_file flash.par
```

### 详细文档

见 `note.txt` 和 `cases/NOTE.txt`。

**按 L-008，不贴"凑数代码"**——这不是 FLASH 源码触发的错误，是系统库配置问题。详细讲机制如上。

---

## 7. setup 过了但 make 失败（缺库）

### 错误形式

setup 成功，但 `make -j4` 报：
```
fatal error: mpi.h: No such file or directory
fatal error: hdf5.h: No such file or directory
cannot find -lHYPRE
```

### Step 0：贴什么现场

```bash
# 1. make 错误前 30 行
cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/cases/<case>
make -j4 2>&1 | head -30

# 2. Makefile.h 库路径
grep -E "MPI_PATH|HDF5_PATH|HYPRE_PATH" Makefile.h

# 3. 库实际存在吗
ls /home/ubuntu/local/flash/myFLASH4.8/mpich/include/mpi.h
ls /home/ubuntu/local/flash/myFLASH4.8/hdf5/include/hdf5.h
ls /home/ubuntu/local/flash/myFLASH4.8/hypre/lib/libHYPRE.*
```

### 通用原因

#### 原因 1：Makefile.h 路径错

新 setup 时如果 Makefile.h 不是本机的（从其他机器拷来），路径可能不对。

**修**：用本机配置：
```bash
cp /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/cases/LaserSlab/Makefile.h \
   /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/cases/<case>/Makefile.h
make -j4
```

#### 原因 2：库没装

本机路径下没有 mpi.h / hdf5.h / libHYPRE.so。

**修**：装库（外部依赖，不是 FLASH 仓库的事）。

#### 原因 3：Makefile.h 用了错编译器

例：Makefile.h 写 `FCOMP=ifort` 但本机只有 gfortran。

**修**：改 Makefile.h 的 FCOMP/CCOMP/LINK 为 mpif90/mpicc/mpif90（本机路径）。

### 怎么修

按上面 3 个原因对照修复。

---

## 8. 边缘错误速查

按 L-013，HEDP 主流不常遇到的错误简列：

| 错误 | 原因 | 修法 |
|---|---|---|
| `SetupError: maxBlocks too small` | `-maxBlocks=N` 太小 | 加大到 10000+ |
| `SetupError: nxb must be >= 2*GUARDCELLS` | nxb 太小 | 用 `-nxb=16` 或更大 |
| `SetupError: Shortcut '<name>' not found` | shortcut 名拼错 | 查 shortcut_table.md |
| `SetupError: -3d requires -nzb` | 3D 漏写 nzb | 加 `-nzb=16` |
| `ImportError: No module named 'rpStructs'` | setup.py 工具链错 | 检查 bin/ 完整性 |
| `Permission denied: cases/<case>/...` | objdir 权限 | `chmod -R +w cases/<case>` |
| `setup.py: error: unrecognized arguments` | setup.py 版本旧 | 用本仓库 bin/setup.py |
| `make: *** No rule to make target 'all'` | Makefile 损坏 | 重 setup（先 `-clean`）|

---

## 9. 诊断流程速查图（文字版，按 L-002 不用 mermaid）

```
setup 报错
│
├─ Unit not found / Ambiguous
│  └─→ 看 §1（单元名拼错 / 缺 +foo / 算例路径错 / 前缀歧义）
│
├─ Site not found
│  └─→ 看 §2（创建 sites/ares/ 或从 cases/LaserSlab 复制）
│
├─ parfile not found
│  └─→ 看 §3（parfile 名错 / 在别的算例目录 / 还没创建）
│
├─ species 数量不匹配
│  └─→ 看 §4（改 species= 数量 / 改 Config）
│
├─ setup_flags 缺宏
│  └─→ 看 §5（setup-variable 名错 / 顺序冲突 / Config 强制覆盖）
│
├─ libmpi.so.40 冲突
│  └─→ 看 §6（编译前 sudo mv / 编完 mv 回）
│
├─ make 缺库
│  └─→ 看 §7（Makefile.h 路径错 / 库没装 / 编译器错）
│
└─ 其他
   └─→ 看 §8（边缘错误速查）+ skills/flash-pitfall-finder/knowledge/pitfalls/
```

如果本 skill 知识库未覆盖你的错误，建议：
1. 提供完整错误信息（前 30 行 + setup_call）
2. 用 `flash-pitfall-finder` skill 做更专门的诊断
3. 或在 `agent/drafts/pending/` 留底，后续补充本 pitfalls.md
