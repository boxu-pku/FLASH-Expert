---
title: <一句话标题：错误信息特征 / 异常现象>（例："setup 报 Unit not found"）
category: <setup 期 | 编译/链接 | 启动期 | 运行期数值 | 运行期 MPI | restart | 本机特定>
severity: <fatal（abort）| 阻塞（不能跑）| 警告（能跑但结果错）| 性能>
first_seen: <YYYY-MM-DD>            # 第一次遇到/沉淀的日期
last_verified: <YYYY-MM-DD>         # 最后一次对照源码核实的日期
verifier: <claude | user>
status: <draft | beta | stable>
tags:                                # 3-7 个，便于检索
  - <关键词1>
  - <关键词2>
source_anchors:                      # 至少 1 个，源码相关的踩坑必须有
  - source/path/file.F90:LXX
  - bin/script.py:LXX
---

# <标题（同 frontmatter title）>

## 错误信息

> 给出**真实的错误信息原文**（从日志复制），含 1-3 种变体。

### 形式 1：<简短描述>
```
<错误原文，含 [routine] 前缀>
```

### 形式 2：<另一种形式（如有）>
```
<错误原文>
```

## 原因

**讲机制**：为什么会触发这个错误。

- 用人话讲清楚错误条件（如 "X > Y 时 abort"）
- 解释涉及的运行时数据（如 "ed_maxBeams 是 setup 期固定，parfile 改不了"）
- 标出**根因分类**（用户操作错 / 源码 bug / 本机特定 / 参数过时）

**源码机制**（如适用）：
```
触发位置：source/path/file.F90:LXX
对应代码：
   if (条件) call Driver_abortFlash("...")
```

## 修复

**按错误形式分**，每种给具体步骤。

### 形式 1 的修复

1. <步骤 1（含具体命令/参数修改）>
2. <步骤 2>
3. ...

```bash
# 示例命令（含原 setup + 改后的对比）
# 旧：./setup Sedov
# 新：./setup SedovSelfGravity
```

### 形式 2 的修复（如有）

<同上>

## 源码锚点

按 L-008：源码相关的踩坑必须给出具体代码位置。

- `source/path/file.F90:LXX` — <这个位置在做什么>
- `bin/script.py:LXX` — <如 setup 期脚本相关>
- `source/**/Config:LXX` — <如参数声明相关>

## 预防

下次怎么避免再踩：
- <规则 1>
- <规则 2>

## 延伸

- 相关踩坑：`<其他 pitfall 文件>.md`
- 对应 skill：`.claude/skills/flash-<unit>/knowledge/pitfalls.md §X.Y`（如有）
- 官方资料：FLASH mailing list / RELEASE-NOTES / <手册章节>

---

## 维护日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| YYYY-MM-DD | 初始创建（draft） | claude |
