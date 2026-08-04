# Grid_getBlkPtr / Grid_releaseBlkPtr — Block 数据指针访问

> **状态**：beta | **最后核对**：2026-07-12 | **源码版本**：FLASH 4.8

## 定义位置

| 类型 | 文件:行号 |
|---|---|
| **stub（顶层，被其他 unit 调用）** | `source/Grid/Grid_getBlkPtr.F90:53` |
| **真实实现（paramesh 后端）** | `source/Grid/GridMain/paramesh/Grid_getBlkPtr.F90`（按 gridDataStruct 分派） |
| **通用包装（varDesc 风格）** | `source/Grid/GridMain/Grid_genGetBlkPtr.F90:39` |
| **release 配对** | `source/Grid/Grid_releaseBlkPtr.F90` |
| **interface 声明** | `source/Grid/Grid_interface.F90:232` |

## 函数签名

```fortran
subroutine Grid_getBlkPtr(blockID, dataPtr, gridDataStruct)

  integer, intent(in) :: blockID                           ! 想访问的 block ID
  real, dimension(:,:,:,:), pointer :: dataPtr             ! ★ 返回的指针
  integer, optional, intent(in) :: gridDataStruct          ! 选 CENTER / FACEX / ...
```

## 两种调用风格

### 风格 A：传统（按 gridDataStruct 分派）

```fortran
real, pointer :: solnData(:,:,:,:)

call Grid_getBlkPtr(blockID, solnData, CENTER)             ! 取中心变量
! 现在可以读 solnData(DENS_VAR, i, j, k) 等
solnData(TELE_VAR, ib:ie, jb:je, kb:ke) = ...
call Grid_releaseBlkPtr(blockID, solnData, CENTER)         ! ★ 必须释放
```

### 风格 B：varDesc 风格（FLASH 4 新接口，更安全）

```fortran
call Grid_genGetBlkPtr(blockID, dataPtr, varDesc)          ! 通过 varDesc 描述要什么
```

`varDesc` 是个小型结构体，指定 variable name + gridDataStruct。详见 `source/Grid/GridMain/Grid_genGetBlkPtr.F90:39-102`。

## gridDataStruct 可选值

| 常量 | 含义 | 典型变量 |
|---|---|---|
| `CENTER` | 中心变量 | `DENS_VAR`, `TELE_VAR`, `EION_VAR`, `VELX_VAR` |
| `FACEX` / `FACEY` / `FACEZ` | 面变量 | 磁场分量（MHD） |
| `WORK` | 工作数组 | AMR 内部 |
| `SCRATCH` / `SCRATCH_CENTER` / `SCRATCH_FACEX` 等 | 临时数组 | 各单元私有 |

## 真实实现的关键逻辑

```fortran
! source/Grid/GridMain/Grid_genGetBlkPtr.F90:65-98（简化）
select case (gds)
case (FACES)
   ! 按 paramesh / UG 后端分派
   call Grid_getBlkPtr(blockID, dataPtr, FACEX)
case (SCRATCH_FACES)
   call Grid_getBlkPtr(blockID, dataPtr, SCRATCH_FACEX)
case default  ! CENTER 等
   call Grid_getBlkPtr(blockID, dataPtr, CENTER)
end select
```

## 重要约束

### 1. **必须配对 Grid_releaseBlkPtr**

```fortran
call Grid_getBlkPtr(blockID, solnData, CENTER)
! ... 用 solnData ...
call Grid_releaseBlkPtr(blockID, solnData, CENTER)   ! ★ 不能漏！
```

**漏 release 后果**：
- 指针悬挂，后续 block 操作可能 corrupt
- paramesh guard cell 更新失败
- 多线程时 race condition

### 2. **指针只在调用期间有效**

```fortran
! ❌ 错误：保存指针长期使用
real, pointer, save :: cached_ptr(:,:,:,:)
call Grid_getBlkPtr(1, cached_ptr, CENTER)
! ... 几步后 ...
! cached_ptr 可能已失效（AMR 重细化改了 block 数据）
```

正确做法：每次用前 get、用完 release。

### 3. **修改后要通知 Grid**

如果你修改了 solnData 的值（不只是读），有些场景需要调 `Grid_notifySolnDataUpdate`，让 Grid 知道 guard cells 失效了。

## 典型用法（来自 ed_updatePlasma）

```fortran
! source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserUtilities/ed_updatePlasma.F90:65-110
do block = 1, blockCount
   blockID = blockList(block)
   
   call Grid_getBlkPtr(blockID, solnData, CENTER)                     ! ★ 取指针
   call Grid_getBlkIndexLimits(blockID, blkLimits, blkLimitsGC, CENTER)
   
   ib = blkLimits(LOW, IAXIS); ie = blkLimits(HIGH, IAXIS)
   ! ... 类似 j, k
   
   ! 修改 solnData：把激光沉积加到 EELE_VAR
   solnData(EELE_VAR, ib:ie, jb:je, kb:ke) = &
       solnData(EELE_VAR, ib:ie, jb:je, kb:ke) + solnData(ed_depoVar, ...)
   
   call Grid_releaseBlkPtr(blockID, solnData, CENTER)                 ! ★ 释放
   call Eos_wrapped(MODE_DENS_EI_GATHER, blkLimits, blockID)          ! 用 EELE 重算 T
end do
```

## 常被问到的问题

**Q: 为什么 dataPtr 是 4 维？**
A: 4 维 = (变量索引, i, j, k)。即使 1D 模拟也是 4 维（j、k 维长度为 1）。

**Q: 怎么知道 block 有多少 cell？**
A: 调 `Grid_getBlkIndexLimits(blockID, blkLimits, blkLimitsGC, CENTER)`，`blkLimits(LOW:HIGH, 1:MDIM)` 是真实 cell 范围，`blkLimitsGC` 含 guard cells。

**Q: 多线程能用吗？**
A: 可以，但要保证不同线程不操作同一 blockID。一般 OpenMP 并行按 block 分。

## 相关条目

- `snippets/eos-wrapped.md` — EOS 包装（也用 Grid_getBlkPtr 取 solnData）
- `flash-laser/knowledge/internals.md §4.3` — 激光代码大量用 Grid_getBlkPtr

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-12 | 初始创建（两种调用风格、约束、典型用法） | claude |
