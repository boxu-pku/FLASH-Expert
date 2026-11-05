---
title: X 射线诊断模块（XrayImaging）配置陷阱
category: 运行期 abort
severity: fatal（abort）
first_seen: 2026-08-02
last_verified: 2026-08-03
verifier: claude
status: stable
tags:
  - xray
  - diagnostics
  - xrayimaging
  - setup
---

# X 射线诊断模块（XrayImaging）配置陷阱

## 6 个连环 abort（按出现顺序）

### 1. `No X-ray detector defined`

**原因**：`xray_numberOfDetectors = -1`（默认），没设。

**修复**：
```fortran
xray_numberOfDetectors = 1
```

### 2. `2D cylindrical domain without 3D in 2D not allowed`

**原因**：2D 圆柱坐标下 X 射线追踪需要 3D 模式。

**修复**：
```fortran
xray_3Din2D = .true.
```

### 3. `The energy level count must be > 0`

**原因**：需要设能级数量参数 `xray_detectorEnergyLevelCount_<N>`。

**修复**：
```fortran
xray_detectorEnergyLevelCount_1 = 1
```

### 4. `The X-ray energy must be >= 10 eV`

**原因**：能级值的参数名不是 `xray_detectorEnergyXrays_<N>`，而是 `xray_detectorEnergy_<det>_Level_<level>`。

**修复**：
```fortran
# ❌ 错误（参数名不对）
xray_detectorEnergyXrays_1 = 6000.0

# ✅ 正确
xray_detectorEnergy_1_Level_1 = 6000.0      # 6 keV
xray_detectorEnergy_1_Fraction_1 = 1.0       # 100%
```

### 5. `The number of atoms per species must be > 0`

**原因**：X 射线诊断需要 species 的**元素组成**（不只是总 A/Z），即 `ms_<spec>NumElems` + `AElems/ZElems/Fractions`。

**修复**（每个 species 都要加）：
```fortran
# CH 塑料（C + H）
ms_tar1NumElems = 2
ms_tar1ZElems_1 = 6
ms_tar1AElems_1 = 12
ms_tar1Fractions_1 = 0.857
ms_tar1ZElems_2 = 1
ms_tar1AElems_2 = 1
ms_tar1Fractions_2 = 0.143
```

### 6. `Detector screen (partially) inside the domain`

**原因**：探测器必须放在**计算域外**。

**修复**：
```fortran
# 域范围：Y: 0 ~ 0.107 cm
xray_detectorCenterY_1 = 0.12     # > ymax=0.107，放在域外
```

## 完整 X 射线诊断 parfile 模板

```fortran
# 主控
useXrayImaging = .true.
xray_3Din2D    = .true.
xray_maxXrayCount = 100000

# 探测器
xray_numberOfDetectors = 1
xray_detectorAlignWRTorigin_1  = .false.
xray_detectorCenterX_1         = 0.0125       # R/2（域中心）
xray_detectorCenterY_1         = 0.12          # 域外（> ymax）
xray_detectorCenterZ_1         = 0.0
xray_detectorNormalX_1         = 0.0
xray_detectorNormalY_1         = -1.0          # 从上往下看
xray_detectorNormalZ_1         = 0.0
xray_detectorOriginX_1         = 0.0           # X 射线源在靶中心
xray_detectorOriginY_1         = 0.0
xray_detectorOriginZ_1         = 0.0
xray_detectorPerpXrays_1       = .true.
xray_detectorResolution_1      = 500
xray_detectorSideLength_1      = 0.05
xray_detectorSideTiltingAngle_1 = 0.0
xray_detectorSideTiltingAxis_1  = "z"
xray_detectorTime2record_1     = 0.0
xray_detectorFileNameTimeStamp = .false.

# 能级
xray_detectorEnergyLevelCount_1 = 1
xray_detectorEnergy_1_Level_1   = 6000.0       # 6 keV
xray_detectorEnergy_1_Fraction_1 = 1.0

# 调试
xray_printDetectors = .true.
xray_printMain      = .true.
```

## setup 命令

```bash
./setup <problem> ... +xrayImaging ...
```

`+xrayImaging` 展开为 `--unit=diagnostics/XrayImaging --without-unit=Particles`。

## 输出文件

| 文件 | 内容 |
|---|---|
| `<basenm>_XrayDetectorFile01` | 3 列 ASCII：(x, y, transmission)，每行一根 X 射线 |
| `<basenm>_XrayImagingDetectors.txt` | 探测器配置信息 |
| `<basenm>_XrayImagingMainPrint.txt` | 运行参数打印 |
| `<basenm>_XrayImagingMonitor.dat` | X 射线统计 |

## 可视化

```bash
python .claude/skills/flash-result-analyzer/examples/flash_plot_all.py \
    <case>/01-data/<basenm>_XrayDetectorFile01 --xray
```

## 附：探测器几何选择——face-on 看不到轴向运动（2026-08-11 实证）

**现象**：Sunliang_Xray 重放 7 个时刻（1/3/6.1/10/14/17/20 ns）的 6 keV 背光图像，
帧间几乎无变化（max|diff|=0.013，仅 4.4% 像素有差异且集中在靶边缘）。

**机制**（两条叠加）：
1. **face-on 几何**（探测器法向沿柱轴 y）：轴向（y）的壳层运动沿视线方向，
   每个像素的面密度柱积分 ∫ρ dy 由质量守恒保持 → 图像不变。
   要看壳层运动必须 **side-on**（法向 ⊥ 柱轴，图像平面含 y 轴）。
2. **Biggs-Lighthill 冷不透明度**：XrayImaging 的不透明度模型不响应温度/电离度，
   加热不会使图像变亮——只对面密度敏感。

**实践**：配置动态照相前先想清楚"看什么"——面密度均匀性用 face-on，
壳层/激波位置用 side-on（探测器 normal 垂直柱轴，侧长要覆盖 y 全 domain）。

## 附 2（2026-08-11 补充）：3Din2D 坐标约定 + side-on 演化态崩溃

- **3Din2D 重构空间坐标**：柱轴 = Z，径向平面 = (X,Y)（证据：
  `xray_detectorsCheck2DCyl3D.F90` 用 X²+Y² vs R²、Z vs 轴向边界做域校验）。
  之前以为柱轴是 Y——**那是错的**，导致 first side-on 尝试把探测器放错位置。
- **side-on 已验证可用配置**（冷靶/早期）：normal=(-1,0,0)，center=(0.1, 0, 0.0535)，
  SideTiltingAxis="y"，SideLength=0.07。屏幕任何像素不得进入域圆柱
  （X²+Y²≤R² 且 Z 在轴向范围内）否则 abort "screen (partially) inside the domain"。
- ⚠️ **side-on 在演化态（≥6 ns）必崩**：`Grid_sortParticles` double free
  （xray_updateXrays.F90:126），1/3 ns 正常、6.1/17 ns 确定性复现，
  分辨率/线程数 workaround 均无效。根因未修；演化态请用合成辐射照相
  （plotfile 弦积分 + 冷不透明度定标，见 `xray-sideon-crash-sortparticles.md`）。
