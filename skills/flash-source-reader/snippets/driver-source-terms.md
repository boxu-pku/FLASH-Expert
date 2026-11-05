# Driver_sourceTerms — sourceTerms 调度器

> **状态**：beta | **最后核对**：2026-07-12 | **源码版本**：FLASH 4.8

## 定义位置

| 类型 | 文件:行号 |
|---|---|
| **主实现** | `source/Driver/DriverMain/Driver_sourceTerms.F90:31` |
| **interface 声明** | `source/Driver/Driver_interface.F90:168` |

## 函数签名

```fortran
! source/Driver/DriverMain/Driver_sourceTerms.F90:31
subroutine Driver_sourceTerms(blockCount, blockList, dt, pass)

  integer, intent(IN) :: blockCount                       ! 本 processor 的 block 数
  integer, dimension(blockCount), intent(IN) :: blockList ! block ID 列表
  real,    intent(IN) :: dt                               ! 当前时间步
  integer, OPTIONAL, intent(IN) :: pass                  ! split Driver 的子步标记
```

## 调用顺序（关键！）

```fortran
! source/Driver/DriverMain/Driver_sourceTerms.F90:46-69

#ifdef DRIVER_EDEARLY
  call EnergyDeposition(...)        ! 排最前（如果 setup 时定义了 DRIVER_EDEARLY）
#endif

  call Polytrope(blockCount, blockList, dt)
  call Stir(blockCount, blockList, dt)
  call Turb_calc(blockCount, blockList)
  call Flame_step(blockCount, blockList, dt)
  call Burn(blockCount, blockList, dt)
  call Heat(blockCount, blockList, dt, dr_simTime)
  call Heatexchange(blockCount, blockList, dt)
  call Cool(blockCount, blockList, dt, dr_simTime)
  call Ionize(blockCount, blockList, dt, dr_simTime)

#ifndef DRIVER_EDEARLY
  call EnergyDeposition(blockCount, blockList, dt, dr_simTime, pass)  ! ★ 默认排这里
#endif

  call Deleptonize(blockCount, blockList, dt, dr_simTime)
```

## 调用顺序的物理动机

| 顺序 | sourceTerm | 修改的变量 | 为什么这个位置 |
|---|---|---|---|
| 1 | Polytrope | 多方过程 EELE | 简单加源，先算 |
| 2 | Stir | 搅拌驱动（动量） | 外部驱动，先于内部过程 |
| 3 | Turb_calc | 湍流统计 | 不修改 unk，只算诊断 |
| 4 | Flame_step | 火焰面 | 反应速率 |
| 5 | Burn | 核燃烧 → EION | 反应释放，加到离子 |
| 6 | Heat | 外部加热 → EELE | 用户定义源 |
| 7 | Heatexchange | T_e ↔ T_i 平衡 | 在 Burn/Heat 后让温度场趋于平衡 |
| 8 | Cool | EELE 减辐射损失 | 平衡后扣损失 |
| 9 | Ionize | 电离/复合 → abundance + EELE | T_e 已稳定，算电离 |
| 10 | **EnergyDeposition** | 激光 → EELE | ★ 默认：等所有温度损失/交换算完，再加激光 |
| 11 | Deleptonize | 中子物质调整 | 收尾 |

## 调用顺序的影响

**默认顺序（激光排第 10）**：
- 激光加到 EELE_VAR 后，**下一步**才被 Heatexchange/Cool 处理
- 数值上更稳（不在同一步内反复迭代）

**定义 DRIVER_EDEARLY（激光排第 1）**：
- 适合激光驱动的燃烧（先加热 → 触发反应）
- setup 时加：`./setup ... -defines=DRIVER_EDEARLY ...`

## `pass` 参数（split Driver 用）

```fortran
call Driver_sourceTerms(blockCount, blockList, dt, pass)
                                                              ↑
                                            split Driver 时传 1（前半步）或 2（后半步）
                                            unsplit Driver 时不传
```

**对激光的影响**：split 模式下每步调 2 次 EnergyDeposition（前半步 + 后半步），更精确但更贵。激光代码内部用 `passSplitDriver` 控制 LaserIO 输出时机。

## 常被问到的问题

**Q: 怎么加新的 sourceTerm？**
A: 4 步：
1. 写自己的 sourceTerm 单元（在 `source/physics/sourceTerms/<YourName>/`）
2. 在 Config 里 `REQUIRES` 或 `REQUESTS` 它
3. 在 `Driver_sourceTerms.F90` 加 `call YourSourceTerm(...)` 到合适位置
4. 重新 setup+make

**Q: 怎么改调用顺序？**
A: 直接编辑 `Driver_sourceTerms.F90:46-69`。但要小心物理一致性（如 Burn 应该在 Heatexchange 前，否则电子-离子能量交换会算错）。

**Q: 为什么 `pass` 是 OPTIONAL？**
A: 兼容 split 和 unsplit Driver。unsplit 调用时不传，split 调用时传 1 或 2。

## 相关条目

- `snippets/driver-evolve-flash.md` — Driver_evolveFlash 完整主循环
- `flash-laser/knowledge/internals.md §2.1` — 激光在 sourceTerms 中的位置详解
- `snippets/runtime-parameters-get.md` — 各 sourceTerm 怎么读自己的参数

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-12 | 初始创建（调用顺序 + 物理动机表） | claude |
