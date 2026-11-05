---
title: Multispecies 参数完整字典 — ms_*/eos_*/op_*/setup 变量
skill: flash-multispecies
category: params
source_anchors:
  - source/Multispecies/MultispeciesMain/Config:L1-L42
  - source/Multispecies/Multispecies.h:L22-L51
  - source/Multispecies/MultispeciesMain/Multispecies_init.F90:L91-L194
  - source/Simulation/SimulationMain/LaserSlab/example.par:L221-L237
  - source/Simulation/SimulationMain/Sunliang_laser_CH/example_xubo.par:L248-L277
manual_ref: "FLASH 4.8 User Guide §17 Multispecies + per-skill setup_help"
created: 2026-07-31
last_verified: 2026-07-31
verifier: claude
status: beta
tags:
  - multispecies
  - params
  - ms-prefix
  - eos-prefix
  - op-prefix
  - setup-variable
---

# Multispecies 参数完整字典

> **TL;DR**：分 4 类——(1) setup 变量（`species=`、`ms_maxelems`）；(2) 物质属性 `ms_<spec>*`（A/Z/N/E/EB/Gamma/ZMin + NumElems/ZElems/AElems/Fractions）；(3) EOS 表绑定 `eos_<spec>*`（EosType/SubType/TableFile/GroupName/SesDblFmt）；(4) Opacity 表绑定 `op_<spec>*`（LowTemp + Absorb/Emiss/Trans/FileName）。所有参数族**只在 `species=` setup 变量设置时自动生成**，否则用户得自己在 Config 写 `SPECIES` 行或在 Simulation_initSpecies 里 setProperty。

---

## 1. setup 变量（顶层）

### 1.1 `species=<spec1>,<spec2>,...`

| 字段 | 值 |
|---|---|
| 类型 | setup 变量（逗号分隔字符串） |
| 默认 | 未设 |
| 在哪写 | setup 命令行 `./setup ... species=cham,targ` |
| 作用 | 触发 Multispecies/Config Python 段，自动生成参数族 |

**L-011 为什么有这个变量**：避免用户手写 `Config` 的 `SPECIES CHAM` 行 + 在 Simulation_initSpecies 里 setProperty。setup 看到后**一次性建好所有 ms_/eos_/op_ 参数 + Flash.h 物种索引常量 + UNK 中心变量**，用户在 parfile 填数值即可。

**L-011 何时填**：
- HEDP 算例（LaserSlab、Sunliang_laser_CH）—— 必填，species 名按物质物理意义命名（cham=chamber 真空腔、targ=target 靶）
- 单物质算例（Sod 激波管）—— 不填（用 Gamma EOS 即可，不需要物种追踪）
- 核合成算例（Type Ia）—— 必填，species 名用核素（NI56、CO61、FE51...）

**L-011 命名约定**：
- 小写（setup 自动 `.upper()` 生成 SPEC 宏，但参数名是小写前缀）：`cham`、`targ`、`he`、`al`、`ch`、`chbr`
- 不要用空格 / 特殊字符（只能是字母数字）
- 多层靶用编号：`targ1`、`targ2`、`targ3`（Sunliang_laser_CH 4 层）

### 1.2 `ms_maxelems=N`

| 字段 | 值 |
|---|---|
| 类型 | setup 变量（整数） |
| 默认 | 6 |
| 范围 | 1 ~ 用户定义上限 |
| 在哪写 | setup 命令行 `./setup ... ms_maxelems=8` |
| 作用 | 单个 species 最多含多少种元素（控制数组维度） |

**L-011 为什么默认 6**：常见 HEDP 物质最多 6 种元素就够（高 Z 物质如 Au 1 种、塑料 CH 2 种、SiO₂ 2 种、玻璃 BéAlSiO 4 种...）。

**L-011 何时改**：
- 复杂化学物质（蛋白质、有机分子）→ 改大（如 10）
- 纯元素（Au、Al）→ 改小（如 1）节省内存
- 大多数 HEDP 用户用默认 6

源码：`source/Multispecies/MultispeciesMain/Config:L7-L13`

```python
maxelems = 6
if "ms_maxelems" in setupvars:
    maxelems = int(setupvars["ms_maxelems"])
yield "PPDEFINE MS_MAXELEMS " + str(maxelems)
```

### 1.3 `ManualSpeciesDirectives=True`

| 字段 | 值 |
|---|---|
| 类型 | setup 变量（布尔） |
| 默认 | False |
| 作用 | 不自动 yield `SPECIES` 行（用户自己在 Config 写） |

**L-011 为什么有这个**：极少数情况用户想**自己控制 species 名到 SPECIES 宏的映射**（如自定义命名空间）。默认 False，HEDP 不需要。

---

## 2. 物质属性 `ms_<spec>*` 参数族

### 2.1 `ms_<spec>A`（原子质量数 A）

| 字段 | 值 |
|---|---|
| 类型 | REAL |
| 默认 | -999.（未定义） |
| 单位 | 无量纲（原子质量单位） |
| 在哪写 | flash.par |
| 作用 | Abar 计算的权重（Abar = 1/Σ(X_i/A_i)） |

**典型值**：
- He: 4.002602
- Al: 26.9815386
- CH 塑料: 13（C=12×0.857 + H=1×0.143 ≈ 10.4，但用户可显式设）
- Au: 196.9665

源码声明：`source/Multispecies/MultispeciesMain/Config:L24`

```python
yield 'PARAMETER  ms_' + spec + 'A          REAL -999.'
```

**L-011 为什么默认 -999.**：未定义标记。如果用户没填，Multispecies_init 检查到负值会**尝试用多元素构成 dot_product 重算**（仅当 NumElems>0）。如果两者都没填，Helmholtz EOS 调 getSumInv(A) 会拿到 -999 → 算 abarInv 是负的 → Abar 是负的 → EOS 表查询失败或 NaN。

**必填**：除非用 NumElems + AElems + Fractions（多元素路径）。

### 2.2 `ms_<spec>Z`（原子序数 Z）

| 字段 | 值 |
|---|---|
| 类型 | REAL |
| 默认 | -999. |
| 单位 | 无量纲 |
| 在哪写 | flash.par |
| 作用 | Zbar 计算（Zbar = Abar·Σ(X_i·Z_i/A_i)） |

**典型值**：
- He: 2.0
- Al: 13.0
- C: 6
- H: 1
- Au: 79

### 2.3 `ms_<spec>ZMin`（最小 Zbar）

| 字段 | 值 |
|---|---|
| 类型 | REAL |
| 默认 | -998.（未定义） |
| 单位 | 无量纲 |
| 在哪写 | flash.par |
| 作用 | EOS 算离子化 Z* 时防止 Z*=0（除零保护） |

**L-011 为什么默认 -998.**：未定义标记。HEDP 物质通常填一个小正数（如 0.01 ~ 0.1），表示离子化下限。

**典型值**：0.02（LaserSlab 默认）、0.01（高 Z 物质）、0.001（极低密度等离子体）

**何时必填**：
- MHD + Hall 效应（`use_Hall=true`）：Multispecies_init 主动警告 "Electron number density may be extremely low"，建议填
- MHD + Biermann3T（`use_Biermann3T=true`）：同上
- 纯 Hydro 不填也行（但建议填）

源码：`source/Multispecies/MultispeciesMain/Multispecies_init.F90:L126-L135`

```fortran
if (useHall .or. useBiermann3T) then
   if (ms_Array(i)%zMin < 0.) then
      if (ms_globalMe == MASTER_PE) then
         PRINT*, "WARNING: Electron number density may be extremely low for Hall and/or"
         PRINT*, "         Biermann3T dt calculations. Consider setting a ZMin for species"
      end if
   end if
end if
```

### 2.4 `ms_<spec>Neutral`（中子数 N）

| 字段 | 值 |
|---|---|
| 类型 | REAL |
| 默认 | -999. |
| 单位 | 无量纲 |
| 作用 | N = A - Z（可自动推导） |

**L-011 为什么默认未定义**：可以从 A 和 Z 推导（N = A - Z），用户通常不填。仅核合成场景手动填（衰变中子守恒）。

### 2.5 `ms_<spec>Negative`（电子数 E）

| 字段 | 值 |
|---|---|
| 类型 | REAL |
| 默认 | -999. |
| 单位 | 无量纲 |
| 作用 | 中性原子 E = Z |

**L-011 为什么默认未定义**：中性物质 E = Z（自动），仅特殊场景（预离子化）手动填。

### 2.6 `ms_<spec>BindEnergy`（核结合能 EB）

| 字段 | 值 |
|---|---|
| 类型 | REAL |
| 默认 | -999. |
| 单位 | MeV |
| 作用 | 核反应能量释放计算 |

**HEDP 不用**（核合成场景才用）。

### 2.7 `ms_<spec>Gamma`（理想气体 γ）

| 字段 | 值 |
|---|---|
| 类型 | REAL |
| 默认 | **5.0/3.0 = 1.6667** |
| 单位 | 无量纲 |
| 作用 | Multigamma EOS 用（Cp/Cv） |

**L-011 为什么默认 5/3**：单原子理想气体标准值（HEDP 物质在高温下近似单原子行为）。双原子（如 H₂、N₂ 在低温）用 7/5=1.4，复杂分子用其他值。

源码：`source/Multispecies/MultispeciesMain/Config:L29`

```python
yield 'PARAMETER  ms_' + spec + 'Gamma      REAL ' + str(5.0/3.0)
```

### 2.8 多元素物质三件套（NumElems + ZElems/AElems/Fractions）

#### `ms_<spec>NumElems`

| 字段 | 值 |
|---|---|
| 类型 | INTEGER |
| 默认 | 0 |
| 范围 | 0 ~ MS_MAXELEMS（默认 6） |
| 作用 | 该 species 含几种元素（0=纯元素，用 ms_<spec>A/Z） |

#### `ms_<spec>ZElems_<i>`（i=1..MS_MAXELEMS）

| 字段 | 值 |
|---|---|
| 类型 | INTEGER |
| 默认 | -999 |
| 作用 | 第 i 种元素的电荷数 Z |

#### `ms_<spec>AElems_<i>`

| 字段 | 值 |
|---|---|
| 类型 | REAL |
| 默认 | -999. |
| 作用 | 第 i 种元素的质量数 A |

#### `ms_<spec>Fractions_<i>`

| 字段 | 值 |
|---|---|
| 类型 | REAL |
| 默认 | -999. |
| 作用 | 第 i 种元素的质量占比（0~1） |

**L-011 什么时候用多元素**：
- 化合物 / 混合物（CH 塑料、SiO₂、CHBr）—— 必用
- 纯元素（Au、Al、He）—— 不用（NumElems=0，直接 A/Z）

**L-011 自动归一化**：Multispecies_init 检查 Σ fractions ≠ 1 时**自动归一化**（除以 sum），让用户填相对比例即可。

**L-011 自动重算 A/Z**：如果用户填了 NumElems>0 但没填 ms_<spec>A，Multispecies_init 按 dot_product 自动算：
- A = Σ(Frac_i × AElem_i)
- Z = Σ(Frac_i × ZElem_i)

源码：`source/Multispecies/MultispeciesMain/Multispecies_init.F90:L154-L172`

```fortran
if (nelems > 0) then
   fracSum = sum(ms_Array(i)%fractions(1:nelems))
   if (fracSum /= 1.) then
      ms_Array(i)%fractions(1:nelems) = ms_Array(i)%fractions(1:nelems) / fracSum
   end if
   if (ms_Array(i)%numTotal < 0.) then
      ms_Array(i)%numTotal = dot_product(ms_Array(i)%Fractions(1:nelems),ms_Array(i)%aElems(1:nelems))
   end if
   if (ms_Array(i)%numPositive < 0.) then
      ms_Array(i)%numPositive = dot_product(ms_Array(i)%Fractions(1:nelems),ms_Array(i)%zElems(1:nelems))
   end if
end if
```

**CH 塑料示例**（典型值）：

```fortran
ms_chNumElems     = 2
ms_chZElems_1     = 6
ms_chAElems_1     = 12
ms_chFractions_1  = 0.857        ! C 质量占比
ms_chZElems_2     = 1
ms_chAElems_2     = 1
ms_chFractions_2  = 0.143        ! H 质量占比
```

---

## 3. EOS 表绑定 `eos_<spec>*` 参数族

### 3.1 `eos_<spec>EosType`（EOS 类型）

| 字段 | 值 |
|---|---|
| 类型 | STRING |
| 默认 | "-none-" |
| 允许值 | `["-none-", "eos_gam", "eos_tab"]` |
| 作用 | 该 species 用哪种 EOS |

**典型值**：
- `"eos_gam"` — Multigamma 理想气体（每种 species 一个 γ）
- `"eos_tab"` — Tabulated 表 EOS（ionmix4 / sesame / opacplot...）

**L-011 何时填什么**：
- LaserSlab cham(He) + targ(Al) 都用 `"eos_tab"`（HEDP 表）
- 纯气体混合（如 Sod 双气体）用 `"eos_gam"`
- 不用该 species 的 EOS（仅追踪质量分数）用 `"-none-"`

源码：`source/Multispecies/MultispeciesMain/Config:L32`

```python
yield 'PARAMETER eos_' + spec + 'EosType    STRING "-none-" ["-none-","eos_gam","eos_tab"]'
```

### 3.2 `eos_<spec>SubType`（EOS 子类型 = 表格式）

| 字段 | 值 |
|---|---|
| 类型 | STRING |
| 默认 | "-none-" |
| 允许值 | `["-none-", "ionmix", "ionmix4", "ionmix6", "propaceos", "opacplot", "sesame"]` |
| 作用 | 表 EOS 的具体格式 |

**主流值**（按 L-013 聚焦）：
- `"ionmix4"` — **HEDP 标准**（LaserSlab/Sunliang_laser_CH 都用），二进制 HDF5 或 ASCII
- `"sesame"` — SESAME 表（高精度，IAPCM/学术合作获取）
- 其他（`ionmix`、`ionmix6`、`propaceos`、`opacplot`）—— 边缘场景

详见 `flash-material` skill（表格式细节）。

### 3.3 `eos_<spec>TableFile`（EOS 表文件名）

| 字段 | 值 |
|---|---|
| 类型 | STRING |
| 默认 | "-none-" |
| 作用 | EOS 表文件路径（相对 / 绝对） |

**典型值**：
- `"he-imx-005.cn4"` — He EOS 表（LaserSlab cham）
- `"al-imx-003.cn4"` — Al EOS 表（LaserSlab targ）
- `"polystyrene-imx-008.cn4"` — CH 塑料（Sunliang_laser_CH targ1）
- `"chBr-hyades.cn4"` — CHBr（Sunliang_laser_CH targ2）

文件必须在 case 目录或 IO 路径下。

### 3.4 `eos_<spec>GroupName`（EOS 表内部 group）

| 字段 | 值 |
|---|---|
| 类型 | STRING |
| 默认 | "-none-" |
| 作用 | 表内部命名空间（同一文件多 species 共用） |

**L-011 什么时候用**：单个 `.cn4` 文件里**含多种物质**（如多群不透明度表分 species 存储）时用。HEDP 算例通常一文件一物质，GroupName="-none-"。

### 3.5 `eos_<spec>SesDblFmt`（SESAME 双精度格式）

| 字段 | 值 |
|---|---|
| 类型 | STRING |
| 默认 | "E22.15" |
| 作用 | 读 SESAME 表时的浮点格式字符串（Fortran format） |

**L-011 为什么默认 E22.15**：SESAME 表常见格式（22 字符宽，15 位有效数字）。某些早期 SESAME 文件用其他格式（如 E16.9），用户可改。

---

## 4. Opacity 表绑定 `op_<spec>*` 参数族

### 4.1 `op_<spec>LowTemp`（低温阈值）

| 字段 | 值 |
|---|---|
| 类型 | REAL |
| 默认 | 0.0 |
| 单位 | K |
| 作用 | 低于此温度时用低温度不透明度（避免表外推） |

**L-011 为什么默认 0**：不启用低温度阈值。某些表在 eV 以下精度差，用户填如 `op_chamLowTemp=1.0`（1 K）或 `op_targLowTemp=10.0`（10 K）启用。

源码：`source/Multispecies/MultispeciesMain/Config:L31`

```python
yield 'PARAMETER  op_' + spec + 'LowTemp    REAL 0.0'
```

### 4.2 其他 op_<spec>* 参数（Opacity 单元定义）

注意：`op_<spec>LowTemp` 在 Multispecies/Config 里 yield，但其他 op_<spec>* 参数族（`op_<spec>Absorb/Emiss/Trans/FileType/FileName`）**由 Opacity 单元的 Config 自动生成**，详见 `flash-material` skill。

典型值（LaserSlab example.par:L63-L74）：

```fortran
op_chamAbsorb   = "op_tabpa"
op_chamEmiss    = "op_tabpe"
op_chamTrans    = "op_tabro"
op_chamFileType = "ionmix4"
op_chamFileName = "he-imx-005.cn4"

op_targAbsorb   = "op_tabpa"
op_targEmiss    = "op_tabpe"
op_targTrans    = "op_tabro"
op_targFileType = "ionmix4"
op_targFileName = "al-imx-003.cn4"
```

---

## 5. 完整参数族示例（双物质 LaserSlab）

`species=cham,targ` 自动生成（按 `source/Multispecies/MultispeciesMain/Config` Python 段 yield）：

```fortran
# cham 物质（He 气体，真空腔）
ms_chamA          = 4.002602        ! 必填
ms_chamZ          = 2.0             ! 必填
ms_chamZMin       = 0.02            ! 推荐（防除零）
ms_chamNeutral    = -999.           ! 未定义（可推导）
ms_chamNegative   = -999.           ! 未定义
ms_chamBindEnergy = -999.           ! 未定义（HEDP 不用）
ms_chamGamma      = 1.6666667       ! 默认 5/3
op_chamLowTemp    = 0.0             ! 默认

ms_chamNumElems   = 0               ! 纯元素
# ZElems_1..6, AElems_1..6, Fractions_1..6 都默认 -999

eos_chamEosType   = "eos_tab"       ! 表 EOS
eos_chamSubType   = "ionmix4"       ! HEDP 标准格式
eos_chamTableFile = "he-imx-005.cn4"
eos_chamSesDblFmt = "E22.15"        ! 默认（SESAME 才用）
eos_chamGroupName = "-none-"        ! 默认

# targ 物质（Al 靶）
ms_targA          = 26.9815386
ms_targZ          = 13.0
ms_targZMin       = 0.02
eos_targEosType   = "eos_tab"
eos_targSubType   = "ionmix4"
eos_targTableFile = "al-imx-003.cn4"
```

---

## 6. 完整参数族示例（4 层靶 Sunliang_laser_CH）

`species=cham,targ1,targ2,targ3` 自动生成 4 套（每个 spec 各 16+ 参数）。Sunliang_laser_CH 实际配置（example_xubo.par:L248-L277）：

```fortran
# 4 种物质，每种都有独立 EOS 表 + Opacity 表
ms_tar1A          = 13              ! CH 塑料近似
ms_tar1Z          = 6
ms_tar1ZMin       = 0.02
eos_tar1EosType   = "eos_tab"
eos_tar1SubType   = "ionmix4"
eos_tar1TableFile = "polystyrene-imx-008.cn4"

ms_tar2A          = 13              ! CHBr 掺杂层
ms_tar2Z          = 6
ms_tar2ZMin       = 0.02
eos_tar2EosType   = "eos_tab"
eos_tar2SubType   = "ionmix4"
eos_tar2TableFile = "chBr-hyades.cn4"

ms_tar3A          = 13              ! CH 塑料（最外层）
ms_tar3Z          = 6
ms_tar3ZMin       = 0.02
eos_tar3EosType   = "eos_tab"
eos_tar3SubType   = "ionmix4"
eos_tar3TableFile = "polystyrene-imx-008.cn4"
```

### 6.1 物质命名约定（L-013 实践经验）

| 命名风格 | 例子 | 适用场景 |
|---|---|---|
| 物理位置 | `cham`（chamber）、`targ`（target） | HEDP 标配（LaserSlab） |
| 编号 + 物理位置 | `targ1`、`targ2`、`targ3` | 多层靶（Sunliang_laser_CH） |
| 元素符号 | `he`、`al`、`au`、`ch` | 单物质算例 |
| 化学式 | `h2o`、`co2` | 化学混合（罕见） |
| 核素 | `ni56`、`co61`、`fe51` | 核合成（天体物理） |

---

## 7. 常见错误速查

| 错误 | 原因 | 修复 |
|---|---|---|
| `Multispecies_getSumInv: divide by ZERO property` | `ms_<spec>A` 未填（-999. → abarInv 计算异常） | parfile 填 `ms_<spec>A=<value>` |
| `Error: Species property not found` | `Multispecies_setProperty(name, property, value)` 的 property 不在 if 链 | 检查 property 是 A/Z/N/E/EB/GAMMA/MS_ZMIN/MS_OPLOWTEMP/MS_EOSTYPE/MS_EOSSUBTYPE 之一 |
| `Multispecies_getSumInv: invalid weights array` | weights 数组长度 ≠ 1 或 NSPECIES | 检查 `size(weights)` |
| `Multispecies_getAvg: mask array wrong size` | speciesMask 长度 ≠ NSPECIES | 检查 `size(speciesMask)`，必须 = NSPECIES |
| Abar=0 / NaN | parfile 里 ms_<spec>A 没填 / 没用 species setup 变量 / 物质属性全默认 | 见 `knowledge/pitfalls.md §B` |

---

## 8. 延伸阅读

- 相关条目：`knowledge/overview.md`（机制 + 物理原理）、`knowledge/internals.md`（API + 数据结构）、`knowledge/recipes.md`（典型 parfile）、`knowledge/pitfalls.md`（错误排查）
- 跨 skill：
  - `flash-eos` — EOS 模式系统、Helmholtz/Tabulated 内部
  - `flash-material` — 不透明度 / 电导率表 + 表格式
  - `flash-param-query` — 单参数基本属性查询

---

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-31 | 初始创建（完整参数字典，含 setup 变量 / ms_/eos_/op_ 前缀族 + 实战 parfile 示例）| claude |
