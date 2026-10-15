#!/usr/bin/env bash
# PreCompact 훅 (manual | auto)
# 압축으로 대화 세부가 사라지기 전에 스냅샷을 남긴다 → .claude-memory/snapshots/<시각>-compact-<trigger>.md
# 압축 직후 SessionStart(compact) 훅이 최신 스냅샷을 다시 주입한다.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[ -d "$MEM_DIR" ] || exit 0

TRIGGER="$(jget .trigger)"
TP="$(jget .transcript_path)"
CUSTOM="$(jget .custom_instructions)"
KEEP="$(cfg snapshot_keep 20)"
SNAP_DIR="$MEM_DIR/snapshots"
mkdir -p "$SNAP_DIR" 2>/dev/null || exit 0
OUT="$SNAP_DIR/$(date +%Y%m%d-%H%M%S)-compact-${TRIGGER:-unknown}.md"

{
  echo "# 압축 전 자동 스냅샷 (${TRIGGER:-unknown}) — $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- session: $(jget .session_id)"
  [ -n "$CUSTOM" ] && echo "- /compact 지시: $CUSTOM"

  echo; echo "## 이번 세션 변경 파일"
  if [ -f "$(session_dir)/changes.log" ]; then
    awk '{print $3}' "$(session_dir)/changes.log" | awk '!seen[$0]++' | tail -n 40 | sed 's/^/- /'
  else
    echo "(없음)"
  fi

  G="$(git_summary)"; [ -n "$G" ] && { echo; echo "## Git"; echo "$G"; }

  if [ -n "$TP" ] && [ -f "$TP" ]; then
    echo; echo "## 최근 사용자 요청 (시간순, 최대 10개)"
    tail -n 4000 "$TP" | jq -R -r '
      fromjson?
      | select(.type == "user" and (.isMeta != true) and (.isSidechain != true))
      | .message.content
      | (if type == "string" then . elif type == "array" then ([.[] | select(.type == "text") | .text] | join(" ")) else "" end)
      | if test("<command-name>") then
          "[명령] " + ((try capture("<command-name>(?<c>[^<]*)</command-name>").c catch "") // "")
          + " " + ((try capture("<command-args>(?<a>[^<]*)</command-args>").a catch "") // "")
        elif startswith("<") then empty
        else . end
      | gsub("\\s+"; " ") | select(length > 1) | .[0:400] | @json' 2>/dev/null \
      | tail -n 10 | jq -r '"- " + .' 2>/dev/null

    echo; echo "## 마지막 어시스턴트 응답 (요지)"
    tail -n 4000 "$TP" | jq -R -r '
      fromjson?
      | select(.type == "assistant" and (.isSidechain != true))
      | [.message.content[]? | select(.type == "text") | .text] | join("\n")
      | select(length > 0) | .[0:1500] | @json' 2>/dev/null \
      | tail -n 2 | jq -r '. + "\n---"' 2>/dev/null
  fi
} > "$OUT" 2>/dev/null

ls -t "$SNAP_DIR"/*-compact-*.md 2>/dev/null | tail -n +"$((KEEP + 1))" | while IFS= read -r old; do rm -f "$old"; done
exit 0
