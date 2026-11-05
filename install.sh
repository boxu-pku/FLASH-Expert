#!/usr/bin/env bash
# FLASH-Expert skill 包安装器
#
# 真身：本仓库 skills/（18 个自包含 skill）
# 安装 = 把 skills/<name> 挂载到各 harness 的 skills 目录（默认符号链接，--copy 复制）
#
# 用法：
#   ./install.sh                                  # 用户级：~/.claude/skills, ~/.zcode/skills, ~/.agents/skills
#   ./install.sh --scope project                  # 项目级：当前目录的 .claude/skills 等
#   ./install.sh --project /path/to/sim-repo      # 项目级：指定项目目录
#   ./install.sh --harness claude,agents          # 只装指定 harness
#   ./install.sh --copy                           # 复制模式（Windows / 不支持符号链接的环境）
#   ./install.sh --uninstall                      # 按安装方式移除
#
# harness → 目录映射（user 级为 ~/.<dir>/skills，project 级为 <proj>/.<dir>/skills）：
#   claude  → .claude   (Claude Code)
#   zcode   → .zcode    (ZCode)
#   agents  → .agents   (Agent Skills 跨 harness 标准目录：DSH、Codex CLI 等)
#   dsh     → .dsh      (DeepSeek Harness 一级目录，一般用 agents 即可)
set -euo pipefail

HARNESSES="claude,zcode,agents"
SCOPE="user"
COPY=0
UNINSTALL=0
PROJECT_DIR="$PWD"
MARKER=".flash-expert-manifest"

usage() { sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --harness)    HARNESSES="${2:?}"; shift 2 ;;
    --scope)      SCOPE="${2:?}"; shift 2 ;;
    --project)    SCOPE="project"; PROJECT_DIR="${2:?}"; shift 2 ;;
    --copy)       COPY=1; shift ;;
    --uninstall)  UNINSTALL=1; shift ;;
    -h|--help)    usage ;;
    *)            echo "未知参数: $1" >&2; usage ;;
  esac
done

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$PKG_DIR/skills"
[[ -d $SKILLS_DIR ]] || { echo "错误：找不到 $SKILLS_DIR（请在仓库根目录运行）" >&2; exit 1; }

skill_names() { ls -1 "$SKILLS_DIR" | grep -v '^flash-expert-manifest$'; }

target_root() {
  local h="$1" dir
  case "$h" in
    claude|zcode|dsh) dir=".$h" ;;
    agents)           dir=".agents" ;;
    *)                echo "未知 harness: $h（可选 claude/zcode/agents/dsh）" >&2; exit 1 ;;
  esac
  case "$SCOPE" in
    user)    echo "$HOME/$dir/skills" ;;
    project) echo "$PROJECT_DIR/$dir/skills" ;;
    *)       echo "--scope 只支持 user|project" >&2; exit 1 ;;
  esac
}

is_ours() {  # 目标是否为本包安装的符号链接（指回 PKG_DIR）
  [[ -L "$1" ]] && [[ "$(readlink -f "$1")" == "$SKILLS_DIR/"* ]]
}

for h in ${HARNESSES//,/ }; do
  t="$(target_root "$h")"
  echo "== harness: $h ($SCOPE 级 → $t)"

  if [[ $UNINSTALL -eq 1 ]]; then
    n=0
    for name in $(skill_names); do
      if is_ours "$t/$name"; then rm "$t/$name"; n=$((n+1))
      elif [[ -e "$t/$name" ]]; then echo "  跳过 $name（非本包符号链接）"
      fi
    done
    if [[ -f "$t/$MARKER" ]]; then  # 移除 --copy 安装的副本
      while read -r name; do
        [[ -d "$t/$name" ]] && rm -rf "${t:?}/$name"
      done < "$t/$MARKER"
      rm -f "$t/$MARKER"
    fi
    echo "  已卸载 $n 个链接"
    continue
  fi

  mkdir -p "$t"
  ok=0; skip=0
  for name in $(skill_names); do
    dest="$t/$name"
    if [[ -e "$dest" || -L "$dest" ]] && ! is_ours "$dest"; then
      echo "  跳过 $name（目标已存在且非本包链接，避免覆盖）"; skip=$((skip+1)); continue
    fi
    rm -rf "${dest:?}"
    if [[ $COPY -eq 1 ]]; then
      cp -r "$SKILLS_DIR/$name" "$dest"
      echo "$name" >> "$t/$MARKER"
    else
      ln -s "$SKILLS_DIR/$name" "$dest"
    fi
    ok=$((ok+1))
  done
  echo "  完成：$ok 安装，$skip 跳过（模式：$([[ $COPY -eq 1 ]] && echo 复制 || echo 符号链接)）"
done

if [[ $UNINSTALL -eq 0 ]]; then
  echo "完成。更新方式：git pull 后符号链接自动生效（--copy 模式需重新运行 ./install.sh）"
fi
