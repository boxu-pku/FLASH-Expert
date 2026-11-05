---
name: flash-case-runner
description: |
  FLASH 4.8 算例操作专家（Phase 3 操作层 skill）——端到端跑通 setup → make → run → restart → 诊断。
  按 L-013 聚焦主流路径——主讲 LaserSlab HEDP（用户实际场景，含激光 + MGD + 3T 多物质 + IONMIX/SESAME 表），
  Sedov 作为入门测试，Sunliang_laser_CH 作为自定义多物质算例参考。
  覆盖：完整算例生命周期（setup 命令构造、site 配置、make 编译、libmpi.so.40 冲突、flash_env.sh 运行环境、
  mpirun -np、flash4 -parfile、日志解析、restart、checkpoint 一致性）；
  setup 语法（-2d/-3d, +pm4dev, +laser, +mgd, +uhd3t, +mtmmmt, +hdf5typeio, species=, mgd_meshgroups=,
  -objdir=, -parfile=, -auto, -debug, -geometry=）；
  本机 site 配置（ares 无 sites/ares/，配置已 baked in cases/*/Makefile.h）；
  本机 libmpi 冲突（编译期 sudo mv / 运行期 LD_PRELOAD via flash_env.sh，2026-08-02 实战验证）；
  日志关键信息提取（dt / nstep / simTime / AMR block 数 / NaN / abort）；
  restart 流程（checkpointFileNumber + NXB 一致性 + parfile 适配）；
  编译/运行错误诊断（按 L-012 先引导贴现场：日志 + setup_call + parfile）。
  非 tool skill——Claude 直接执行 bash 命令而不是调 Python wrapper（D-决策：knowledge > Python 脚本）。
  触发词：跑算例, setup, make, 编译, flash4, mpirun, restart, checkpoint,
        算例生命周期, objdir, parfile, setup_call, setup_flags,
        LaserSlab, Sedov, Sunliang, 跑 Sedov, 跑 LaserSlab,
        -2d, -3d, -nxb, +laser, +mgd, +uhd3t, +mtmmmt, +hdf5typeio, +pm4dev,
        species=, mgd_meshgroups=, -objdir=, -parfile=, -auto, -debug, -geometry=,
        undefined reference, Unit not found, SetupError, site not found,
        forrtl error, SIGSEGV, NaN, abort, below floor,
        编译报错, 链接报错, 运行报错, 跑不起来,
        flash_env.sh, LD_PRELOAD, libmpi, mpich, OpenMPI,
        checkpointFileNumber, restart, 续跑,
        dt, nstep, simTime, block count, AMR blocks
triggers:
  # 中文 - 操作类
  - 跑算例
  - 跑 Sedov
  - 跑 LaserSlab
  - 跑 Sunliang
  - 编译算例
  - 编译报错
  - 链接报错
  - 运行报错
  - 跑不起来
  - 算例跑不通
  - 算例生命周期
  - 续跑
  - 重启算例
  - 续算
  - 怎么 setup
  - 怎么编译
  - 怎么跑
  - 怎么 restart
  - 看日志
  - 日志解析
  # 英文 - 操作类
  - setup
  - setup command
  - make
  - make -j
  - compile
  - flash4
  - mpirun
  - run case
  - run simulation
  - restart
  - checkpoint
  - checkpointFileNumber
  - objdir
  - parfile
  # setup 语法
  - "-2d"
  - "-3d"
  - "-1d"
  - "-nxb"
  - "-nyb"
  - "-nzb"
  - "-auto"
  - "-debug"
  - "-objdir="
  - "-parfile="
  - "-geometry="
  - "+laser"
  - "+mgd"
  - "+uhd3t"
  - "+mtmmmt"
  - "+hdf5typeio"
  - "+pm4dev"
  - "+ug"
  - "+cylindrical"
  - "+cartesian"
  - "+spherical"
  - species=
  - mgd_meshgroups=
  # 算例名
  - LaserSlab
  - Sedov
  - Sunliang
  - Sunliang_laser_CH
  - SimulationMain
  # 编译/链接错误
  - undefined reference
  - Unit not found
  - SetupError
  - site not found
  - sites/
  - Makefile.h
  - ld warning
  - ld error
  - libmpi
  - libmpi.so.40
  - libmpi.so.12
  - libHYPRE
  # 运行错误
  - forrtl
  - "forrtl: error"
  - SIGSEGV
  - segfault
  - NaN
  - abort
  - below floor
  - Driver_abortFlash
  - MPI_ERRORS_ABORT
  - MPI_COMM_WORLD
  # 环境配置
  - flash_env.sh
  - LD_PRELOAD
  - LD_LIBRARY_PATH
  - mpich
  - OpenMPI
  # 日志关键字
  - dt
  - nstep
  - simTime
  - block count
  - AMR blocks
  - plotfile
  - checkpoint
  # 输出文件
  - setup_call
  - setup_flags
  - setup_defines
  - flash.par
  - flash.log
when_to_use: |
  调用本 skill 的场景（操作类——不是问物理，是问/做"怎么跑"）：
  1. 用户说"跑 X 算例" / "怎么跑 Sedov" / "怎么 setup LaserSlab"——给完整流程 + setup 命令
  2. 用户说"编译报错" / "make 出错"——按 L-012 引导贴现场 + 诊断（含 libmpi 冲突）
  3. 用户说"flash4 abort" / "运行报错" / "NaN" / "段错误"——按 L-012 引导贴日志 + 诊断
  4. 用户说"怎么 restart" / "怎么续跑"——讲 checkpoint + parfile 适配 + NXB 一致性
  5. 用户问 setup 命令某参数什么意思（-2d / +laser / +mgd / species=）——讲作用 + 为什么这么用（L-011）
  6. 用户问"site 配置在哪" / "Makefile.h 怎么改"——讲本机 ares 特殊性（无 sites/ares/，已 baked in）
  7. 用户问"怎么用 flash_env.sh" / "libmpi 冲突怎么破"——讲编译期 vs 运行期两套方案
  8. 用户问日志怎么看 / dt 怎么提取 / nstep 到哪了——给日志解析命令 + 期望关键字段
  9. 用户问怎么加新算例 / 改自定义算例——指 setup_builder + SimulationMain 结构
  10. 用户问 checkpoint 文件编号怎么续——讲 checkpointFileNumber + 文件命名规则
when_not_to_use: |
  **不调用本 skill 的场景**（属于其他 skill）：
  - 物理原理（"激光怎么沉积"、"MGD 怎么解"） → `flash-laser` / `flash-radtrans`
  - 参数物理含义（"ed_wavelength 是什么"、"hx_dtFactor 默认多少"） → `flash-param-query`
  - parfile 完整配置（"LaserSlab 该配哪些参数"） → `flash-laser` / `flash-sourceterms` 等知识层
  - 源码位置（"Driver_abortFlash 在哪"） → `flash-source-reader`
  - 错误信息匹配（已知错误信息想查修复） → `flash-pitfall-finder`
  - 构造新 setup 命令的辅助工具 → `flash-setup-builder`（Phase 3 兄弟 skill）
  - 分析已跑完的结果（看 plotfile / hdf5） → `flash-result-analyzer`（Phase 3 兄弟 skill）
  - 手册查询 → `flash-manual-search`
layer: operations
phase: 3
status: stable
created: 2026-07-19
last_updated: 2026-08-02
owner: user
---

# flash-case-runner — FLASH 算例操作专家（setup → make → run → restart）
> 路径约定：`$FLASH_ROOT` = FLASH 4.8 仓库根目录（本机 `$FLASH_ROOT`）；`$FLASH_LIBS` = 外部库根目录（本机 `$FLASH_LIBS`，含 mpich/hdf5/hypre）。其它机器按实际路径替换。


> **状态**：beta（Phase 3 第一个操作层 skill；2026-08-02 LaserSlab 实战验证通过 libmpi 冲突解决方案）
>
> **按 L-013 聚焦主流**：主讲 **LaserSlab HEDP**（用户实际场景：2D 圆柱 + 多物质 + 激光 + MGD + 3T + IONMIX/SESAME 表），**Sedov** 作为入门测试（最简单的纯 Hydro），**Sunliang_laser_CH** 作为多物质自定义算例参考。
>
> **本 skill 的特殊价值**（L-001）：不只是给命令模板——讲清楚每个步骤"为什么这么操作"、"不这么做会怎样"、本机 ares 的特有坑（libmpi 冲突）、诊断类按 L-012 先引导贴现场。

## 1. 角色与边界

### 1.1 我是做什么的

帮用户**端到端跑通 FLASH 算例**——从 `./setup` 命令构造、`make` 编译、`mpirun` 运行、日志诊断、到 `restart` 续跑。

| 范畴 | 详见 |
|---|---|
| 生命周期总览 + 术语速查 | `knowledge/overview.md` — setup/make/run/restart 四阶段 + objdir/parfile/checkpoint 术语 |
| setup 阶段 | `knowledge/setup_guide.md` — 完整 setup 语法 + 选 SimulationMain + site 配置 + 常见错误 |
| make 阶段 | `knowledge/make_guide.md` — 编译流程 + libmpi 冲突 + undefined reference / Unit not found 诊断 |
| run/restart 阶段 | `knowledge/run_guide.md` — flash_env.sh + mpirun + 日志解析 + restart + 运行错误诊断 |
| 全阶段踩坑汇总 | `knowledge/pitfalls.md` — 按 L-012 每条都给"贴什么现场 + 怎么诊断 + 怎么修" |
| 算例配方 | `recipes/sedov.md` / `recipes/laser-slab-2d.md` / `recipes/sunliang-laser-CH.md` |
| 一键脚本 | `examples/run-sedov.sh` / `examples/run-laser-slab.sh` / `examples/flash_log_parser.sh` |

### 1.2 我不做什么

| 用户问题类型 | 归属 skill |
|---|---|
| 激光沉积物理原理 | `flash-laser` |
| MGD 辐射扩散物理 | `flash-radtrans` |
| EOS 三温耦合机制 | `flash-eos` |
| Heatexchange（电子-离子平衡） | `flash-sourceterms` |
| Grid/AMR 机制 | `flash-grid` |
| Driver 主循环 | `flash-driver` |
| Multispecies（species= 变量触发什么） | `flash-multispecies` |
| 参数物理含义/默认值 | `flash-param-query` |
| parfile 完整配置 | 各知识层 skill 的 recipes.md |
| 源码位置 | `flash-source-reader` |
| 错误信息匹配（已有 pitfall 数据库） | `flash-pitfall-finder` |
| 构造新 setup 命令辅助 | `flash-setup-builder` |
| 分析已跑完结果 | `flash-result-analyzer` |

### 1.3 与 flash-pitfall-finder 的边界（重要）

`flash-pitfall-finder` 是**错误信息匹配器**——已有 pitfall 数据库，用户给错误信息它返回修复方案。

本 skill 是**操作流程导向**——讲"怎么从头跑到尾"，遇到错误时按 L-012 引导贴现场 + 用 flash-pitfall-finder 检索 + 给本机特定的诊断命令。

| 场景 | 用谁 |
|---|---|
| 用户给一句完整错误信息，想直接看修复 | `flash-pitfall-finder` |
| 用户说"我跑 Sedov 跑不通" / "编译 LaserSlab 报错" | 本 skill（流程导向） |
| 用户问"libmpi.so.40 怎么破"（本机特定） | 本 skill（pitfall-finder 也覆盖但本 skill 给更具体的运行/编译流程） |

## 2. 行为协议

按 `agent/TEMPLATES/skill-template.md §2` 通用协议。核心要点：

- **运行输出隔离（硬约束，2026-08-10 起）**：运行 flash4 一律在 **`cases/<case>/01-data/`** 目录下启动（CWD=01-data），所有运行输出（plotfile / checkpoint / .dat / .log）只落在 `01-data/`；objdir 根目录只放编译产物（flash4 / *.o / Makefile / setup_*）和 parfile，**禁止**在 objdir 根目录直接 `mpirun ./flash4` 让输出散落。标准姿势：
  ```bash
  mkdir -p cases/<case>/01-data && cd cases/<case>/01-data
  source $FLASH_ROOT/flash_env.sh
  mpirun -np N ../flash4 -par_file ../flash.par 2>&1 | tee flash.log
  ```
  为什么用 CWD 法而不用 parfile 的 `output_directory` 参数：`output_directory` 只管 plt/chk（`source/IO/IOMain/io_getOutputName.F90`），`.log` / `.dat`（如 `*_LaserEnergyProfile.dat`）仍写 CWD——CWD 法一刀切全覆盖。restart 续跑也在同一 `01-data/` 里跑（chk 就在本目录，用 `checkpointFileNumber` 指定编号；**必须同时设 `plotFileNumber`** 否则新 plt 从 0 重编号覆盖旧文件，见 `skills/flash-pitfall-finder/knowledge/pitfalls/restart-plotfilenumber-overwrite.md`）
- **讲逻辑**（L-001）：不只是给命令模板，讲清楚"为什么这么操作"、"不这么做会怎样"
- **不用 mermaid**（L-002）：流程图用文字+缩进
- **核心 4 段 + 引导项**（L-010）：核心段（setup/make/run 命令）必给详细，引导项（背景原理）按需展开
- **讲为什么**（L-011）：每个 setup 参数/操作步骤必给"为什么这么用/什么场景该选"
- **诊断类先引导贴现场**（L-012）：编译报错/运行 abort 时**第一步**是引导用户贴 setup_call / 日志 / parfile
- **公式 CLI 友好**（L-012）：用 ASCII / 代码块
- **聚焦主流路径**（L-013）：主讲 LaserSlab（用户实际场景），Sedov 入门，简要带过其他
- **专业术语先解释**（L-014）：objdir/parfile/site/checkpoint 等术语第一次出现先一句话定义
- **先讲完整故事线**（L-015）：用户问"怎么跑 X"时先讲 setup → make → run → 看结果四步流程，再讲每步细节

## 3. knowledge/ + recipes/ + examples/ 子目录

| 文件 | 内容 |
|---|---|
| `knowledge/overview.md` | 算例生命周期总览 + 4 阶段流程 + 常见算例（Sedov/LaserSlab/Sunliang）+ 术语速查 |
| `knowledge/setup_guide.md` | setup 命令完整语法 + 选 SimulationMain 决策树 + site 配置 + SetupError 诊断 |
| `knowledge/make_guide.md` | 编译流程 + libmpi 冲突（编译期 sudo mv）+ undefined reference / Unit not found 诊断 |
| `knowledge/run_guide.md` | flash_env.sh + mpirun + 日志解析 + restart + 运行错误诊断（abort/NaN/SIGSEGV） |
| `knowledge/pitfalls.md` | 全阶段踩坑汇总，每条按 L-012 结构（贴现场命令 + 原因 + 修复） |
| `recipes/sedov.md` | Sedov 爆炸完整跑法（入门，纯 Hydro，最小可运行） |
| `recipes/laser-slab-2d.md` | LaserSlab HEDP 完整跑法（含 flash_env.sh + LD_PRELOAD + 3T + MGD） |
| `recipes/sunliang-laser-CH.md` | 自定义多物质算例跑法（多 species CHBr，含多 targ 物质） |
| `examples/run-sedov.sh` | Sedov 一键运行 bash 脚本 |
| `examples/run-laser-slab.sh` | LaserSlab 一键运行 bash 脚本（含 source flash_env.sh） |
| `examples/flash_log_parser.sh` | 日志关键信息提取（dt/nstep/simTime/NaN/abort） |
| `examples/README.md` | 脚本用法说明 |

## 4. 示例问答（验收基准）

### Q1: 怎么从头跑通 Sedov 算例？

**A**: 见 `recipes/sedov.md` + `examples/run-sedov.sh`。**先讲完整故事线（L-015）**：

```
1. setup 阶段：./setup Sedov -auto -objdir=cases/Sedov
   → 生成 cases/Sedov/ 下的所有 .F90 / Makefile / setup_*
2. make 阶段：cd cases/Sedov && make -j4
   → 生成 ./flash4 可执行文件
3. run 阶段：cd cases/Sedov/01-data && mpirun ../flash4 -par_file ../flash.par
   → 写 plotfile / checkpoint / 日志到 01-data/（硬约束：不在 objdir 根目录跑）
4. 看结果：ls 01-data/（plotfile）；grep simTime 01-data/flash.log（进度）
```

**Sedov 是入门算例**——纯 Hydro、单物质、无激光/MGD/3T，最适合验证"环境配通没"。**完整命令**：

```bash
cd $FLASH_ROOT
./setup Sedov -auto -objdir=cases/Sedov
cd cases/Sedov && make -j4
mkdir -p 01-data && cd 01-data
source ../../../flash_env.sh
mpirun -np 1 ../flash4 -par_file ../flash.par 2>&1 | tee flash.log
```

**关键点**：
- `-objdir=cases/Sedov`：本机约定（默认是 `object/`）
- `-auto`：跳过交互式提示
- **run 在 `01-data/` 子目录里跑**（§2 硬约束）：`../flash4` 指 objdir 的可执行文件，输出全落 01-data
- Sedov 不需要 flash_env.sh（无 MPI 冲突？错——Sedov 也用 MPI，**仍然要 source flash_env.sh**）

### Q2: 怎么 setup 一个 LaserSlab 2D 圆柱 HEDP 算例？

**A**: 见 `recipes/laser-slab-2d.md`。**主流 setup 命令**（从 `cases/LaserSlab/setup_call` 实证）：

```bash
./setup LaserSlab -2d -auto +cylindrical \
  -nxb=16 -nyb=16 +hdf5typeio \
  species=cham,targ +mtmmmt +laser +uhd3t +mgd \
  mgd_meshgroups=6 \
  -objdir=cases/LaserSlab -parfile=example.par
```

**每个参数为什么（L-011）**：
| 参数 | 作用 | 为什么这么用 |
|---|---|---|
| `-2d` | 二维 | HEDP 平面靶，2D 圆柱足够；3D 太贵 |
| `+cylindrical` | 圆柱坐标 (r, z) | 平面靶轴对称，圆柱比笛卡尔省一半 CPU |
| `-nxb=16 -nyb=16` | block 大小 16×16 | Paramesh 标准块；AMR 单元 |
| `+hdf5typeio` | HDF5 IO 后端 | 默认非 HDF5，HEDP 后处理要 HDF5 |
| `species=cham,targ` | 两种物质 | cham=腔体材料，targ=靶材料；触发生成 SPECIES_VAR 等 |
| `+mtmmmt` | multi-temp EOS | HEDP 必须 3T（Tele/Tion/Trad 分开）|
| `+laser` | 激光沉积单元 | HEDP 核心物理 |
| `+uhd3t` | unsplit Hydro + 3T | 主流 Hydro 后端（vs split）|
| `+mgd` | 多群扩散辐射 | HEDP 辐射传输主流（vs flux-limited diffusion）|
| `mgd_meshgroups=6` | 6 群辐射 | 平衡精度和成本（生产用 70+ 群，调试用 6）|

**关键陷阱**：**不要相信 parfile 顶部 setup 注释（L-009）**——`cases/LaserSlab/example.par` 顶部注释的 setup 命令可能和 `setup_call` 不一致。永远以 `setup_call` 为准。

**编译后运行（§2 硬约束）**：

```bash
cd cases/LaserSlab && make -j4        # 本机先处理 libmpi 冲突（见 Q3）
mkdir -p 01-data && cd 01-data
source ../../../flash_env.sh
mpirun -np 2 ../flash4 -par_file ../flash.par 2>&1 | tee flash.log
# 所有 plt/chk/dat/log 落在 cases/LaserSlab/01-data/，不散落在 objdir 根目录
```

### Q3: 编译 LaserSlab 时报 `libmpi.so.40 may conflict with libmpi.so.12` 怎么办？

**A**: 见 `knowledge/make_guide.md §3` + `skills/flash-pitfall-finder/knowledge/pitfalls/libmpi-conflict.md`。**按 L-012 先确认现场**：

```bash
# 1. 确认这是 warning 还是 error（warning 可忽略，error 要修）
grep -A2 "libmpi" cases/<your_case>/make.log | head -10

# 2. 确认 Makefile.h 用的 MPI_PATH
grep MPI_PATH cases/<your_case>/Makefile.h
# 应该是 $FLASH_LIBS/mpich
```

**机制解释（L-008：非源码错，不贴"凑数代码"）**：

`libmpi.so.40` 是系统 OpenMPI（Ubuntu apt 装的），`libmpi.so.12` 是本机用户自建 mpich。`libHYPRE.so` 链接的是 mpich（.12），但系统 loader 路径优先找到 .40，触发 ld 警告。

**为什么是 warning 不是 error**：编译期只是 ld 警告，能生成 flash4。但**运行时**如果不处理，loader 会先加载 .40 导致 MPI 符号冲突，触发 `SIGSEGV in Driver_initParallel.F90:92`（2026-08-02 实战遇到的）。

**两套修复**：
- **编译期（make 阶段）**：`sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak && make -j4 && sudo mv ... .40.bak ... .40`（让 ld 找不到 .40）
- **运行期（mpirun 阶段）**：`source flash_env.sh`（设 LD_PRELOAD，让 .12 最先加载）

**实战推荐**：编译期用 sudo mv（一次），运行期永远先 source flash_env.sh。

### Q4: flash4 跑到一半 abort，怎么看日志？

**A**: 见 `knowledge/run_guide.md §4` + `examples/flash_log_parser.sh`。**按 L-012 先引导贴现场**：

```bash
# 0. 日志在 01-data/ 子目录（§2 硬约束——运行输出不散落在 objdir 根目录）
# 1. 找 abort 位置和最后几步
grep -B2 -A20 "abort\|forrtl: error\|SIGSEGV\|MPI_ERRORS" \
  cases/<your_case>/01-data/flash.log | tail -50

# 2. 找 NaN（看 TELE/TRAD 等是否爆）
grep -i "nan\|inf\|below floor" cases/<your_case>/01-data/flash.log | head -20

# 3. 看 dt 演化（dt 突然变小 = 物理炸了）
grep -E "nstep|simTime|^\s*dt" cases/<your_case>/01-data/flash.log | tail -30

# 4. 看 AMR block 数（block 暴涨 = 激波传出 domain）
grep -i "block\|leaf" cases/<your_case>/01-data/flash.log | tail -10
```

**贴完后能给出针对性诊断**（按 L-012 第二层通用原因）：

| abort 类型 | 最可能原因 | 快速验证 |
|---|---|---|
| `[Driver_initParallel]` abort | libmpi 冲突（运行时） | `source flash_env.sh` 后重跑 |
| `[ed_]`（EnergyDeposition） | 激光参数错（束指向/截面/功率） | 检查 ed_* 参数 |
| `[Multitype]` / `[Tabulated]` | EOS 表超范围（密度/温度过低/过高） | 检查 sim_rhoMin / 温度初值 |
| `forrtl: error (65)` floating invalid | 数值爆炸（除零/负开方） | 降 CFL（cfl >= 0.1） |
| `fortrl: error (72)` | 数组越界 | 检查 NXB/NYB 和几何 |

### Q5: 怎么从 checkpoint 续跑？

**A**: 见 `knowledge/run_guide.md §5`。**完整故事线（L-015）**：

```
1. 算例跑时会定期写 checkpoint 文件到 01-data/（*_hdf5_chk_<NNNN>）
2. 续跑前确认：
   a. 最新 chk 编号：ls cases/<case>/01-data/*_hdf5_chk_* | tail
   b. NXB/NYB/nDim 和原 setup 一致（L-008：源码检查 Grid_init.ft）
3. 改 parfile（objdir 里的 flash.par）——续跑三件套，缺一不可：
   restart              = .true.
   checkpointFileNumber = <最新 chk 编号>     # 决定读哪个 chk
   plotFileNumber       = <最新 plt 编号 + 1> # 不设会从 0 重编号，覆盖旧 plotfile！
4. 用相同 setup 命令重 build（保险）或复用原 flash4
5. 在 01-data/ 里续跑（§2 硬约束）：
   cd cases/<case>/01-data && source ../../../flash_env.sh
   mpirun -np N ../flash4 -par_file ../flash.par
```

**关键陷阱**：
- **NXB 不一致会 abort**——见 `skills/flash-pitfall-finder/knowledge/pitfalls/restart-incompatibility.md`。续跑前 grep `setup_flags` 确认 NXB
- **物种数变了也不能续跑**（species 数 baked in 编译期）
- **parfile 顶部 setup 注释可能误导**（L-009）——以 setup_call 为准

## 5. 关键源码/文件入口

| 想理解 | 看哪个文件 |
|---|---|
| setup 命令实现 | `bin/setup.py:main()` |
| setup 工具链 | `bin/genFiles.py` / `bin/linkFiles.py` / `bin/unitCfg.py` / `bin/rpStructs.py` |
| Sedov 算例 Config | `source/Simulation/SimulationMain/Sedov/Config` |
| LaserSlab 算例 Config | `source/Simulation/SimulationMain/LaserSlab/Config` |
| Sunliang 算例 Config | `source/Simulation/SimulationMain/Sunliang_laser_CH/Config` |
| Sedov setup_call（实证） | `cases/Sedov/setup_call` |
| LaserSlab setup_call（实证） | `cases/LaserSlab/setup_call` |
| Sunliang setup_call（实证） | `cases/Sunliang_laser_CH/setup_call` |
| 本机 site 配置（已 baked in） | `cases/LaserSlab/Makefile.h`（无 sites/ares/）|
| 运行环境脚本 | `flash_env.sh`（项目根）|
| 运行输出目录（§2 硬约束） | `cases/<case>/01-data/`——plt/chk/dat/log 全在这；objdir 根目录只放编译产物 + parfile |
| libmpi 冲突详细 | `skills/flash-pitfall-finder/knowledge/pitfalls/libmpi-conflict.md` |
| MPI 运行时错误 | `skills/flash-pitfall-finder/knowledge/pitfalls/mpi-errors.md` |
| restart 不兼容 | `skills/flash-pitfall-finder/knowledge/pitfalls/restart-incompatibility.md` |
| setup Unit not found | `skills/flash-pitfall-finder/knowledge/pitfalls/setup-unit-not-found.md` |
| site not found | `skills/flash-pitfall-finder/knowledge/pitfalls/site-not-found.md` |
| -ffpe-trap 触发 NaN | `skills/flash-pitfall-finder/knowledge/pitfalls/ffpe-trap-and-nan.md` |
| Driver 主循环（abort 出处） | `source/Driver/DriverMain/Driver_evolveFlash.F90` |
| Driver_abortFlash | `source/Driver/DriverMain/Driver_abortFlash.F90` |
| IO_output（写 plotfile/chk） | `source/IO/IOMain/<...>/IO_output.F90` |

## 6. 与其他 skill 的协作链

| 场景 | 协作链 |
|---|---|
| 用户跑 Sedov 跑不通，先帮跑 → 物理问题 | 本 skill（流程）→ `flash-hydro`（Hydro 物理诊断） |
| 用户跑 LaserSlab，激光参数错 | 本 skill（流程）→ `flash-laser`（ed_* 参数详解） |
| 用户跑 LaserSlab，3T 不平衡 | 本 skill（流程）→ `flash-sourceterms`（Heatexchange 诊断） |
| 用户编译报 undefined reference | 本 skill（编译诊断）→ `flash-pitfall-finder`（已知错误匹配） |
| 用户跑出来 NaN | 本 skill（贴日志引导）→ `flash-pitfall-finder`（NaN 类匹配）→ 知识层（根因）|
| 用户要构造新 setup 命令 | `flash-setup-builder`（构造辅助）→ 本 skill（实际执行）|
| 用户要分析跑完的结果 | 本 skill（流程直到产出 plotfile）→ `flash-result-analyzer`（HDF5 分析）|

## 7. 待办

- [ ] 跑 5 道验收考题（用户评分驱动迭代 SKILL.md，按 L-007）
- [ ] 持续累积踩坑（用户实战 HEDP 算例遇到的运行/编译问题）
- [ ] 扩展 recipes（用户加新算例时同步加 recipe）
- [ ] 验证 recipes/sunliang-laser-CH.md（用户实际 sunliang 算例真实跑通后）

## 8. 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft 骨架）| claude |
| 2026-08-02 | **升级 draft → beta**（Phase 3 第一个操作层 skill）：基于 2026-08-02 LaserSlab 4.8 实战验证（libmpi LD_PRELOAD 方案 + 66 步跑通），按 L-001~L-015 全部经验写完 SKILL.md + 5 knowledge + 3 recipes + 4 examples；核心设计——用 knowledge 而不是 Python 工具脚本（Claude 直接执行 bash 更灵活）；按 L-013 聚焦 LaserSlab（用户实际场景）+ Sedov（入门）+ Sunliang（多物质自定义）；按 L-014 解释 setup/make/objdir/site/parfile/checkpoint 等术语；按 L-015 setup→make→run→看结果四步流程先讲故事线；按 L-012 编译/运行错误先引导贴现场；libmpi 冲突编译期 + 运行期两套方案都有 | claude |
| 2026-08-07 | **CarbonSlab 实战经验沉淀**（自建 LaserSlab 变体 + IONMIX 表接入）：pitfalls.md 新增 §3.5.1（`ed_setupBeams` invalid 2D/3D beam grid type——flash.par 是 3D 版 + `ed_gridType` 必须与 `ed_laser3Din2D` 配套，源码 ed_setupBeams.F90:118-132）、§3.5.2（IONMIX 表群数/群边界硬校验 abort）、§3.8.1（`opacity_writeOpacityInfo` 触发 `op_writeOpacity.F90:97` 段错误——FLASH bug，但表打印文件先完成仍可用于验证）；recipes/laser-slab-2d.md 新增 §4.8-4.10（光束类型修复、IONMIX 表接入五步操作 + 三一致性要求、三级验证法含逐值对比结果 PA/RO ~5e-7） | claude |
| 2026-08-10 | **新增运行输出隔离硬约束**（§2 第一条）：运行 flash4 一律在 `cases/<case>/01-data/` 下启动（CWD 法），plt/chk/dat/log 只落 01-data，objdir 根目录只留编译产物 + parfile；源码依据——`output_directory` 参数只管 plt/chk（io_getOutputName.F90），.log/.dat 仍写 CWD，故用 CWD 法一刀切。同步改 SKILL.md Q1/Q2/Q4/Q5 + §5 表、run_guide.md 全部运行/日志/restart 命令、overview.md 术语表 + 阶段 3/4 + 速查、3 个 recipes、run-sedov.sh / run-laser-slab.sh 脚本、pitfalls.md 日志路径；flash-result-analyzer 原本就是 `cases/<case>/01-data/` 约定，无需改 | claude |
| 2026-08-10 | **Sunliang_Xray MPI 崩溃排查沉淀**：新建 `skills/flash-pitfall-finder/knowledge/pitfalls/mpi-romio-null-comm-allreduce.md` + pitfalls.md 新增 §3.1.1——`internal_Allreduce ... op=0x98000000, MPI_COMM_NULL`（step 8041/2.5h 长跑后）根因锁定 ROMIO（MPI-IO）two-phase 集合写 consensus Allreduce；证据链：5 行 C 程序逐字复现错误指纹、handle 解码（0x98000000=首个用户 op）、objdir 全部 Allreduce 穷举（Fortran 全是 MPI_INTEGER，与指纹 MPI_INT 不符）、反汇编（仅 ROMIO 创建用户 op，HYPRE/HDF5 为 0）、沙箱 restart 越过崩溃点（非确定性）；触发条件=每步一个 plotfile 的极端集合 IO 频率；修复=restart 续跑 + 降 IO 频率 + ROMIO_CB_WRITE=disable | claude |
| 2026-08-10 | **restart 三件套纠正（Sunliang_Xray 续跑实战，跑到 tmax=20ns 完成）**：① ~~`restartFile`~~ 不是 FLASH 4.8 有效参数（报 ignoring unknown parameter），续跑靠 `checkpointFileNumber`；② **必须设 `plotFileNumber`**——parfile 显式值覆盖 chk 计数器，不设则新 plt 从 0 重编号静默覆盖旧文件（本次损失原 plt 0000-0069 共 70 个早期文件后发现并纠正）；新建 `skills/flash-pitfall-finder/knowledge/pitfalls/restart-plotfilenumber-overwrite.md`；全库 11 处 `restartFile` 错误写法全部修正（SKILL.md Q5 + §2、run_guide.md §5.3/5.4/5.6/§7、overview.md 阶段 4、pitfalls.md §4.3 重写 + 索引表） | claude |
| 2026-08-10 | **restart 空壳 plotfile 发现（可视化实战）**：restart 后定时 plotfile 只有 AMR 元数据、无物理场数据集（~0.2MB vs 正常 4.7MB，日志却显示 wrote N blocks）——forced plotfile 和 checkpoint 正常；新建 `skills/flash-pitfall-finder/knowledge/pitfalls/restart-skeleton-plotfiles.md`，case-runner/result-analyzer pitfalls 索引均登记；可视化脚本 `make_figures.py`（figs/）已内置空壳过滤 | claude |
| 2026-08-10 | **IO 频率建议落地 + 经验沉淀**：`plotFileIntervalTime` 0.01e-09 → 0.1e-09（源模板 example_xray.par + objdir flash.par，后者同时复位 restart=.false. 安全态）；新建 `skills/flash-pitfall-finder/knowledge/pitfalls/plotfile-interval-too-dense.md`；pitfalls.md 新增 §5.4 + 索引表 2 行；`skills/flash-pitfall-finder/knowledge/pitfalls/README.md` 清单加 3 条；`agent/LESSONS_LEARNED.md` 新增 L-018（restart 三件套）/ L-019（IO 频率按物理时间分辨率设）/ L-020（MPI 崩溃取证方法论） | claude |
| 2026-08-13 | **side-on 崩溃根因修复（DEBUG 构建 + bounds-check + gdb 实证）**：错误链 XrayImaging→xray_updateXrays→Grid_moveParticles→gr_ptMoveOffBlk→gr_findNeghID→Grid_getBlkBoundBox（blkHandle=32766 垃圾值越界）；根因=NONEXISTENT 邻块分支未遵守 gr_getBlkHandle 哨兵契约 + level-1 块无父块；修复=gr_findNeghID 双保险（返回 NONEXISTENT 走 gr_findBlock 重定位）+ xray_updateXrays 清扫兜底；三个曾崩例（6.1/16.6/17ns）全过；全时刻 side-on 重放 7 帧产出（xray_sideon_real_series.png），与密度提取曲线互证一致；残留 1.7-6.8% 像素缺失（搬迁静默丢光，最近值插值）。经验：-debug 构建要 -fallow-argument-mismatch + 去 -ffpe-trap + make clean | claude |
| 2026-08-11 | **X 光动态照相（side-on）实战**：发现 3Din2D 重构空间柱轴=Z（非 Y！域校验代码 xray_detectorsCheck2DCyl3D.F90 实证）；side-on 验证配置 normal=(-1,0,0)+center=(0.1,0,0.0535) 出图正常（t=0/1/3ns），但**演化态（≥6ns）确定性崩溃**（xray_updateXrays.F90:126 Grid_sortParticles double free，分辨率/线程 workaround 无效）；最终交付=合成辐射照相（plotfile 弦积分 + t=0 真机帧定标 κ_CH=10.6/κ_CHBr=60，逐位吻合）+ 壳层位置曲线 shell_position_vs_time.png（856→513μm）；新建 `skills/flash-pitfall-finder/knowledge/pitfalls/xray-sideon-crash-sortparticles.md` | claude |
| 2026-08-11 | **`-parfile=` 静默忽略纠正（X 光重放验证跑抓出）**：源码实证 flash4 只认 `-par_file X`（RuntimeParameters_init.F90:86-89，`rp_getOpt` 精确匹配 + 值取下一 argv），`-parfile=X`/`-parfile X` 均静默回退默认 flash.par——以前没炸是因为文件名恰好都是 flash.par；新建 `skills/flash-pitfall-finder/knowledge/pitfalls/parfile-flag-ignored.md`；全库 62 处修正（CLAUDE.md + case-runner 40 处 + laser/driver/setup-builder/multispecies 22 处），**setup 的 `-parfile=` 不动**（setup.py 吃等号形式）。附带成果：新建 cases/Sunliang_Xray_xray8 二进制（xray_maxDetectors=8）并验证 restart 后 X 光按时刻正常记录 | claude |
