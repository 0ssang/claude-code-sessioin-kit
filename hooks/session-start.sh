#!/usr/bin/env bash
# SessionStart 훅 (startup | resume | clear | compact)
# 인계 노트, 최근 진행 로그, git 상태, (압축 직후라면) 압축 스냅샷을 Claude 컨텍스트에 주입한다.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[ -d "$MEM_DIR" ] || exit 0

SOURCE="$(jget .source)"
HANDOFF_CHARS="$(cfg handoff_inject_chars 4000)"
HAS=0

OUT="$(
  echo "## 🔁 이전 세션 맥락 (SessionStart: ${SOURCE:-unknown})"
  if [ -s "$MEM_DIR/handoff.md" ]; then
    echo; echo "### 인계 노트 (.claude-memory/handoff.md)"; clip_file "$HANDOFF_CHARS" "$MEM_DIR/handoff.md"
  fi
  if [ "$SOURCE" = "compact" ]; then
    SNAP="$(ls -t "$MEM_DIR"/snapshots/*-compact-*.md 2>/dev/null | head -n 1)"
    [ -n "$SNAP" ] && { echo; echo "### 압축 직전 자동 스냅샷 (${SNAP#"$ROOT"/})"; clip_file 3000 "$SNAP"; }
  fi
  P="$(recent_progress 8)"
  [ -n "$P" ] && { echo; echo "### 최근 진행 로그 (.claude-memory/progress.md)"; echo "$P"; }
  G="$(git_summary)"
  [ -n "$G" ] && { echo; echo "### Git"; echo "$G"; }
)"

# 실제로 복원할 내용이 있을 때만 주입
case "$OUT" in *"### "*) HAS=1;; esac
[ "$HAS" = 1 ] || exit 0

{
  echo "$OUT"
  echo
  case "$SOURCE" in
    compact) echo "→ 방금 컨텍스트가 압축되었다. 위 스냅샷과 노트로 맥락을 복원하고, 진행 중이던 작업의 관련 파일을 다시 읽은 뒤 이어서 진행하라.";;
    *)       echo "→ 위 맥락을 기준으로 이어서 작업하라. 노트의 내용은 실제 파일과 대조해 확인하라. 상세 복원은 /session-resume.";;
  esac
} | head -c 9500
exit 0
