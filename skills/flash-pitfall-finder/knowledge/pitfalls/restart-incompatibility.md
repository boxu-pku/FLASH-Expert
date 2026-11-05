---
title: Restart 失败（checkpoint 不兼容）
category: 运行期 restart
severity: fatal（无法 restart）
first_seen: 2026-06-17
last_verified: 2026-07-12
verifier: claude
status: beta
tags:
  - restart
  - checkpoint
  - hdf5
  - 兼容性
---

# Restart 失败（checkpoint 不兼容）

## 常见错误信息

### 形式 1：找不到 checkpoint
```
[IO_init] Restart requested but checkpoint file '<name>_hdf5_chk_0000' not found
```

### 形式 2：版本不匹配
```
[IO_init] Checkpoint version mismatch: file=v4.6, code=v4.8
[IO_init] Cannot restart from incompatible checkpoint
```

### 形式 3：变量不匹配
```
[IO_init] Variable count mismatch: file=45, code=42
[IO_init] Missing: RADIATION_FLUX_VAR, RADIATION_ENER_VAR
```

### 形式 4：grid 不匹配
```
[IO_init] Block structure mismatch: file=256 blocks, code=128 blocks
```

### 形式 5：HDF5 错
```
HDF5-DIAG: Error reading dataset 'dens'
H5Dread failed
```

## 原因

### A. Setup 变了

最常见。Restart 要求 checkpoint 时和当前 setup 一致：
- `NXB/NYB/NZB` 变了
- 物种数变了（`species=` 改了）
- 物理单元变了（如加了 `+laser` 或去掉 `+mgd`）
- 几何变了（cartesian → cylindrical）

### B. FLASH 版本变了

checkpoint 格式可能跨版本不兼容。常见不兼容点：
- 4.5 → 4.6：变量重命名
- 4.6 → 4.7：IO 接口改动
- 4.7 → 4.8：变量增加（如新增 LASER 相关）

### C. checkpoint 文件损坏

HDF5 文件可能因为：
- 中途中断写（断电、abort 时正在写）
- 磁盘满
- 并行 IO race condition

### D. parfile 不一致

restart 用 parfile 和 checkpoint 不一致：
- 不同 sim_xxx 参数
- 不同 grid_xmax 等
- 不同 BC

## 修复

### A. Setup 变了

**永远不要在 setup 变了后 restart**。两种选择：
1. 从头跑（最稳）
2. 用相同 setup 重建 objdir，再 restart（保留原 setup_call）

### B. 版本不兼容

如果一定要跨版本：
1. 用旧版本 FLASH 跑一个 plotfile 作为"restart 中介"
2. 写 Python 脚本把 plotfile 转 checkpoint（部分情况可行）
3. 用新版本从头跑

### C. 文件损坏

```bash
# 验证 HDF5 文件
h5dump -H <checkpoint_file> | head -30
# 如果报错，文件损坏

# 尝试用上一个 checkpoint
ls 01-data/<basenm>_hdf5_chk_*
# 用 _chk_0010 而不是 _chk_0020
```

### D. parfile 不一致

restart 模式下，多数 sim_xxx 参数会被 checkpoint 覆盖，但有些不会：
- IO 相关（`checkpointFileIntervalStep` 等）
- `restart = .true.` 必须设
- `checkpointFileNumber` 指定从哪个 chk 启动

parfile 模板：
```fortran
restart              = .true.
checkpointFileNumber = 10                    # 从 chk_0010 重启
basenm               = "01-data/lasslab_"    # 同原始 parfile
# 其他 sim_xxx 可以保留，但会被 checkpoint 覆盖
```

## 诊断

### Step 1：对比 setup_call

```bash
# 当前 setup_call
cat cases/<new_case>/setup_call

# 原始 setup_call（如果有）
cat cases/<old_case>/setup_call
diff cases/<new_case>/setup_call cases/<old_case>/setup_call
```

不一致 → 是 A 类问题。

### Step 2：对比 Flash.h

```bash
diff cases/<new_case>/Flash.h cases/<old_case>/Flash.h
```

Flash.h 含所有变量索引和宏定义。差异即问题源。

### Step 3：HDF5 文件验证

```bash
# 列文件内的 datasets
h5ls -r 01-data/<basenm>_hdf5_chk_0010

# 看具体 dataset 的内容
h5dump -d "dens" 01-data/<basenm>_hdf5_chk_0010 | head -20
```

### Step 4：日志

```bash
# restart 失败的日志通常在 stderr，不在主 log
./flash4 -parfile=flash.par 2>&1 | tee restart.log
grep -i "restart\|incompat\|mismatch" restart.log
```

## 最佳实践（避免 restart 失败）

1. **每个 case 保留 setup_call**：`cp setup_call setup_call.bak`
2. **checkpoint 频率**：`checkpointFileIntervalStep = 100`（不要 1000）
3. **重要算例双备份**：每次写 chk 时同时 plot
4. **不跨版本 restart**：升级 FLASH 前结束所有运行中算例
5. **磁盘空间监控**：写脚本定期检查 `df -h`，避免磁盘满导致 chk 损坏

## 源码锚点

- `source/IO/IOMain/default/IO_readPłas.F90`（或 hdf5/IO_readPłas.F90） — restart 读取逻辑
- `source/IO/IO_init.F90` — restart 初始化校验
- `source/Driver/Driver_initFlash.F90` — 主初始化入口

## 跨 skill 引用

- IO 单元详情：`flash-io` skill（Phase 2）
- checkpoint 格式：`flash-io/knowledge/internals.md`（待建）

## 延伸

- 类似问题：变量不匹配 → setup 改了，必须重跑
- HDF5 工具：`h5dump`、`h5ls`、`h5diff`
