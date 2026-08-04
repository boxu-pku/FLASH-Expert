# examples/ — flash-grid 配置示例

> 4 个文件覆盖 backend 选择、AMR 配置、几何配置三大场景。

| 文件 | 类型 | 适用场景 |
|---|---|---|
| `setup-pm4dev.sh` | setup 命令 | Paramesh 4 dev backend（默认，AMR 算例） |
| `setup-ug.sh` | setup 命令 | Uniform Grid backend（无 AMR；PIC、FFT、nofbs） |
| `parfile-amr.txt` | parfile 片段 | AMR 配置（lrefine_max / refine_var / cutoff） |
| `parfile-geometry.txt` | parfile 片段 | 5 种几何 + 边界条件组合 |

## 怎么用

### setup 命令

直接复制到 case 目录运行：

```bash
cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
# 改 setup-pm4dev.sh 里的 problem 名后
bash .claude/skills/flash-grid/examples/setup-pm4dev.sh
```

或者手动复制 setup 命令段。

### parfile 片段

把对应段（去掉 `#` 注释）复制到你的 `flash.par` 顶层（不在任何 sourceTerm 段）：

```bash
# 复制 parfile-amr.txt 的内容到 flash.par
# 按需调整数值（如 lrefine_max、refine_var_1）
```

## 注意（L-009）

按 L-009 经验，**parfile 顶部 setup 注释可能不可信**。如果你看 case 目录已有 flash.par，它的顶部 setup 命令注释要对照实际 setup_call 文件验证：

```bash
cat cases/<your_case>/setup_call    # 实际 setup 命令
```

如果 setup_call 和 parfile 顶部注释不一致，**以 setup_call 为准**。
