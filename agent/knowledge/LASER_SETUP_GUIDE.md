# FLASH 4.8 激光设置与自定义空间分布手册

本手册覆盖三件事：
1. **parfile 实例**：4 个可直接改、可运行的真实激光配置（基于 `cases/laser_CH`）。
2. **参数完整清单**：每个 `ed_*` 参数的物理含义、单位、几何/数值意义。
3. **自定义空间分布**：从源码层面加新的截面函数（含完整 diff），以及如何改 ray 布点。

---

## 目录

- [1. 物理模型回顾](#1-物理模型回顾)
- [2. 参数完整清单](#2-参数完整清单)
- [3. parfile 实例（4 个）](#3-parfile-实例4-个)
- [4. "我想要 X 分布" 对照表](#4-我想要-x-分布-对照表)
- [5. 自定义截面函数（详细步骤 + 源码 diff）](#5-自定义截面函数详细步骤--源码-diff)
- [6. 自定义 ray 布点（grid type）](#6-自定义-ray-布点grid-type)
- [7. 调试与可视化](#7-调试与可视化)
- [8. 常见错误与排查](#8-常见错误与排查)

---

## 1. 物理模型回顾

FLASH 把一束激光表示成 **N 根几何光线 (ray)**，从 `lens` 椭圆面出发，射向 `target` 椭圆面，沿途被等离子体按逆韧致吸收机制吸收，沉积到 cell 的电子内能 `EELE_VAR` 上。

```
        lens 椭圆面                       target 椭圆面（你关心的截面）
       (光源 / 透镜)                         (功率密度分布的"画板")
       ┌────────────┐                      ┌────────────┐
       │  • • • • • │  ─── N 根 ray ───→  │  • • • • • │
       │  • • • • • │                      │  • • • • • │
       │  • • • • • │                      │  • • • • • │
       └────────────┘                      └────────────┘
        ed_lens{X,Y,Z}                      ed_target{X,Y,Z}
        ed_lensSemiAxisMajor                ed_targetSemiAxis{Major,Minor}
```

**核心归一化公式**（源码：`LaserBeams/ed_beam3DGridWeightRadial.F90:158-184` + `LaserRaysCreate/ed_createRays3DRec.F90:979-994`）：

```
gridWeight       = Σ_i  w(x_i, y_i)            # setup 时一次性算好
powerFraction_i  = w(x_i, y_i) / gridWeight    # 每根 ray 占的功率份额
P_ray_i          = P_beam(t) × powerFraction_i # 每根 ray 实际携带的功率
```

其中 `w(x, y)` 就是截面权重函数（`ed_beamCrossSectionWeight`），由 `ed_crossSectionFunctionType_<i>` 选定。**不论选什么函数、不论 grid 用什么形状，Σ P_ray 永远严格等于 P_beam**。

→ 所以**目标截面 (x, y) 处的功率密度 ∝ w(x, y)**。控制 w 就是控制分布形状。

---

## 2. 参数完整清单

所有 `_<i>` 表示第 i 束激光（i 从 1 到 `ed_maxBeams`）。

### 2.1 总开关

| 参数 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `useEnergyDeposition` | bool | .false. | 激光总开关 |
| `ed_laser3Din2D` | bool | .false. | 2D RZ 几何下用 3D ray（推荐 .true.） |
| `ed_laser3Din2DwedgeAngle` | real (度) | — | 楔形对称角，< 180，常用 0.1 |
| `ed_gradOrder` | int | 2 | 折射梯度阶：1=无折射，2=一阶 |
| `ed_cellWallThicknessFactor` | real | 1e-6 | ray 不能贴 cell 壁的距离（防数值误差） |
| `ed_enforcePositiveTele` | bool | .true. | 强制 T_e 梯度 ≥ 0 |
| `ed_enforcePositiveNele` | bool | .true. | 强制 N_e 梯度 ≥ 0 |
| `ed_depoVarName` | string | "depo" | 沉积变量名 |
| `ed_depoReuseMaxSteps` | int | -1 | 复用上次沉积结果的最大步数（-1=禁用） |
| `ed_printBeams/Pulses/Main` | bool | .false. | 调试：把 beam/pulse 信息打到日志 |

### 2.2 Pulse（时间波形 P(t)）

| 参数 | 含义 | 单位 |
|---|---|---|
| `ed_numberOfPulses` | pulse 总数 | — |
| `ed_numberOfSections_<p>` | 第 p 条 pulse 的 (time, power) 段数（≥2） | — |
| `ed_time_<p>_<s>` | 第 p 条 pulse 第 s 段的时间 | **s** |
| `ed_power_<p>_<s>` | 第 p 条 pulse 第 s 段的功率 | **W**（不是 erg/s） |

→ FLASH 在每步内对 P(t) 做分段线性插值 + 梯形积分，得到当前步平均 `beamPower`（源码 `LaserBeams/ed_computeBeamPower.F90:122-156`）。

### 2.3 Beam 几何

| 参数 | 含义 | 单位 |
|---|---|---|
| `ed_numberOfBeams` | beam 总数 | — |
| `ed_pulseNumber_<i>` | 第 i 束绑哪条 pulse | — |
| `ed_wavelength_<i>` | 波长 λ（决定临界密度 N_c） | **μm** |
| `ed_lensX/Y/Z_<i>` | lens 椭圆中心坐标 | cm |
| `ed_lensSemiAxisMajor_<i>` | lens 椭圆半长轴 | cm |
| `ed_targetX/Y/Z_<i>` | target 椭圆中心坐标（**光斑中心**） | cm |
| `ed_targetSemiAxisMajor_<i>` | target 半长轴 a | cm |
| `ed_targetSemiAxisMinor_<i>` | target 半短轴 b（a≥b） | cm |
| `ed_semiAxisMajorTorsionAxis_<i>` | target 主轴绕哪个坐标轴扭转 | "x"/"y"/"z" |
| `ed_semiAxisMajorTorsionAngle_<i>` | 扭转角 | 度 |
| `ed_adjustInitialRaySpeed_<i>` | 是否按初始 N_e 调 ray 初速（折射修正） | bool |
| `ed_ignoreBoundaryCondition_<i>` | ray 是否忽略域边界条件 | bool |

### 2.4 Ray 布点（grid）

| 参数 | 含义 |
|---|---|
| `ed_numberOfRays_<i>` | 总 ray 数（采样精度，不改变分布形状） |
| `ed_gridType_<i>` | ray 在 target 面上的几何分布方式（见下表） |
| `ed_gridnRadialTics_<i>` | (radial2D) 径向环数 |
| `ed_gridnAngularTics_<i>` | (radial2D) 角向切片数（≤0 表示自动） |
| `ed_gridnSemiAxisMajorTics_<i>` | (rectangular2D) 主轴方向 tic 数 |
| `ed_gridnSemiAxisMinorTics_<i>` | (rectangular2D) 副轴方向 tic 数 |
| `ed_gridDeltaSemiAxis{Major,Minor}_<i>` | (delta2D) 单点位置 |
| `ed_gridSeed/SeedMaximum/SeedStepping_<i>` | (statistical2D) 随机种子参数 |

**gridType 可选值**（源码：`LaserBeams/ed_setupBeams.F90:345-355`）：

| gridType | 布点方式 | 适用 |
|---|---|---|
| `radial2D` | 同心环 + 角向均匀 | 圆/近圆光斑（最常用） |
| `square2D` | 等间距方形 | 方形光斑 |
| `rectangular2D` | 矩形（两边 tic 数独立） | 矩形光斑 |
| `delta2D` | 所有 ray 从同一点 | 点光源测试 |
| `statistical2D` | 蒙特卡洛随机 | 散斑、相位板 |
| `regular1D` / `statistical1D` | (仅 1D/2D 模拟) 一维布点 | — |

### 2.5 截面权重函数（控制空间分布的核心）

| 参数 | 含义 | 单位 |
|---|---|---|
| `ed_crossSectionFunctionType_<i>` | 截面函数类型字符串 | — |
| `ed_gaussianExponent_<i>` | 指数 α（公式见下） | — |
| `ed_gaussianRadiusMajor_<i>` | 主轴方向 1/e 半径 R_x | cm |
| `ed_gaussianRadiusMinor_<i>` | 副轴方向 1/e 半径 R_y | cm |
| `ed_gaussianCenterMajor_<i>` | 主轴方向中心偏移 C_x（默认 0） | cm |
| `ed_gaussianCenterMinor_<i>` | 副轴方向中心偏移 C_y（默认 0） | cm |

**gaussian2D 实际公式**（源码：`LaserBeams/ed_beamCrossSectionFunctions.F90:255-261`）：

```
w(x, y) = exp( -[ ((x - C_x)/R_x)² + ((y - C_y)/R_y)² ]^α )
```

其中 (x, y) 是 ray 在 target 椭圆**局部坐标系**下的位置（主轴方向为 x，副轴方向为 y，原点在椭圆中心）。

→ `α=1` 标准高斯；`α=4` 是 super-Gaussian（中心平台 + 陡边，ICF 常用）；`α→∞` 趋于 top-hat。

**可选 crossSectionFunctionType**（源码：`LaserBeams/ed_setupBeams.F90:336-343`）：

| 类型 | 公式 | 几何 |
|---|---|---|
| `uniform` | 1 | 全域等权（top-hat） |
| `gaussian1D` | `exp(-[(x-Cx)/Rx]²^α)` | 1D（仅 1D/2D 模拟） |
| `gaussian2D` | `exp(-[((x-Cx)/Rx)²+((y-Cy)/Ry)²]^α)` | 2D 椭圆高斯 |
| `gaussianInverse1D` / `gaussianInverse2D` | 把上面公式的 `-` 变 `+` | 环形（中心暗、边缘亮） |
| `radialweighted` | `sqrt((tx-Cx)²+(ty-Cy)²)` | 径向权重（仅 3D，已自动用） |

---

## 3. parfile 实例（4 个）

下面 4 个例子都按 liang_laser_CH 的设置（2D RZ + 3T + MGD + Laser），只改激光块。把对应块替换到 `cases/laser_CH/flash.par` 的 `##### LASER PARAMETERS #####` 段即可。

### 例 1：圆光斑平顶 super-Gaussian（最常用，ICF 直接驱动样式）

**目标**：100 μm 半径的圆光斑，中心近似平顶、边缘陡降。300 GW、6 ns 梯形脉冲。

```fortran
# ===== 总开关 =====
useEnergyDeposition       = .true.
ed_laser3Din2D            = .true.
ed_laser3Din2DwedgeAngle  = 0.1
ed_gradOrder              = 2

# ===== Pulse 1: 梯形 100ps 上升 + 5.9ns 平顶 + 100ps 下降 =====
ed_numberOfPulses     = 1
ed_numberOfSections_1 = 4
ed_time_1_1 = 0.0       ; ed_power_1_1 = 0.0
ed_time_1_2 = 0.1e-9    ; ed_power_1_2 = 3.0e11
ed_time_1_3 = 6.0e-9    ; ed_power_1_3 = 3.0e11
ed_time_1_4 = 6.1e-9    ; ed_power_1_4 = 0.0

# ===== Beam 1 =====
ed_numberOfBeams = 1
ed_pulseNumber_1              = 1
ed_wavelength_1               = 1.053         # μm，钕玻璃激光

# 几何：lens 在 z=12 cm（域外），target 在原点
ed_lensX_1 = 0.0  ; ed_lensY_1 = 0.0  ; ed_lensZ_1 = 12.0     # cm
ed_lensSemiAxisMajor_1        = 0.5           # cm，lens 口径 1 cm
ed_targetX_1 = 0.0 ; ed_targetY_1 = 0.0 ; ed_targetZ_1 = 0.0   # cm
ed_targetSemiAxisMajor_1      = 0.01          # cm，光斑半径 100 μm
ed_targetSemiAxisMinor_1      = 0.01          # cm，a=b 圆形
ed_semiAxisMajorTorsionAxis_1 = "x"
ed_semiAxisMajorTorsionAngle_1= 0.0

# 空间分布：α=4 super-Gaussian，R = 100 μm 与 target 半径一致
ed_numberOfRays_1             = 4096
ed_gridType_1                 = "radial2D"
ed_gridnRadialTics_1          = 64
ed_crossSectionFunctionType_1 = "gaussian2D"
ed_gaussianExponent_1         = 4.0
ed_gaussianRadiusMajor_1      = 0.01          # cm，1/e 半径 = 100 μm
ed_gaussianRadiusMinor_1      = 0.01
ed_gaussianCenterMajor_1      = 0.0
ed_gaussianCenterMinor_1      = 0.0

# 可视化（推荐打开，画 ray 轨迹）
ed_useLaserIO                  = .true.
ed_laserIOMaxNumberOfPositions = 10000
ed_laserIOMaxNumberOfRays      = 128
```

### 例 2：椭圆光斑高斯分布（非对称打靶）

**目标**：a=150 μm, b=80 μm 椭圆光斑，标准高斯（α=1），中心强度最高。

```fortran
ed_targetSemiAxisMajor_1      = 0.015         # cm，150 μm
ed_targetSemiAxisMinor_1      = 0.008         # cm，80 μm
ed_crossSectionFunctionType_1 = "gaussian2D"
ed_gaussianExponent_1         = 1.0           # 标准高斯
ed_gaussianRadiusMajor_1      = 0.015         # cm，主轴 1/e 半径
ed_gaussianRadiusMinor_1      = 0.008         # cm，副轴 1/e 半径
ed_semiAxisMajorTorsionAxis_1 = "z"           # 椭圆长轴绕 z 转
ed_semiAxisMajorTorsionAngle_1= 45.0          # 旋转 45°
# ... 其余同例 1
```

### 例 3：环形分布（中心暗、亮环）

**目标**：用 `gaussianInverse2D`，中心弱、半径 ~50 μm 处最亮。

```fortran
ed_targetSemiAxisMajor_1      = 0.01          # cm
ed_targetSemiAxisMinor_1      = 0.01
ed_crossSectionFunctionType_1 = "gaussianInverse2D"
ed_gaussianExponent_1         = 2.0
ed_gaussianRadiusMajor_1      = 0.005         # cm，亮峰在 ~50 μm
ed_gaussianRadiusMinor_1      = 0.005
# ... 其余同例 1
```

注意：`gaussianInverse2D` 在边缘会发散，所以 `targetSemiAxis` 必须比 `gaussianRadius` 大，把分布截断在合理范围。

### 例 4：多束对称打靶（6 束，环周向均匀排布）

需要 setup 时加 `ed_maxBeams=6`：

```bash
./setup laser_CH -2d -auto +pm4dev -geometry=cylindrical \
    -nxb=16 -nyb=16 +mtmmmt +laser +mgd +uhd3t \
    species=cham,targ1,targ2,targ3 mgd_meshgroups=6 \
    ed_maxBeams=6 \
    -parfile=example_6beams.par -objdir=cases/6beams
```

parfile（节选，pulse 块同例 1）：

```fortran
ed_numberOfBeams = 6

# 6 束沿 z=12 cm 圆周均匀排布，全部指向原点
# 注意：2D RZ + ed_laser3Din2D 下，多束在 wedge 内对称采样，
# 这里把 6 束的 lens 放在 wedge 角内不同位置。
ed_pulseNumber_1              = 1
ed_wavelength_1               = 1.053
ed_lensX_1 = 0.0  ; ed_lensY_1 = 0.0  ; ed_lensZ_1 = 12.0
ed_targetX_1 = 0.0 ; ed_targetY_1 = 0.0 ; ed_targetZ_1 = 0.0
ed_lensSemiAxisMajor_1        = 0.5
ed_targetSemiAxisMajor_1      = 0.01
ed_targetSemiAxisMinor_1      = 0.01
ed_numberOfRays_1             = 2048
ed_gridType_1                 = "radial2D"
ed_gridnRadialTics_1          = 64
ed_crossSectionFunctionType_1 = "gaussian2D"
ed_gaussianExponent_1         = 4.0
ed_gaussianRadiusMajor_1      = 0.01
ed_gaussianRadiusMinor_1      = 0.01
ed_semiAxisMajorTorsionAxis_1 = "x"
ed_semiAxisMajorTorsionAngle_1= 0.0

# Beam 2-6：复制 beam 1 的所有参数，下标改成 _2, _3, ..., _6
# 想要对称排布，可以让 lensX/Y 在不同方位：
# ed_lensX_2 = 0.3 ; ed_lensY_2 = 0.0  ; ed_lensZ_2 = 12.0
# ed_lensX_3 = 0.15; ed_lensY_3 = 0.26 ; ed_lensZ_3 = 12.0   (60° 方位)
# ed_lensX_4 = -0.15; ed_lensY_4 = 0.26; ed_lensZ_4 = 12.0  (120°)
# ed_lensX_5 = -0.3 ; ed_lensY_5 = 0.0 ; ed_lensZ_5 = 12.0  (180°)
# ed_lensX_6 = ...
ed_pulseNumber_2              = 1
# ... 把 beam 1 的参数全部复制并改下标
```

---

## 4. "我想要 X 分布" 对照表

| 想要的分布 | `crossSectionFunctionType` | 关键参数 |
|---|---|---|
| 圆形平顶（中心平台 + 陡边） | `gaussian2D` | `α=4~8`，`Radius=target 半径` |
| 圆形标准高斯（缓降） | `gaussian2D` | `α=1`，`Radius=你想要的 1/e 半径` |
| 完全均匀 top-hat | `uniform` | 不需要 gaussian 参数 |
| 椭圆高斯 | `gaussian2D` | `RadiusMajor≠RadiusMinor`，`target{Major,Minor}` 同比 |
| 偏心光斑 | `gaussian2D` | `gaussianCenter{Major,Minor} ≠ 0` |
| 环形（中心暗） | `gaussianInverse2D` | `target 半径 > gaussianRadius`，截断发散 |
| 一维条带（slit） | `gaussian1D` | 仅 1D/2D 模拟 |
| 实验近场图（任意） | **自定义**（见第 5 节） | 改源码加新 case |

| 想要的光斑几何 | `gridType` | 备注 |
|---|---|---|
| 圆/近圆 | `radial2D` | 默认首选 |
| 矩形 | `rectangular2D` | 配 `nSemiAxis{Major,Minor}Tics` |
| 方形 | `square2D` | 等间距 |
| 单点测试 | `delta2D` | 所有 ray 同起点 |
| 散斑/相位板 | `statistical2D` | 配 `gridSeed*` |

---

## 5. 自定义截面函数（详细步骤 + 源码 diff）

如果 6 种内置函数都不够（比如你要平顶 + 高斯边沿的"smoothing by spectral dispersion"样、要读入实验测量的近场图、要 Lorentzian、要双高斯叠加），就改源码加新 case。**这是 FLASH 设计上预留的扩展点，不用动 Driver 或 Grid**。

### 5.1 设计你的函数

先把你想实现的分布写成数学形式 `w(x, y; 参数列表)`。约束：

1. **必须非负**（用于 ray 功率分配）。
2. **可微性无所谓**（不需要梯度）。
3. **(x, y) 是 target 椭圆局部坐标**，原点在椭圆中心，x 沿主轴、y 沿副轴，单位 cm。
4. **可调参数能从 parfile 传进来**。内置函数用了 `(Cx, Cy, Rx, Ry, P)` 这 5 个 real。**加更多参数需要改 wrapper 的 signature**——比较麻烦。建议复用：
   - `Cx, Cy` 当中心位置或某个偏移
   - `Rx, Ry` 当特征长度
   - `P` 当无量纲指数/比例因子

举例：实现 **"平顶 + 高斯边沿"**（super-Gaussian 在 α→∞ 时太陡，这里做软边沿）：

```
w(x, y) = 1                                     , if r² < R_core²
        = exp(-((r² - R_core²)/R_fall²)²)       , otherwise

其中 r² = (x/Rx)² + (y/Ry)²
- Rx, Ry 复用 gaussianRadius 主/副轴 → 控制光斑整体大小
- Cx 复用为 R_core（核心平顶半径，cm）
- Cy 复用为 R_fall（边沿衰减尺度，cm）
- P  不用，设 1.0
```

### 5.2 修改源码：3 处改动

#### 改动 1：在 `ed_beamCrossSectionFunctions.F90` 加新函数

**文件**：`source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserBeams/ed_beamCrossSectionFunctions.F90`

**位置 1**：在 wrapper 的 `select case` 里加新分支（第 162 行后，`case default` 之前）：

```fortran
    ! === [新增] 平顶 + 高斯边沿 ===
    case ('flattopGaussian')

      argumentsMissing =     (.not.present (x))        &
                        .or. (.not.present (y))        &
                        .or. (.not.present (Cx))       &   ! Cx 复用为 R_core
                        .or. (.not.present (Cy))       &   ! Cy 复用为 R_fall
                        .or. (.not.present (Rx))       &
                        .or. (.not.present (Ry))

      if (argumentsMissing) then
          call Driver_abortFlash ("ed_beamCrossSectionWeight: Missing Argument(s)!")
      end if

      ed_beamCrossSectionWeight = ed_flattopGaussian2D (x,y,Cx,Cy,Rx,Ry)

    case default

      call Driver_abortFlash ("ed_beamCrossSectionWeight: No proper function specified!")
```

**位置 2**：在 module 的 `contains` 区里加新函数实现（建议加在 `ed_gaussInverse2D` 之后，第 281 行附近）：

```fortran
!-----------------------------------------------------------------------
  real function ed_flattopGaussian2D (x, y, R_core, R_fall, Rx, Ry)
!
!     ...Flat-top core with Gaussian-style soft edge:
!
!        w = 1                                  , if r² < R_core²
!          = exp( - ((r² - R_core²)/R_fall²)² ) , otherwise
!
!        where r² = (x/Rx)² + (y/Ry)²
!
!        Arguments are reused from the wrapper:
!          x, y   : target-plane local coords (cm)
!          Rx, Ry : overall spot semi-axes (cm)  [from gaussianRadius{Major,Minor}]
!          R_core : flat-top radius (cm)         [from gaussianCenterMajor]
!          R_fall : edge fall-off scale (cm)     [from gaussianCenterMinor]
!
    implicit none
    real, intent (in) :: x, y
    real, intent (in) :: R_core, R_fall, Rx, Ry

    real :: r2, r2_core, r2_fall

    r2      = (x/Rx)**2 + (y/Ry)**2
    r2_core = R_core * R_core
    r2_fall = R_fall * R_fall

    if (r2 <= r2_core) then
       ed_flattopGaussian2D = 1.0
    else
       if (r2_fall <= 0.0) then
          ed_flattopGaussian2D = 0.0
       else
          ed_flattopGaussian2D = exp( - ((r2 - r2_core)/r2_fall)**2 )
       end if
    end if
  end function ed_flattopGaussian2D
!-----------------------------------------------------------------------
```

#### 改动 2：在 `ed_setupBeams.F90` 放行新 type

**文件**：`source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserBeams/ed_setupBeams.F90`

**位置**：第 336-343 行的 3D beam 白名单（`beams3D` 分支里）。把新 type 加进去：

```fortran
         if (      (crossSectionFunctionType /= 'uniform'          ) &
             .and. (crossSectionFunctionType /= 'radialweighted'   ) &
             .and. (crossSectionFunctionType /= 'gaussian2D'       ) &
             .and. (crossSectionFunctionType /= 'gaussianInverse2D') &
             .and. (crossSectionFunctionType /= 'flattopGaussian'  ) &   ! === 新增 ===
             ) then
              write (*,*) ' Beam # , cross section function type = ',beam, crossSectionFunctionType
              write (*,*) ' Should be: uniform, radialweighted, gaussian2D, gaussianInverse2D or flattopGaussian '
              call Driver_abortFlash ("ed_setupBeams: invalid 3D beam cross section function type!")
         end if
```

如果用 1D/2D 模拟（`beams2D` 分支），同样的逻辑加到第 285-292 行。

#### 改动 3（可选）：在 `ed_beamsInfo3DRec.F90` 等加日志输出

**文件**：`source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserBeams/ed_beamsInfo3DRec.F90` 及对应的 `ed_beamsInfo2DRec.F90`、`ed_beamsInfo1DRec.F90`。

这些文件在 `ed_printBeams = .true.` 时打印 beam 详情。**新加的 type 不影响运算**，但日志里会显示原始字符串。无需改动；如果想让日志更友好可以加 `case` 输出你的参数复用含义。

### 5.3 注意 gridWeight 自动归一化

`gridWeight` 由 `ed_beam3DGridWeight{Radial,Square,RecBeam,Statistical}` 在 setup 时算好（见 `ed_beam3DGridWeightRadial.F90:158-184`），代码长这样：

```fortran
do n = 1, nGridPoints
   weightCrossSection = ed_beamCrossSectionWeight (crossSectionFunctionType, ...)
   gridWeight = gridWeight + weightRadial * weightCrossSection
end do
```

→ 你新加的 `flattopGaussian` case 会自动被这里调用并求和。**只要 wrapper 的 signature 没变，gridWeight 就自动归一化**，不需要再改 gridWeight 子程序。

### 5.4 重新 setup + make

```bash
cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8

# 用 laser_CH 的 setup 命令重建 objdir
./setup laser_CH -2d -auto +pm4dev -geometry=cylindrical \
    -nxb=16 -nyb=16 +mtmmmt +laser +mgd +uhd3t \
    species=cham,targ1,targ2,targ3 mgd_meshgroups=6 \
    -parfile=example_flattop.par \
    -objdir=cases/flattop

cd cases/flattop
make -j4
```

### 5.5 parfile 里使用新 type

```fortran
ed_crossSectionFunctionType_1 = "flattopGaussian"
ed_gaussianRadiusMajor_1      = 0.01     # Rx = 整体光斑半径 100 μm
ed_gaussianRadiusMinor_1      = 0.01     # Ry
ed_gaussianCenterMajor_1      = 0.005    # R_core = 平顶半径 50 μm
ed_gaussianCenterMinor_1      = 0.002    # R_fall = 边沿衰减尺度 20 μm
ed_gaussianExponent_1         = 1.0      # 不用，写 1.0 占位
```

### 5.6 验证

```bash
# 跑几步
./flash4 -parfile=flash.par

# 看日志（如果开了 ed_printBeams = .true.）
grep -A 30 "Beam" 01-data/lasslab.log | head -60

# 看 plotfile 里的 depo 变量
ls 01-data/lasslab_hdf5_plt_cnt_*
# 用 fidlr / yt 可视化 depo 在 target 面上的分布
```

如果分布形状不对，最常见原因是：
- 参数单位搞错（`Center/Radius` 是 **cm**，不是 μm）
- `(x, y)` 不是 target 局部坐标而是全局坐标（错！永远是椭圆局部）
- 函数在边缘发散导致 gridWeight 溢出（用 `targetSemiAxis` 截断）

---

## 6. 自定义 ray 布点（grid type）

如果改截面函数还不够（比如你想用准随机序列、想读入实验测量的近场强度图直接当 ray 权重），就改 grid。这比改截面复杂得多，因为要同时维护 **grid 点位置** 和 **gridWeight 归一化**。

### 6.1 内置 grid 的代码组织

每种 grid type 对应 3 个文件（在 `LaserBeams/`）：

| 文件模式 | 作用 |
|---|---|
| `ed_beam{2,3}DGridPoints<Type>.F90` | 生成 grid 点的 (x, y) |
| `ed_beam{2,3}DGridSetup<Type>.F90` | 初始化 tic 数、步长 |
| `ed_beam{2,3}DGridWeight<Type>.F90` | 计算 gridWeight |

### 6.2 加新 grid 的步骤（以"准随机 Sobol 序列"为例）

#### 步骤 1：写 3 个新文件

模仿 `ed_beam3DGridPointsRadial.F90` / `ed_beam3DGridSetupRadial.F90` / `ed_beam3DGridWeightRadial.F90` 各写一份 `*Sobol.F90`。

- `ed_beam3DGridSetupSobol.F90`：初始化 Sobol 序列参数
- `ed_beam3DGridPointsSobol.F90`：用 Sobol 序列在 target 椭圆内生成 (x, y)
- `ed_beam3DGridWeightSobol.F90`：累加 cross-section 权重得到 gridWeight

#### 步骤 2：在 `Makefile` 加文件

**文件**：`source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserBeams/Makefile`

把新文件名加到对应的 `.F90` 列表里。

#### 步骤 3：在 `ed_beamsInfo3DRec.F90` 加分支

**文件**：`LaserBeams/ed_beamsInfo3DRec.F90`

在 `if (gridType == 'delta2D') then ... else if (gridType == 'square2D') ...` 链条里加：

```fortran
else if (gridType == 'sobol2D') then
    call ed_beam3DGridSetupSobol  (nRays, nTics1stDim, ...)
    call ed_beam3DGridWeightSobol (targetSemiAxisMajor, ..., gridWeight)
    ! ...
```

#### 步骤 4：在 `ed_setupBeams.F90` 白名单放行

第 345-355 行的 3D `gridType` 白名单加 `'sobol2D'`。

#### 步骤 5：在 `ed_createRays{1DRec,2DRec,3DRec,2DCyl3D}.F90` 加调用

每个 createRays 文件里都有按 gridType 分发 ray 生成的逻辑（如 `ed_createRays3DRec.F90` 的 `select case (gridType)`），加新分支调用你的 `ed_beam3DGridPointsSobol`。

#### 步骤 6：setup + make + 测试

加新 grid 的工作量大约是加新截面函数的 5 倍。**绝大多数需求通过改截面函数就够了**——优先考虑这条路。

---

## 7. 调试与可视化

### 7.1 调试日志

parfile 里打开这三个开关，beam/pulse/main 信息会写到 `01-data/<basenm>.log`：

```fortran
ed_printMain   = .true.
ed_printPulses = .true.
ed_printBeams  = .true.
```

日志会列出每束的：wavelength、frequency、critical density、lens/target 坐标、半轴、ray 数、grid 类型、cross-section 类型、gaussian 参数。

### 7.2 可视化 ray 轨迹

```fortran
ed_useLaserIO                  = .true.
ed_laserIOMaxNumberOfPositions = 10000   # 每根 ray 最多写多少个轨迹点
ed_laserIOMaxNumberOfRays      = 128     # 最多写多少根 ray
ed_laserIORayFrequency         = 1       # 每步都写
```

这些数据随 plotfile 一起输出，可用 yt 或 fidlr 画：

```python
# yt 示例
import yt
ds = yt.load("01-data/lasslab_hdf5_plt_cnt_0100")
# LaserIO 数据在 ds.ray 数据集里
```

### 7.3 验证沉积量

`depo` 变量（per-mass）记录每个 cell 在当前步的激光能量沉积。能量守恒检查：

```
Σ_cells (depo × dens × cell_volume) ≈ P_beam × dt
```

如果不等，可能原因：
- `targetSemiAxis` 太小，部分 ray 落在椭圆外被丢弃
- `gaussianRadius` 远大于 `targetSemiAxis`，能量集中在椭圆外
- ray 数太少（统计涨落）

---

## 8. 常见错误与排查

| 错误信息 | 原因 | 修复 |
|---|---|---|
| `ed_setupBeams: Not enough beam runtime parameters` | beam 数 > `ed_maxBeams` 默认 6 | setup 时加 `ed_maxBeams=N` |
| `ed_setupPulses: Wrong time order for pulse sections!` | `ed_time_*_*` 没严格递增 | 检查时间序列 |
| `ed_setupPulses: Negative pulse power specified!` | `ed_power_*_*` < 0 | pulse 功率不能负 |
| `ed_setupBeams: No beam defined!` | `ed_numberOfBeams` 未设或 < 1 | 在 parfile 显式设置 |
| `ed_setupBeams: invalid 3D beam cross section function type!` | 拼错 type 名 | 对照 5.1 节 |
| `ed_setupBeams: invalid 3D beam grid type!` | 拼错 grid type | 对照 2.4 节 |
| `ed_setupBeams: target semiaxes lengths out of order (major < minor)!` | `Major < Minor` | 交换二者 |
| `ed_createRays*: Too many rays! No storage` | ray 数超 `ed_maxRayCount` | 减小 `numberOfRays` 或 setup 时调 `ed_maxRayCount` |
| 沉积量为 0 | pulse 时间没覆盖当前 simTime，或 lens/target 落域外 | 检查时间区间和坐标 |
| 沉积图有明显噪点 | ray 数太少 | 增大 `ed_numberOfRays`（建议 ≥ 2048） |
| 自定义函数算出 NaN | 函数在边缘发散或除零 | 用 `targetSemiAxis` 截断；除法加保护 |

---

## 附录：源码导航

| 文件 | 作用 |
|---|---|
| `Laser/Config` | 注册所有 PARAMETER，genLines 生成 ed_maxBeams/Pulses |
| `Laser/EnergyDeposition_init.F90` | 初始化入口，调用 setupPulses/setupBeams/setupRays |
| `Laser/LaserPulses/ed_setupPulses.F90` | 读 pulse 时间/功率表 |
| `Laser/LaserBeams/ed_setupBeams.F90` | 读 beam 参数 + 白名单验证 |
| `Laser/LaserBeams/ed_computeBeamPower.F90` | 由 P(t) 计算当前步平均功率 |
| `Laser/LaserBeams/ed_beamCrossSectionFunctions.F90` | **截面函数定义（自定义改这里）** |
| `Laser/LaserBeams/ed_beam3DGridWeightRadial.F90` | gridWeight 归一化（radial2D） |
| `Laser/LaserBeams/ed_beamsInfo3DRec.F90` | 按 gridType 分发 setup/weight 调用 |
| `Laser/LaserRaysCreate/ed_createRays3DRec.F90` | 按 gridType 生成 ray 位置 + 算每根 ray 功率 |
| `Laser/LaserRaysCreate/ed_createRays2DCyl3D.F90` | 同上（2D RZ + 3D ray 模式） |
| `Laser/LaserRayTrace/CellAverage/ed_traceBlockRays*.F90` | ray 追踪 + 逆韧致吸收 |
| `Laser/LaserUtilities/ed_inverseBremsstrahlungRate.F90` | 逆韧致率公式 |
| `Laser/LaserUtilities/ed_updatePlasma.F90` | 把 depo 加到 EELE_VAR，调 Eos_wrapped |

---

**反馈**：如果按本手册操作遇到问题，把以下信息收集起来再排查：
1. setup 命令行（`cases/<name>/setup_call`）
2. parfile 的 laser 段
3. 日志 `01-data/*.log` 的开头 100 行（含 ed_printMain/Pulses/Beams 输出）
4. abort 信息的完整 traceback
