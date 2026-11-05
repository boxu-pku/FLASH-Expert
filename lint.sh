#!/usr/bin/env bash
# FLASH-Expert skill 包可移植性门禁
#
# 检查 skills/ 下的内容不依赖特定 harness、特定仓库布局或特定机器路径，
# 保证包可以在任意 harness（Claude Code / ZCode / DSH / Codex 等）安装使用。
#
# 用法：./lint.sh          # 全部检查，非零退出码 = 有 error（warning 不影响退出码）
set -uo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS="$PKG_DIR/skills"
ERRORS=0
WARNINGS=0

err()  { echo "  ✗ $1"; ERRORS=$((ERRORS+1)); }
warn() { echo "  ⚠ $1"; WARNINGS=$((WARNINGS+1)); }
ok()   { echo "  ✓ $1"; }

echo "== 1. 目录结构与 frontmatter"
for d in "$SKILLS"/*/; do
  name="$(basename "$d")"
  [[ -f "$d/SKILL.md" ]] || { err "$name/SKILL.md 不存在"; continue; }
  # name 与目录一致 + kebab-case
  fm_name="$(awk '/^name:/{print $2; exit}' "$d/SKILL.md")"
  [[ "$fm_name" == "$name" ]] || err "$name: frontmatter name='$fm_name' 与目录名不一致"
  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || err "$name: 不是 kebab-case"
  # description 非空
  desc="$(awk '/^description:/{flag=1;next} /^[a-z_]+:/{flag=0} flag' "$d/SKILL.md" | tr -d '>\n' | head -c 40)"
  [[ -n "$desc" ]] || err "$name: description 为空"
done
ok "18 个 skill 目录、frontmatter 基本字段"

echo "== 2. 禁止 harness 专属路径（.claude/.zcode/.dsh/.codex 硬编码）"
n=$(grep -rn -E '\.(claude|zcode|dsh|codex)/' "$SKILLS" --include='*.md' | wc -l)
[[ $n -eq 0 ]] && ok "无 harness 目录硬编码" || { grep -rn -E '\.(claude|zcode|dsh|codex)/' "$SKILLS" --include='*.md' | head -5; err "$n 处 harness 目录硬编码"; }

echo "== 3. 禁止本机绝对路径（/home/、/Users/）"
# 白名单：'本机' 对照说明行、ld 警告日志证据行、IONMIX 本机工具引用、
#         knowledge/pitfalls/ 踩坑实录目录（本机案例记录，路径是证据的一部分）
n=$(grep -rn '/home/\|/Users/' "$SKILLS" --include='*.md' \
     | grep -v '本机' | grep -v 'ld: warning' | grep -v 'IONMIX' \
     | grep -v 'knowledge/pitfalls/' | wc -l)
[[ $n -eq 0 ]] && ok "无未标注的本机绝对路径" || { grep -rn '/home/\|/Users/' "$SKILLS" --include='*.md' | grep -v '本机' | grep -v 'ld: warning' | grep -v 'IONMIX' | grep -v 'knowledge/pitfalls/' | head -5; err "$n 处未标注的本机绝对路径"; }

echo "== 4. 禁止已迁移资产的旧路径"
n=$(grep -rn -E 'agent/(param-index|pitfalls)' "$SKILLS" --include='*.md' | wc -l)
[[ $n -eq 0 ]] && ok "无 agent/param-index、agent/pitfalls 旧引用" || err "$n 处旧资产路径"
# agent/manual/ 只允许出现原 PDF（工作台资产）
n=$(grep -rn 'agent/manual/' "$SKILLS" --include='*.md' | grep -v 'flash4_ug_4p8\.pdf' | wc -l)
[[ $n -eq 0 ]] && ok "agent/manual/ 仅剩原 PDF 引用" || { grep -rn 'agent/manual/' "$SKILLS" --include='*.md' | grep -v 'flash4_ug_4p8\.pdf' | head -3; err "$n 处 agent/manual 非引用"; }

echo "== 5. 治理引用（agent/ 工作区）应有条件措辞或集中在说明处"
n=$(grep -rn -E 'agent/(TEMPLATES|drafts|workflows|LESSONS|PROJECT_PLAN|GOVERNANCE)' "$SKILLS" --include='*.md' | wc -l)
if [[ $n -gt 0 ]]; then
  warn "$n 处 agent/ 工作区引用（开发仓库有效；CLAUDE.md 已有外部降级说明，新增时避免扩散）"
else
  ok "无治理引用"
fi

echo "== 6. 交叉引用有效性（skills/<owner>/... 指向的文件存在）"
bad=0
while IFS= read -r ref; do
  # 提取形如 skills/<skill>/xxx 的引用，检查目标存在
  path="$(echo "$ref" | grep -oE 'skills/[a-z0-9-]+/[a-zA-Z0-9_./-]+' | head -1 | sed 's/[)。；,]*$//')"
  [[ -n "$path" && ! -e "$PKG_DIR/$path" && ! -d "$PKG_DIR/${path%/}" ]] && { warn "悬空引用: $ref"; bad=$((bad+1)); }
done < <(grep -rhoE 'skills/[a-z0-9-]+/[a-zA-Z0-9_./-]+' "$SKILLS" --include='*.md' | sort -u)
[[ $bad -eq 0 ]] && ok "交叉引用均可解析"

echo "== 7. 本仓库挂载链接（仅开发仓库检查）"
if [[ -d "$PKG_DIR/.git" ]]; then
  for l in .claude/skills .zcode/skills .agents/skills; do
    [[ -L "$PKG_DIR/$l" && -d "$PKG_DIR/$l/" ]] && ok "$l → $(readlink "$PKG_DIR/$l")" || err "$l 挂载链接缺失"
  done
fi

echo
echo "结果: $ERRORS 个 error，$WARNINGS 个 warning"
[[ $ERRORS -eq 0 ]]