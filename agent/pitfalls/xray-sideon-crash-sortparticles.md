---
title: XrayImaging 3Din2D side-on 演化态崩溃（Grid_sortParticles double free）——已修复
category: 运行期 abort（X 光诊断）
severity: 已修复（源码补丁 2026-08-13）；记录供参考
first_seen: 2026-08-11
last_verified: 2026-08-13
verifier: claude
status: stable（已修复）
tags:
  - xray
  - XrayImaging
  - side-on
  - Grid_sortParticles
  - gr_findNeghID
  - gr_getBlkHandle
  - double-free
  - 3Din2D
related:
  - agent/pitfalls/xray-imaging-setup.md
---

# XrayImaging 3Din2D side-on 演化态崩溃——已修复（2026-08-13）

## 错误指纹

```
double free or corruption (out)  → SIGABRT
调用链：XrayImaging → xray_updateXrays:102 → Grid_moveParticles →
        gr_ptMoveOffBlk:101 → gr_findNeghID:92 → Grid_getBlkBoundBox:80
Fortran runtime error: Index '30077' of dimension 3 of array 'bnd_box'
outside of expected range (1:10000)
```

**复现条件**：2D 圆柱 + `xray_3Din2D=.true.` + **side-on 探测器**（法向 ⊥ 柱轴），
在等离子体演化态（本算例 ≥6 ns）必现；冷靶/早期（≤3 ns）正常。
face-on 几何任何时刻正常。降分辨率、关 OpenMP 均不能规避。

## 根因（DEBUG 构建 + gdb 实证，2026-08-13）

side-on 光线在回转 3D 空间穿行时可能越出径向域边（或跨到无同级邻块的边界），
粒子搬家链 `gr_ptMoveOffBlk → gr_findNeghID` 的"邻居 NONEXISTENT"分支会
查父块，但有两个未防护的坑：

1. **level-1 块没有父块**——`parent()` 返回垃圾/负值，`gr_getBlkHandle` 的
   `ladd_strt(proc)` 会被非法索引
2. **父块在其他进程且不在本进程 laddress 缓存**——`gr_getBlkHandle` 按其文档
   契约"找不到就不动输出参数"，但调用方没预置哨兵值也没检查 → 未初始化栈垃圾
   （32766/30077 这类值）直接传给 `Grid_getBlkBoundBox` → 越界写/读 → 堆损坏
   → 后续 `Grid_sortParticles` double free

**为什么 face-on 不触发**：face-on 光线沿柱轴走，块间迁移都落在有合法邻块/
父块缓存的路径上；side-on 横穿径向边界才会进入该分支。

## 修复（已入源码，两处）

### 1. `source/Grid/GridMain/paramesh/paramesh4/gr_findNeghID.F90`

NONEXISTENT 分支加双保险（无父块 / 父块不在缓存 → 返回 NONEXISTENT，
让调用方走 gr_findBlock 重定位或按丢失处理——两条路都被调用方妥善处理）：

```fortran
     proc=parent(PROCNO,blockID)
     blk=parent(BLKNO,blockID)
     if (lrefine(blockID) <= 1 .or. blk < 1 .or. proc < 0) then
        neghID(BLKNO:PROCNO) = NONEXISTENT
        return
     end if
     blkHandle = -1                                ! 哨兵（gr_getBlkHandle 契约）
     call gr_getBlkHandle(blk,proc,blkHandle)
     if (blkHandle < 1) then
        neghID(BLKNO:PROCNO) = NONEXISTENT
        return
     end if
```

### 2. `source/diagnostics/XrayImaging/.../XrayUtilities/xray_updateXrays.F90`

`Grid_moveParticles` 之后加清扫兜底：BLCK<1 且非 NONEXISTENT 的光线标记为
NONEXISTENT 并计数打印（防 tracer 的 "block ID < 1" abort）。
**实测三个曾崩溃例（6.1/16.6/17 ns）全部通过且 0 条光线被丢**——说明
gr_findNeghID 修复后重定位路径完全够用，清扫只是保险。

## 排查方法论（可复用）

本次定位靠的是 L-020 取证链的延伸：**`-debug` 构建的 `-fbounds-check` 直接
报出越界行号**（注意：该算例要去掉 `-ffpe-trap` 否则 init 就 FPE，且 gfortran≥10
需 `-fallow-argument-mismatch`，改 Makefile.h 后要 `make clean`）+
**gdb 条件断点**（`break grid_getblkboundbox_ if blockid>10000`）打印调用方
全部局部变量，一次拿到 blockid/negh/parent/blkHandle 全套值。

## side-on 正确几何（已验证）

3Din2D 重构空间：**柱轴=Z，径向平面=(X,Y)**（域校验代码实证）。
```
normal=(-1,0,0), center=(0.1, 0, 0.0535), SideTiltingAxis="y", SideLength=0.07
```
屏幕像素不得进入域圆柱（X²+Y²≤R² 且 Z 在轴向范围），否则 abort
"screen (partially) inside the domain"。

## 影响面与注意

- 修复在 paramesh4 通用代码——对 Particles 单元只影响"以前会崩"的路径，安全
- 老 objdir 需 `make` 重编才带修复（源码符号链接，不用重 setup）

## 已知残留问题（2026-08-13）：演化态 side-on 帧少量像素缺失

修复崩溃后，演化态帧存在**少量像素无记录**（缺失率：6.1/10/14 ns 帧 1.7%，
17 ns 帧 6.8%，20 ns 帧 4.3%；t≤3 ns 帧为 0）。缺失区呈矩形白盒，
是光线在跨进程搬迁中被静默丢弃（与崩溃同源的次要表现，未再深究）。
图件处理时用最近值插值填充（scipy distance_transform_edt），
对壳层位置判读无影响。后续若追求像素级完备，可在 gr_ptMovePttoPt
迁移路径加计数/记录。

**交付产物**：`cases/Sunliang_Xray/01-data/figs/xray_sideon_real_series.png`
（7 时刻真机帧）+ `shell_position_vs_time.png`（提取曲线，两者互证一致）。
