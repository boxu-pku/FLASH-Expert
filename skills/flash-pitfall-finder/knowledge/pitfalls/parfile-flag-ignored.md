---
title: flash4 的 -parfile=X 被静默忽略（正确是 -par_file X，空格分隔）
category: 运行期参数
severity: 高（静默——读了错误的 parfile 或不报错，极具迷惑性）
first_seen: 2026-08-11
last_verified: 2026-08-11
verifier: claude
status: stable
tags:
  - parfile
  - 命令行
  - flash4
  - 静默失败
related:
  - skills/flash-pitfall-finder/knowledge/pitfalls/restart-plotfilenumber-overwrite.md
---

# flash4 的 `-parfile=X` 被静默忽略

## 现象

```bash
./flash4 -parfile=myrun.par     # 想用自己的 parfile
# 实际行为：静默忽略该参数，读 CWD 下的默认 flash.par
```

- 若 CWD 有 flash.par → 跑的是**别人的参数**，无任何提示
- 若 CWD 无 flash.par → abort "cannot open parfile" 类错误

## 源码机制（实证）

`RuntimeParameters_init.F90:86-89`：

```fortran
pCheck='-par_file'                          ! ← 真正的旗标是 -par_file（下划线）
call rp_getOpt(pCheck, 1, parfileFlagExists, parmFile)
if(parfileFlagExists /= 1) parmFile = 'flash.par'   ! ← 缺省回退
```

`rp_getOpt.F90` 做**精确字符串匹配**（长度+逐字符），值取**下一个 argv**。
所以：
- `-parfile=X`（等号）：匹配失败 → 静默回退默认
- `-parfile X`（空格，无下划线）：匹配失败 → 静默回退默认
- **`-par_file X`（下划线+空格）：唯一正确写法** ✓

（`rp_getOpt.F90` 头注释里写的示例 `-parfile flash.par` 与实现不符——注释错了。）

## 为什么以前没炸

只要文件名恰好是 `flash.par`（本机所有算例的惯例），被忽略后回退读的
就是同一个文件——**错误写法产生了正确结果**，潜伏多年。包括 CLAUDE.md
和各 skill 文档里的 `-parfile=flash.par` 示例（2026-08-11 已全部修正为
`-par_file`）。

## 实证（2026-08-11 Sunliang_Xray_xray8）

`mpirun -np 8 ./flash4 -parfile=flash_verify.par`：静默读默认 flash.par，
从新算例 t=0 开跑（预期是 restart 到 16.57 ns），靠 basenm 前缀不对才发现。

## 修复

```bash
# ✅ 正确
mpirun -np N ./flash4 -par_file myrun.par

# ✅ 更省事（parfile 就是 flash.par 时，什么旗标都不用）
mpirun -np N ./flash4
```

**01-data CWD 运行法配套**：在 `01-data/` 里跑时，用
`mpirun -np N ../flash4 -par_file ../flash.par`（指向 objdir 根的 parfile）；
或先 `cp ../flash.par .` 再裸跑 `../flash4`（parfile 随输出归档，利于复现）。

## 预防

- 传非默认名 parfile 后，**先看日志确认读的是哪个文件**（basenm/参数是否生效）
- 文档/脚本里写运行命令时只用 `-par_file X` 或默认 flash.par
