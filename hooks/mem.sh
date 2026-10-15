#!/usr/bin/env bash
# 스킬(/session-save, /session-resume)이 호출하는 조회 도구. 표준입력을 읽지 않는다.
#   mem.sh changes   — 가장 최근 세션의 변경 파일
#   mem.sh overview  — 인계 노트·스냅샷·로그·git 요약
KIT_NO_STDIN=1
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

changes() {
  local d; d="$(ls -td "$RUNTIME_DIR"/sessions/*/ 2>/dev/null | head -n 1)"
  if [ -n "$d" ] && [ -f "${d%/}/changes.log" ]; then
    awk '{print $3}' "${d%/}/changes.log" | awk '!seen[$0]++' | tail -n 50
  else
    echo "(기록된 변경 없음)"
  fi
}

overview() {
  echo "### 인계 노트"
  if [ -f "$MEM_DIR/handoff.md" ]; then echo "(저장: $(date -r "$MEM_DIR/handoff.md" '+%Y-%m-%d %H:%M' 2>/dev/null))"; cat "$MEM_DIR/handoff.md"; else echo "(없음)"; fi
  echo; echo "### 최근 스냅샷 (최신순)"
  ls -t "$MEM_DIR"/snapshots/ 2>/dev/null | head -n 5 | sed 's/^/- /' || true
  echo; echo "### 최근 진행 로그"
  recent_progress 15
  echo; echo "### 최근 세션"
  grep -E '^- ' "$MEM_DIR/session-log.md" 2>/dev/null | tail -n 5
  echo; echo "### Git"
  git_summary
}

case "${1:-overview}" in
  changes) changes;;
  *) overview;;
esac
exit 0
