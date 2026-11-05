# examples/ — flash-diffuse 配置示例

> 3 个文件，按 L-013 聚焦主流路径（Unsplit + HYPRE，HEDP 标准）。

| 文件 | 类型 | 适用场景 |
|---|---|---|
| `setup-diffuse-unsplit.sh` | setup 命令 | LaserSlab HEDP 标准 + 多物质 + 1T 教学 + 3D 大规模 + MHD |
| `parfile-diffuse-therm.txt` | parfile 片段 | Diffuse 热传导完整配置（含 diff_thetaImplct / fl_larsen / dt_diff_factor）|
| `parfile-hypre-solvers.txt` | parfile 片段 | 5 种 HYPRE 求解器配置对比（PCG / AMG / BiCGSTAB / GMRES / Hybrid）|

## 怎么用

### setup 命令

直接复制到 case 目录运行：

```bash
cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
# 改 setup-diffuse-unsplit.sh 里的 problem 名后
bash .claude/skills/flash-diffuse/examples/setup-diffuse-unsplit.sh
```

### parfile 片段

把 `parfile-diffuse-therm.txt` 的内容（去掉 `#` 注释）复制到你的 `flash.par` 顶层（不在任何 sourceTerm 段）。

### HYPRE 求解器选择

`parfile-hypre-solvers.txt` 提供 5 种求解器配置，按场景选一种复制对应段到 parfile。**默认 PCG+AMG**（中小网格），**LaserSlab 用 AMG**（大网格）。

## 6 大陷阱提醒（按 L-011）

按 L-011 重点讲为什么——这些是新手最容易踩的：

| # | 陷阱 | 后果 | 修复 |
|---|---|---|---|
| 1 | `diff_eleFlMode` 默认 `fl_none` | 辐射超光速，能量爆炸 | parfile 显式设 `"fl_larsen"` |
| 2 | `diff_thetaImplct` 默认 0.5（CN） | HEDP 陡梯度 CN 震荡 | HEDP 设 `1.0`（后向 Euler）|
| 3 | `dt_diff_factor` 默认 0.8 | HEDP 显式 dt 太小，步数爆炸 | HEDP 设 `1.0e+100`（隐式禁用）|
| 4 | `diff_useEleCond` 默认 `.false.` | 3T 算例没解电子热传导 | parfile 显式 `.true.` |
| 5 | `Yl` 边界默认 `neumann`（应 vacuum） | LaserSlab 热不逃出，物理错 | 设 `diff_eleYlBoundaryType = "vacuum"` |
| 6 | `gr_hypreMaxIter=500` 默认 | 大网格不收敛 | 大问题调到 `2000+` |

## 何时换 HYPRE 求解器（按 L-011）

| 症状 | 推荐求解器 | 为什么 |
|---|---|---|
| 默认 PCG 不收敛（num_iter=500）| AMG 独立 | 避免双重存储，更稳健 |
| PCG 不收敛 + flux limiter | BiCGSTAB | flux limiter 让矩阵非对称，CG 不适用 |
| BiCGSTAB 也不收敛 | GMRES | 兜底，最难问题 |
| 大网格内存不够 | AMG 独立 | PCG 存 5+ 向量，AMG 内存小 |
| 中小网格速度优先 | PCG + AMG | CG 对称正定最优，加 AMG PC 快几个数量级 |

## 注意（L-009）

按 L-009 经验，**parfile 顶部 setup 注释可能不可信**。验证实际 setup 命令：

```bash
cat cases/<your_case>/setup_call
```

如果 setup_call 和 parfile 顶部注释不一致，**以 setup_call 为准**。

特别是：
- `+mgd` / `+uhd3t` 等编译期变量（不能在 parfile 改）
- `SupportAnisoCond`（各向异性扩散编译期开关）
- `mgd_meshgroups=N`（setup 期变量）

## 验证 HYPRE 是否生效（调试）

跑算例后看日志：

```bash
# 看 HYPRE 收敛情况
grep -E "HYPRE SOLVE|num_iterations|final_res_norm|Nonconv|ierr" \
    cases/<case>/01-data/<basenm>.log | head -30
```

健康指标：
- `num_iterations < 100`（小问题）/ `< 500`（大问题）
- `final_res_norm < 1e-8`（或你设的 gr_hypreRelTol）
- 无 `Nonconv` 警告
- `ierr = 0`

不健康时见 `knowledge/pitfalls.md §A`。
