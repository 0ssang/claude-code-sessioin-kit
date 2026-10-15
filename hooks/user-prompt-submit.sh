#!/usr/bin/env bash
# UserPromptSubmit 훅 — 마지막 토큰 사용량이 기준을 넘으면 /session-save 를 제안하도록 경고를 주입한다.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TP="$(jget .transcript_path)"
LIMIT="$(cfg context_warn_tokens 150000)"
[ -n "$TP" ] && [ -f "$TP" ] || exit 0

USED="$(tail -n 400 "$TP" 2>/dev/null | jq -R -n '
  reduce (inputs | fromjson?) as $e (0;
    if ($e.type == "system" and $e.subtype == "compact_boundary") then 0
    elif ($e.type == "assistant" and ($e.isSidechain != true) and ($e.message.usage? != null)) then
      ($e.message.usage | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))
    else . end)' 2>/dev/null)"

if [ -n "$USED" ] && [ "$USED" -ge "$LIMIT" ] 2>/dev/null; then
  echo "[session-kit] ⚠ 컨텍스트 사용량 약 ${USED} tokens (경고 기준 ${LIMIT}). 지금 요청을 처리하되, 현재 작업 단위를 마무리한 뒤 사용자에게 /session-save → /clear 를 제안하라."
fi
exit 0
