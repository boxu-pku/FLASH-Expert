# flash-multispecies examples
> 路径约定：`$FLASH_ROOT` = FLASH 4.8 仓库根目录（本机 `/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8`）；`$FLASH_LIBS` = 外部库根目录（本机 `/home/ubuntu/local/flash/myFLASH4.8`）。其它机器按实际路径替换。


FLASH 4.8 Multispecies 多物质追踪的典型配置示例。

## 文件清单

| 文件 | 内容 |
|---|---|
| `setup-species-basics.sh` | LaserSlab 双物质 + Sunliang_laser_CH 多层靶 + 多元素物质的 setup 命令脚本 |
| `parfile-multispecies.txt` | 完整物种段 parfile 参考（含 3 场景：双物质 / 多层靶 / 多元素）|

## 使用流程（典型工作流）

### 1. 选择算例并 setup

```bash
cd $FLASH_ROOT

# 双物质（HEDP 标准，LaserSlab cham+targ）
bash skills/flash-multispecies/examples/setup-species-basics.sh laserslab

# 或：多层靶（Sunliang_laser_CH 4 层）
bash skills/flash-multispecies/examples/setup-species-basics.sh sunliang

# 或：多元素物质（CH 塑料 NumElems=2）
bash skills/flash-multispecies/examples/setup-species-basics.sh multi-element
```

### 2. 确认 setup 生成的物种宏

```bash
grep -E 'FLASH_MULTISPECIES|NSPECIES|MS_MAXELEMS|CHAM_SPEC|TARG_SPEC' \
  cases/<case>/setup_defines
```

应看到：
- `FLASH_MULTISPECIES` 编译宏
- `NSPECIES = 2`（或 4 多层靶）
- `MS_MAXELEMS = 6`（默认）
- `CHAM_SPEC = <number>`、`TARG_SPEC = <number+1>`

### 3. 检查 parfile 物种段

```bash
grep -E '^ms_|^eos_|^op_' cases/<case>/flash.par
```

确认所有 `ms_<spec>A/Z/ZMin`、`eos_<spec>EosType/SubType/TableFile`、`op_<spec>FileName` 都填了具体值，不是 -999. 或 "-none-"。

参考：`parfile-multispecies.txt` 有完整模板，可直接 cp 物种段到 flash.par。

### 4. 编译 + 运行

```bash
cd cases/<case>
make -j4
./flash4 -par_file flash.par
```

### 5. 验证运行时物种数据库

跑起来后查看日志：

```bash
grep -A 30 'Initially defined values of species' 01-data/<basenm>.log
```

应看到 `Multispecies_list` 打印的完整物种表，包括 A、Z、eosType 等。

多元素物质场景：

```bash
grep -A 5 '<spec>      2 constituents' 01-data/<basenm>.log
```

应看到元素构成段（C/H 等）。

## 关键参数族速查

| 前缀 | 含义 | 自动生成条件 |
|---|---|---|
| `ms_<spec>A/Z/Neutral/Negative/BindEnergy/Gamma/ZMin` | 物质属性 | `species=` setup 变量 |
| `ms_<spec>NumElems/ZElems_<i>/AElems_<i>/Fractions_<i>` | 多元素构成 | `species=` + `ms_maxelems=N` |
| `eos_<spec>EosType/SubType/TableFile/GroupName/SesDblFmt` | EOS 表绑定 | `species=` |
| `op_<spec>LowTemp` | Opacity 低温阈值 | `species=` |
| `op_<spec>Absorb/Emiss/Trans/FileType/FileName` | Opacity 表绑定 | `species=`（Opacity 单元 Config） |

## 三个场景对比

| 场景 | 物种数 | 物理图景 | 关键参数 |
|---|---|---|---|
| LaserSlab 双物质 | 2 (cham, targ) | HEDP 标准：He 真空腔 + Al 靶 | ms_chamA=4.002 ms_targA=26.98 |
| Sunliang 多层靶 | 4 (cham, targ1, targ2, targ3) | ICF 多层靶：He + CH 外层 + CHBr 掺杂 + CH 内层 | 每层独立 EOS 表 |
| 多元素物质 | 2 (cham, ch) | CH 塑料按元素构成（C+H） | NumElems=2 + ZElems/AElems/Fractions |

## 关键源码入口

详见 `skills/flash-multispecies/SKILL.md §6`。

| 想理解 | 看哪个文件 |
|---|---|
| 自动生成机制 | `source/Multispecies/MultispeciesMain/Config:L1-L42`（Python genLines）|
| 属性宏 | `source/Multispecies/Multispecies.h:L22-L51` |
| 数据结构 | `source/Multispecies/MultispeciesMain/Multispecies_data.F90:L32-L58` |
| 初始化主流程 | `source/Multispecies/MultispeciesMain/Multispecies_init.F90:L33-L200` |
| Helmholtz 算 Abar/Zbar | `source/physics/Eos/EosMain/Helmholtz/SpeciesBased/eos_helmholtz.F90:L326-L337` |
| LaserSlab 质量分数初始化 | `source/Simulation/SimulationMain/LaserSlab/Simulation_initBlock.F90:L100-L153` |

## 跨 skill 协作

- 想了解 EOS 模式系统 / Helmholtz 内部 → `flash-eos`
- 想了解 EOS 表格式（ionmix4 / sesame）/ 不透明度 → `flash-material`
- 找 Multispecies_* 函数源码位置 → `flash-source-reader`
- 错误信息匹配（如 `divide by ZERO property`）→ `flash-pitfall-finder`
- 单参数基本属性查询 → `flash-param-query`
