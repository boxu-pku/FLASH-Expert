# examples/ — flash-sourceterms 配置示例

> 2 个文件，按 L-013 聚焦主流路径（Heatexchange/Spitzer HEDP）。

| 文件 | 类型 | 适用场景 |
|---|---|---|
| `setup-heatexchange-spitzer.sh` | setup 命令 | LaserSlab HEDP 标准 + 5 变体选择 + DRIVER_EDEARLY |
| `parfile-heatexchange.txt` | parfile 片段 | Heatexchange 完整配置（含 hx_dtFactor / hx_ieTimeCoef） |

## 怎么用

### setup 命令

直接复制到 case 目录运行：

```bash
cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
# 改 setup-heatexchange-spitzer.sh 里的 problem 名后
bash skills/flash-sourceterms/examples/setup-heatexchange-spitzer.sh
```

### parfile 片段

把 `parfile-heatexchange.txt` 的内容（去掉 `#` 注释）复制到你的 `flash.par` 顶层。

## 6 大陷阱提醒（按 L-011）

| # | 陷阱 | 后果 | 修复 |
|---|---|---|---|
| 1 | 用 `hxcouple`（不存在） | parfile 不生效 | 用 `hx_couplingConst12`（Constant）/ `hx_ieTimeCoef`（Spitzer）|
| 2 | `useHeatexchange` 默认 FALSE | HX 不调 | parfile 显式 `useHeatexchange = .true.` |
| 3 | Heatexchange 不配 3T | abort | setup 加 `+uhd3t` 或 `+3t` |
| 4 | Immediate 当生产用 | 物理失真 | 用 Spitzer（或 LeeMore 高 Z） |
| 5 | 不理解 `hx_dtFactor = 1e100` | 以为是 bug | LaserSlab 故意禁用（eqtime << dt_hydro）|
| 6 | 以为 HX 处理 TRAD | 辐射不平衡没修 | 辐射-电子平衡看 flash-radtrans |

## 注意（L-009）

按 L-009 经验，**parfile 顶部 setup 注释可能不可信**。验证实际 setup 命令：

```bash
cat cases/<your_case>/setup_call
```

如果 setup_call 和 parfile 顶部注释不一致，**以 setup_call 为准**。
