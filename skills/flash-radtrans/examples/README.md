# examples/ — flash-radtrans 配置示例
> 路径约定：`$FLASH_ROOT` = FLASH 4.8 仓库根目录（本机 `/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8`）；`$FLASH_LIBS` = 外部库根目录（本机 `/home/ubuntu/local/flash/myFLASH4.8`）。其它机器按实际路径替换。


> 3 个文件，按 L-013 聚焦主流路径（HEDP MGD）。

| 文件 | 类型 | 适用场景 |
|---|---|---|
| `setup-mgd-laser.sh` | setup 命令 | LaserSlab HEDP 标准 + 多物质 + 单群测试 |
| `parfile-mgd.txt` | parfile 片段 | MGD 完整配置（含 6 群 + 边界 + flux limiter） |
| `parfile-groups.txt` | parfile 片段 | 4 种能群数配置（1/6/10/70 群） |

## 怎么用

### setup 命令

直接复制到 case 目录运行：

```bash
cd $FLASH_ROOT
# 改 setup-mgd-laser.sh 里的 problem 名后
bash skills/flash-radtrans/examples/setup-mgd-laser.sh
```

### parfile 片段

把 `parfile-mgd.txt` 的内容（去掉 `#` 注释）复制到你的 `flash.par` 顶层（不在任何 sourceTerm 段）。

### 群结构选择

`parfile-groups.txt` 提供 4 种群数配置，按需选一种复制对应段到 parfile。**记得 setup 命令的 `mgd_meshgroups=N` 要匹配**。

## 6 大陷阱提醒（按 L-011）

按 L-011 重点讲为什么——这些是新手最容易踩的：

| # | 陷阱 | 后果 | 修复 |
|---|---|---|---|
| 1 | `rt_mgdFlMode` 默认 `fl_none` | 辐射超光速，能量爆炸 | parfile 显式设 `"fl_harmonic"` |
| 2 | `rt_mgdBounds_*` 单位 eV 不是 erg | 物理量错算 | 写 `1.e-1` 表示 0.1 eV |
| 3 | `mgd_meshgroups` 是 setup 变量 | parfile 改不生效 | setup 命令加 `mgd_meshgroups=N` |
| 4 | `rt_mgdBounds_*` 数量 ≠ N+1 | 启动 abort | N 群要 N+1 个边界 |
| 5 | MGD 群边界不和 IONMIX 表对齐 | 物理静默错误 | 用 `head -10 *.cn4` 看表群结构 |
| 6 | operator-split MGD 不应用 PRAD_VAR | 辐射压力主导算例失真 | 用 Unified 变体（实验性） |

## 注意（L-009）

按 L-009 经验，**parfile 顶部 setup 注释可能不可信**。验证实际 setup 命令：

```bash
cat cases/<your_case>/setup_call
```

如果 setup_call 和 parfile 顶部注释不一致，**以 setup_call 为准**。
