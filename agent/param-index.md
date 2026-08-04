# FLASH 参数核心索引

> 手工维护的高频参数索引。覆盖 ~150 条核心参数，按单元分类。
> 完整 2884+ 条 PARAMETER 声明靠 `find source -name Config | xargs grep "^PARAMETER"` 动态查。
>
> **使用规则**：
> - 查具体参数时先用本索引（含 Config 没写的单位、典型值、含义）
> - 本索引没有的参数 → 用 `rg` 在 Config 文件动态搜
> - 详细物理背景 → 对应 `flash-<unit>` skill 的 `knowledge/params.md`
>
> **维护**：每次遇到不在索引里的高频参数就追加。

---

## 目录

- [1. Driver（时间步/IO/模拟控制）](#1-driver时间步io模拟控制)
- [2. Grid（AMR/几何/refinement）](#2-gridamr几何refinement)
- [3. Hydro（流体求解器）](#3-hydro流体求解器)
- [4. Eos（状态方程）](#4-eos状态方程)
- [5. RadTrans / MGD（辐射传输）](#5-radtrans--mgd辐射传输)
- [6. EnergyDeposition / Laser（激光）](#6-energydeposition--laser激光)
- [7. Diffuse（扩散）](#7-diffuse扩散)
- [8. materialProperties（物质属性）](#8-materialproperties物质属性)
- [9. sourceTerms（Burn/Cool/Heat）](#9-sourcetermsburncoolheat)
- [10. IO（输入输出）](#10-io输入输出)
- [11. Multispecies（多物种）](#11-multispecies多物种)
- [12. Simulation（用户参数）](#12-simulation用户参数)

---

## 1. Driver（时间步/IO/模拟控制）

> 文件：`source/Driver/DriverMain/Config`

### 时间步控制

| 参数 | 类型 | 默认 | 单位 | 含义 |
|---|---|---|---|---|
| `dtinit` | REAL | 1e-10 | s | 初始时间步 |
| `dtmin` | REAL | 1e-10 | s | 最小允许 dt（小于则 abort） |
| `dtmax` | REAL | 1e5 | s | 最大允许 dt |
| `tstep_change_factor` | REAL | 2.0 | — | dt 单步最大变化倍数 |
| `dr_tstepSlowStartFactor` | REAL | 0.1 | — | 慢启动因子 |
| `useSTS` | BOOLEAN | false | — | Super-time-stepping（加速扩散） |
| `useSTSforDiffusion` | BOOLEAN | false | — | STS 用于扩散 |
| `allowDtSTSDominate` | BOOLEAN | false | — | 允许 STS 主导 dt |

### 模拟范围

| 参数 | 类型 | 默认 | 单位 | 含义 |
|---|---|---|---|---|
| `nbegin` | INTEGER | 1 | — | 起始步 |
| `nend` | INTEGER | 100 | — | 终止步 |
| `tinitial` | REAL | 0.0 | s | 起始时间 |
| `tmax` | REAL | 0.2 | s | 终止时间 |
| `wall_clock_time_limit` | REAL | 604800 | s（壁钟） | 墙钟超时（默认 7 天） |

### Restart

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `restart` | BOOLEAN | false | 是否从 checkpoint 重启 |
| `initializeParticleAtRestart` | BOOLEAN | false | 重启时重初始化粒子 |

### 诊断

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `dr_printTStepLoc` | BOOLEAN | true | 打印 dt 计算位置 |
| `eachProcWritesOwnAbortLog` | BOOLEAN | false | 每个 processor 写独立 abort 日志 |
| `dr_abortPause` | INTEGER | 2 | abort 前暂停秒数 |
| `dr_usePosdefComputeDt` | BOOLEAN | false | 强制正定 dt |

---

## 2. Grid（AMR/几何/refinement）

> 文件：`source/Grid/GridMain/Config`、`source/Grid/Config`

### 域边界

| 参数 | 类型 | 默认 | 单位 | 含义 |
|---|---|---|---|---|
| `xmin` / `xmax` | REAL | 0 / 1 | cm | X 方向域边界 |
| `ymin` / `ymax` | REAL | 0 / 1 | cm | Y 方向 |
| `zmin` / `zmax` | REAL | 0 / 1 | cm | Z 方向 |

### 几何

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `geometry` | STRING | "cartesian" | 几何类型：cartesian / cylindrical / spherical / polar |
| `problo` / `probhi` | REAL | — | 域下/上角（与 xmin/xmax 等价，部分版本用） |

### AMR refinement

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `lrefine_min` | INTEGER | 1 | 最小细化层 |
| `lrefine_max` | INTEGER | 1 | 最大细化层 |
| `nrefs` | INTEGER | 2 | 触发细化的"误差超过"次数 |
| `refine_var_1` ~ `_4` | INTEGER | -1 | 触发细化的变量索引（如 DENS_VAR=1） |
| `deref_var_1` ~ `_4` | INTEGER | -1 | 触发粗化的变量索引 |
| `convertToConsvdForMeshCalls` | BOOLEAN | false | 网格调用时转守恒形式 |
| `gr_ptRemove` | BOOLEAN | false | 是否删除越界粒子 |
| `gr_ptRemoveAlgo` | INTEGER | 2 | 粒子删除算法 |

### 边界条件

| 参数 | 类型 | 含义 |
|---|---|---|
| `bc_left_x` / `bc_right_x` 等字符串 | STRING | 各方向 BC 类型：`reflect`/`outflow`/`diode`/`axisymmetric`/`vacuum`/`user` 等 |

---

## 3. Hydro（流体求解器）

> 文件：`source/physics/Hydro/HydroMain/Config`、`source/physics/Hydro/HydroMain/unsplit/Config`

### 总开关

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `useHydro` | BOOLEAN | true（CONSTANT） | Hydro 总开关 |

### 数值稳定性

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `cfl` | REAL | 0.8 | ★ Courant 数（CFL），强激波建议 0.4-0.5 |
| `small` | REAL | 1e-10 | 密度/压强下限（防 0） |
| `smallp` | REAL | 1e-10 | 压强下限 |
| `smallu` | REAL | 1e-10 | 速度下限 |
| `smallx` | REAL | 1e-99 | 质量分数下限 |

### 限幅器（unsplit）

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `use_steepening` | BOOLEAN | true | 接触不连续面陡化 |
| `use_cma_flattening` | BOOLEAN | false | CMA flattening（接触面抹平） |
| `use_cma_advection` | BOOLEAN | false | CMA 平流（partial mass 作主变量） |
| `CMAxh`, `CMAxlo` 等 | REAL | — | CMA 各方向参数 |
| `epsilon_1`, `epsilon_2` | REAL | — | shock 检测阈值 |

### 物种与单位

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `UnitSystem` | STRING | "none" | 单位制（none/cgs/mks） |
| `irenorm` | INTEGER | 0 | 重归一化频率 |

---

## 4. Eos（状态方程）

> 文件：`source/physics/Eos/EosMain/<variant>/Config`

### 总开关

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `eos_gammas` | REAL | 5/3 | 单原子理想气体 γ |
| `eos_singleSpecies` | BOOLEAN | true | 单物种模式 |
| `eos_temp` | REAL | — | 默认温度（用于初始化） |
| `eos_tolerance` | REAL | 1e-12 | EOS 迭代容差 |
| `eos_maxNewton` | INTEGER | 50 | Newton 迭代最大次数 |

### multiTemp 特有（`+mtmmmt`）

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `eos_applyNeleAbcCorrections` | BOOLEAN | false | 电子数密度下限修正 |
| `eos_lowTemp` | REAL | — | 表格适用最低温度 |
| `eos_highTemp` | REAL | — | 表格适用最高温度 |

详见 `flash-eos` skill（Phase 2）。

---

## 5. RadTrans / MGD（辐射传输）

> 文件：`source/physics/RadTrans/RadTransMain/MGD/Config`

### 总开关

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `useRadTrans` | BOOLEAN | false | RadTrans 总开关 |

### MGD 多群扩散

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `rt_mgdNumGroups` | INTEGER | 4 | 多群数（典型 4-70） |
| `rt_mgdBounds_1` ~ `_71` | REAL | — | 群边界（eV 或 erg） |
| `rt_mgdFlMode` | STRING | — | Flux limiter 模式：fl_harmonic / fl_geometric / fl_arithmetic / fl_none |
| `rt_mgdFlCoef` | REAL | 1.0 | Flux limiter 系数 |
| `rt_mgdXlBoundaryType` | STRING | — | X 左 BC 类型：vacuum/reflecting/marshak ... |
| `rt_mgdXrBoundaryType` | STRING | — | X 右 BC |
| `rt_mgdYlBoundaryType` 等 | STRING | — | Y/Z 方向 BC |
| `rt_mgdDtFactor` | REAL | 1e100 | 辐射时间步因子 |
| `rt_useMGD` | BOOLEAN | false | 启用 MGD |

详见 `flash-radtrans` skill（Phase 2）。

---

## 6. EnergyDeposition / Laser（激光）

> 文件：`source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/Config`
> 详细见 `.claude/skills/flash-laser/knowledge/params.md`（38 全局 + pulse/beam 字典）

### 总开关

| 参数 | 类型 | 默认 | 单位 | 含义 |
|---|---|---|---|---|
| `useEnergyDeposition` | BOOLEAN | true | — | 激光总开关 |
| `ed_laser3Din2D` | BOOLEAN | false | — | 2D RZ 用 3D ray（**必须 true**） |
| `ed_laser3Din2DwedgeAngle` | REAL | 0.0 | 度 | 楔形角 |
| `ed_gradOrder` | INTEGER | 2 | — | 折射阶：1=无折射，2=一阶 |

### Pulse（时间波形）

| 参数 | 类型 | 默认 | 单位 | 含义 |
|---|---|---|---|---|
| `ed_numberOfPulses` | INTEGER | -1 | — | 实际 pulse 数 |
| `ed_numberOfSections_<p>` | INTEGER | -1 | — | 第 p 条 pulse 的 (time, power) 段数 |
| `ed_time_<p>_<s>` | REAL | -1.0 | **s** | 第 p 条 pulse 第 s 段时间 |
| `ed_power_<p>_<s>` | REAL | -1.0 | **W** | 第 p 条 pulse 第 s 段功率 |

### Beam 几何（每束 30 个属性，列核心 5 个）

| 参数 | 类型 | 默认 | 单位 | 含义 |
|---|---|---|---|---|
| `ed_wavelength_<i>` | REAL | -HUGE | **μm** | 波长（决定 N_c） |
| `ed_lensX/Y/Z_<i>` | REAL | -HUGE | cm | lens 椭圆中心 |
| `ed_targetX/Y/Z_<i>` | REAL | -HUGE | cm | target 椭圆中心（光斑中心） |
| `ed_targetSemiAxisMajor/Minor_<i>` | REAL | -HUGE | cm | target 半长/短轴 |
| `ed_pulseNumber_<i>` | INTEGER | -HUGE | — | 绑哪条 pulse |

### Beam 截面与网格

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `ed_crossSectionFunctionType_<i>` | STRING | " " | 截面函数：uniform/gaussian2D/gaussianInverse2D/... |
| `ed_gaussianExponent_<i>` | REAL | -HUGE | α（1=标准高斯，4=平顶） |
| `ed_gaussianRadius{Major,Minor}_<i>` | REAL | -HUGE | cm，1/e 半径 |
| `ed_gaussianCenter{Major,Minor}_<i>` | REAL | 0.0 | cm，偏心 |
| `ed_numberOfRays_<i>` | INTEGER | -HUGE | 该束 ray 数 |
| `ed_gridType_<i>` | STRING | " " | radial2D/square2D/rectangular2D/delta2D/statistical2D |

### Setup 变量（编译期）

| 变量 | 默认 | 含义 |
|---|---|---|
| `ed_maxBeams` | 6 | 生成多少套 beam 参数槽 |
| `ed_maxPulses` | 5 | 多少条 pulse |
| `ed_maxPulseSections` | 20 | 每条 pulse 多少段 |
| `ed_maxRayCount` | 100 | 每 processor 最大 ray 数 |

---

## 7. Diffuse（扩散）

> 文件：`source/physics/Diffuse/DiffuseMain/Unsplit/Config`

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `useDiffuse` | BOOLEAN | false | 扩散总开关 |
| `diff_useThermDiff` | BOOLEAN | true | 电子热传导 |
| `diff_useIonDiff` | BOOLEAN | false | 离子热传导 |
| `diff_useRadDiff` | BOOLEAN | false | 辐射扩散 |
| `diff_useViscous` | BOOLEAN | false | 粘性 |
| `diff_useMagDiff` | BOOLEAN | false | 磁扩散 |
| `diff_theta` | REAL | 1.0 | 隐式参数（0=显式，1=全隐式） |
| `diff_dtFactor` | REAL | 1e100 | 扩散时间步因子 |
| `diff_3Ttheta` | REAL | 0.5 | 3T 隐式参数 |
| `diff_isoCoeff` | REAL | 0 | 各向同性扩散系数 |

详见 `flash-diffuse` skill（Phase 2）。

---

## 8. materialProperties（物质属性）

> 文件：`source/physics/materialProperties/*/Config`

### Conductivity（电导率）

| 参数 | 类型 | 含义 |
|---|---|---|
| `useConductivity` | BOOLEAN | 启用电导率 |
| `cond_constantConductivity` | REAL | 常数电导率值 |
| `cond_variableType` | STRING | "constant" / "spitzer" / "table" |

### Opacity（不透明度）

| 参数 | 类型 | 含义 |
|---|---|---|
| `useOpacity` | BOOLEAN | 启用不透明度 |
| `op_<species>Absorb` | STRING | 物种吸收模式：op_tabpa / op_constant / ... |
| `op_<species>Emiss` | STRING | 发射模式 |
| `op_<species>Trans` | STRING | 透射模式 |
| `op_<species>FileType` | STRING | ionmix4 / ionmix7 / sesame / opacplot |
| `op_<species>FileName` | STRING | 表格文件名 |

详见 `flash-material` skill（Phase 2）。

---

## 9. sourceTerms（Burn/Cool/Heat）

> 文件：`source/physics/sourceTerms/*/Config`

### Burn（核燃烧）

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `useBurn` | BOOLEAN | false | Burn 总开关 |
| `burn_dtFactor` | REAL | 1e100 | Burn 时间步因子 |
| `burn_eosMode` | STRING | "dens_e" | Burn 内 EOS 模式 |

### Cool（辐射冷却）

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `useCool` | BOOLEAN | false | Cool 总开关 |
| `cool_dtFactor` | REAL | 1e100 | Cool 时间步因子 |
| `cool_tableFile` | STRING | — | 冷却率表 |

### Heat / Heatexchange

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `useHeat` | BOOLEAN | false | Heat 总开关 |
| `useHeatexchange` | BOOLEAN | false | 电子-离子能量交换 |
| `he_dtFactor` | REAL | 1e100 | Heatexchange 时间步因子 |

详见 `flash-sourceterms` skill（Phase 2）。

---

## 10. IO（输入输出）

> 文件：`source/IO/IOMain/<variant>/Config`

### Plotfile

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `basenm` | STRING | — | 输出文件名前缀（如 "01-data/lasslab_"） |
| `plot_var_1` ~ `_N` | INTEGER | 0 | 输出的变量索引 |
| `plotFileIntervalStep` | INTEGER | 1000 | 每 N 步输出 plotfile |
| `plotFileIntervalTime` | REAL | 0 | 每 N 秒输出 |
| `plotFileNumber` | INTEGER | 0 | 当前 plotfile 编号 |

### Checkpoint

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `checkpointFileIntervalStep` | INTEGER | 1000 | 每 N 步写 checkpoint |
| `checkpointFileIntervalTime` | REAL | 1.0 | 每 N 秒写 |
| `checkpointFileNumber` | INTEGER | 0 | 当前 chk 编号 |

### 日志

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `log_file` | STRING | — | 日志文件名 |
| `run_comment` | STRING | — | 算例注释（写日志头） |
| `alwaysRestrictCheckpoint` | BOOLEAN | false | checkpoint 时强制 restrict |

详见 `flash-io` skill（Phase 2）。

---

## 11. Multispecies（多物种）

| 参数 | 类型 | 含义 |
|---|---|---|
| `species` | (setup 变量) | species=cham,targ1,... 在 setup 命令行 |
| `ms_<species>A` | REAL | 物种 A（质量数） |
| `ms_<species>Z` | REAL | 物种 Z（电荷数） |
| `ms_<species>BindingEnergy` | REAL | 结合能 |
| `ms_<species>Gamma` | REAL | 单物种 γ |

详见 `flash-multispecies` skill（Phase 2）。

---

## 12. Simulation（用户参数）

每个 `SimulationMain/<problem>/Config` 声明该算例特有的 `sim_*` 参数。常见：

| 参数 | 类型 | 含义 |
|---|---|---|
| `sim_xmin` / `sim_xmax` 等 | REAL | 算例域边界（独立于 Grid xmin/xmax） |
| `sim_pAmbient` | REAL | 环境压强 |
| `sim_rhoAmbient` | REAL | 环境密度 |
| `sim_teleAmbient` / `sim_tionAmbient` / `sim_tradAmbient` | REAL | 环境温度（3T） |
| `sim_initGeom` | STRING | 几何（部分算例） |
| `sim_targetRadius` / `sim_targetHeight` 等 | REAL | 算例特定几何 |

每个 SimulationMain 都有自己的 sim_* 集合。查具体算例：
```bash
cat source/Simulation/SimulationMain/<your_problem>/Config
```

---

## 附录：按前缀速查

| 前缀 | 单元 |
|---|---|
| `ed_` | EnergyDeposition（激光） |
| `rt_` | RadTrans |
| `mgd_` | MGD（多群扩散，RadTrans 子集） |
| `hy_` | Hydro（部分版本） |
| `eos_` | Eos |
| `gr_` | Grid |
| `sim_` | Simulation（用户算例参数） |
| `dr_` | Driver |
| `io_` | IO |
| `mesh_` | Grid（部分版本） |
| `diff_` | Diffuse |
| `cool_` | Cool |
| `heat_` | Heat |
| `he_` | Heatexchange |
| `burn_` | Burn |
| `fl_` | Flame |
| `stir_` | Stir |
| `turb_` | Turb |
| `op_<species>` | Opacity（每物种一套） |
| `cond_` | Conductivity |
| `visc_` | Viscosity |
| `ms_<species>` | Multispecies（每物种一套） |

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-12 | 初始创建（12 个单元 + 前缀速查 + ~150 核心参数） | claude |
