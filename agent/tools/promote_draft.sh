#!/usr/bin/env bash
# promote_draft.sh — FLASH Expert Agent 草稿审核升级工具
#
# 按 GOVERNANCE.md §5 审核流程：
#   pending/  → promote 到 skill knowledge/ (status: beta)
#             → reject 到 archive/rejected/  (附原因)
#             → leave 留在 pending/ 等修订
#
# 用法：
#   promote_draft.sh list                              列出 pending/ 中的草稿
#   promote_draft.sh show <file>                       查看草稿摘要（frontmatter + 前 50 行）
#   promote_draft.sh promote <file> <target-dir>       通过审核，移到 skill knowledge/
#   promote_draft.sh reject <file> <reason>            拒绝，移到 archive/rejected/
#   promote_draft.sh help                              显示帮助
#
# 例子：
#   promote_draft.sh list
#   promote_draft.sh promote pending/ed-setuvwavelength-20260718.md \
#                              .claude/skills/flash-laser/knowledge/
#   promote_draft.sh reject pending/some-draft.md "和 flash-laser/knowledge/params.md §3 重复"

set -euo pipefail

# 项目的 agent/ 路径解析（基于本脚本所在位置）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DRAFTS_DIR="$AGENT_DIR/drafts"
PENDING_DIR="$DRAFTS_DIR/pending"
ARCHIVE_DIR="$DRAFTS_DIR/archive"
REJECTED_DIR="$ARCHIVE_DIR/rejected"
ACCEPTED_DIR="$ARCHIVE_DIR/accepted"

PROJ_ROOT="$(cd "$AGENT_DIR/.." && pwd)"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
err()   { echo -e "${RED}✗${NC} $*" >&2; }
info()  { echo -e "${BLUE}ℹ${NC} $*"; }

# 确保目录存在
mkdir -p "$PENDING_DIR" "$REJECTED_DIR" "$ACCEPTED_DIR"

# ─── 帮助 ──────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
FLASH Expert Agent 草稿审核升级工具

用法:
  $(basename "$0") <command> [args]

命令:
  list                                 列出 pending/ 中的草稿
  show <file>                          查看草稿摘要
  promote <file> <target-dir>          通过审核，移到 skill knowledge/，自动改 status: beta
  reject <file> <reason>               拒绝草稿，移到 archive/rejected/，附原因
  help                                 显示此帮助

例子:
  $(basename "$0") list
  $(basename "$0") show pending/ed-setuvwavelength-20260718.md
  $(basename "$0") promote pending/foo-20260718.md .claude/skills/flash-laser/knowledge/
  $(basename "$0") reject pending/foo-20260718.md "和现有条目重复"

审核流程（GOVERNANCE.md §5）:
  1. Agent 在 pending/ 生成草稿
  2. 用户按审核清单 review
  3. 全部通过 → promote（status: draft → beta，备份到 archive/accepted/）
  4. 有小问题 → 留在 pending/，让 Agent 修订
  5. 严重错误 → reject（附原因）

文件位置:
  pending/:   $PENDING_DIR
  accepted/:  $ACCEPTED_DIR
  rejected/:  $REJECTED_DIR
EOF
}

# ─── list ─────────────────────────────────────────────────────────────
cmd_list() {
    info "pending/ 草稿（$PENDING_DIR）:"
    echo
    local count=0
    if compgen -G "$PENDING_DIR/*.md" > /dev/null; then
        for f in "$PENDING_DIR"/*.md; do
            count=$((count+1))
            local name title skill status
            name="$(basename "$f")"
            # 提取 frontmatter 关键字段
            title="$(awk -F': *' '/^title:/{print $2; exit}' "$f" 2>/dev/null || echo '?')"
            skill="$(awk -F': *' '/^skill:/{print $2; exit}' "$f" 2>/dev/null || echo '?')"
            status="$(awk -F': *' '/^status:/{print $2; exit}' "$f" 2>/dev/null || echo '?')"
            printf "  ${GREEN}[%d]${NC} %s\n" "$count" "$name"
            printf "      title:  %s\n" "$title"
            printf "      skill:  %s\n" "$skill"
            printf "      status: %s\n" "$status"
            echo
        done
    fi
    if [[ $count -eq 0 ]]; then
        echo "  (空)"
    fi
    echo
    info "共 $count 条草稿待审核"
}

# ─── show ─────────────────────────────────────────────────────────────
cmd_show() {
    local file="$1"
    local path="$(resolve_path "$file")"
    if [[ ! -f "$path" ]]; then
        err "文件不存在: $file"
        exit 1
    fi
    info "草稿: $path"
    echo
    echo "── frontmatter ──"
    awk '/^---$/{c++; if(c==2) exit; if(c==1) next} c==1{print}' "$path"
    echo
    echo "── 前 50 行（去 frontmatter）──"
    awk '/^---$/{c++; if(c==2){p=1; next}} p{print}' "$path" | head -50
    echo
    info "完整内容用: cat $path"
}

# ─── promote ──────────────────────────────────────────────────────────
cmd_promote() {
    local file="$1"
    local target_dir="$2"
    local path="$(resolve_path "$file")"

    if [[ ! -f "$path" ]]; then
        err "草稿不存在: $file"
        exit 1
    fi

    # target_dir 是相对项目根的路径
    local target_abs
    if [[ "$target_dir" = /* ]]; then
        target_abs="$target_dir"
    else
        target_abs="$PROJ_ROOT/$target_dir"
    fi

    if [[ ! -d "$target_abs" ]]; then
        err "目标目录不存在: $target_abs"
        err "应该是 .claude/skills/<skill-name>/knowledge/ 或 agent/manual/<chapter>/"
        exit 1
    fi

    local basename_file
    basename_file="$(basename "$path")"

    # 备份到 archive/accepted/（带时间戳防覆盖）
    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"
    local backup="$ACCEPTED_DIR/${basename_file%.md}-promoted-$timestamp.md"
    cp "$path" "$backup"

    # 移到目标目录
    local target_file="$target_abs/$basename_file"
    if [[ -f "$target_file" ]]; then
        warn "目标已存在，覆盖: $target_file"
    fi
    mv "$path" "$target_file"

    # 把 status: draft 改为 status: beta（如果存在）
    if grep -q "^status:.*draft" "$target_file"; then
        sed -i "s/^status:.*draft.*/status: beta/" "$target_file"
        ok "status: draft → beta"
    fi

    # 把 last_verified 更新为今天
    local today
    today="$(date +%Y-%m-%d)"
    if grep -q "^last_verified:" "$target_file"; then
        sed -i "s/^last_verified:.*/last_verified: $today/" "$target_file"
        ok "last_verified: → $today"
    fi

    ok "草稿已 promote:"
    echo "  → $target_file"
    echo "  备份: $backup"
    echo
    warn "下一步（手动）:"
    echo "  1. 在 skill SKILL.md §8 维护日志加一行"
    echo "  2. 在 PROJECT_PLAN.md §9 变更日志加一行"
    echo "  3. 检查是否要更新 §10 下一步行动"
}

# ─── reject ───────────────────────────────────────────────────────────
cmd_reject() {
    local file="$1"
    local reason="${2:-未提供原因}"

    local path="$(resolve_path "$file")"
    if [[ ! -f "$path" ]]; then
        err "草稿不存在: $file"
        exit 1
    fi

    local basename_file
    basename_file="$(basename "$path")"
    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"
    local target="$REJECTED_DIR/${basename_file%.md}-rejected-$timestamp.md"

    # 在文件末尾追加拒绝原因
    {
        echo
        echo "---"
        echo
        echo "## 拒绝记录"
        echo
        echo "- **拒绝日期**: $(date +%Y-%m-%d)"
        echo "- **拒绝原因**: $reason"
        echo
    } >> "$path"

    mv "$path" "$target"

    ok "草稿已拒绝:"
    echo "  → $target"
    echo "  原因: $reason"
}

# ─── 辅助 ─────────────────────────────────────────────────────────────
# 解析路径：支持 pending/foo.md 和绝对路径和相对当前目录
resolve_path() {
    local input="$1"
    # 绝对路径
    if [[ "$input" = /* ]]; then
        echo "$input"
        return
    fi
    # pending/foo.md 形式
    if [[ "$input" = pending/* ]]; then
        echo "$DRAFTS_DIR/$input"
        return
    fi
    # 相对当前目录
    if [[ -f "$input" ]]; then
        echo "$input"
        return
    fi
    # 最后兜底：当作 pending/ 下的文件名
    echo "$PENDING_DIR/$input"
}

# ─── 主入口 ───────────────────────────────────────────────────────────
main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        list)
            cmd_list "$@"
            ;;
        show)
            if [[ $# -lt 1 ]]; then
                err "用法: $0 show <file>"
                exit 1
            fi
            cmd_show "$1"
            ;;
        promote)
            if [[ $# -lt 2 ]]; then
                err "用法: $0 promote <file> <target-dir>"
                err "例: $0 promote pending/foo.md .claude/skills/flash-laser/knowledge/"
                exit 1
            fi
            cmd_promote "$1" "$2"
            ;;
        reject)
            if [[ $# -lt 1 ]]; then
                err "用法: $0 reject <file> [reason]"
                exit 1
            fi
            cmd_reject "$1" "${2:-未提供原因}"
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            err "未知命令: $cmd"
            usage
            exit 1
            ;;
    esac
}

main "$@"
