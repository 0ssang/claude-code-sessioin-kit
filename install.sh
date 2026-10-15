#!/usr/bin/env bash
# claude-session-kit 설치
#   ./install.sh <프로젝트 경로>   — 해당 프로젝트에만 설치 (팀과 git으로 공유 가능)
#   ./install.sh --global          — ~/.claude 에 설치 (모든 프로젝트, 단 .claude-memory/ 가 있는 프로젝트에서만 동작)
# 여러 번 실행해도 안전하다(훅 중복 등록 안 함, 기존 메모리 파일 보존).
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { echo "❌ $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq가 필요합니다: brew install jq"

MODE="${1:-}"
[ -n "$MODE" ] || die "사용법: ./install.sh <프로젝트 경로> | --global"

if [ "$MODE" = "--global" ]; then
  BASE="$HOME/.claude"
  HOOK_DIR="$BASE/hooks/session"
  CMD_PREFIX="$HOOK_DIR"                          # 절대 경로
  SKILL_KIT_DIR="$HOOK_DIR"
  PROJECT=""
else
  PROJECT="$(cd "$MODE" && pwd)" || die "경로가 없습니다: $MODE"
  BASE="$PROJECT/.claude"
  HOOK_DIR="$BASE/hooks/session"
  CMD_PREFIX='$CLAUDE_PROJECT_DIR/.claude/hooks/session'   # 이식 가능한 경로
  SKILL_KIT_DIR=".claude/hooks/session"
fi

echo "▶ 설치 위치: $BASE"

# 0) 기존 settings.json 이 올바른 JSON인지 먼저 확인 (실패 시 아무 파일도 건드리지 않음)
SETTINGS="$BASE/settings.json"
if [ -f "$SETTINGS" ]; then
  jq empty "$SETTINGS" 2>/dev/null || die "$SETTINGS 를 JSON으로 읽을 수 없습니다(주석·문법 오류 등). 아무것도 바꾸지 않았습니다 — 훅은 README의 형식대로 직접 추가하세요."
fi

# 1) 훅 스크립트
mkdir -p "$HOOK_DIR"
cp "$KIT"/hooks/*.sh "$HOOK_DIR/"
chmod +x "$HOOK_DIR"/*.sh

# 2) 스킬 (기존 것이 있으면 .bak 으로 백업)
for s in session-save session-resume; do
  dst="$BASE/skills/$s"
  if [ -f "$dst/SKILL.md" ] && ! grep -q "__KIT_MARK__\|mem.sh" "$dst/SKILL.md"; then
    cp "$dst/SKILL.md" "$dst/SKILL.md.bak"; echo "  ⚠ 기존 $s 스킬을 SKILL.md.bak 으로 백업"
  fi
  mkdir -p "$dst"
  sed "s|__KIT_DIR__|$SKILL_KIT_DIR|g" "$KIT/skills/$s/SKILL.md" > "$dst/SKILL.md"
done

# 3) 규칙 (매 세션 자동 로드)
mkdir -p "$BASE/rules"
cp "$KIT/rules/session-memory.md" "$BASE/rules/session-memory.md"

# 4) settings.json 에 훅 병합 (백업 후, 이미 등록된 훅은 건너뜀)
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp -p "$SETTINGS" "$SETTINGS.bak"
tmp="$(mktemp)"
if ! jq --arg p "$CMD_PREFIX" '
  def add(ev; m; script; extra):
    ("bash \"" + $p + "/" + script + "\"") as $cmd
    | if ([.hooks[ev][]?.hooks[]?.command] | any(. != null and contains("hooks/session/" + script))) then .
      else .hooks[ev] = ((.hooks[ev] // []) + [
        ((if m == null then {} else {matcher: m} end)
         + {hooks: [({type: "command", command: $cmd} + extra)]})
      ]) end;
  .hooks //= {}
  | add("SessionStart"; "startup|resume|clear|compact"; "session-start.sh"; {})
  | add("UserPromptSubmit"; null; "user-prompt-submit.sh"; {})
  | add("PostToolUse"; "Edit|Write|MultiEdit|NotebookEdit"; "track-changes.sh"; {})
  | add("PreCompact"; "manual|auto"; "pre-compact.sh"; {timeout: 30})
  | add("SessionEnd"; null; "session-end.sh"; {})
' "$SETTINGS" > "$tmp"; then
  rm -f "$tmp"; die "settings.json 병합 실패. 원본은 그대로입니다."
fi
cat "$tmp" > "$SETTINGS" && rm -f "$tmp"     # cat 으로 덮어써 원본 파일 권한 유지
echo "  ✓ 훅 등록: $SETTINGS (백업: settings.json.bak — 원본에 토큰이 있다면 백업에도 있으니 확인 후 삭제하세요)"

# 5) 프로젝트 모드: 메모리 폴더 생성 + .gitignore
if [ -n "$PROJECT" ]; then
  M="$PROJECT/.claude-memory"
  mkdir -p "$M/snapshots"
  [ -f "$M/progress.md" ]    || printf '# 진행 로그\n\n' > "$M/progress.md"
  [ -f "$M/decisions.md" ]   || printf '# 결정 기록\n\n' > "$M/decisions.md"
  [ -f "$M/session-log.md" ] || printf '# 세션 로그\n\n' > "$M/session-log.md"
  [ -f "$M/config.json" ]    || printf '{\n  "context_warn_tokens": 150000,\n  "handoff_inject_chars": 4000,\n  "snapshot_keep": 20\n}\n' > "$M/config.json"
  GI="$PROJECT/.gitignore"
  for line in ".claude-memory/.runtime/" ".claude-memory/snapshots/" ".claude/settings.json.bak"; do
    grep -qxF "$line" "$GI" 2>/dev/null || echo "$line" >> "$GI"
  done
  echo "  ✓ 메모리 폴더: $M"
else
  echo "  ℹ 전역 모드: 프로젝트에서 처음 /session-save 를 실행하면 .claude-memory/ 가 생기고 그때부터 훅이 동작합니다."
fi

echo "✅ 설치 완료 — Claude Code 세션을 새로 시작하세요. (/hooks 로 등록 확인)"
