#!/usr/bin/env bash
# PostToolUse 훅 (Edit|Write|MultiEdit|NotebookEdit) — 세션별 변경 파일 기록
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[ -d "$MEM_DIR" ] || exit 0

FP="$(jget '.tool_input.file_path // .tool_input.notebook_path')"
[ -n "$FP" ] || exit 0
D="$(session_dir)"
mkdir -p "$D" 2>/dev/null || exit 0
echo "$(date '+%H:%M:%S') $(jget .tool_name) ${FP#"$ROOT"/}" >> "$D/changes.log"
exit 0
