---
title: Multispecies 踩坑排查 — ms_<spec>A 没生效、Abar=0、speciesMask wrong size、归一化
skill: flash-multispecies
category: pitfalls
source_anchors:
  - source/Multispecies/MultispeciesMain/Multispecies_getSumInv.F90:L120-L149
  - source/Multispecies/MultispeciesMain/Multispecies_getProperty.F90:L96-L99
  - source/Multispecies/MultispeciesMain/Multispecies_setProperty.F90:L82-L84
  - source/Multispecies/MultispeciesMain/Multispecies_init.F90:L91-L194
  - source/physics/Eos/EosMain/Helmholtz/SpeciesBased/eos_helmholtz.F90:L326-L337
manual_ref: "FLASH 4.8 User Guide §17 Multispecies troubleshooting"
created: 2026-07-31
last_verified: 2026-07-31
verifier: claude
status: beta
tags:
  - multispecies
  - pitfalls
  - debugging
  - abar-zero
  - species-mask
  - normalization
---

# Multispecies 踩坑排查

> **TL;DR**：3 类常见错误——(A) setup / 配置类（species setup 变量没传、ms_<spec>A 没填）；(B) 运行时数值类（Abar=0/NaN、能量不守恒）；(C) 编程接口误用（speciesMask 大小错、property 宏错）。**诊断类问题先贴现场**（L-012），按通用原因排查。

---

## 0. 诊断通用流程（L-012 Step 0）

遇到 Multispecies 相关错误时，**先贴以下信息**：

```bash
# 1. setup 命令（确认 species= 变量传了）
cat cases/<my_case>/setup_call

# 2. setup_flags（确认 FLASH_MULTISPECIES、NSPECIES、MS_MAXELEMS 编译期宏）
grep -E "MULTISPECIES|NSPECIES|MS_MAXELEMS|SPECIES_SETUPVAR|CHAM_SPEC|TARG_SPEC" cases/<my_case>/setup_defines

# 3. parfile 物种段（确认 ms_*/eos_*/op_* 都填了）
grep -E "^ms_|^eos_|^op_" cases/<my_case>/flash.par

# 4. 日志里 Multispecies_list 打印的物种数据库（确认运行时值）
grep -A 20 "Initially defined values of species" 01-data/<basenm>.log | head -30

# 5. 报错信息（找第一次 abort / NaN 出现位置）
grep -B 2 -A 5 "Multispecies\|abort\|NaN" 01-data/<basenm>.log | head -40
```

贴完后再展开通用原因排查。

---

## 1. A 类：setup / 配置类错误

### A1: `species=` setup 变量没传

**症状**：
- setup 后 NSPECIES=0，没有 CHAM_SPEC/TARG_SPEC 宏
- parfile 里写 `ms_chamA = 4.0` 报 `Unknown runtime parameter ms_chamA`
- Helmholtz EOS 用 `eos_singleSpeciesA/Z`（默认值，不是用户期望）

**原因**：setup 命令没加 `species=cham,targ`，Multispecies/Config Python 段没触发参数族生成。

**修复**：在 setup 命令加 `species=cham,targ`：

```bash
# 错
./setup LaserSlab -2d -auto +mtmmmt +laser ...
# 对
./setup LaserSlab -2d -auto +mtmmmt +laser ... species=cham,targ ...
```

**验证**：

```bash
grep "FLASH_MULTISPECIES\|NSPECIES\|CHAM_SPEC" cases/<my_case>/setup_defines
# 应看到 FLASH_MULTISPECIES、NSPECIES = 2、CHAM_SPEC 等定义
```

### A2: `ms_<spec>A` 没填（默认 -999.）

**症状**：
- Abar 算出来是负值或 NaN
- 日志里 `Multispecies_list` 打印 `ms_chamA = -999.`
- 没有 abort（getSumInv 不会因 -999 触发除零检查，因为 `ms_isZero` 检查 `< 1e-12`）

**L-008 触发代码**（getSumInv 的除零保护，不抓 -999）：

```fortran
! source/Multispecies/MultispeciesMain/Multispecies_getSumInv.F90:L135-L149
if (ms_isZero(propVal))                                                 &
&    call Driver_abortFlash("Multispecies_getSumInv: divide by ZERO property")
```

`ms_isZero` 检查 `abs(propVal) < 1e-12`，-999. 不在这个范围 → 不 abort → 返回 1/-999 ≈ -0.001 → Abar ≈ -1000（负）→ 后续 EOS NaN。

**原因**：parfile 里漏写 `ms_chamA = 4.002`，或写错变量名（如 `ms_cham_a` 大小写错）。

**修复**：

```fortran
# parfile 物种段
ms_chamA          = 4.002602
ms_chamZ          = 2.0
# ... 其他必填项
```

**验证**：

```bash
grep -E "^ms_chamA|^ms_targA" cases/<my_case>/flash.par
# 应看到具体数值，不是 -999.
```

### A3: `eos_<spec>EosType` 不匹配实际 EOS

**症状**：
- 用户跑 Gamma EOS（单物质理想气体），但 parfile 里 `eos_chamEosType="eos_tab"` 引用表
- 反之，跑 Helmholtz/Tabulated 但 EosType 未设

**原因**：EOS 单元选的变体和 species 的 EosType 不一致。

**修复**：让 species 的 EosType 和 EOS 单元变体一致：

| EOS 单元变体（+eos=... 或 setup） | species EosType |
|---|---|
| Gamma（单物质） | 不用 species（NSPECIES=0）|
| Multigamma | "eos_gam" |
| Helmholtz / Tabulated | "eos_tab" |
| multiTemp（Gamma 子变体） | "eos_gam" |
| multiTemp（Helmholtz 子变体） | "eos_tab" |

### A4: `eos_<spec>TableFile` 路径错

**症状**：
- `Error opening EOS table file: he-imx-005.cn4`
- 表文件在 source/Simulation/SimulationMain/<problem>/ 但 setup 没复制到 case 目录

**修复**：
1. 确认表文件在 `source/Simulation/SimulationMain/<problem>/`
2. setup 自动复制（应该）；如果没有，手动 `cp source/.../<file>.cn4 cases/<my_case>/`
3. parfile 里用相对路径（`he-imx-005.cn4`）不是绝对路径

### A5: CHAM_SPEC / TARG_SPEC 未定义

**症状**：
- 编译错 `Unclassifiable declaration` 或 `Symbol CHAM_SPEC not found`
- 用 `species=cham,targ` setup 但 Config 用了别的 SPECIES 名

**原因**：setup 把 `species=cham,targ` 转成 `CHAM_SPEC` / `TARG_SPEC` 宏。代码里引用这些宏时大小写必须一致。

**修复**：

```fortran
! 对
integer :: species = CHAM_SPEC
if (n == TARG_SPEC) ...

! 错（小写不行）
integer :: species = cham_spec
```

### A6: `ms_maxelems` 太小

**症状**：
- 多元素物质（NumElems=4）报 `index out of bounds` for `ms_chZElems_5`
- 编译时 MS_MAXELEMS = 6 但 parfile 引用 ZElems_7

**修复**：在 setup 加 `ms_maxelems=8`（或更大）。

---

## 2. B 类：运行时数值类错误

### B1: Abar = 0 / NaN（最常见）

**症状**：
- 日志里 `Abar` 是 NaN 或 0
- Helmholtz EOS 返回 NaN P、T
- Hydro 出现 NaN 密度

**Step 0**（L-012 引导贴现场）：

```bash
# 1. 看 Multispecies_list 打印的物种属性
grep -A 30 "Initially defined values of species" 01-data/<basenm>.log | head -40

# 2. 看 parfile ms_<spec>A/Z 是否填了
grep "^ms_.*A\|^ms_.*Z" cases/<my_case>/flash.par

# 3. setup_flags 确认 FLASH_MULTISPECIES
grep "FLASH_MULTISPECIES" cases/<my_case>/setup_defines
```

**通用原因**（按概率排序）：

1. **parfile 没填 `ms_<spec>A`**（A2）—— 默认 -999.，Abar 算出来是 -1000
2. **species setup 变量没传**（A1）—— NSPECIES=0，Helmholtz 走单物质分支
3. **Simulation_initBlock 没初始化质量分数** —— 默认 0，ΣX=0 → abarInv=0 → Abar=Inf
4. **质量分数归一化错** —— ΣX ≠ 1（数值漂移）—— 用 `sim_smallX` 范式

### B2: 物种质量分数超出 [0, 1]

**症状**：
- IO plotfile 里 `cham` 或 `targ` 是负数或 >1
- Hydro 数值不稳定

**原因**：Hydro advection 数值误差累积（特别是激波附近），让 ΣX 偏离 1。

**修复**：
1. 用 unsplit Hydro（`+uhd`）—— 比 split 数值耗散小
2. 在 Simulation_initBlock 用 `sim_smallX`（1e-10）代替 0（避免除零）
3. 检查 hydro 求解器参数（CFL、limiter）

### B3: 混合区域 EOS 表外推

**症状**：
- cham/targ 边界附近 NaN
- 日志里 `EOS table extrapolation` 警告

**原因**：ionmix4 表的 (T, ρ) 范围有限，混合区温度 / 密度超出表范围。

**修复**：
1. 用更宽范围的 EOS 表（重新生成 .cn4）
2. 降低算例的密度 / 温度极值
3. 检查 Simulation_initBlock 的初始条件是否合理

### B4: ms_targA=13 但 EOS 表内部 A 不同

**症状**：
- EOS 表查询结果和预期差几倍
- 不透明度 / 压力 / 温度系统性偏差

**原因**：ionmix4 表生成时按某个 A/Z（如纯 C 的 A=12），用户在 parfile 填 A=13 → EOS 表查询用错 A。

**修复**：从同款算例（Sunliang_laser_CH）拷 parfile，不要自己改 A/Z。或者打开 .cn4 文件元数据看生成时的 A/Z 约定。

### B5: `ZMin=0` 导致除零（MHD）

**症状**：
- MHD + Hall/Biermann3T 算例发散
- 日志警告：`WARNING: Electron number density may be extremely low for Hall and/or Biermann3T dt calculations`

**L-008 触发代码**（警告但非 abort）：

```fortran
! source/Multispecies/MultispeciesMain/Multispecies_init.F90:L126-L135
if (useHall .or. useBiermann3T) then
   if (ms_Array(i)%zMin < 0.) then
      PRINT*, "WARNING: Electron number density may be extremely low for Hall"
      PRINT*, "         and/or Biermann3T dt calculations. Consider setting a ZMin"
   end if
end if
```

**修复**：parfile 设 `ms_<spec>ZMin = 0.02`（典型 HEDP 值）。

---

## 3. C 类：编程接口误用

### C1: `speciesMask` 长度错

**症状**：abort `Multispecies_getSumInv: mask array wrong size`

**L-008 触发代码**：

```fortran
! source/Multispecies/MultispeciesMain/Multispecies_getSumInv.F90:L126-L130
if (present(speciesMask)) then
   if (size(speciesMask,1) /= NSPECIES ) then
      call Driver_abortFlash("Multispecies_getSumInv: mask array wrong size")
   endif
endif
```

**原因**：用户传了子集大小的 mask（如 2 个物种的子集 → mask 大小 2），但源码强制 mask 长度 = NSPECIES。

**修复**：mask 大小必须 NSPECIES，未用位置填 UNDEFINED_INT：

```fortran
integer :: mask(NSPECIES)
mask(1) = CHAM_SPEC         ! 包含 cham
mask(2) = UNDEFINED_INT     ! 跳过 targ（如 2 个 species）
call Multispecies_getSumInv(A, val, weights, mask)
```

### C2: `weights` 数组大小错

**症状**：abort `Multispecies_getSumInv: invalid weights array`

**L-008 触发代码**：

```fortran
! source/Multispecies/MultispeciesMain/Multispecies_getSumInv.F90:L113-L121
if (present(weights)) then
   numWeights = size(weights,1)
   if (numWeights == NSPECIES) then
      weightsFull = weights
   else if (numWeights == 1) then
      weightsFull = weights(1)
   else
      call Driver_abortFlash("Multispecies_getSumInv: invalid weights array")
   endif
endif
```

**原因**：weights 大小不是 1 也不是 NSPECIES。

**修复**：weights 大小必须是 1（标量扩展）或 NSPECIES。

### C3: `property` 宏错

**症状**：abort `Error: Species property not found`

**L-008 触发代码**（setProperty）：

```fortran
! source/Multispecies/MultispeciesMain/Multispecies_setProperty.F90:L82-L84
else
   call Driver_abortFlash("Error: Species property not found")
end if
```

**原因**：传了未识别的 property 值（如数字 999）。

**修复**：用 Multispecies.h 的标准宏：`A`、`Z`、`N`、`E`、`EB`、`GAMMA`、`MS_ZMIN`、`MS_OPLOWTEMP`、`MS_EOSTYPE`、`MS_EOSSUBTYPE`。

```fortran
#include "Multispecies.h"

call Multispecies_setProperty(CHAM_SPEC, A, 4.002)         ! 对
call Multispecies_setProperty(CHAM_SPEC, MS_ZMIN, 0.02)    ! 对
call Multispecies_setProperty(CHAM_SPEC, 999, 1.0)         ! 错 → abort
```

### C4: `divide by ZERO property` abort

**症状**：abort `Multispecies_getSumInv: divide by ZERO property`

**L-008 触发代码**：

```fortran
! source/Multispecies/MultispeciesMain/Multispecies_getSumInv.F90:L135-L136
if (ms_isZero(propVal))                                                 &
&    call Driver_abortFlash("Multispecies_getSumInv: divide by ZERO property")
```

**原因**：某 species 的 property（如 A）= 0（精确 0 或绝对值 < 1e-12）。

**修复**：
1. parfile 填非零 A 值
2. 多元素物质用 NumElems+AElems 路径（自动 dot_product 算 A，不会是 0）

### C5: getProperty 返回 -1（未知 property）

**症状**：getProperty 调用返回 -1.0，但没 abort（看似"正常"返回，但下游异常）。

**L-008 触发代码**：

```fortran
! source/Multispecies/MultispeciesMain/Multispecies_getProperty.F90:L96-L99
else
   value = -1.0  ! default, to avoid compiler warnings with abort
   call Driver_abortFlash("Error: Species property not found")
end if
```

**注意**：abort 会终止程序，但 `value = -1.0` 是 abort 前的默认值（防编译器警告）。如果用 -nodie 调试模式跳过 abort，会看到 -1 返回。

---

## 4. D 类：进阶诊断

### D1: Abar 计算和手算不符

**症状**：用户手算 50% He + 50% Al 应该 Abar ≈ 7.04，但日志打印 15.5（算术平均）。

**原因**：用户用错 API —— 用 getAvg（算术平均）而不是 getSumInv（调和平均）。

**正确公式**：
```
Abar = 1 / Σ(X_i/A_i)         ← Helmholtz 用 getSumInv(A)
不是 Abar = Σ X_i · A_i        ← 这是 getAvg，错的物理
```

源码：`source/physics/Eos/EosMain/Helmholtz/SpeciesBased/eos_helmholtz.F90:L326-L337`

```fortran
call Multispecies_getSumInv(A, abarInv, massFrac(...))    ! ← 调和平均
abarRow(k) = 1.e0 / abarInv
```

### D2: 物种在 plotfile 里看不到

**症状**：plotfile 里没有 `cham` / `targ` 变量。

**原因**：
1. setup 没传 `species=` → NSPECIES=0 → 无 SPECIES_VAR
2. IO plotfile 参数未包含物种变量

**修复**：
1. 确认 setup 传了 `species=cham,targ`
2. 检查 parfile 的 `plot_var_1`、`plot_var_2` 是否含 SPECIES_VAR（如 `plot_var_5 = "cham"`）

### D3: 物种顺序（CHAM_SPEC=1 还是 2）

**症状**：用户期望 CHAM_SPEC=1, TARG_SPEC=2，但实际反了。

**原因**：species 索引按 setup 命令 `species=` 列表顺序赋值。

源码：`source/Multispecies/MultispeciesMain/Config:L18`

```python
species = [s.lower() for s in setupvars["species"].split(',')]
# species[0]='cham' → CHAM_SPEC（第一个）
# species[1]='targ' → TARG_SPEC（第二个）
```

**验证**：

```bash
grep "CHAM_SPEC\|TARG_SPEC" cases/<my_case>/setup_defines | head
# 应看到 CHAM_SPEC = <number>、TARG_SPEC = <number+1>
```

### D4: `Multispecies_list` 不打印多元素段

**症状**：日志只打印基础段，没有 `Species Constituents` 段。

**原因**：`ms_Array(i)%numElems = 0`（所有 species 都是纯元素，没多元素物质）。

**正常**：如果没配多元素，确实不打印。要打印得在 parfile 设 `ms_<spec>NumElems > 0` + ZElems/AElems/Fractions。

### D5: 多元素 fractions 不归一化

**症状**：用户填 Fractions_1=0.5, Fractions_2=0.6（sum=1.1），运行时不归一化。

**实际**：Multispecies_init **会自动归一化**（除以 fracSum）。

源码：`source/Multispecies/MultispeciesMain/Multispecies_init.F90:L156-L161`

```fortran
if (fracSum /= 1.) then
   ms_Array(i)%fractions(1:nelems) = ms_Array(i)%fractions(1:nelems) / fracSum
end if
```

验证：

```bash
grep -A 5 "ch      2 constituents" 01-data/<basenm>.log
# 应看到归一化后的 Frac（0.5/1.1=0.4545、0.6/1.1=0.5455）
```

---

## 5. 调试技巧

### 5.1 用 Multispecies_list 看运行时值

在 Simulation_initSpecies 末尾或 Driver_initFlash 后加：

```fortran
use Multispecies_interface, ONLY : Multispecies_list
integer :: logUnit
open(newunit=logUnit, file="species_debug.txt", status="unknown")
call Multispecies_list(logUnit)
close(logUnit)
```

输出完整 ms_Array 内容。

### 5.2 单元测试

`source/Multispecies/MultispeciesMain/unitTest/Multispecies_unitTest.F90` 提供 sfocu 测试。跑：

```bash
./setup unitTest/Multispecies -auto -objdir=cases/test_ms
cd cases/test_ms && make -j4 && ./flash4
```

### 5.3 print 大法

在 Eos 调用前后插：

```fortran
print *, "DEBUG cell ", i, j, k
print *, "  massFrac = ", massFrac
print *, "  abar = ", abar, " zbar = ", zbar
```

定位哪个 cell 的 Abar 异常。

---

## 6. 延伸阅读

- 相关条目：`knowledge/overview.md`（机制）、`knowledge/params.md`（参数）、`knowledge/internals.md`（API）、`knowledge/recipes.md`（典型配置）
- 跨 skill：
  - `flash-pitfall-finder` — 错误信息自动匹配（如果有具体 abort 字符串）
  - `flash-source-reader` — 找 Multispecies_* 源码位置
  - `flash-case-runner` — 跑算例时常见问题（Phase 3）
- 全局踩坑库：`skills/flash-pitfall-finder/knowledge/pitfalls/`（跨领域问题）

---

## 7. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-31 | 初始创建（A/B/C/D 四类踩坑 + L-008 触发代码贴 + L-012 诊断引导）| claude |
