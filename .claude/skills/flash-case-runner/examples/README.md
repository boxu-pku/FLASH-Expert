# flash-case-runner examples/

> 一键运行脚本和日志分析工具。本 skill 的 examples/ 是**可直接执行的 bash 脚本**（不是 parfile，因为是操作层 skill）。

## 脚本一览

| 脚本 | 用途 |
|---|---|
| `run-sedov.sh` | Sedov 算例一键运行（入门） |
| `run-laser-slab.sh` | LaserSlab HEDP 算例一键运行（主流） |
| `flash_log_parser.sh` | FLASH 日志关键信息提取（dt/nstep/NaN/abort） |

## 用法

### run-sedov.sh

```bash
# 跑 Sedov（默认 2 核）
bash /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/.claude/skills/flash-case-runner/examples/run-sedov.sh

# 跑 4 核
bash /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/.claude/skills/flash-case-runner/examples/run-sedov.sh 4
```

**做什么**：
1. setup Sedov（如 objdir 不存在）
2. 处理 libmpi 冲突（sudo mv）
3. make -j4
4. source flash_env.sh
5. mpirun -np 2 ./flash4
6. 检查产物（plotfile / checkpoint / 日志末尾）

### run-laser-slab.sh

```bash
# 前台跑（默认 2 核）
bash /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/.claude/skills/flash-case-runner/examples/run-laser-slab.sh

# 4 核后台跑（长算例推荐）
bash /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/.claude/skills/flash-case-runner/examples/run-laser-slab.sh 4 background
```

**做什么**：
1. setup LaserSlab（HEDP 全套：laser/mgd/uhd3t/mtmmmt/3T）
2. 处理 libmpi 冲突（sudo mv）
3. make -j4（3-5 分钟）
4. source flash_env.sh（关键——防 SIGSEGV）
5. mpirun ./flash4
6. 检查产物 + 验证 libmpi 链接（应该是 mpich .12，不是 OpenMPI .40）

**2026-08-02 实战验证**：本脚本流程跑通 66 步，零 MPI 错误。

### flash_log_parser.sh

```bash
# 分析日志
bash /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/.claude/skills/flash-case-runner/examples/flash_log_parser.sh cases/LaserSlab/flash.log
```

**提取什么**：
1. setup 信息（命令、版本）
2. 初始化完成检查（Hydro_init/RadTrans_init/...）
3. dt 演化（最后 20 步）
4. simTime 推进
5. AMR block 数变化
6. 错误检测（NaN / abort / SIGSEGV / forrtl / MPI error）
7. plotfile / checkpoint 写入次数
8. 完成状态

## 脚本设计原则（L-011 讲为什么）

### 1. 幂等性

脚本检查 objdir 是否存在、flash4 是否生成，已存在则跳过对应步骤。可以多次跑而不重复 setup/make。

### 2. 错误传播

`set -e` 让任一步失败立即退出。make 失败时显示 make.log 错误段。

### 3. libmpi 冲突处理

两个 run-*.sh 都自动处理本机 libmpi 冲突：
- 编译期：sudo mv 系统 .40，编译后恢复（即使失败也恢复）
- 运行期：source flash_env.sh（设 LD_PRELOAD）

### 4. 后台模式

`run-laser-slab.sh` 支持 `background` 参数，长算例后台跑（nohup + tail -f）。

### 5. 产物验证

跑完后自动检查：
- plotfile 数量
- checkpoint 数量
- 日志末尾
- 是否含 SIGSEGV / abort / NaN

## 修改建议

如果要扩展（如加 run-sunliang.sh），参考 `run-laser-slab.sh` 模板：
1. 改 CASE_NAME 和 setup 命令
2. 其他逻辑（make / source flash_env.sh / mpirun / 检查）保持一致

## 关联

- 详细操作流程：`../knowledge/overview.md` + `../knowledge/setup_guide.md` + `../knowledge/make_guide.md` + `../knowledge/run_guide.md`
- 算例配方：`../recipes/sedov.md` + `../recipes/laser-slab-2d.md` + `../recipes/sunliang-laser-CH.md`
- 踩坑速查：`../knowledge/pitfalls.md`
- 项目根 flash_env.sh：`/home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/flash_env.sh`
