#!/usr/bin/env bash
# SessionEnd 훅 — 세션 종료 시 한 줄 기록 (기본 타임아웃 1.5초이므로 가볍게 유지)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[ -d "$MEM_DIR" ] || exit 0

SID="$(jget .session_id)"
LOG="$MEM_DIR/session-log.md"
[ -f "$LOG" ] || printf '# 세션 로그\n\n' > "$LOG"
N=0
CL="$(session_dir)/changes.log"
[ -f "$CL" ] && N="$(awk '{print $3}' "$CL" | sort -u | wc -l | tr -d ' ')"
echo "- $(date '+%Y-%m-%d %H:%M') 세션 ${SID:0:8} 종료($(jget .reason)) · 변경 파일 ${N}개" >> "$LOG"

find "$RUNTIME_DIR/sessions" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null
exit 0
