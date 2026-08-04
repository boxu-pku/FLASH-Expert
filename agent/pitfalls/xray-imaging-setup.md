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
