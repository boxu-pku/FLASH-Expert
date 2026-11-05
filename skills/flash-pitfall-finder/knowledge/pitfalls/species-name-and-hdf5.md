---
title: species 名过长导致 HDF5 冲突 + parfile 前缀不一致
category: 运行期 IO / 编译期
severity: fatal（abort / 编译错）
first_seen: 2026-08-02
last_verified: 2026-08-03
verifier: claude
status: stable
tags:
  - multispecies
  - hdf5
  - species-name
  - parfile
  - naming
---

# species 名过长导致 HDF5 冲突 + parfile 前缀不一致

## 错误信息（3 种表现）

### 表现 1：HDF5 写入 abort

```
HDF5-DIAG: Error detected in HDF5 (1.14.3)
H5Dcreate1(): unable to create dataset
H5L__link_cb(): name already exists
DRIVER_ABORT: Error: H5Dcreate io_h5write_unk
```

### 表现 2：parfile 参数被忽略

```
RuntimeParameters_read: ignoring unknown parameter "op_tar1Absorb"...
RuntimeParameters_read: ignoring unknown parameter "ms_tar1A"...
RuntimeParameters_read: ignoring unknown parameter "eos_tar1EosType"...
```

### 表现 3：EOS abort（参数没配的后果）

```
DRIVER_ABORT: [Eos_putData] ERROR Density or Internal Energy are zero after a call to EOS!
```

## 原因

FLASH 的 species 名在 4 个位置必须**完全一致**，但长名（>4 字符）会导致 HDF5 dataset 名冲突：

| 位置 | `targ1`（长名 5 字符）| `tar1`（短名 4 字符）|
|---|---|---|
| setup 命令 | `species=cham,targ1,...` | `species=cham,tar1,...` |
| Flash.h 宏 | `#define TARG1_SPEC 36` | `#define TAR1_SPEC 36` |
| parfile 前缀 | `ms_targ1A` / `op_targ1Absorb` | `ms_tar1A` / `op_tar1Absorb` |
| initBlock 代码 | `species = TARG1_SPEC` | `species = TAR1_SPEC` |

**问题 1**：`targ1`（5 字符）→ HDF5 dataset 名冲突（"name already exists"）
**问题 2**：setup 用 `targ1` 但 parfile 写 `tar1`（或反过来）→ 参数被忽略
**问题 3**：initBlock 用 `TAR1_SPEC` 但 Flash.h 定义 `TARG1_SPEC` → 物种判断失败

## 修复

**统一用短名（≤4 字符）**：

```bash
# setup 命令
./setup <problem> ... species=cham,tar1,tar2,tar3 ...

# parfile
ms_tar1A = 13
op_tar1Absorb = "op_tabpa"
eos_tar1EosType = "eos_tab"

# Simulation_initBlock.F90
#ifndef CHAM_SPEC
  integer :: CHAM_SPEC = 1
  integer :: TAR1_SPEC = 2, TAR2_SPEC = 3, TAR3_SPEC = 4
#endif
```

**关键**：`integer :: TAR1_SPEC` 声明必须在 `#ifndef CHAM_SPEC` 块**里面**，否则和 Flash.h 的 `#define TAR1_SPEC 36` 冲突（预处理后变成 `integer :: 36`）。

## 命名建议

| 物质 | ✅ 安全（≤4 字符）| ❌ 危险（>4 字符）|
|---|---|---|
| chamber 气体 | `cham` | `chamber` |
| target 1 | `tar1` | `targ1` |
| 氢 | `h` / `hyd` | `hydro` |
| 氦 | `he` | `heli` |
| 铝 | `al` | `alum` |
| CH 塑料 | `ch` | `plas` |

## 验证

`tar1`/`tar2`/`tar3`（4 字符）→ 275+ 步跑通，HDF5 正常。
`targ1`/`targ2`/`targ3`（5 字符）→ HDF5 abort。
