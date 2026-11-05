---
title: materialProperties 常见错误 + 诊断引导（按 L-012 先贴现场）
skill: flash-material
category: pitfalls
source_anchors:
  - source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Conductivity.F90:L67-L91
  - source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity.F90:L94-L104
  - source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity_init.F90:L168-L185
  - source/physics/materialProperties/Conductivity/ConductivityMain/cond_getCv.F90:L97-L121
manual_ref: "FLASH 4.8 User Guide §16-§17"
created: 2026-07-30
last_verified: 2026-07-30
verifier: claude
status: beta
tags:
  - materialproperties
  - pitfalls
  - debugging
  - abort
  - ionmix4
---

# materialProperties 常见错误（含诊断引导）

> **TL;DR**：按错误类型分类，每条给"诊断命令"+"触发代码"+"原因"+"修复"。按 L-012 诊断类问题先引导贴现场。

---

## A. 通用诊断引导（按 L-012，所有错误先做这步）

### A.1 Step 0：贴现场

收到 Conductivity / Opacity 相关错误时，**先让用户贴以下信息**：

```bash
# 1. 报错日志（找 abort 字符串）
grep -B 2 -A 10 "Driver_abortFlash\|abort\|ERROR" 01-data/<basenm>.log | head -50

# 2. Conductivity/Opacity init 打印的参数（确认表加载成功）
grep -i "Opacity_init\|Conductivity_init\|ionmix\|table" 01-data/<basenm>.log | head -30

# 3. setup 命令
cat cases/<case>/setup_call

# 4. parfile 物质属性段（含 useConductivity / useOpacity / op_*）
grep -E "useConductivity|useOpacity|op_|cond_|diff_useEleCond" cases/<case>/flash.par

# 5. 数据文件是否存在
ls cases/<case>/*.cn4 cases/<case>/*.imx cases/<case>/*.ses 2>&1

# 6. .cn4 文件头部（看群边界）
head -30 cases/<case>/<table>.cn4
```

### A.2 Step 1：判断错误类型

```
错误信息含 "[Conductivity]" 或 "[Opacity]" 前缀
   → FLASH 源码触发，走 §B 找具体 abort 字符串

错误信息含 "bad opacity kind" / "no corresponding energy group"
   → Opacity 配置错，走 §C

错误信息含 "only works in 3T" / "does not work with radiation"
   → Conductivity 变体不匹配编译模式，走 §D

错误现象：cond_zone 全 0 / κ 返回 0 / 物理异常（温度不扩散）
   → 隐式错（无 abort），走 §E

错误信息含 "IONMIX" / "table" / "format"
   → 表加载错，走 §F
```

---

## B. Conductivity abort 类

### B.1 `[Conductivity] SpitzerHighZ conductivity only works in 3T`

**触发代码**：源码 `source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Conductivity.F90:L67-L69`

```fortran
#ifndef FLASH_3T
  call Driver_abortFlash("[Conductivity] SpitzerHighZ conductivity only works in 3T")
#endif
```

**为什么触发**：SpitzerHighZ 需要区分 TION_VAR 和 TELE_VAR。**1T 模式只有 TEMP_VAR**，公式没法算。

**修复**：
1. setup 加 `+uhd3t` 或 `+3t`（启用三温编译宏）
2. 或换 Conductivity/Spitzer（无 3T 要求，但 Z=1 才准）

### B.2 `[Conductivity] SpitzerHighZ conductivity does not work with radiation`

**触发代码**：源码 `source/physics/materialProperties/Conductivity/ConductivityMain/SpitzerHighZ/Conductivity.F90:L89-L92`

```fortran
case(3)
#ifdef TRAD_VAR
   call Driver_abortFlash("[Conductivity] SpitzerHighZ conductivity does not work with radiation")
#endif
```

**为什么触发**：用户传 `component=3`（辐射）。SpitzerHighZ 只算电子/离子热导率，辐射扩散由 RadTrans/MGD 处理。

**修复**：调用方（通常是 Diffuse）别传 component=3 给 Conductivity。辐射扩散由 Opacity + RadTrans 管。

### B.3 `[Conductivity] Spitzer conductivity does not work with radiation`

类似 B.2，但触发文件是 `ConductivityMain/Spitzer/Conductivity.F90:L79`。同样修复。

### B.4 `[Conductivity] LeeMore conductivity computes only electron conduction, not ion conduction`

**触发代码**：源码 `source/physics/materialProperties/Conductivity/ConductivityMain/LeeMore/Conductivity.F90:L86`

```fortran
case(1)
#ifdef TION_VAR
   tempToUse = TION_VAR
   call Driver_abortFlash("[Conductivity] LeeMore conductivity computes only electron conduction, not ion conduction")
#endif
```

**为什么触发**：Lee-More 1984 公式只算电子热导率（基于电子输运理论）。用户传 component=1（离子）。

**修复**：LeeMore 算例别用 component=1。如需离子热导率用 SpitzerHighZ。

### B.5 `[Conductivity] PowerLaw conductivity does not work with radiation`

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/PowerLaw/Conductivity.F90:L82`

类似 B.2，PowerLaw 不支持 component=3。

### B.6 `[Conductivity] JiHeld conductivity coefficients ...` / `EppHain conductivity coefficients ...`

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/JiHeld/Conductivity.F90:L85` 和 `EppHain/Conductivity.F90:L80`

**为什么触发**：JiHeld / EppHain 是磁化等离子体变体，需要磁场信息。**未配磁场**会 abort。

**修复**：MHD 算例才用 JiHeld/EppHain。非 MHD 用 SpitzerHighZ。

---

## C. Opacity abort 类

### C.1 `[Opacity] ERROR: no corresponding energy group`

**触发代码**：源码 `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity.F90:L102-L104`

```fortran
if ( (ngrp < 1) .or. (ngrp > op_nEnergyGroups) ) then
    call Driver_abortFlash ('[Opacity] ERROR: no corresponding energy group')
end if
```

**为什么触发**：调用方（通常是 RadTrans）传的群号 ngrp 超出 `[1, op_nEnergyGroups]` 范围。

**诊断**：
```bash
grep "rt_mgdNumGroups\|op_nEnergyGroups" 01-data/<basenm>.log
```

**修复**：
1. 检查 parfile `rt_mgdNumGroups = N`（如 6）
2. 检查调用循环 `do g = 1, N`
3. 检查 .cn4 表的群数和 rt_mgdNumGroups 一致

### C.2 `[opacity_init] bad opacity kind`

**触发代码**：源码 `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity_init.F90:L168-L185`

```fortran
if( any(op_absorptionKind == 0) .or. &
     any(op_emissionKind   == 0) .or. &
     any(op_transportKind  == 0) ) then

   if (op_globalMe == MASTER_PE) then
      do species = 1, op_totalSpecies
         print '(4i6)', species, &
              op_absorptionKind(species), &
              op_emissionKind(species), &
              op_transportKind(species)
      end do
   end if

   call Driver_abortFlash("[opacity_init] bad opacity kind")
end if
```

**为什么触发**：某 species 的 `op_<spec>Absorb/Emiss/Trans` 没在 parfile 显式给，保持默认 `"op_undefined"`（内部 kind=0）。

**诊断**：
```bash
# 看启动日志，会有上面 print 的 4 列：
# species  abs_kind  emi_kind  trans_kind
# 应该都是非零正整数
grep -A 5 "bad opacity kind\|species.*absorbKind" 01-data/<basenm>.log
```

**修复**：parfile 显式给每 species 三种 kind：
```fortran
op_chamAbsorb   = "op_tabpa"
op_chamEmiss    = "op_tabpe"
op_chamTrans    = "op_tabro"
op_targAbsorb   = "op_tabpa"
op_targEmiss    = "op_tabpe"
op_targTrans    = "op_tabro"
```

### C.3 `[Opacity_init] ERROR: no energy groups found`

**触发代码**：源码 `source/physics/materialProperties/Opacity/OpacityMain/Multispecies/Opacity_init.F90:L113-L115`

```fortran
if (op_nEnergyGroups < 1) then
    call Driver_abortFlash ('[Opacity_init] ERROR: no energy groups found')
end if
```

**为什么触发**：`rt_mgdNumGroups` 没设或设成 0/负数。

**修复**：parfile 加：
```fortran
rt_useMGD       = .true.
rt_mgdNumGroups = 6
rt_mgdBounds_1  = 1.0e-01
# ... rt_mgdBounds_7
```

### C.4 `[res_multitype] ERROR: res_mt_materialModel not recognized`

源码：`source/physics/materialProperties/MagneticResistivity/MagneticResistivityMain/Multitype/res_multitype.F90:L52`

**为什么触发**：`res_mt_materialModel` 参数给错了（不是支持的字符串）。

**修复**：检查 `res_mt_materialModel` 值（应为一个支持的子模型名）。

### C.5 `[res_davieswen] DaviesWen resistivity only works in MHD`

源码：`source/physics/materialProperties/MagneticResistivity/MagneticResistivityMain/DaviesWen/res_davieswen.F90:L74`

**为什么触发**：DaviesWen 磁阻需要磁场变量（MHD 编译宏）。非 MHD 算例用了。

**修复**：非 MHD 算例用 Constant 或 SpitzerHighZ 磁阻，不用 DaviesWen。

### C.6 `[Viscosity_fullState] Spitzer Viscosity only works in 3T`

源码：`source/physics/materialProperties/Viscosity/ViscosityMain/Spitzer/Viscosity_fullState.F90:L70`

类似 B.1，Spitzer Viscosity 需要 3T。

---

## D. 变体选择错误

### D.1 SpitzerHighZ 在 1T 模式下 abort

见 §B.1。

### D.2 Lee-More 在算离子热导率时 abort

见 §B.4。

### D.3 PowerLaw-gray 在 component=4 时 abort

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/PowerLaw-gray/Conductivity.F90:L141`

```fortran
call Driver_abortFlash("Conductivity: requested invalid component")
```

**为什么触发**：PowerLaw-gray 只支持 component=1（ion）、2（ele）、3（rad）。传其他值 abort。

---

## E. 隐式错误（无 abort，但物理失真）

### E.1 cond_zone 全 0（热传导不起作用）

**现象**：
- TELE 没扩散（梯度大）
- Diffuse 步没改变温度

**诊断**：
```bash
# 看 useConductivity 是否 true
grep "useConductivity" cases/<case>/flash.par

# 看 setup 是否 REQUESTS 了 Conductivity 变体
grep "Conductivity" cases/<case>/setup_defines

# 看 Diffuse 是否启用
grep "useDiffuse\|diff_useEleCond" cases/<case>/flash.par
```

**常见原因**：
1. `useConductivity = .false.`（默认是 TRUE，但可能被覆盖）
2. setup 没 REQUESTS 任何 Conductivity 变体（默认 Constant 但 cond_constantIsochoric=0）
3. `diff_useEleCond = .false.`（Diffuse 不算电子热传导）
4. `diffusion_cutoff_density` 太高（低密度区被关闭扩散）

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/diff_advanceTherm.F90:L233-L238`

```fortran
! if the density is too low, turn off thermal diffusion
if (xdens < diffusion_cutoff_density) then
   cond_zone(:) = 0.0
else
   call Conductivity(solnVec(:,i,j,k), cond_zone, component=EOSCOMP_ELE)
end if
```

**修复**：检查上述 4 项，逐一排除。

### E.2 Opacity 返回 0（辐射不吸收/不发射）

**现象**：
- 辐射场不演化
- TELE 不受辐射影响

**诊断**：
```bash
# 看 useOpacity
grep "useOpacity" cases/<case>/flash.par

# 看表是否加载成功
grep -i "ionmix\|table\|loaded" 01-data/<basenm>.log | head -20
```

**常见原因**：
1. `useOpacity = .false.`
2. `op_<spec>Absorb/Emiss/Trans = "op_undefined"`（会 abort，但如果 RadTrans 没启用就不报）
3. `rt_useMGD = .false.`（RadTrans 不算辐射）
4. 低温泉化机制（`opacity_ignoreLowTemp = .false.` + T < 表下限 → 用 Biggs1971 公式，但配置错可能给 0）

**修复**：参考 LaserSlab parfile 完整配置。

### E.3 cv 不正确（导致 diffCoeff 异常）

**现象**：
- diffCoeff 太大或太小
- 扩散行为异常

**诊断**：
```bash
# 看 EOS 类型
grep "eos_.*EosType" cases/<case>/flash.par
```

**常见原因**：
1. 用 `eos_gam`（理想气体 EOS）而非 `eos_tab`（表格 EOS）——cv 不准确
2. multiTemp EOS 没启用 → cv 是综合而非 cvion/cvele
3. abar/zbar 错（Multispecies 没配 ms_<spec>A/Z）

源码：`source/physics/materialProperties/Conductivity/ConductivityMain/cond_getCv.F90:L150-L166`

```fortran
#ifdef TELE_VAR
  if (present(component)) then
     select case (component)
     case(1)
        if (whichCv == EOS_CV) then
           cvOut = cvOut / (1.0+zbar)        ! fallback 拆分
        end if
     case(2)
        if (whichCv == EOS_CV) then
           if (zbar .NE. 0.0) &
                cvOut = cvOut * zbar / (1.0+zbar)
        end if
     end select
  end if
#endif
```

**修复**：用 `eos_tab` + `ionmix4` EOS 表，确保 multiTemp 模式。

### E.4 cond_zone 在低密度区被关闭

见 §E.1 第 4 条。`diffusion_cutoff_density` 默认值取决于 Diffuse 配置。

**修复**：
```fortran
# parfile 调低 cutoff（如调到 1e-10）
diffusion_cutoff_density = 1.0e-10
```

---

## F. 表加载错误

### F.1 IONMIX4 文件读不了

**现象**：启动时 abort 或表数据全 0

**诊断**：
```bash
# 文件是否存在
ls -la cases/<case>/<table>.cn4

# 是否被 setup 复制（看 DATAFILES）
grep "<table>.cn4" source/Simulation/SimulationMain/<problem>/Config

# 文件格式（看开头）
head -5 cases/<case>/<table>.cn4
```

**常见原因**：
1. **文件路径错**：op_<spec>FileName 给错文件名
2. **没在 Config 加 DATAFILES**：setup 没复制文件到 objdir
3. **文件格式坏**：手动编辑过，破坏了格式
4. **FileType 不匹配**：给了 `.cn4` 但 FileType 不是 "ionmix4"

**修复**：
1. 确认文件存在且可读
2. Config 加 `DATAFILES <table>.cn4`
3. parfile 检查 `op_<spec>FileName = "<table>.cn4"` 和 `op_<spec>FileType = "ionmix4"`
4. 如文件损坏，从源（IAPCM/SESAME/FEOS）重新获取

### F.2 群边界不匹配

**现象**：启动时 abort

**诊断**：
```bash
# 读 .cn4 文件看群边界
grep -A 1 "groups\|group boundaries" cases/<case>/<table>.cn4 | head -20

# 看 parfile 群边界
grep "rt_mgdBounds" cases/<case>/flash.par
```

**原因**：parfile `rt_mgdBounds_*` 和 .cn4 表的群边界差异 > 1e-8 eV。

**修复**：
1. **改 parfile**：让 `rt_mgdBounds_*` 匹配 .cn4 表的群边界
2. **或换表**：用群边界匹配 parfile 的表
3. **或重新生成表**：用 IONMIX4 工具按 parfile 群边界生成

### F.3 表的温度/密度网格不够

**现象**：表插值时 T 或 n 越界，给最大/最小值

**诊断**：
```bash
# 看表温度范围（K 或 eV）
grep -A 5 "temperature" cases/<case>/<table>.cn4 | head -10

# 看运行时 cell 温度范围
grep "TELE\|minimum\|maximum" 01-data/<basenm>.log
```

**原因**：算例 T 或 ρ 超出表覆盖范围。FLASH 会 clamp 到最近值（不 abort，但物理失真）。

**修复**：
1. 换覆盖更宽的表
2. 调整初始条件让 T/ρ 在表范围内
3. 启用低温泉化（`opacity_ignoreLowTemp = .false.`）

---

## G. 性能问题

### G.1 Opacity 调用太慢

**现象**：每步耗时长，Opacity 计时占比高

**原因**：
- 群数太多（如 100 群）
- cell 数多 + 每 cell 每群查 3 个表（PA/PE/RO）
- 表插值未优化

**修复**：
1. 减少群数（如 6 群，LaserSlab 默认）
2. 用 `opacity_ignoreLowTemp = .true.`（跳过 Biggs1971 公式）
3. 检查是否有冗余 species（合并相似物质）

### G.2 Conductivity 反复调 EOS 算 cv

**现象**：cond_getCv 耗时长

**原因**：cond_getCv 内部调 `Eos(MODE_DENS_TEMP_GATHER)`，EOS 表插值慢

**修复**：
1. 用更简单的 EOS（`eos_gam` 而非 `eos_tab`）—— 牺牲精度
2. 用 Constant Conductivity（跳过 EOS 调用）—— 调试用

---

## H. 跨单元冲突

### H.1 Conductivity 调用 EOS 时 cv 变化导致 EOS 状态不一致

**现象**：cond_getCv 调用后 EOS 内部状态改变

**原因**：cond_getCv 调用 `Eos(MODE_DENS_TEMP_GATHER)`，**MODE_DENS_TEMP_GATHER 是只读模式**不应改状态，但某些 EOS 实现可能有副作用。

**修复**：检查 EOS 实现，确保 GATHER 模式只读。详见 flash-eos skill。

### H.2 Opacity 单位混乱（cm^-1 vs cm²/g）

**现象**：κ 数值异常大或小

**原因**：用户给 op_<spec>AbsorbConstant 时单位错。`op_constant` 是 cm^-1（path-length），`op_constcm2g` 是 cm²/g（mass）。

**诊断**：
```bash
# 检查 Absorb/Emiss/Trans 类型和常数
grep "op_.*Absorb\b\|op_.*Constant" cases/<case>/flash.par
```

**修复**：根据变体类型给正确单位。

### H.3 PlasmaState_logLambda 给 NaN

**现象**：cond_zone 出现 NaN

**原因**：
- nele 或 mion 为 0（极端真空区）
- zbar 为 0（全中性，ms_<spec>ZMin 没设）
- T_ele 或 T_ion 为 0（边界 cell）

**诊断**：
```bash
# 看 cell 状态范围
grep "TELE\|minimum\|maximum" 01-data/<basenm>.log
```

**修复**：
1. parfile 加 `smallt = 1.0`（最小温度，LaserSlab 默认）
2. parfile 加 `ms_<spec>ZMin = 0.02`（最小电离度）
3. 检查初始条件没有全 0 cell

---

## I. 最常见错误 Top 5（按概率排序）

按 L-013 聚焦用户最常遇到的：

| 排名 | 错误 | 频率 | 详见 |
|---|---|---|---|
| 1 | `[opacity_init] bad opacity kind`（op_undefined） | ★★★★★ | §C.2 |
| 2 | IONMIX4 文件读不了（路径/格式） | ★★★★ | §F.1 |
| 3 | `[Conductivity] only works in 3T`（setup 没 +uhd3t） | ★★★ | §B.1 |
| 4 | cond_zone 全 0（useConductivity/diff_useEleCond 关） | ★★★ | §E.1 |
| 5 | 群边界不匹配（rt_mgdBounds vs .cn4 表） | ★★ | §F.2 |

---

## J. 调试 checklist

按 L-012 收到错误时按这个清单排查：

```
□ 1. 日志看 abort 字符串（找 [Conductivity] / [Opacity] 前缀）
□ 2. setup_call 确认 setup 命令正确
□ 3. setup_defines 确认 REQUESTS 落地（含 SpitzerHighZ / Multispecies）
□ 4. parfile 物质属性段完整（useConductivity / useOpacity / op_<spec>*）
□ 5. parfile MGD 群数和边界（rt_mgdNumGroups / rt_mgdBounds_*）
□ 6. 数据文件存在且可读（.cn4 / .ses）
□ 7. .cn4 表群边界和 rt_mgdBounds 一致
□ 8. ms_<spec>A / ms_<spec>Z 设了（Multispecies）
□ 9. smallt / ms_<spec>ZMin 防全 0（防 NaN）
□ 10. diffusion_cutoff_density 不要太高
```

---

## K. 延伸阅读

- **物理原理 + 设计**：`knowledge/overview.md`
- **参数完整字典**：`knowledge/params.md`
- **内部实现**：`knowledge/internals.md`
- **典型配置**：`knowledge/recipes.md`
- **LaserSlab 实际 parfile**：`source/Simulation/SimulationMain/LaserSlab/flash.par`
- **跨单元踩坑**：`agent/pitfalls/`（如有）
- **手册**：FLASH 4.8 User Guide §16-§17

---

## L. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-30 | 初始创建（beta）：12 节踩坑文档，覆盖通用诊断引导（L-012）+ Conductivity abort 6 条 + Opacity abort 6 条 + 变体选择错误 + 隐式错误（cond=0/Opacity=0）+ 表加载错误 + 性能问题 + 跨单元冲突 + Top 5 最常见错误 + 调试 checklist；按 L-008 贴源码相关代码 + L-012 先引导贴现场 + L-013 按概率排序 | claude |
