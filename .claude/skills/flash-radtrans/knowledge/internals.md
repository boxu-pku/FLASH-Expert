---
title: RadTrans 内部实现 — RadTrans.F90 主流程 + Diffuse_solveScalar + 能群循环
skill: flash-radtrans
category: internals
source_anchors:
  - source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90:L31-L555
  - source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90:L250-L546
  - source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90:L415
  - source/physics/RadTrans/RadTransMain/MGD/rt_init.F90:L15-L314
  - source/physics/RadTrans/RadTransMain/MGD/RadTrans_computeFluxLimiter.F90:L40
manual_ref: "FLASH 4.8 User Guide §25"
created: 2026-07-19
last_verified: 2026-07-19
verifier: claude
status: draft
tags:
  - radtrans
  - internals
  - mgd
  - call-graph
  - hypre
---

# RadTrans 内部实现（MGD 聚焦）

> **TL;DR**：MGD 公共 API ~15 个函数。核心是 `RadTrans(nblk, blklst, dt, pass)`——每 hydro 步调一次，循环每群调 `Diffuse_solveScalar`（HYPRE 求解）。本文件讲：① 15 公共 API；② RadTrans.F90 主流程；③ Diffuse_solveScalar 调用细节；④ 能群循环；⑤ HYPRE 矩阵结构；⑥ retry 机制。

### 术语速查（按 L-014，先解释再讲机制）

- **HYPRE**：美国 LLNL 开发的解大稀疏线性方程组 `Ax = b` 的数学库。专门处理百万级未知数 + 稀疏矩阵（每行只有 ~7 个非零）。提供 BoomerAMG / PFMG / BiCGSTAB 等求解器，支持分布式 MPI 并行。**为什么需要**：MGD 把辐射扩散方程离散后变成百万级线性系统，普通高斯消元需要 O(N³) = 10¹⁸ 次运算不可行，HYPRE 用迭代法 + 多重网格几秒解完。
- **Diffuse_solveScalar**：FLASH 的标量扩散方程求解接口（在 `physics/Diffuse/` 单元）。MGD 不直接调 HYPRE，而是通过这个接口——抽象层让 MGD 不必管 HYPRE API 细节。
- **operator-split**：把复杂多物理过程拆成"一次解一个"的策略。MGD 默认 operator-split = 每群独立 HYPRE 求解（6 群就调 6 次 HYPRE）。相对的是 Unified（所有群耦合一个矩阵）。
- **flux limiter**：限制辐射通量不超过物理上限 `c·E`（自由流极限）的数学函数。光学薄区纯扩散会超光速，flux limiter 把有效扩散系数降低。
- **θ-加权（theta-weighted）**：时间离散的隐式度参数。θ=1 全隐式（后向 Euler，无条件稳定）；θ=0.5 Crank-Nicolson（2 阶精度但可能震荡）；θ=0 全显式（不稳定）。MGD 默认 θ=1。

---

## 1. 公共 API 总览

源码：`source/physics/RadTrans/RadTrans_interface.F90`（171 行）

### 1.1 API 分类

| 类别 | 函数 | 数量 |
|---|---|---|
| **生命周期** | `RadTrans`（主入口）、`RadTrans_init`、`RadTrans_finalize` | 3 |
| **辅助** | `RadTrans_computeDt`、`RadTrans_computeFluxLimiter`、`RadTrans_planckInt` | 3 |
| **MGD 边界/群操作** | `RadTrans_mgdGetBound`、`RadTrans_mgdSetBound`、`RadTrans_mgdSetEnergy`、`RadTrans_mgdSetBc`、`RadTrans_mgdEFromT`、`RadTrans_mgdUFromT` | 6 |
| **诊断** | `RadTrans_sumEnergy`、`RadTrans_getDbgContext`、`RadTrans_getDbgContextPtr` | 3 |

### 1.2 关键 API 详解

#### `RadTrans`（主入口）

源码：`source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90:L31`

```fortran
subroutine RadTrans(nblk, blklst, dt, pass)
```

Driver_sourceTerms 每 hydro 步调一次。`pass` 用于多 pass 算法（如 split Hydro）。

#### `RadTrans_init`

源码：`source/physics/RadTrans/RadTransMain/MGD/rt_init.F90:L15`（314 行）

读所有 `rt_mgd*` 参数 + 建群边界 + 配置 BC + 设 up `rt_*` 模块变量。

#### `RadTrans_computeDt`

源码：`source/physics/RadTrans/RadTransMain/MGD/RadTrans_computeDt.F90:L33`

Morel-McClarren (2010) 辐射 dt：

```
dt_loc = 2 · cv · ρ / (κ · c · (dB/dT - cv · ρ))
```

只在 `rt_computeDt = .true.` 时用。LaserSlab 不开（隐式不需要）。

### 1.3 不存在的 API（避免混淆）

**`RadTrans_mgdStaggeredSource` 和 `RadTrans_mgdEvolveModel` 在本树不存在**（其他文档可能误列）。实际 MGD 演化全在 `RadTrans(nblk, blklst, dt, pass)` 里。

---

## 2. RadTrans.F90 主流程（MGD operator-split）

源码：`source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90`（555 行）

### 2.1 10 步流程（文字 + 缩进）

```
RadTrans(nblk, blklst, dt, pass)
│
├── Step 1: 前置检查（行 50-80）
│   ├── if (.not. rt_useMGD) return
│   ├── if (dt <= 0) return
│   └── 检查 pass 是否合法
│
├── Step 2: 填 guard cell + EOS 调和（行 220-222）
│   ├── Grid_fillGuardCells(CENTER, ALLDIR)
│   └── Eos_guardCells(MODE_DENS_EI_ELE, ...)
│       └── 让 TELE_VAR 在 guard cell 自洽（MGD 查 Opacity 用 TELE）
│
├── Step 3: 重缩放每群 MGDRi（行 117-187）
│   └── for g = 1 to N:
│       └── MGDRg_VAR *= ERAD_VAR / Σ MGDRi_VAR
│           └── 保证 Σ MGDRi = ERAD（Hydro 步可能改变了 ERAD）
│
├── Step 4: 初始化 MGDC_VAR = 0（行 240-245）
│   └── MGDC_VAR 是"所有群辐射能量变化累加器"
│
├── Step 5: 主循环——逐群求解（行 250-510）
│   for gloc = 1 to rt_mgdNumGroups:
│   │
│   ├── Step 5a: 取当前群的 UNK 索引（行 255-260）
│   │   └── gvar = MGDR_NONREP_LOC2UNK(gloc) → MGDRg_VAR
│   │
│   ├── Step 5b: 计算每 cell 的 Opacity（行 290-310）
│   │   └── call Opacity(solnData(:,i,j,k), g, absorb_opac, emit_opac, trans_opac)
│   │       ├── ABSR_VAR(i,j,k) = c · absorb_opac
│   │       ├── EMIS_VAR(i,j,k) = emit_opac · c · a · TELE⁴ · ΔP_g
│   │       └── COND_VAR(i,j,k) = c³ / max(trans_opac, ε·c³)
│   │
│   ├── Step 5c: 应用 flux limiter（行 340-356）
│   │   └── call Diffuse_computeFluxLimiter(COND_VAR, gvar, FLLM_VAR,
│   │                                            rt_mgdFlMode, rt_mgdFlCoef, ...)
│   │       └── FLLM_VAR 存每 cell 的 λ(R) 值
│   │
│   ├── Step 5d: 设边界条件（行 380-400）
│   │   └── 6 个面的 bcTypes/bcValues 从 rt_mgdXlBoundaryType 等读
│   │
│   ├── Step 5e: HYPRE 求解（行 415）★ 核心
│   │   └── call Diffuse_solveScalar(gvar, COND_VAR, DFCF_VAR,
│   │                                bcTypes, bcValues, dt,
│   │                                1.0, 1.0, mgdTheta,
│   │                                pass, nblk, blklst,
│   │                                ABSR_VAR, EMIS_VAR)
│   │       └── Diffuse 内部建 HYPRE 矩阵 + 解 + 返回更新后的 MGDRg_VAR
│   │
│   ├── Step 5f: 累加 MGDC_VAR（行 480-490）
│   │   └── MGDC_VAR += (MGDRg_VAR_new - MGDRg_VAR_old) / dt
│   │
│   └── Step 5g: 错误 retry（行 402-471，当前 MAXRETRY=0 禁用）
│       └── 如果 HYPRE 失败：COND_VAR *= 0.1，重试
│
├── Step 6: 更新电子内能（行 528-540）
│   └── EELE_VAR += MGDC_VAR · dt / ρ
│       └── 辐射能量变化反馈到电子（能量守恒）
│
├── Step 7: 更新 ERAD_VAR（行 542-544）
│   └── ERAD_VAR = Σ MGDRi_VAR
│       └── 总辐射能量 = 各群之和（保持一致性）
│
├── Step 8: EOS 调和（行 546）
│   └── call Eos_wrapped(MODE_DENS_EI_GATHER, blkLimits, blockID, CENTER)
│       └── 从更新后的 EELE_VAR 重算 TELE_VAR, PELE_VAR
│
└── Step 9: 返回
```

### 2.2 为什么是这个流程

| 步骤 | 为什么必须在这位置 |
|---|---|
| Step 2 (fillGuardCells + EOS) | 后续 Opacity 查询需要 guard cell 的 TELE |
| Step 3 (重缩放 MGDRi) | Hydro 步改变了 ERAD，要保证 Σ MGDRi = ERAD |
| Step 4 (MGDC=0) | 累加器清零，准备 Step 5f 累加 |
| Step 5 主循环（per-group） | 每群独立 HYPRE 求解 |
| Step 5b-c (Opacity + flux limiter) | 必须在 5e 求解前算好 COND/ABSR/EMIS |
| Step 5e (Diffuse_solveScalar) | 核心求解，HYPRE 解矩阵 |
| Step 6 (更新 EELE) | 用所有群累加的 MGDC 反馈到电子 |
| Step 8 (EOS) | 让温度从更新后的能量重算（自洽） |

---

## 3. Diffuse_solveScalar 调用细节（HYPRE 接口）

源码：`source/physics/RadTrans/RadTransMain/MGD/RadTrans.F90:L415-L419`

### 3.1 调用签名

```fortran
call Diffuse_solveScalar( &
    iVar       = gvar,           ! 求解的 UNK 索引（MGDRg_VAR）
    iFactorB   = COND_VAR,       ! 扩散系数 = c³/max(κ_t, ε·c³) · λ(R)
    iFactorA   = DFCF_VAR,       ! 前导系数 = 1（辐射）
    bcTypes,                      ! 6 面 BC 类型
    bcValues,                     ! 6 面 BC 值（Dirichlet 温度）
    dt,                           ! 时间步
    scaleFactor  = 1.0,           ! 系数倍数
    scaleFactor3 = 1.0,
    theta        = mgdTheta,     ! 隐式度（默认 1.0）
    pass,                         ! pass 标志
    blockCount, blockList,        ! block 列表
    iSourceB    = ABSR_VAR,       ! 吸收源项 = c · κ_a
    iSourceA    = EMIS_VAR)       ! 发射源项 = κ_e · c · a · T⁴ · ΔP
```

### 3.2 Diffuse_solveScalar 解什么

源码：`source/physics/Diffuse/DiffuseMain/Unsplit/Diffuse_solveScalar.F90:L87`

解标量扩散方程：

```
∂E_g/∂t - ∇·(D · ∇E_g) + Σ_a · E_g = Σ_e
```

离散后是 7 点（3D）/ 5 点（2D）/ 3 点（1D）模板的线性系统：

```
A · E_g^{n+1} = b
```

HYPRE 用 BoomerAMG / PFMG / BiCGSTAB 解。

### 3.3 HYPRE 矩阵结构（per-group）

- **未知数**：每 cell 一个 `MGDRg_VAR^{n+1}` 值
- **大小**：`Ncells × Ncells`（Ncells = 所有 leaf cell 数）
- **稀疏**：每行 ~7 个非零（3D 7 点模板）
- **对称性**：理论上对称（常数系数时），但 flux limiter 让系数 cell-face 依赖 → 一般非对称
- **AMR 处理**：HYPRE 通过 FLASH Grid 拿到 block-structured AMR composite grid，自动处理细-粗边界

### 3.4 Unified 变体矩阵（参考，不推荐）

源码：`source/physics/RadTrans/RadTransMain/MGD/Unified/RadTrans.F90`

矩阵大小 `(Ngroups + 1) · Ncells`——电子能量 + 所有群辐射能量耦合。

每 cell 含 `(Ngroups+1) × (Ngroups+1)` dense block（群间通过共享电子温度耦合），cell 间有扩散模板。

---

## 4. 能群循环机制（NONREP / meshCopyCount）

源码：`RadTrans.F90:L250`

### 4.1 NONREP MASS_SCALAR

MGD 的群辐射能量 `MGDRg_VAR` 是 **NONREP**（非复制）MASS_SCALAR：

```
MGDR1_VAR, MGDR2_VAR, ..., MGDRn_VAR
```

由 `mgd_meshgroups` 在 setup 期决定编译期有多少槽。

### 4.2 meshCopyCount > 1（群-网格复制）

源码：`RadTrans.F90:L250`

```fortran
do gloc = 1, NONREP_NLOCS(MGDR_VAR, blockID)
    gvar = MGDR_NONREP_LOC2UNK(gloc, blockID)
    ...
end do
```

如果 `meshCopyCount > 1`，不同 mesh copy 持有不同群，允许群并行求解（HYPRE 调用并行）。

**LaserSlab 默认 meshCopyCount=1**——所有群在同一 mesh，串行求解。

### 4.3 限制

源码：`rt_init.F90:L86`

```
rt_mgdNumGroups ≤ MGDR_NONREP_MAXLOCS · meshCopyCount
```

否则 rt_init abort。

---

## 5. rt_init.F90 详解（启动时）

源码：`source/physics/RadTrans/RadTransMain/MGD/rt_init.F90:L15-L314`

### 5.1 rt_init 做什么（10 步）

```
rt_init
│
├── Step 1: 读 rt_useMGD（行 50-55）
│   └── if (useRadTrans) rt_useMGD = .true.
│
├── Step 2: 读 rt_mgdFlMode + 字符串映射（行 43-45）
│   └── RuntimeParameters_mapStrToInt(rt_mgdFlMode) → 整数常量
│
├── Step 3: 读 rt_mgdNumGroups（行 80-90）
│   └── if (rt_mgdNumGroups > MGDR_NONREP_MAXLOCS · meshCopyCount)
│       call Driver_abortFlash("rt_mgdNumGroups too large")
│
├── Step 4: 读 rt_mgdBoundEntry（行 95-100）
│   └── if (rt_mgdBoundEntry != "grbd_manual") abort（只实现了 grbd_manual）
│
├── Step 5: 读 rt_mgdBounds_*（行 105-130）
│   for i = 1 to rt_mgdNumGroups+1:
│   ├── call RuntimeParameters_get("rt_mgdBounds_"//i, group_bound)
│   ├── if (group_bound < 0) call Driver_abortFlash("group boundary not specified")
│   ├── group_bound_erg = group_bound * EV_TO_ERGS   ★ eV → erg
│   └── call RadTrans_mgdSetBound(i, group_bound_erg)
│
├── Step 6: 读 rt_mgdthetaImplct（行 140）
├── Step 7: 读 rt_dtFactor（行 145）
├── Step 8: 读 rt_mgdFlCoef（行 150）
├── Step 9: 读 6 个 BC 类型 + Dirichlet 温度（行 155-200）
└── Step 10: 验证 + 打印初始化信息（行 250-314）
```

### 5.2 关键检查（容易踩坑）

- `rt_mgdNumGroups` 必须 ≤ `mgd_meshgroups`（setup 期变量）
- 所有 `rt_mgdBounds_*` 必须 ≥ 0（负值 abort）
- `rt_mgdFlMode` 必须是允许值之一（不允许值 abort）

---

## 6. retry 机制（当前禁用）

源码：`MGD/RadTrans.F90:L402-L471`

```fortran
integer, parameter :: MAXRETRY = 0   ! 当前禁用
...
do attempt = 0, MAXRETRY
    call Diffuse_solveScalar(...)
    if (ierr == 0) exit
    ! retry: COND_VAR *= 0.1
    COND_VAR = COND_VAR * 0.1
end do
```

**当前 MAXRETRY=0**——HYPRE 失败直接 abort。

未来可能开启：HYPRE 不收敛时降低扩散系数重试。

---

## 7. 完整调用关系（文字 + 缩进）

```
Driver_evolveFlash
│
├── (初始化) Driver_initFlash
│   └── RadTrans_init ★
│       └── rt_init
│           ├── 读所有 rt_mgd* 参数
│           ├── 验证（群数、边界、FlMode）
│           ├── eV → erg 转换群边界
│           └── 配置 BC
│
├── (主循环每步)
│   ├── Grid_fillGuardCells
│   ├── Hydro
│   ├── Eos_wrapped
│   ├── Driver_sourceTerms:
│   │   ├── EnergyDeposition（激光，flash-laser）
│   │   ├── Heatexchange（电子-离子平衡）
│   │   └── RadTrans(nblk, blklst, dt, pass) ★
│   │       ├── fillGuardCells + Eos_guardCells(MODE_DENS_EI_ELE)
│   │       ├── 重缩放 MGDRi 保证 Σ MGDRi = ERAD
│   │       ├── MGDC_VAR = 0
│   │       ├── for g = 1 to N:
│   │       │   ├── Opacity(blkPtr, g, ...) → ABSR/EMIS/COND_VAR
│   │       │   ├── Diffuse_computeFluxLimiter → FLLM_VAR
│   │       │   ├── Diffuse_solveScalar(gvar, COND, DFCF, bcTypes,
│   │       │   │                          dt, ..., theta=1.0,
│   │       │   │                          ABSR, EMIS) ★ HYPRE 求解
│   │       │   │   └── HYPRE 解 7 点扩散方程 → 更新 MGDRg_VAR
│   │       │   └── MGDC_VAR += (MGDRg_new - MGDRg_old) / dt
│   │       ├── EELE_VAR += MGDC_VAR · dt / ρ
│   │       ├── ERAD_VAR = Σ MGDRi_VAR
│   │       └── Eos_wrapped(MODE_DENS_EI_GATHER)
│   │
│   └── Grid_updateRefinement
│
└── (收尾) Driver_finalizeFlash
    └── RadTrans_finalize（空 stub）
```

---

## 8. 延伸阅读

- **MGD 总览 / 数学模型**：`knowledge/overview.md`
- **参数字典**：`knowledge/params.md`
- **典型配置**：`knowledge/recipes.md`
- **常见错误**：`knowledge/pitfalls.md`
- **Diffuse 单元（HYPRE 内部）**：`flash-diffuse`（Phase 2 后）
- **EOS（TELE/EELE 耦合）**：`flash-eos` skill
- **手册**：FLASH 4.8 User Guide §25（opencode 已转）

---

## 9. 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-19 | 初始创建（draft）：9 段 internals；15 公共 API 分类；RadTrans.F90 10 步流程含行号；Diffuse_solveScalar 调用细节；HYPRE 矩阵结构；能群循环（NONREP/meshCopyCount）；rt_init 详解；retry 机制；完整文字调用图（按 L-002 不用 mermaid） | claude |
