# flash-io examples/

本目录含 LaserSlab / HEDP 算例的标准 IO 配置示例。按 L-005 用纯 parfile / shell 格式（可直接 `cp` 使用，不用 markdown 包裹）。

## 文件清单

| 文件 | 内容 | 用法 |
|---|---|---|
| `setup-hdf5-parallel.sh` | LaserSlab + `+hdf5typeio` 的标准 setup 脚本 | `bash setup-hdf5-parallel.sh` |
| `parfile-io-control.txt` | 完整 IO 控制 parfile 片段（输出频率 / plot_var / restart / HDF5 模式）| 片段拷贝到 flash.par |
| `restart-recipe.txt` | restart 续跑 parfile 片段 + 步骤说明 | restart 时拷贝到 restart.par |

## 使用流程

### 1. 全新 setup + 跑

```bash
# 复制 setup 脚本到任意位置（或直接用）
cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8

# 编辑 setup-hdf5-parallel.sh，确认 FLASH_DIR / CASE_NAME / CASE_DIR 路径正确
# 然后：
bash .claude/skills/flash-io/examples/setup-hdf5-parallel.sh

# 复制 parfile 片段到你的 flash.par
cp .claude/skills/flash-io/examples/parfile-io-control.txt cases/LaserSlab/flash.par
# 编辑 flash.par，调整 basenm / 输出频率 / plot_var 等

# 跑
cd cases/LaserSlab
./flash4 -par_file=flash.par
```

### 2. restart 续跑

```bash
# 用和原 run 完全一致的 setup（仅 -objdir / -parfile 不同）
cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
./setup LaserSlab -2d -auto +cylindrical -nxb=16 -nyb=16 \
        +hdf5typeio species=cham,targ +mtmmmt +laser +uhd3t +mgd mgd_meshgroups=6 \
        -objdir=cases/LaserSlab_restart -parfile=restart.par

# 复制 restart parfile 模板
cp .claude/skills/flash-io/examples/restart-recipe.txt cases/LaserSlab_restart/restart.par
# 编辑 restart.par，设 checkpointFileNumber 为要读的编号

# 把 chk 文件拷过来
cp cases/LaserSlab/lasslab_hdf5_chk_0015 cases/LaserSlab_restart/

# make + 跑
cd cases/LaserSlab_restart
make -j4
./flash4 -par_file=flash.par
```

## 注意

- parfile 文件用 `#` 注释（FLASH 原生支持）
- shell 脚本含 `sudo mv libmpi.so.40` workaround（本机特定，参考 `note.txt`）
- restart 时 setup 必须和原 run 一致（`-nxb` / `-nyb` / `+laser` 等），否则 `NXB in checkpoint does not match this executable` abort
- 详见 `../knowledge/recipes.md` 完整说明

## 关键参数速查

| 参数 | 默认 | HEDP 典型 | 说明 |
|---|---|---|---|
| `plotFileIntervalStep` | 0 | 100 | 每 N 步出 plotfile |
| `checkpointFileIntervalStep` | 0 | 1000 | 每 N 步出 chk |
| `basenm` | "flash_" | "lasslab_" | 文件名前缀 |
| `plot_var_1..12` | "none" | "dens" 等 | plotfile 写的 unk 名 |
| `restart` | .false. | .true.（续跑时）| 是否 restart |
| `checkpointFileNumber` | 0 | 续跑时设要读的编号 | restart 用 |
| `wall_clock_checkpoint` | 43200 | 36000（12h queue）| 墙钟触发 |
| `rolling_checkpoint` | 10000 | 10（盘紧张时）| 滚动覆盖 |
| `useCollectiveHDF5` | .true. | .true. | 集体 IO（默认快）|

## 完整参数字典

见 `../knowledge/params.md`。
