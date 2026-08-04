# drafts/ — Agent 自动生成草稿的暂存区

> 按 D-004（维护模式 = Agent 自动扩写 + 用户审核）建立。
> Agent 在遇到**未覆盖问题**时自动生成草稿到 `pending/`，用户定期 review。

## 目录结构

```
agent/drafts/
├── README.md             # 本文件
├── pending/              # 草稿暂存（Agent 写入，用户审核）
└── archive/
    ├── accepted/         # 已通过审核并合并到 skill 的（保留备份）
    └── rejected/         # 拒绝的草稿（附拒绝原因）
```

## 草稿生命周期（GOVERNANCE.md §5）

```
[Agent 生成] ──> pending/
                      │
                      ├── 审核通过 ──> 移到 skill 的 knowledge/，改 status: beta
                      │                └── 备份到 archive/accepted/
                      │
                      ├── 有小问题 ──> 留在 pending/，Agent 修订
                      │
                      └── 严重错误 ──> archive/rejected/，附拒绝原因
```

## 命名约定

`pending/<topic-kebab-case>-<YYYYMMDD>.md`

例：
- `ed-setuvwavelength-default-20260718.md`
- `driver-wallclock-20260719.md`

## 审核清单（GOVERNANCE.md §5）

**格式合规**：frontmatter 齐全、3+ 源码锚点、代码 ≤ 20 行
**内容准确**：行号对、默认值/单位与 Config 一致、不写推测为事实
**边界清晰**：不与其他 skill 重复、不含跨单元复杂耦合
**可维护性**：last_verified 准确、tags 合理、§9 changelog 有"初始创建"行

## 审核工具

```bash
# 列出 pending 草稿
agent/tools/promote_draft.sh list

# 通过审核 → 移到 skill knowledge/
agent/tools/promote_draft.sh promote <file.md> <target-dir>

# 拒绝 → 移到 archive/rejected/，附原因
agent/tools/promote_draft.sh reject <file.md> "拒绝原因"
```

详见 `agent/tools/promote_draft.sh`。
