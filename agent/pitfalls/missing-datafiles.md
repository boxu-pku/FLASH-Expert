---
title: Config DATAFILES 声明遗漏导致运行时找不到表文件
category: 运行期 abort
severity: fatal（abort）
first_seen: 2026-08-02
last_verified: 2026-08-03
verifier: claude
status: stable
tags:
  - config
  - datafiles
  - ionmix
  - opacity
---

# Config DATAFILES 声明遗漏导致运行时找不到表文件

## 错误信息

```
[op_browseIonmixTables] ERROR: IONMIX file not found: CHBr-opacity.cn4
DRIVER_ABORT: [op_browseIonmixTables] ERROR: no IONMIX file found
```

## 原因

parfile 引用的表文件（如 `op_targ2FileName = "CHBr-opacity.cn4"`）没在算例的 Config 文件里用 `DATAFILES` 声明。setup 时只拷贝 Config 声明的 DATAFILES 到 objdir，没声明的不会拷贝。

## 修复

### 方法 1：手动拷贝（快速验证）

```bash
cp source/Simulation/SimulationMain/<problem>/CHBr-opacity.cn4 cases/<problem>/
```

### 方法 2：Config 声明（永久修复）

在算例 Config 文件加：
```
DATAFILES CHBr-opacity.cn4
```

这样 `./setup` 会自动拷贝。

## 常见漏声明场景

parfile 引用了**不同于 EOS 表的额外不透明度表**：

```fortran
# EOS 用 chBr-hyades.cn4（已在 Config DATAFILES 声明）
eos_tar2TableFile = "chBr-hyades.cn4"

# 但 Opacity 用 CHBr-opacity.cn4（没在 DATAFILES 声明！）
op_tar2FileName = "CHBr-opacity.cn4"
```

**规则**：parfile 引用的**每一个文件名**都要在 Config DATAFILES 里声明（或手动拷贝到 case 目录）。

## 诊断命令

```bash
# 列出 parfile 引用的所有文件名
grep "FileName\|TableFile" flash.par | grep -v "^#" | awk -F'"' '{print $2}' | sort -u

# 检查 case 目录里有没有
for f in $(grep "FileName\|TableFile" flash.par | grep -v "^#" | awk -F'"' '{print $2}' | sort -u); do
    if [ -f "$f" ]; then echo "✓ $f"; else echo "✗ $f"; fi
done
```
