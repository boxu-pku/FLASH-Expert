# flash-setup-builder examples

本目录是 setup 命令的可直接复制模板。

## 文件清单

| 文件 | 内容 | 用途 |
|---|---|---|
| `sedov-minimal.sh` | Sedov 最小 setup 命令 | 验证编译环境，第一次跑 FLASH |
| `laserslab-hedp.sh` | LaserSlab HEDP 主流 setup 命令 | 标准 HEDP 激光打靶算例 |
| `custom-recipe.sh` | 4 个变体 setup 命令（3D / Debug / 多物质 / MHD）| 进阶场景 |

## 用法

```bash
# 1. 复制需要的模板到工作目录
cp /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8/skills/flash-setup-builder/examples/<file>.sh /tmp/

# 2. 按需修改（改算例名、objdir、parfile 等）
vi /tmp/<file>.sh

# 3. 执行（在 FLASH 根目录）
cd /home/ubuntu/local/flash/FLASH4.8/FLASH/FLASH4.8
bash /tmp/<file>.sh
```

## 注意

- 这些是 setup 命令模板（**不包含 make 和 run**）
- setup 后请参考 `flash-case-runner` skill 做 make + run
- 本机编译前可能要处理 libmpi.so.40 冲突（见 `../knowledge/pitfalls.md` §6）

## 模板内容速览

详细解释见 `../knowledge/recipes.md`。本目录的 .sh 文件是 recipes.md 的可执行版本。

## 反馈

如果模板跑不通或需要新场景，提 issue 到 `agent/drafts/pending/`。
