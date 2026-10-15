---
name: session-save
description: 현재 세션의 작업 맥락(목표, 진행 상황, 결정, 다음 할 일, 주의사항)을 .claude-memory/handoff.md에 저장한다. 작업 단위가 끝났을 때, 세션을 바꾸거나 /clear 하기 전, 컨텍스트가 길어졌을 때 사용한다.
argument-hint: "[추가 메모]"
---

# 세션 인계 노트 저장

추가 메모: `$ARGUMENTS`

## 이번 세션 변경 파일 (훅 기록)
!`bash "__KIT_DIR__/mem.sh" changes 2>&1 || true`

## 기존 인계 노트
!`ls -l .claude-memory/handoff.md 2>/dev/null || echo "(없음 — .claude-memory/ 가 없으면 이번에 만든다)"`

## 절차
1. **준비** — `.claude-memory/`가 없으면 만든다(`mkdir -p .claude-memory/snapshots`). 이 폴더가 생기면 이 프로젝트에서 세션 훅이 켜진다.
2. **기존 노트 백업** — handoff.md가 있으면 먼저 옮긴다.
   ```bash
   cp .claude-memory/handoff.md ".claude-memory/snapshots/handoff-$(date +%Y%m%d-%H%M%S).md"
   ```
3. **로그 보완** — 이번 세션에서 끝낸 일을 `.claude-memory/progress.md`에, 내린 결정을 `.claude-memory/decisions.md`에 추가한다(형식은 `.claude/rules/session-memory.md` 참고).
4. **handoff.md 작성** — 대화 전체를 돌아보고 아래 형식으로 새로 쓴다.
   - 새 세션에서 앞부분 약 4,000자만 자동 주입되므로 **중요한 내용을 위에** 쓴다.
   - 다음 세션의 내가 이 노트만 보고 바로 이어갈 수 있게 구체적으로 쓴다: 파일 경로, 함수명, 명령, 에러 메시지.
   - 파일에 이미 있는 내용은 복사하지 말고 경로로 가리킨다.

```markdown
# 세션 인계 노트
- 저장: YYYY-MM-DD HH:MM

## TL;DR
<지금 무엇을 하고 있고 어디까지 왔는지 2~3줄>

## 다음에 할 일 (우선순위순)
1. <구체적 행동>

## 진행 중이던 작업 (중단 지점)
- 작업: <무엇> · 상태: <어디까지>
- 실패 중인 테스트 / 에러: <명령과 핵심 메시지>
- 원인 가설과 시도한 것: <…>

## 이번 세션에서 한 일
- …

## 결정 사항
- <결정과 이유> (decisions.md 반영 여부)

## 미해결 질문 · 블로커
- …

## 주의사항 (Gotchas)
- <시행착오, 하면 안 되는 것, 환경 특이사항>

## 관련 파일
- <경로 — 왜 중요한지>
```

5. **보고** — 저장했다고 알리고 안내한다: "이제 `/clear`하거나 새 세션을 열어도 이 노트가 자동으로 불러와집니다. 더 자세히 복원하려면 `/session-resume`을 쓰세요."
