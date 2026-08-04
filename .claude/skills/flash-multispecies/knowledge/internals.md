---
title: Multispecies 内部实现 — API、multispecies_type、Config 自动生成、EOS 耦合
skill: flash-multispecies
category: internals
source_anchors:
  - source/Multispecies/Multispecies.h:L22-L51
  - source/Multispecies/MultispeciesMain/Multispecies_data.F90:L32-L58
  - source/Multispecies/MultispeciesMain/Multispecies_init.F90:L33-L200
  - source/Multispecies/MultispeciesMain/Multispecies_getSumInv.F90:L87-L159
  - source/Multispecies/MultispeciesMain/Multispecies_getSumFrac.F90:L1-L100
  - source/Multispecies/MultispeciesMain/Multispecies_getProperty.F90:L45-L309
  - source/Multispecies/MultispeciesMain/Multispecies_setProperty.F90:L44-L88
  - source/Multispecies/MultispeciesMain/ms_mapMSIndex.F90:L29-L40
  - source/physics/Eos/EosMain/Helmholtz/SpeciesBased/eos_helmholtz.F90:L326-L337
manual_ref: "FLASH 4.8 User Guide §17 Multispecies + doxygen"
created: 2026-07-31
last_verified: 2026-07-31
verifier: claude
status: beta
tags:
  - multispecies
  - internals
  - api
  - data-structure
  - helmholtz-coupling
---

# Multispecies 内部实现

> **TL;DR**：8 个核心 API（getSum / getSumInv / getSumFrac / getSumSqr / getAvg / getProperty / setProperty / list）+ 一个数据结构 `multispecies_type`（13 个字段：A/Z/N/E/EB/Gamma/ZMin/opacityLowTemp/numElems/zElems/aElems/fractions + EOS 子结构）+ Config Python 段的自动参数族生成机制 + ms_mapMSIndex 把全局 UNK 索引映射到数组下标。Helmholtz EOS 通过 `getSumInv(A) + getSumFrac(Z)` 算 Abar/Zbar。

---

## 1. 数据结构 `multispecies_type`

源码：`source/Multispecies/MultispeciesMain/Multispecies_data.F90:L32-L58`

```fortran
type multispecies_type
   integer :: name                       ! UNK 全局变量号（CHAM_SPEC/TARG_SPEC）
   real :: numTotal                      ! A 原子质量数
   real :: numPositive                   ! Z 原子序数
   real :: numNeutral                    ! N 中子数
   real :: numNegative                   ! E 电子数
   real :: bindingEnergy                 ! EB 核结合能
   real :: adiabaticIndex                ! GAMMA 理想气体 γ
   real :: zMin                          ! 离子化下限
   real :: opacityLowTemp                ! Opacity 低温阈值（K）
   integer :: numElems                   ! 多元素物质：含几种元素
   integer :: zElems(MS_MAXELEMS)        ! 第 i 种元素的 Z
   real :: aElems(MS_MAXELEMS)           ! 第 i 种元素的 A
   real :: fractions(MS_MAXELEMS)        ! 第 i 种元素的占比

   integer :: eosType                    ! EOS 类型宏（eos_gam/eos_tab）
   integer :: eosSubtype                 ! EOS 子类型宏（ionmix4/sesame）

   character(len=MS_STRINGLEN) :: eosZfreeTableFile      ! EOS Z-free 表文件
   character(len=MS_STRINGLEN) :: eosEnerTableFile       ! EOS 能量表
   character(len=MS_STRINGLEN) :: eosPresTableFile       ! EOS 压力表
   character(len=MS_STRINGLEN) :: eosGroupName           ! EOS 表内 group 名
   character(len=MS_STRINGLEN) :: eosSesDblFmt           ! SESAME 双精度格式
end type multispecies_type

type(multispecies_type), save :: ms_Array(NSPECIES)
```

**L-011 设计动机**：

1. **每 species 一份**（不是 per-cell）—— 全局常数（物质属性），节省内存
2. **数组而非散列** —— species 数小（典型 2~10），线性遍历比哈希快
3. **integer name 字段** —— 让 list.F90 反查 species 名（通过 `Simulation_mapIntToStr`）
4. **MS_MAXELEMS 固定大小** —— 编译期常量，栈分配快（不用 allocate）
5. **混合 real/integer/character** —— Fortran derived type 自然支持，单结构通吃所有属性

### 1.1 module 私有 helper `ms_isZero`

```fortran
CONTAINS
    function ms_isZero(smallReal) RESULT (yesno)
        real, intent(in)        ::  smallReal
        logical                 ::  yesno
        yesno = .false.
        if (abs(smallReal) .lt. ms_tinyNumber) yesno = .true.   ! ms_tinyNumber = 1.0e-12
    end function ms_isZero
```

`ms_isZero` 用于 getSumInv 防止除零（如果某 species 的 A=0，跳过它）。

### 1.2 属性宏（Multispecies.h）

源码：`source/Multispecies/Multispecies.h:L22-L51`

```c
#define A (1)
#define Z (2)
#define N (3)
#define E (4)
#define EB (5)
#define GAMMA 6
#define MS_ZMIN 7
#define Z2 8                      ! Z^2（多元素时按 Σ frac·Z² 算）
#define MS_EOSTYPE 107
#define MS_EOSSUBTYPE 108
#define MS_EOSZFREEFILE 208
#define MS_EOSENERFILE 209
#define MS_EOSPRESFILE 210
#define MS_EOSGROUPNAME 211
#define MS_EOSSESDBLFMT 212
#define MS_EOSIONFILE 408
#define MS_EOSELEFILE 409
#define MS_NUMELEMS   300
#define MS_ZELEMS     301
#define MS_AELEMS     302
#define MS_FRACTIONS  303
#define MS_OPLOWTEMP  304

#define UNDEFINED_REAL -999.
#define UNDEFINED_INT -999
#define MS_UNDEFINED_STRING '-none-'
#define NO_MASK -1
#define MS_STRINGLEN 128
```

**L-011 为什么宏值跳跃**（1~8 跳到 107/108/208~212/300~304/408~409）：分组（scalar real / EOS / elements / files），便利于 if 链快速判断。

---

## 2. 初始化主流程 `Multispecies_init`

源码：`source/Multispecies/MultispeciesMain/Multispecies_init.F90:L33-L200`

### 2.1 Step 1: 全部置 UNDEFINED（L68-L89）

```fortran
do i=1, NSPECIES
   ms_Array(i)%name           = i + NPROP_VARS                    ! UNK 全局号
   ms_Array(i)%numTotal       = UNDEFINED_REAL
   ms_Array(i)%numPositive    = UNDEFINED_REAL
   ms_Array(i)%numNeutral     = UNDEFINED_REAL
   ms_Array(i)%numNegative    = UNDEFINED_REAL
   ms_Array(i)%bindingEnergy  = UNDEFINED_REAL
   ms_Array(i)%adiabaticIndex = UNDEFINED_REAL
   ms_Array(i)%zMin           = UNDEFINED_REAL
   ms_Array(i)%opacityLowTemp = 0.0
   ms_Array(i)%eosType        = UNDEFINED_INT
   ms_Array(i)%eosSubtype     = UNDEFINED_INT
   ms_Array(i)%eosZfreetableFile = MS_UNDEFINED_STRING
   ms_Array(i)%eosEnertableFile  = MS_UNDEFINED_STRING
   ms_Array(i)%eosPrestableFile  = MS_UNDEFINED_STRING
   ms_Array(i)%eosGroupName   = MS_UNDEFINED_STRING
   ms_Array(i)%eosSesDblFmt   = MS_UNDEFINED_STRING
   ms_Array(i)%numElems       = 0
   ms_Array(i)%zElems(:)      = UNDEFINED_INT
   ms_Array(i)%aElems(:)      = UNDEFINED_REAL
   ms_Array(i)%fractions(:)   = 0.0
end do
```

### 2.2 Step 2: 走自动参数族分支（仅当 `SPECIES_SETUPVAR` 定义）

```fortran
#ifdef SPECIES_SETUPVAR
  do i=1, NSPECIES
     call Simulation_mapIntToStr(i+SPECIES_BEGIN-1, spec_str, MAPBLOCK_UNK)

     write(rtpar,'(3a)') "ms_", trim(spec_str), "A"
     call RuntimeParameters_get(rtpar, ms_Array(i)%numTotal)
     ! ... 对所有 ms_<spec>* 重复 30+ 次
  end do
#endif
```

**L-011 为什么用 `Simulation_mapIntToStr`**：从 UNK 全局号（CHAM_SPEC）反查 species 字符串名（"cham"）。MAPBLOCK_UNK 表示 UNK 块的映射表。

### 2.3 Step 3: 多元素物质自动归一化 + 重算 A/Z

```fortran
nelems = ms_Array(i)%numElems
if (nelems > 0) then
   fracSum = sum(ms_Array(i)%fractions(1:nelems))
   if (fracSum /= 1.) then
      ms_Array(i)%fractions(1:nelems) = ms_Array(i)%fractions(1:nelems) / fracSum
   end if
   if (ms_Array(i)%numTotal < 0.) then
      ms_Array(i)%numTotal = dot_product(ms_Array(i)%Fractions(1:nelems), ms_Array(i)%aElems(1:nelems))
   end if
   if (ms_Array(i)%numPositive < 0.) then
      ms_Array(i)%numPositive = dot_product(ms_Array(i)%Fractions(1:nelems), ms_Array(i)%zElems(1:nelems))
   end if
end if
```

### 2.4 Step 4: 调 Simulation_initSpecies（用户 hook）

```fortran
call Simulation_initSpecies()
```

**L-011 为什么留 hook**：
- 用户用 `species=` setup 变量时，参数自动从 parfile 读，hook 可空
- 用户不用 setup 变量（手写 SPECIES 行）时，必须在 hook 里 setProperty 填属性

---

## 3. 索引映射 `ms_mapMSIndex`

源码：`source/Multispecies/MultispeciesMain/ms_mapMSIndex.F90:L29-L40`

```fortran
subroutine ms_mapMSIndex(name, msindex)
   integer, intent(in)   :: name        ! CHAM_SPEC（UNK 全局号）
   integer, intent(out)  :: msindex     ! ms_Array 下标（1, 2, ...）
   msindex = name - NPROP_VARS
end subroutine ms_mapMSIndex
```

**L-011 为什么需要这个映射**：
- `CHAM_SPEC` 是 UNK 全局变量号（要避开 DENS_VAR/PRES_VAR/TEMP_VAR 等）
- `ms_Array` 是简单 1, 2, 3... 下标
- 函数隐藏这层细节，用户调 `Multispecies_getProperty(CHAM_SPEC, A, val)` 不用关心

例如 NPROP_VARS=15（15 个非物种中心变量），则：
- CHAM_SPEC = 16 → msindex = 1
- TARG_SPEC = 17 → msindex = 2

---

## 4. 8 个核心 API

### 4.1 `Multispecies_getSumInv(property, value, weights, speciesMask)`

源码：`source/Multispecies/MultispeciesMain/Multispecies_getSumInv.F90:L87-L159`

**签名**：
```fortran
subroutine Multispecies_getSumInv(property, value, weights, speciesMask)
  integer, intent(in)                   :: property      ! 如 A
  real, intent(out)                     :: value         ! 返回 Σ(w_i/prop_i)
  real, intent(in), optional            :: weights(:)    ! 质量分数 X_i
  integer, intent(in), optional         :: speciesMask(NSPECIES)  ! 选子集
```

**核心实现**：
```fortran
value = 0.0
if (.not. present(speciesMask)) then
   do i=1, NSPECIES
      call Multispecies_getProperty(SPECIES_BEGIN + (i-1), property, propVal)
      if (ms_isZero(propVal))                                                 &
   &    call Driver_abortFlash("Multispecies_getSumInv: divide by ZERO property")
      invPropVal = 1.e0 / propVal
      value = value + weightsFull(i) * invPropVal
   end do
else  ! 有 speciesMask
   do i=1, NSPECIES
      iMask = speciesMask(i)
      if (iMask /= UNDEFINED_INT) then
         call Multispecies_getProperty(iMask, property, propVal)
         if (ms_isZero(propVal)) call Driver_abortFlash("divide by ZERO")
         invPropVal = 1.e0 / propVal
         value = value + weightsFull(i) * invPropVal
      end if
   end do
end if
```

**用途**：算 `Abar = 1/Σ(X_i/A_i)`，所以返回 `Σ(X_i/A_i)`，调用方算 `Abar = 1/value`。

**L-011 为什么 getSumInv 而不是直接给 Abar**：通用性——某些场景需要 Σ(X_i/A_i)（如 mol 数计算），不仅 Abar。让调用方决定怎么用。

**L-008 abort 触发代码**（除零保护）：

```fortran
if (ms_isZero(propVal)) then
    call Driver_abortFlash("Multispecies_getSumInv: divide by ZERO property")
end if
```

`ms_isZero` 检查 `abs(x) < 1e-12`。如果用户没填 `ms_<spec>A`（默认 -999.），这里**不会触发**（-999. 不是 0），但返回的 `1/-999` 是负小值，导致 Abar 错误。**正确做法是 parfile 必填 ms_<spec>A**。

### 4.2 `Multispecies_getSumFrac(property, value, weights, speciesMask)`

源码：`source/Multispecies/MultispeciesMain/Multispecies_getSumFrac.F90:L88+`

**语义**：
```
SumFrac = Σ_i ( weights_i * property_i / A_i )
```

**用途**：算 `Zbar = Abar × Σ(X_i·Z_i/A_i)`，所以传 `property=Z`，返回 `Σ(X_i·Z_i/A_i)`，调用方算 `Zbar = Abar * value`。

**和 getSumInv 区别**：getSumInv 返回 `Σ(w/prop)`，getSumFrac 返回 `Σ(w*prop/A)`（多除了一个 A）。

### 4.3 `Multispecies_getSum(property, value, weights, speciesMask)`

**语义**：
```
Sum = Σ_i ( weights_i * property_i )
```

**用途**：算简单加权和（如总能量密度、Σ X_i·E_i）。

### 4.4 `Multispecies_getSumSqr(property, value, weights, speciesMask)`

源码：`source/Multispecies/MultispeciesMain/Multispecies_getSumSqr.F90:L88-L154`

**语义**：
```
SumSqr = Σ_i ( weights_i * property_i^2 )
```

**用途**：算二阶矩（如 Σ X_i·Z_i²，用于 Coulomb 修正）。

### 4.5 `Multispecies_getAvg(property, value, weights, speciesMask)`

源码：`source/Multispecies/MultispeciesMain/Multispecies_getAvg.F90:L98-L182`

**语义**：
```
Avg = Σ_i ( weights_i * property_i ) / N_species
```

**用途**：算物种数加权平均（罕见，调试用）。

**L-011 为什么不用质量加权**：物理上 Abar/Zbar 用调和平均（getSumInv），不是算术平均（getAvg）。getAvg 主要用于诊断（"看看 ms_Array 里 A 的平均值"）。

### 4.6 `Multispecies_getProperty(name, property, value)`

源码：`source/Multispecies/MultispeciesMain/Multispecies_getProperty.F90:L45-L309`

**3 个重载（interface）**：
- `getProperty(name, property, real_value)` — 查 real 属性
- `getIntegerProperty(name, property, int_value)` — 查 integer 属性（EOS 类型）
- `getStringProperty(name, property, char_value)` — 查 string 属性（EOS 表文件名）
- `getRealArrProperty(name, property, real_array)` — 查 real 数组（AElems/Fractions）
- `getIntArrProperty(name, property, int_array)` — 查 int 数组（ZElems）

**核心实现（real 版）**：
```fortran
subroutine Multispecies_getProperty(name, property, value)
   call ms_mapMSIndex(name, msindex)

   nelems = ms_Array(msindex)%numElems
   if (nelems > 0) then
      allocate(fracs(nelems))
      fracs = ms_Array(msindex)%fractions(1:nelems)
   end if

   if (property == A) then
      value = ms_Array(msindex)%numTotal
   else if (property == Z) then
      value = ms_Array(msindex)%numPositive
   else if (property == Z2) then
      value = (ms_Array(msindex)%numPositive)**2
      if (nelems > 0) value = dot_product(fracs, real(ms_Array(msindex)%zElems(1:nelems))**2)
   else if (property == N) then
      value = ms_Array(msindex)%numNeutral
   ! ... 其他属性
   else
      value = -1.0
      call Driver_abortFlash("Error: Species property not found")
   end if
end subroutine
```

**L-011 为什么 Z2（Z²）特殊处理**：多元素物质的"平均 Z²"不是 Z 的平方，而是 `Σ frac·Z²`（线性叠加规则）。Coulomb 修正需要这个量。

### 4.7 `Multispecies_setProperty(name, property, value)`

源码：`source/Multispecies/MultispeciesMain/Multispecies_setProperty.F90:L44-L88`

**核心实现**：
```fortran
subroutine Multispecies_setProperty(name, property, value)
   call ms_mapMSIndex(name, msindex)

   if (property == A) then
      ms_Array(msindex)%numTotal = value
   else if (property == Z) then
      ms_Array(msindex)%numPositive = value
   ! ... 所有属性
   else
      call Driver_abortFlash("Error: Species property not found")
   end if
end subroutine
```

**L-008 abort 触发代码**（未知 property）：
```fortran
else
    call Driver_abortFlash("Error: Species property not found")
end if
```

### 4.8 `Multispecies_list(fileUnit)`

源码：`source/Multispecies/MultispeciesMain/Multispecies_list.F90:L23-L144`

**用途**：把 ms_Array 写到日志文件（debug 用）。

**输出格式**：
```
Name   Index   Total  Positive  Neutral  Negative  bindEner  Gamma  eosType
cham     16    4.00E+00 2.00E+00 2.00E+00 2.00E+00 0.00E+00 1.67E+00    4
targ     17    2.70E+01 1.30E+01 1.40E+01 1.30E+01 0.00E+00 1.67E+00    4

# multiTemp EOS 时打印额外段
Name   Index   OpacityLowTemp  Zmin     Subtype  ZFreeTableFile  EnerTableFile  PresTableFile
...

# 物种元素构成（多元素物质）
Species Constituents
cham    0 constituents
targ    0 constituents
ch      2 constituents
#  Z    A       Frac
  6   12  8.57E-01
  1    1  1.43E-01
```

---

## 5. speciesMask + weights 选子集机制

### 5.1 默认行为（不带 speciesMask）

`Multispecies_getSum(A, value)` 遍历所有 NSPECIES，权重默认 1.0，返回 `Σ prop_i`。

### 5.2 带 weights（质量分数）

```fortran
real :: massFrac(NSPECIES)
massFrac(1) = solnData(SPECIES_VAR(CHAM_SPEC), i, j, k)   ! cham 质量分数
massFrac(2) = solnData(SPECIES_VAR(TARG_SPEC), i, j, k)   ! targ 质量分数
call Multispecies_getSumInv(A, abarInv, massFrac)
! 现在 weightsFull = massFrac，value = Σ(X_i/A_i)
```

### 5.3 带 speciesMask（选子集）

```fortran
integer :: mask(NSPECIES)
mask(1) = NI56_SPEC      ! 只算 Ni56
mask(2) = FE51_SPEC      ! 和 Fe51
mask(3) = UNDEFINED_INT  ! 跳过 CO61
mask(4) = UNDEFINED_INT  ! 跳过 MG23

call Multispecies_getSum(A, value, weights, mask)
! 仅 Ni56 和 Fe51 参与求和
```

**L-011 为什么 mask 长度必须 = NSPECIES**：源码强制检查（`if (size(speciesMask,1) /= NSPECIES)` → abort）。设计选择——固定长度避免动态分配，未用的位置填 UNDEFINED_INT。

### 5.4 weights 是 size=1 的特殊用法

源码：`Multispecies/Multispecies_getSumInv.F90:L113-L124`

```fortran
if (numWeights == NSPECIES) then
   weightsFull = weights
else if (numWeights == 1) then
   weightsFull = weights(1)     ! 标量扩展到所有 species
else
   call Driver_abortFlash("Multispecies_getSumInv: invalid weights array")
endif
```

**用途**：所有 species 同权重时简化调用（不必建 NSPECIES 长度的全 1 数组）。

---

## 6. 与 EOS Helmholtz 的耦合（实例）

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

### 6.1 `#ifdef FLASH_MULTISPECIES` 双路径

- 用了 species setup 变量 → `FLASH_MULTISPECIES` 定义 → 走 Multispecies 查询
- 没用 → 用全局常数 `eos_singleSpeciesA/Z`（Helmholtz 单物质场景）

### 6.2 向量化 massFrac

`massFrac((k-1)*NSPECIES+1:k*NSPECIES)` 是**向量 EOS**（vector-based）的写法：
- `vecLen` 个 cell 一次处理（典型 vecLen=128 或 1024）
- `massFrac` 大小 `vecLen × NSPECIES`
- 第 k 个 cell 的物种切片是 `massFrac((k-1)*NSPECIES+1:k*NSPECIES)`

### 6.3 调用图

```
Eos_wrapped(mode=MODE_DENS_TEMP)
├── eos_helmholtz(vecLen, vecLen, eosData, subIdx, massFrac, mode)
│   ├── 对每个 cell k = 1..vecLen:
│   │   ├── Multispecies_getSumInv(A, abarInv, massFrac((k-1)*NSPECIES+1:k*NSPECIES))
│   │   │   └── Multispecies_getProperty(CHAM_SPEC, A, propVal)  ! 内部循环
│   │   │   └── Multispecies_getProperty(TARG_SPEC, A, propVal)
│   │   ├── abarRow(k) = 1 / abarInv
│   │   ├── Multispecies_getSumFrac(Z, zbarFrac, massFrac(...))
│   │   └── zbarRow(k) = abarRow(k) * zbarFrac
│   └── 用 abarRow/zbarRow + denRow/tempRow 调用 eos_helm（Helmholtz 表查询）
└── 返回 eosData（PRES、EINT、etc）
```

---

## 7. 与 Opacity 单元的耦合

源码：`source/physics/materialProperties/Opacity/OpacityMain/Multispecies/op_setSpeciesElementsData.F90:L101-L185`

```fortran
do species = 1, numSpecies
   call Multispecies_getProperty(SPECIES_BEGIN - 1 + species, MS_NUMELEMS, nElements)
   call Multispecies_getProperty(SPECIES_BEGIN - 1 + species, MS_ZELEMS, Zvalues)
   call Multispecies_getProperty(SPECIES_BEGIN - 1 + species, A, Aspecies)
   call Multispecies_getProperty(SPECIES_BEGIN - 1 + species, MS_NUMELEMS, nElements)
   call Multispecies_getProperty(SPECIES_BEGIN - 1 + species, MS_ZELEMS, Zvalues)
   call Multispecies_getProperty(SPECIES_BEGIN - 1 + species, MS_FRACTIONS, numberFractions)
   call Multispecies_getProperty(SPECIES_BEGIN - 1 + species, MS_OPLOWTEMP, lowTempCutoff)
end do
```

Opacity 用这些查每种 species 的元素构成，从而查 per-element 不透明度表（如 XRay 库、USEEOS 表），按 Fractions 加权合成。详见 `flash-material`。

---

## 8. 与 Burn（核反应）耦合（简要）

Burn 单元（核合成场景）：

1. 直接读 / 写 `SPECIES_VAR`（如 Ni56 衰变后质量分数减少）
2. 必要时调 `Multispecies_setProperty` 改变 ms_Array（如衰变产物变更 EOS 表绑定）
3. HEDP 不用，仅天体物理（Type Ia、CCSN）用

---

## 9. 完整调用链（HEDP 一步）

```
Driver_evolveFlash (主循环)
├── Grid_fillGuardCells ★ (含物种质量分数)
├── Hydro
│   └── advect SPECIES_VAR（质量分数跟流体走）
├── Eos_wrapped ★ (Helmboltz 算 Abar/Zbar)
│   └── eos_helmholtz
│       ├── Multispecies_getSumInv(A) → abarInv
│       ├── Multispecies_getSumFrac(Z) → zbarFrac
│       └── 用 abar/zbar + den/temp 调 eos_helm
├── Driver_sourceTerms
│   ├── Heatexchange (3T 平衡)
│   ├── EnergyDeposition (激光)
│   │   └── Opacity 查询
│   │       └── op_setSpeciesElementsData
│   │           └── Multispecies_getProperty(MS_NUMELEMS, MS_ZELEMS, ...)
│   └── Burn (核反应，HEDP 不用)
└── IO_output (写 plotfile，含 SPECIES_VAR)
```

---

## 10. 已知陷阱 / 与手册差异

| 点 | 手册 / 直觉 | 源码实际 |
|---|---|---|
| `Multispecies_getProperty` 第二参数 | 以为是字符串 "A" | 是整数宏 A=1（编译期常量） |
| `ms_<spec>A` 没填 | 报错 "A not set" | 静默（默认 -999.），算 Abar 时给出错误结果，下游 NaN |
| `speciesMask` 长度 | 以为是子集大小 | 必须是 NSPECIES（子集大小通过 UNDEFINED_INT 标记） |
| `weights` 数组大小 | 必须严格 NSPECIES | 可以是 1（标量扩展）或 NSPECIES |
| `numElements` 字段 | 以为是 NumElems 参数 | 实际是 ms_Array 的 numElems（多元素物质用） |
| 多元素物质 fractions | 必须 Σ=1 | 不必，Multispecies_init 自动归一化 |
| `ms_isZero` 检查 | 检查 propVal = 0 | 检查 `abs(propVal) < 1e-12` |

---

## 11. 延伸阅读

- 相关条目：`knowledge/overview.md`（机制 + 物理原理）、`knowledge/params.md`（参数族）、`knowledge/recipes.md`（典型配置）、`knowledge/pitfalls.md`（错误排查）
- 跨 skill：
  - `flash-eos` — EOS 模式 + Helmholtz/Tabulated 细节
  - `flash-material` — Opacity 表 + 多元素不透明度
  - `flash-source-reader` — 找具体 Multispecies_* 源码位置

---

## 12. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-31 | 初始创建（8 个 API + multispecies_type + Config 自动生成 + Helmholtz/Opacity/Burn 耦合）| claude |
