---
title: Multispecies 单元总览 — 角色、species setup 机制、质量分数、Abar/Zbar
skill: flash-multispecies
category: overview
source_anchors:
  - source/Multispecies/MultispeciesMain/Config:L1-L42
  - source/Multispecies/Multispecies.h:L22-L51
  - source/Multispecies/MultispeciesMain/Multispecies_data.F90:L32-L58
  - source/Multispecies/MultispeciesMain/Multispecies_init.F90:L91-L198
  - source/physics/Eos/EosMain/Helmholtz/SpeciesBased/eos_helmholtz.F90:L326-L337
  - source/Simulation/SimulationMain/LaserSlab/Simulation_initBlock.F90:L100-L153
manual_ref: "FLASH 4.8 User Guide §17 Multispecies"
created: 2026-07-31
last_verified: 2026-07-31
verifier: claude
status: beta
tags:
  - multispecies
  - overview
  - mass-fraction
  - abar
  - zbar
  - species-setup
---

# Multispecies 单元总览

> **TL;DR**：Multispecies 是 FLASH 的**多物质追踪单元**——给定每个 cell 里 N 种物质各自的质量分数 `X_i`（0~1，Σ=1），让 EOS、Opacity、Laser 等单元能按物质加权查询热力学量和不透明度。**核心机制**：`./setup species=cham,targ` setup 变量触发 Python Config 自动生成 `ms_<spec>*` / `eos_<spec>*` / `op_<spec>*` 参数族 + `SPECIES_VAR(SPECIES_BEGIN..SPECIES_END)` UNK 变量 + `CHAM_SPEC`/`TARG_SPEC` 索引常量。Helmholtz EOS 调 `Multispecies_getSumInv(A) + getSumFrac(Z)` 自动算 `Abar = 1/Σ(X_i/A_i)`、`Zbar = Abar·Σ(X_i·Z_i/A_i)`。

---

## 1. Multispecies 在 FLASH 里扮演什么角色

### 1.1 一句话定位

Multispecies 单元 = **多物质追踪器**。它**不演化**质量分数（那是 Hydro 的 advection 任务），它的职责是：

1. **注册**每种物质（名字、A 质量数、Z 电荷数、EOS 表、Opacity 表...）到全局数据库 `ms_Array(NSPECIES)`
2. **提供查询 API**（getSum / getSumInv / getSumFrac / getSumSqr / getAvg / getProperty），让其他单元按 mass fraction 加权算平均
3. **维护**质量分数作为 UNK 中心变量（Hydro advect 它）

### 1.2 为什么需要 Multispecies

HEDP 算例（如 LaserSlab）的物理图景：

```
靶 Al (A=26.98, Z=13)
        │
        │  ← 激光从左打到靶表面
        ▼
真空腔 He (A=4.002, Z=2)
```

激光打到 Al 表面时，电子被加速、能量沉积到电子内能。要正确算：

- **不透明度**（激光怎么被吸收）—— 靶是 Al（强吸收），腔是 He（弱吸收），按 mass fraction 加权
- **EOS**（温度、压力、声速）—— Al 的 EOS 表（ionmix4 .cn4）和 He 完全不同
- **Abar/Zbar**（Helmholtz EOS 自由能表的关键参数）—— 混合区域必须加权平均

**没有 Multispecies**，每个 cell 只能用单一 EOS（如 Gamma 单原子理想气体），物理失真。

### 1.3 术语速查（L-014）

| 术语 | 全称 | 含义 | 为什么需要 |
|---|---|---|---|
| **species** | 物种 | FLASH 里一种"物质"的统称，可以是元素（Al、He）也可以是化合物（CH 塑料、CHBr）甚至核素（Ni56） | 区分不同 EOS / 不透明度的材料 |
| **mass fraction X_i** | 质量分数 | cell 里 species i 的质量 / 总质量，0~1，所有 species 之和 = 1 | 用于质量加权平均（HEDP 标准） |
| **A**（numTotal） | atomic mass number 原子质量数 | 原子核里**质子+中子**的总数（整数） | Helmholtz EOS 算 Abar 用 |
| **Z**（numPositive） | atomic number 原子序数 / 电荷数 | 原子核里**质子**数（整数） | Helmholtz EOS 算 Zbar / Coulomb 修正用 |
| **N**（numNeutral） | neutron number 中子数 | 原子核里**中子**数 = A - Z | 核合成场景用（HEDP 不常用） |
| **E**（numNegative） | electron number 电子数 | 原子里电子数（中性原子 = Z） | 罕用，特殊场景 |
| **EB** | binding energy 结合能 | 核结合能（MeV 单位） | 核合成能量释放 |
| **GAMMA** | adiabatic index | 理想气体 γ=Cp/Cv（默认 5/3） | Multigamma EOS 用 |
| **ZMin** | zbar 下限 | 离子化的最小 Z* 值（默认未设） | 防止 Z*=0 时除零（Hall/Biermann MHD 必须） |
| **Abar** | 平均原子量 | 混合气体的"等效"原子质量数 | EOS 表查询的关键参数 |
| **Zbar** | 平均电荷数 | 混合气体的"等效"原子序数 | EOS 表查询 + Coulomb 修正 |
| **UNK** | unknown variable | FLASH Grid 的中心（cell-centered）变量 | 质量分数存这里 |
| **species setup 变量** | — | setup 命令行 `species=cham,targ` | 自动建参数族 + UNK 变量 |

### 1.4 与其他单元的耦合

```
┌─────────────────────────────────────────────────────┐
│ Driver_initFlash                                     │
│   └── Multispecies_init ★                            │ ← 物种数据库初始化
│       ├── 读 ms_<spec>* 参数族（如果 species= 设置）│
│       ├── 归一化 fractions（多元素）                │
│       └── Simulation_initSpecies（用户 hook）        │
├─────────────────────────────────────────────────────┤
│ Simulation_initBlock                                 │ ← 用户初始化每个 cell
│   └── Grid_putPointData(CENTER, SPECIES_BEGIN+n,    │
│                          EXTERIOR, axis, X_i)       │
│       （循环 SPECIES_BEGIN..SPECIES_END 填质量分数）│
├─────────────────────────────────────────────────────┤
│ Hydro（每步）                                        │
│   └── advect SPECIES_VAR ★（质量分数跟流体走）      │
│       （Hydro 不知道物种语义，只 advect 标量）       │
├─────────────────────────────────────────────────────┤
│ Eos_wrapped（每步）                                  │ ← Helmholtz / multiTemp
│   ├── Multispecies_getSumInv(A, abarInv, massFrac)  │
│   │   → Abar = 1/abarInv                            │
│   ├── Multispecies_getSumFrac(Z, zbarFrac, massFrac)│
│   │   → Zbar = Abar * zbarFrac                      │
│   └── 用 Abar/Zbar 查 EOS 表算 P、T、c_s            │
├─────────────────────────────────────────────────────┤
│ Opacity（每步，per-species）                         │ ← flash-material
│   └── 用 Multispecies_getProperty(MS_NUMELEMS, ...)  │
│       查 species 的元素构成 → 查 per-species 表     │
├─────────────────────────────────────────────────────┤
│ Burn（核反应，每步，可选）                           │
│   └── Multispecies_setProperty 改物种的 X_i         │
│       （核合成场景：Ni56 → Co → Fe 衰变链）          │
├─────────────────────────────────────────────────────┤
│ IO_output（每次 plotfile）                          │
│   └── 写 SPECIES_VAR 到 HDF5/Fortran plotfile       │
└─────────────────────────────────────────────────────┘
```

---

## 2. 物理原理：质量分数加权

### 2.1 为什么是 mass fraction（质量分数）

FLASH 的物质追踪用**质量分数 X_i** 而不是**体积分数**或**摩尔分数**。原因：

| 选择 | 优点 | 缺点 |
|---|---|---|
| **质量分数 X_i** | Hydro 守恒方程自然演化（质量守恒 → X_i 也守恒）；EOS 加权（abundance-weighted）天然是质量加权 | 混合区域 Abar/Zbar 不是简单平均 |
| 体积分数 | 几何直观 | 不守恒（密度变化时变） |
| 摩尔分数 | 化学反应场景直观 | 不守恒 |

FLASH HEDP 主流场景（流体 + EOS）用 mass fraction 最自然。

### 2.2 Abar/Zbar 加权公式

**Abar**（平均原子量，mass-fraction-weighted harmonic mean）：

```
Abar = 1 / Σ_i ( X_i / A_i )
```

这是**调和平均**（不是算术平均），物理意义：**单位物质的量（mole）的反比之和**。例：100g 的 50% He + 50% Al（mass fraction）混合物：
- He: 50g / 4 g/mol = 12.5 mol
- Al: 50g / 27 g/mol = 1.85 mol
- 平均 A = 总质量 / 总摩尔 = 100 / (12.5 + 1.85) = 7.04 ≈ Abar

`Multispecies_getSumInv(A, abarInv, massFrac)` 返回 `Σ(X_i/A_i)`，调用方算 `Abar = 1/abarInv`。

**Zbar**（平均电荷数）：

```
Zbar = Abar × Σ_i ( X_i × Z_i / A_i )
```

物理意义：每克混合物贡献的质子摩尔数，乘上 Abar 转回"每原子平均质子数"。`Multispecies_getSumFrac(Z, zbarFrac, massFrac)` 返回 `Σ(X_i·Z_i/A_i)`，调用方算 `Zbar = Abar * zbarFrac`。

### 2.3 为什么不是简单算术平均

如果用 `Abar = Σ X_i · A_i`（算术平均），例：50% He(A=4) + 50% Al(A=27)：
- 算术平均: `Abar = 0.5×4 + 0.5×27 = 15.5`
- 调和平均（正确）: `1/(0.5/4 + 0.5/27) = 7.04`

差异巨大（2 倍以上）。算术平均**错的物理**——它假设每克物质含相同原子数，实际上同样质量下 He 原子数比 Al 多近 7 倍。EOS 表查询用 Abar 决定每克物质的粒子数密度，错一个量级直接破坏热力学。

### 2.4 为什么 EOS 主动算 Abar/Zbar（不在 Multispecies 里算）

Multispecies 单元**只返回加权和**，不返回 Abar/Zbar 本身。原因：

- 不同 EOS 用不同的加权方式（Helmholtz 用质量加权；某些核合成场景用摩尔加权）
- Multispecies 保持通用（不知道 EOS 的偏好）
- 接口最小化（getSumInv/getSumFrac 是 building block）

这是经典的"**数据 vs 业务逻辑分离**"——Multispecies 是数据层（数据库 + 查询），EOS 是业务层（怎么用这些数据）。

---

## 3. species setup 变量机制（核心！）

### 3.1 setup 怎么看到 species

`./setup LaserSlab ... species=cham,targ` 时，setup.py 把 `species=cham,targ` 存到 setupvars dict，然后**对每个 unit 的 Config 文件执行 Python 段**。Multispecies/Config 第一段就是 Python：

源码：`source/Multispecies/MultispeciesMain/Config:L1-L42`

```python
##python:genLines

def genLines(setupvars):
    yield "PPDEFINE FLASH_MULTISPECIES"                  # 编译宏，激活 #ifdef

    maxelems = 6
    if "ms_maxelems" in setupvars:
        maxelems = int(setupvars["ms_maxelems"])
    yield "PPDEFINE MS_MAXELEMS " + str(maxelems)        # 元素数上限

    if "species" in setupvars:
        yield "PPDEFINE SPECIES_SETUPVAR"                # 让 Multispecies_init 走自动读参数族分支

        species = [s.lower() for s in setupvars["species"].split(',')]   # cham, targ

        for spec in species:                             # 对每个 species
            if not ManualSpeciesDirectives:
                yield "SPECIES " + spec.upper()          # 让 setup.py 在 Flash.h 生成 CHAM_SPEC/TARG_SPEC

            # 自动建一整套参数族（10+ 个 PARAMETER 行）
            yield 'PARAMETER  ms_' + spec + 'A          REAL -999.'
            yield 'PARAMETER  ms_' + spec + 'Z          REAL -999.'
            yield 'PARAMETER  ms_' + spec + 'Neutral    REAL -999.'
            yield 'PARAMETER  ms_' + spec + 'Negative   REAL -999.'
            yield 'PARAMETER  ms_' + spec + 'BindEnergy REAL -999.'
            yield 'PARAMETER  ms_' + spec + 'Gamma      REAL ' + str(5.0/3.0)
            yield 'PARAMETER  ms_' + spec + 'ZMin       REAL -998.'
            yield 'PARAMETER  op_' + spec + 'LowTemp    REAL 0.0'
            yield 'PARAMETER eos_' + spec + 'EosType    STRING "-none-" ["-none-","eos_gam","eos_tab"]'
            yield 'PARAMETER eos_' + spec + 'SubType    STRING "-none-" ["-none-","ionmix","ionmix4","ionmix6","propaceos","opacplot","sesame"]'
            yield 'PARAMETER eos_' + spec + 'TableFile  STRING "-none-"'
            yield 'PARAMETER eos_' + spec + 'SesDblFmt  STRING "E22.15"'
            yield 'PARAMETER eos_' + spec + 'GroupName  STRING "-none-"'

            # 多元素物质支持
            yield 'PARAMETER  ms_' + spec + 'NumElems   INTEGER 0 [... ' + str(maxelems) + ']'
            for i in range(maxelems):
                yield 'PARAMETER  ms_' + spec + 'ZElems_'    + str(i+1) + ' INTEGER -999'
                yield 'PARAMETER  ms_' + spec + 'AElems_'    + str(i+1) + ' REAL    -999.'
                yield 'PARAMETER  ms_' + spec + 'Fractions_' + str(i+1) + ' REAL    -999.'
```

### 3.2 setup 自动产出的东西（总结）

`species=cham,targ` 触发后：

| 产出 | 文件 / 位置 | 用途 |
|---|---|---|
| `FLASH_MULTISPECIES` PPDEFINE | setup_defines / Flash.h | 让代码 `#ifdef FLASH_MULTISPECIES` 分支生效 |
| `NSPECIES = 2` | Flash.h | 全局宏，物种数 |
| `MS_MAXELEMS = 6` | setup_defines | 单物种最多 6 种元素 |
| `SPECIES_SETUPVAR` PPDEFINE | Flash.h | 让 Multispecies_init 走自动读参数族分支 |
| `CHAM_SPEC` / `TARG_SPEC` | Flash.h | 物种索引常量（UNK 中心变量号） |
| `SPECIES_BEGIN` / `SPECIES_END` | Flash.h | 循环上下界 |
| `NPROP_VARS` | Flash.h | 物种变量起始编号偏移 |
| `ms_chamA` ... `ms_targFractions_6` 参数 | flash.par / RuntimeParameters | 物质属性 |
| `eos_chamEosType` ... `eos_targGroupName` 参数 | flash.par / RuntimeParameters | EOS 表绑定 |
| `op_chamLowTemp` 参数 | flash.par / RuntimeParameters | Opacity 表绑定 |
| UNK 中心变量 `SPECIES_VAR(CHAM_SPEC..TARG_SPEC)` | Grid | 质量分数 X_i 存储 |

用户**不需要写 Config 的 SPECIES 行**、**不需要手算索引**，只要在 parfile 填数值即可。

### 3.3 不用 species setup 变量会怎样

如果 setup 命令不带 `species=...`：

- `SPECIES_SETUPVAR` PPDEFINE **不定义**
- 参数族**不自动生成**（用户没法在 parfile 填 `ms_chamA`）
- 用户必须在 `Simulation/<problem>/Config` 手写 `SPECIES CHAM` + `SPECIES TARG`（推荐做法）
- 或者在 `Simulation_initSpecies.F90` 里用 `Multispecies_setProperty(CHAM_SPEC, A, 4.002)` 手动填（老式风格）

LaserSlab 推荐 `species=cham,targ` 走自动路径——简单、错误少、parfile 即文档。

---

## 4. 质量分数存储：UNK 中心变量

### 4.1 SPECIES_VAR 是什么

`SPECIES_VAR(CHAM_SPEC)`、`SPECIES_VAR(TARG_SPEC)` 是 **GRID 中心变量**（cell-centered UNK），和 `DENS_VAR`、`PRES_VAR`、`TEMP_VAR` 一样。

源码：`source/Simulation/SimulationMain/LaserSlab/Simulation_initBlock.F90:L142-L153`

```fortran
if (NSPECIES > 0) then
   ! Fill mass fractions in solution array if we have any SPECIES defined.
   do n = SPECIES_BEGIN,SPECIES_END
      if (n==species) then
         call Grid_putPointData(blockID, CENTER, n, EXTERIOR, axis, 1.0e0-(NSPECIES-1)*sim_smallX)
      else
         call Grid_putPointData(blockID, CENTER, n, EXTERIOR, axis, sim_smallX)
      end if
   enddo
end if
```

这是 LaserSlab 初始化质量分数的范式：被选中的 species 设 `1 - (NSPECIES-1)*smallX`，其余设 `smallX`（典型 1e-10，避免 EOS divide by zero）。

### 4.2 SPECIES_BEGIN / SPECIES_END 的关系

`SPECIES_BEGIN = NPROP_VARS + 1`，`SPECIES_END = NPROP_VARS + NSPECIES`。`NPROP_VARS` 是非物种中心变量数（DENS、PRES、TEMP、ENER、VELX...）。物种变量编号紧跟其后。

`ms_mapMSIndex(name, msindex)` 把 species 索引（如 CHAM_SPEC）映射到 ms_Array 内部索引（1, 2, 3...）：

源码：`source/Multispecies/MultispeciesMain/ms_mapMSIndex.F90:L29-L40`

```fortran
subroutine ms_mapMSIndex(name, msindex)
  integer, intent(in)   :: name
  integer, intent(out)  :: msindex
  msindex = name - NPROP_VARS        ! CHAM_SPEC - NPROP_VARS = 1（数组下标）
end subroutine ms_mapMSIndex
```

为什么这样设计？因为 Flash.h 里的 `CHAM_SPEC` 是**UNK 全局变量编号**（要避免和 DENS_VAR、PRES_VAR 等冲突），而 ms_Array 是**简单数组下标**（1, 2, 3...）。这个映射隐藏在 `Multispecies_getProperty` 里，用户不用关心。

### 4.3 物种在 plotfile 里怎么显示

`SPECIES_VAR(CHAM_SPEC)` 在 plotfile 里显示为变量名 `cham`、`targ`（由 `Simulation_mapIntToStr` 映射）。Flash 提供的 Python 工具（`flashy` / `yt`）可直接读这些变量做质量分数图。

---

## 5. 与 EOS / Opacity / Burn 的耦合

### 5.1 EOS（Helmholtz）算 Abar/Zbar

源码：`source/physics/Eos/EosMain/Helmholtz/SpeciesBased/eos_helmholtz.F90:L326-L337`

```fortran
#ifdef FLASH_MULTISPECIES
     !Calculate the inverse in a way that allows for zero mass fractions
     call Multispecies_getSumInv(A, abarInv, massFrac((k-1)*NSPECIES+1:k*NSPECIES))
     abarRow(k) = 1.e0 / abarInv

     call Multispecies_getSumFrac(Z, zbarFrac, massFrac((k-1)*NSPECIES+1:k*NSPECIES))
     zbarRow(k) = abarRow(k) * zbarFrac
#else
     ! No multispecies defined, use default values
     abarRow(k) = eos_singleSpeciesA
     zbarRow(k) = eos_singleSpeciesZ
#endif
```

注释 `allows for zero mass fractions`：getSumInv 对 `X_i=0` 的 species 自动跳过（权重 0，不贡献），所以混合区域里某 species 的 X_i 是 0 也 OK。

`massFrac((k-1)*NSPECIES+1:k*NSPECIES)` 是**向量化 EOS**（vector-based）的写法——一次处理 vecLen 个 cell，massFrac 数组大小 `vecLen × NSPECIES`。

### 5.2 EOS（multiTemp / Multigamma）同样机制

`source/physics/Eos/EosMain/multiTemp/Multigamma/eos_mgamma.F90:L402-L413` 用相同的 getSumInv(A)+getSumFrac(Z) 模式。LaserSlab 的 +mtmmmt（multiTemp multiTemp main）走这条路径。

### 5.3 Opacity（per-species 多元素）

源码：`source/physics/materialProperties/Opacity/OpacityMain/Multispecies/op_setSpeciesElementsData.F90:L101-L185`

```fortran
call Multispecies_getProperty(SPECIES_BEGIN - 1 + species, MS_NUMELEMS, nElements)
call Multispecies_getProperty(SPECIES_BEGIN - 1 + species, MS_ZELEMS,   Zvalues)
call Multispecies_getProperty(SPECIES_BEGIN - 1 + species, A,           Aspecies)
call Multispecies_getProperty(SPECIES_BEGIN - 1 + species, MS_FRACTIONS, numberFractions)
call Multispecies_getProperty(SPECIES_BEGIN - 1 + species, MS_OPLOWTEMP, lowTempCutoff)
```

Opacity 单元用这些查询每种物质的**元素构成**（如 CH 塑料 = 1 C + 1 H，按 Fractions 加权），从而查 per-element 的不透明度表再合成。详见 `flash-material`。

### 5.4 Burn（核反应改物种）

核合成场景下，Burn 网络演化物种的 X_i（Ni56 → Co → Fe 衰变链）。Burn 单元直接读 / 写 `SPECIES_VAR`，并在必要时调 `Multispecies_setProperty` 改变物种的 A/Z（如果产物物种不同）。HEDP 不用，简要。

### 5.5 Laser（per-species 吸收）

激光沉积通常按 cell 整体算（不区分物种），但某些高级 setup（如 per-species 吸收系数）会用 `Multispecies_getProperty` 查询。详见 `flash-laser`。

---

## 6. 核心数据流（HEDP 典型流程）

以 LaserSlab 一步为例：

```
T=0 (初始化)
├── Multispecies_init
│   ├── 读 ms_chamA=4.002 ms_chamZ=2 ms_targA=26.98 ms_targZ=13（从 parfile）
│   ├── 存到 ms_Array(1)={A=4.002, Z=2, name=CHAM_SPEC}、ms_Array(2)={A=26.98, Z=13, name=TARG_SPEC}
│   └── 调 Simulation_initSpecies（hook，一般空）
└── Simulation_initBlock
    ├── 对每个 cell 判断是 cham 还是 targ 区域
    ├── cham 区: SPECIES_VAR(CHAM_SPEC)=1-smallX, SPECIES_VAR(TARG_SPEC)=smallX
    └── targ 区: SPECIES_VAR(CHAM_SPEC)=smallX, SPECIES_VAR(TARG_SPEC)=1-smallX

T=N (每步)
├── Hydro_advect （advect SPECIES_VAR ★ 质量分数跟流体走）
│   └── cham/targ 边界随流体演化（扩散、混合）
├── Eos_wrapped（让变量自洽）
│   ├── 取 cell 的 massFrac = [SPECIES_VAR(CHAM_SPEC), SPECIES_VAR(TARG_SPEC)]
│   ├── Multispecies_getSumInv(A, abarInv, massFrac)
│   │   → abarInv = X_cham/4.002 + X_targ/26.98
│   ├── abar = 1/abarInv（混合区自动得到过渡值）
│   ├── Multispecies_getSumFrac(Z, zbarFrac, massFrac)
│   │   → zbarFrac = X_cham*2/4.002 + X_targ*13/26.98
│   └── zbar = abar * zbarFrac
├── Opacity 查询（per-species）
│   └── Helmholtz 用 abar/zbar + 温度查 .cn4 表 → 得 ionization、pressure、eint
├── Laser 沉积
│   └── 用 Opacity 算逆韧致吸收 → 沉积到 EELE
└── Heatexchange 平衡 TELE/TEION
```

---

## 7. 关键设计选择与"为什么"

### 7.1 为什么质量分数用 UNK 中心变量（不是单独存储）

- 和 DENS、PRES 一致 → Hydro advect 不用区分
- IO 自动写 plotfile（不需要额外 IO 代码）
- AMR refine/prolong 自动处理（Grid 框架负责）

### 7.2 为什么属性存全局 ms_Array（不是每个 cell）

物质属性（A、Z、EOS 表名）是**全局常数**（每个 species 一份），不是 per-cell 变量。只质量分数是 per-cell。这避免内存浪费（NSPECIES × Ncells vs NSPECIES）。

### 7.3 为什么属性用整数宏 A=1, Z=2...（不用字符串）

源码：`source/Multispecies/Multispecies.h:L22-L43`

```c
#define A (1)
#define Z (2)
#define N (3)
#define E (4)
#define EB (5)
#define GAMMA 6
#define MS_ZMIN 7
#define Z2 8
#define MS_EOSTYPE 107
#define MS_EOSSUBTYPE 108
...
```

整数宏的好处：
- 编译期常量，subroutine 调用快（无需字符串比较）
- 类型安全（编译器检查 property 是合法值）
- 简化接口（一个 `Multispecies_getProperty(name, property, value)` 通吃所有属性类型）

代价：用户记不住 `MS_EOSTYPE=107`，必须用宏名调用。

### 7.4 为什么默认 ms_<spec>A = -999.

未定义标记。Multispecies_init 检查到负值，知道用户**没填**。多元素物质场景里，如果用户填了 NumElems>0 但没填 A，会自动按元素构成 dot_product 算 A。

### 7.5 为什么 qualityFraction 用 0~1（不是百分比）

物理标准（化学 / 等离子体物理都用 0~1），EOS 公式直接用 0~1，不用除以 100。

---

## 8. 与手册的差异 / 已知陷阱

| 点 | 手册说 | 源码实际 |
|---|---|---|
| 单元路径 | `physics/Multispecies/` | 实际在 `source/Multispecies/`（不是 physics 子目录） |
| `Multispecies_getProperty` 限制 | 只能查 scalar | 有 getRealArrProperty / getIntArrProperty 查数组（ZElems/Fractions 等） |
| Simulation_initSpecies 必要性 | 必须 | 仅当**不用 species setup 变量**时必须；用了 setup 变量，hook 可空 |

---

## 9. 延伸阅读

- 相关条目：`knowledge/params.md`（参数族完整字典）、`knowledge/internals.md`（API + 数据结构）、`knowledge/recipes.md`（典型配置）、`knowledge/pitfalls.md`（踩坑排查）
- 手册章节：FLASH 4.8 User Guide §17 Multispecies
- 跨 skill：
  - `flash-eos` — EOS 模式系统、Helmholtz/Tabulated 内部
  - `flash-material` — 不透明度 / 电导率表 + per-species 多元素
  - `flash-laser` — 激光吸收
  - `flash-source-reader` — 找 Multispecies_* 源码位置

---

## 10. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-31 | 初始创建（按 flash-eos overview 模板 + L-001~L-014 全部经验）| claude |
