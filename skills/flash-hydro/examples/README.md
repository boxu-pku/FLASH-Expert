# examples/ — flash-hydro 配置示例
> 路径约定：`$FLASH_ROOT` = FLASH 4.8 仓库根目录（本机 `/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8`）；`$FLASH_LIBS` = 外部库根目录（本机 `/home/ubuntu/local/flash/myFLASH4.8`）。其它机器按实际路径替换。


> 4 个文件覆盖 3 种变体 + 1 个完整 parfile 片段。

| 文件 | 类型 | 适用场景 |
|---|---|---|
| `setup-unsplit.sh` | setup 命令 | unsplit pure hydro（默认，99% 算例） |
| `setup-usm-mhd.sh` | setup 命令 | USM-MHD（磁流体，含 CT） |
| `setup-split-ppm.sh` | setup 命令 | split PPM（燃烧算例）+ 8-wave MHD |
| `parfile-hydro.txt` | parfile 片段 | Hydro 参数完整配置（CFL/Riemann/限幅器/截断/MHD） |

## 怎么用

### setup 命令

直接复制到 case 目录运行：

```bash
cd $FLASH_ROOT
# 改 setup-unsplit.sh 里的 problem 名后
bash skills/flash-hydro/examples/setup-unsplit.sh
```

### parfile 片段

把 `parfile-hydro.txt` 的内容（去掉 `#` 注释）复制到你的 `flash.par` 顶层（不在任何 sourceTerm 段）。

## 注意（L-009）

按 L-009 经验，**parfile 顶部 setup 注释可能不可信**。验证实际 setup 命令：

```bash
cat cases/<your_case>/setup_call
```

如果 setup_call 和 parfile 顶部注释不一致，**以 setup_call 为准**。

## 关键参数命名（容易踩坑）

按 L-011 讲清楚：parfile 参数名**没有 hy_ 前缀**：

| parfile 写法 | 内部模块变量 | 备注 |
|---|---|---|
| `cfl = 0.5` | `hy_cfl` | ✓ 正确 |
| `RiemannSolver = "HLLC"` | `hy_RiemannSolver`（int） | ✓ 正确 |
| `slopeLimiter = "vanLeer"` | `hy_limiter`（int） | ✓ 正确 |
| `hy_cfl = 0.5` | — | ✗ 不识别（无 hy_ 前缀） |
| `hy_RiemannSolver = "HLLC"` | — | ✗ 不识别 |
