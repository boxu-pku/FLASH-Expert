# examples/ — flash-eos 配置示例
> 路径约定：`$FLASH_ROOT` = FLASH 4.8 仓库根目录（本机 `/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8`）；`$FLASH_LIBS` = 外部库根目录（本机 `/home/ubuntu/local/flash/myFLASH4.8`）。其它机器按实际路径替换。


> 4 个文件覆盖 3 种变体 + 1 个完整 parfile 片段。

| 文件 | 类型 | 适用场景 |
|---|---|---|
| `setup-gamma.sh` | setup 命令 | Gamma（理想气体，默认，教学/测试） |
| `setup-helmholtz.sh` | setup 命令 | Helmholtz（HEDP/ICF/激光默认） |
| `setup-multitype-3t.sh` | setup 命令 | 3T Multitype（生产级三温） |
| `parfile-eos.txt` | parfile 片段 | EOS 参数完整配置（主控/Helmholtz/3T/性能） |

## 怎么用

### setup 命令

直接复制到 case 目录运行：

```bash
cd $FLASH_ROOT
# 改 setup-helmholtz.sh 里的 problem 名后
bash skills/flash-eos/examples/setup-helmholtz.sh
```

### parfile 片段

把 `parfile-eos.txt` 的内容（去掉 `#` 注释）复制到你的 `flash.par` 顶层。

## 注意（L-009）

按 L-009 经验，**parfile 顶部 setup 注释可能不可信**。验证实际 setup 命令：

```bash
cat cases/<your_case>/setup_call
```

如果 setup_call 和 parfile 顶部注释不一致，**以 setup_call 为准**。

## 关键参数位置（容易踩坑）

按 L-011 讲清楚：**`eosMode` / `smalle` 等不在 `physics/Eos/` Config**：

| parfile 参数 | 在哪声明 | 备注 |
|---|---|---|
| `eosMode` / `eosModeInit` | `source/Grid/GridMain/Config:L155-L175` | Grid 单元也用（填 guard cell） |
| `smalle` / `smallt` / `smlrho` / `smallx` | 同上 | 截断值 |
| `eintSwitch` / `gamma` | `source/physics/Eos/Config` | Eos 顶层 |
| `eos_coulombMult` / `eos_tolerance` / `eos_maxNewton` | `source/physics/Eos/EosMain/Helmholtz/Config` | Helmholtz 专属 |
| `eos_combinedTempRule` / `eos_smallEion` | `source/physics/Eos/EosMain/multiTemp/Config` | 3T 专属 |
| `hy_eosModeGc` / `hy_eosModeAfter` | `source/physics/Hydro/HydroMain/unsplit/Config` | Hydro 单元的 EOS 模式覆盖 |
