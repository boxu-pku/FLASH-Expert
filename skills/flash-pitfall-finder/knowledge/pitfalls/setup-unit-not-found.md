---
title: setup 报 "Unit not found" 或 "Unit ... is ambiguous"
category: setup 期
severity: fatal（abort）
first_seen: 2026-06-17
last_verified: 2026-07-12
verifier: claude
status: beta
tags:
  - setup
  - 拼写
  - unit
  - Config
---

# setup 报 "Unit not found" / "Unit ... is ambiguous"

## 错误信息

### 形式 1：完全找不到
```
SetupError: Unit <Name> not found
```

### 形式 2：多个匹配（歧义）
```
Potential completions : Sedov, SedovSelfGravity, SedovSolidWall, SedovChamber
SetupError: Unit Sedov is ambiguous
```

### 形式 3：找不到依赖
```
SetupError: Unit <X> requires unit <Y>, but <Y> not found
```

## 原因

FLASH 的 setup.py 把第一个位置参数当 `SimulationMain/<Name>` 来匹配，规则：

1. **大小写不敏感前缀匹配**（在 `source/Simulation/SimulationMain/` 下找）
2. 唯一匹配 → 通过
3. 0 个匹配 → `Unit not found`
4. 多个匹配 → `Unit ambiguous`

源码：`bin/setup.py` 的 `main()` 函数，`os.chdir(GVars.simulationsDir)` 后做 `dirGlob`。

## 修复

### 形式 1：找不到

常见原因：
- **拼写错**：`./setup Sdeov` → 改成 `./setup Sedov`
- **大小写错**：`./setup sedov` → 也能匹配（不敏感），但 `./setup SEDOV` 在某些版本可能失败
- **路径错**：单元不在 `source/Simulation/SimulationMain/` 下
- **新加的单元没刷新**：刚 cp 进去但 setup.py 缓存了旧目录列表 → 重启 setup

**诊断**：
```bash
# 列所有 SimulationMain 子目录
ls source/Simulation/SimulationMain/ | grep -i <你的名字>
```

### 形式 2：歧义

写**完整名字**：
```bash
# ❌ 歧义
./setup Sedov

# ✅ 明确
./setup SedovSelfGravity
```

### 形式 3：依赖找不到

通常意味着你的 setup 命令缺关键选项。例：
- `+laser` 没加 → Laser 单元不会被 pull in
- `species=` 缺失 → Multispecies 不生成对应物种

查 Config 文件的 `REQUIRES` / `REQUESTS` 关系：
```bash
cat source/Simulation/SimulationMain/<your_problem>/Config
```

## 源码锚点

- `bin/setup.py:main()` — 单元查找逻辑
- `bin/setup.py:dirGlob()` — 大小写不敏感目录匹配
- `source/Simulation/SimulationMain/` — SimulationMain 单元目录（59 个算例）

## 预防

- setup 命令的单元名用 Tab 补全
- 新算例命名避免前缀冲突（不要建 `Sedov2`，用 `SedovMyVersion`）
- 看 `cases/<existing>/setup_call` 文件，从已知能跑的命令开始改

## 延伸

- 详细的 setup 命令语法：`bin/Readme.SetupVars`
- setup 报错的另一种形式：见 `site-not-found.md`
- 修改 setup 命令的脚本：`bin/setup.py` 本身
