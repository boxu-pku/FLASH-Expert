# examples/ — flash-material skill 示例文件

> 本目录提供 flash-material skill 的可执行示例。

## 文件清单

| 文件 | 内容 | 适用场景 |
|---|---|---|
| `setup-spitzerhighz-ionmix4.sh` | LaserSlab HEDP setup 命令 | 标准 HEDP 算例起步 |
| `parfile-material-laserslab.txt` | LaserSlab 物质属性完整 parfile 片段 | 生产 HEDP 算例 |
| `parfile-constant-conductivity.txt` | Constant Conductivity + Constcm2g Opacity | 调试/教学 |

## 使用方法

### 1. LaserSlab HEDP 标准路径

```bash
# Step 1: setup（生成 objdir 和 Makefile）
cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
bash .claude/skills/flash-material/examples/setup-spitzerhighz-ionmix4.sh

# Step 2: 编译
cd cases/LaserSlab
make -j4

# Step 3: 检查 parfile 物质属性段（参考 parfile-material-laserslab.txt）
# 编辑 flash.par，确保含 op_cham*/op_targ* 等参数

# Step 4: 跑
./flash4 -par_file=flash.par
```

### 2. 简化调试路径

```bash
# Step 1: 修改 Simulation Config REQUESTS：
#   REQUESTS physics/materialProperties/Conductivity/ConductivityMain/Constant
#   REQUESTS physics/materialProperties/Opacity/OpacityMain/Constcm2g

# Step 2: setup
./setup MyDebugCase -2d -auto \
    species=cham \
    +mtmmmt +uhd3t +mgd \
    mgd_meshgroups=4 \
    -objdir=cases/MyDebugCase

# Step 3: 复制 parfile 片段到 flash.par
cp .claude/skills/flash-material/examples/parfile-constant-conductivity.txt \
   cases/MyDebugCase/flash.par

# Step 4: 编译 + 跑
cd cases/MyDebugCase
make -j4
./flash4 -par_file=flash.par
```

## 配套知识

- 完整物质属性讲解：`../knowledge/overview.md`
- 参数完整字典：`../knowledge/params.md`
- 内部实现：`../knowledge/internals.md`
- 典型配置：`../knowledge/recipes.md`
- 常见错误：`../knowledge/pitfalls.md`

## 注意事项

- parfile 中所有 `#` 注释是 FLASH 原生支持的，可保留
- 文件路径在 parfile 中是相对 objdir 的（如 `al-imx-003.cn4`）
- 数据文件必须放到 objdir（通过 Config 的 `DATAFILES` 指令）
- 修改 setup 后必须 `make clean && make -j4` 重新编译
