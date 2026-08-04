# Eos_wrapped — EOS 包装接口

> **状态**：beta | **最后核对**：2026-07-12 | **源码版本**：FLASH 4.8

## 定义位置（多实现，按 EOS 类型分）

| 类型 | 文件:行号 | 适用 |
|---|---|---|
| **stub（顶层）** | `source/physics/Eos/Eos_wrapped.F90:79` | 默认 dispatch |
| **Gamma** | `source/physics/Eos/EosMain/Gamma/Eos_wrapped.F90` | 理想气体 γ 法则 |
| **Gamma/RHD** | `source/physics/Eos/EosMain/Gamma/RHD/Eos_wrapped.F90:101` | 相对论流体 |
| **Helmholtz** | `source/physics/Eos/EosMain/Helmholtz/Ye/Eos_wrapped.F90:96` | 简并物质（白矮星 / 恒星） |
| **multiTemp** | `source/physics/Eos/EosMain/multiTemp/Eos_wrapped.F90:91` | ★ 3T 电子-离子-辐射分离（ICF/激光用） |
| **multifluid** | `source/physics/Eos/EosMain/multiFluid/Eos_wrapped.F90` | 多流体 |
| **Tabulated** | `source/physics/Eos/EosMain/Tabulated/Eos_wrapped.F90` | EOS 表（如 SESAME / IONMIX） |
| **interface 声明** | `source/physics/Eos/Eos_interface.F90:22` | — |

setup 选哪个：
- 默认 → Gamma
- `+mtmmmt` → **multiTemp**（激光算例必须用这个）
- `+eos=helmholtz` → Helmholtz
- `+eos=tabulated` → Tabulated

## 函数签名

```fortran
subroutine Eos_wrapped(mode, range, blockID, gridDataStruct)

  integer, intent(in) :: mode                       ! ★ 计算模式（见下表）
  integer, dimension(2, MDIM), intent(in) :: range  ! block 内的 cell 范围
  integer, intent(in) :: blockID                    ! block ID
  integer, optional, intent(IN) :: gridDataStruct   ! 默认 CENTER
```

## mode 参数（关键）

| mode 常量 | 含义 | 输入 → 输出 |
|---|---|---|
| `MODE_DENS_TEMP` | 给定 ρ、T 算其他 | ρ, T → P, E_int, etc. |
| `MODE_DENS_PRES` | 给定 ρ、P 算其他 | ρ, P → T, E_int, etc. |
| `MODE_DENS_EI` / `MODE_DENS_EI_GATHER` | ★ 给定 ρ、内能算其他 | ρ, E_int → T, P, etc. |
| `MODE_EOS_NOP` | 不计算，只包装 | 用于诊断 |
| `MODE_EOS_WRAPPERONLY` | 只做 wrap/unwrap | 特殊用 |

**最常用**：`MODE_DENS_EI_GATHER`——给定密度和内能，重算温度和压强。

源码声明：`source/physics/Eos/EosMain/multiTemp/Eos_wrapped.F90:135-156`（mode 白名单检查）。

## 工作机制（multiTemp 版）

```fortran
! source/physics/Eos/EosMain/multiTemp/Eos_wrapped.F90:91-250（简化）

subroutine Eos_wrapped(mode, range, blockID, gridDataStruct)
   ! ...
   call Grid_getBlkPtr(blockID, solnData, CENTER)             ! ★ 取 block 数据
   
   ! 检查 mode 合法性
   select case (mode)
   case (MODE_DENS_PRES, MODE_DENS_TEMP, MODE_DENS_EI, ...)
      ! OK
   case default
      call Driver_abortFlash("[Eos_wrapped] invalid mode")
   end select
   
   ! 按 cell 算（或按 vector 算）
   do k = range(LOW, KAXIS), range(HIGH, KAXIS)
      do j = range(LOW, JAXIS), range(HIGH, JAXIS)
         do i = range(LOW, IAXIS), range(HIGH, IAXIS)
            ! 从 solnData 收集当前 cell 的 ρ、T_e、T_i、T_r 等
            ! 调 Eos(mode, eosData, massFrac)  ← 真实 EOS 计算
            ! 把结果写回 solnData（P, c_sound, etc.）
         end do
      end do
   end do
   
   call Grid_releaseBlkPtr(blockID, solnData, CENTER)         ! ★ 释放
end subroutine
```

## 为什么要有 wrapped 版本

**Eos**（无 wrapped）是**单元接口**，输入输出是 1D 数组（vec），不知道 block/grid 概念。

**Eos_wrapped** 把它包装成：
- 输入 blockID + range → 自动取 solnData → 调 Eos vec → 写回 solnData

→ 调用者不用关心 cell 循环和 Grid_getBlkPtr 细节。

## 典型用法

### 用法 1：在 sourceTerm 内修改 EELE 后重算 T

```fortran
! 来自 ed_updatePlasma.F90（激光沉积后）
call Grid_getBlkPtr(blockID, solnData, CENTER)
solnData(EELE_VAR, ib:ie, jb:je, kb:ke) = &
    solnData(EELE_VAR, ...) + depo_contribution
call Grid_releaseBlkPtr(blockID, solnData, CENTER)

! ★ 用更新后的 EELE 重算 T_e, T_i, P 等
call Eos_wrapped(MODE_DENS_EI_GATHER, blkLimits, blockID)
```

### 用法 2：在初始化时根据初值算一致状态

```fortran
! 来自 Simulation_initBlock.F90（典型）
call Grid_getBlkPtr(blockID, solnData, CENTER)
solnData(DENS_VAR, ...) = sim_rhoAmbient
solnData(PRES_VAR, ...) = sim_pAmbient
solnData(TELE_VAR, ...) = sim_teleAmbient
! ... 但 EELE_VAR 没设 ...
call Grid_releaseBlkPtr(blockID, solnData, CENTER)

! 用 ρ, T 反算 EELE 和其他
call Eos_wrapped(MODE_DENS_TEMP, blkLimits, blockID)
```

## 常被问到的问题

**Q: `range` 参数怎么填？**
A: 通常是 `blkLimits`（不含 guard cells）或 `blkLimitsGC`（含 guard cells）。从 `Grid_getBlkIndexLimits` 获取。

**Q: wrapped 和 unwrapped 哪个快？**
A: `Eos_wrapped` 多了取指针、cell 循环的开销。如果你已经持有 solnData 指针、要算多个变量，直接调 `Eos` 更快。但通常 wrapped 更安全（不易出错）。

**Q: 为什么我调完 `Eos_wrapped`，温度没变？**
A: 检查 mode。如果你用 `MODE_EOS_NOP` 或 `MODE_EOS_WRAPPERONLY`，确实不会算。

**Q: 3T 模式下，T_e / T_i / T_r 都会被更新吗？**
A: 是的。multiTemp Eos_wrapped（`+mtmmmt`）会同时更新 `TELE_VAR`、`TION_VAR`、`TRAD_VAR`、`EELE_VAR`、`EION_VAR`、`ERAD_VAR` 和 `PRES_VAR`。

## 相关条目

- `snippets/grid-get-blk-ptr.md` — 取 solnData 指针
- `snippets/runtime-parameters-get.md` — 怎么读 EOS 类型参数
- `flash-laser/knowledge/internals.md §4.1` — 激光代码调 Eos_wrapped 的位置
- `flash-eos` skill（Phase 2）— 完整 EOS 单元讲解

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-12 | 初始创建（7 个 EOS 实现位置、mode 表、工作机制、典型用法） | claude |
