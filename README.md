# claude-session-kit

Claude Code에서 `/clear`나 자동 압축 뒤에도 **이전 세션의 작업 맥락을 이어가게 해 주는** 훅·스킬 묶음입니다.

- `/session-save`로 인계 노트를 저장해 두면, `/clear` 뒤나 새 세션을 열 때 그 노트를 자동으로 불러옵니다.
- 저장을 잊은 채 자동 압축이 일어나도, 압축 직전에 최근 요청·변경 파일·git 상태를 스냅샷으로 남겼다가 압축 직후 다시 불러옵니다.
- 토큰 사용량이 기준을 넘으면 Claude가 먼저 저장을 제안합니다.

필요 도구: `bash`, `jq` (macOS는 기본 포함, 없으면 `brew install jq`)

## 설치

```bash
# A. 특정 프로젝트에만 (설치된 파일을 커밋하면 팀원도 그대로 사용)
./install.sh /path/to/project

# B. 내 모든 프로젝트에 (~/.claude 에 설치)
./install.sh --global
```

- 설치 후 **Claude Code 세션을 새로 시작**하세요. `/hooks`로 등록됐는지 확인할 수 있습니다.
- 기존 `settings.json`의 다른 설정과 훅은 유지되고, 이 키트의 훅만 덧붙습니다. 원본은 `settings.json.bak`으로 백업됩니다. 여러 번 실행해도 중복 등록되지 않습니다.
- **전역 모드는 프로젝트별로 켜집니다.** 프로젝트에 `.claude-memory/` 폴더가 있을 때만 기록하고 불러옵니다. 그 프로젝트에서 처음 `/session-save`를 실행하면 폴더가 생깁니다. 그래서 다른 프로젝트에 파일이 함부로 생기지 않습니다.

## 사용법

```text
... 작업 ...
/session-save          # 작업 단위가 끝나면 인계 노트 저장
/clear                 # 컨텍스트 비우기 → 인계 노트가 자동으로 다시 들어옴
... 이어서 작업 ...
/session-resume        # 더 자세히 복원하고 싶을 때 (노트 전체, 스냅샷, 로그, git 대조)
```

경고(`⚠ 컨텍스트 사용량`)가 뜨기 전에, 작업 단위가 끝날 때마다 `/session-save` → `/clear` 하는 습관을 추천합니다. 자동 압축 요약보다 직접 저장한 노트가 훨씬 정확합니다.

## 동작 방식

| 시점 | 동작 | 주체 |
|---|---|---|
| 매 세션 | `rules/session-memory.md`(메모리 사용 규칙) 로드 | Claude Code 기본 기능 |
| 세션 시작 · `/clear` · 재개 | 인계 노트(앞 4,000자), 최근 진행 로그, git 요약 주입 | `SessionStart` 훅 |
| 압축 직전 | 변경 파일, 최근 사용자 요청, 마지막 응답, git 상태를 스냅샷으로 저장 | `PreCompact` 훅 |
| 압축 직후 | 위 스냅샷과 인계 노트 다시 주입 | `SessionStart(compact)` 훅 |
| 매 프롬프트 | 토큰 사용량이 기준을 넘으면 저장 제안 | `UserPromptSubmit` 훅 |
| 파일 수정 | 세션별 변경 파일 기록 | `PostToolUse` 훅 |
| 세션 종료 | 세션 로그에 한 줄 기록 | `SessionEnd` 훅 |
| 사람이 실행 | 인계 노트 작성 / 상세 복원 | `/session-save` / `/session-resume` 스킬 |

## 파일

```text
설치되는 것 (<base> = 프로젝트/.claude 또는 ~/.claude)
  <base>/hooks/session/*.sh            훅 6개 + 조회 도구 mem.sh
  <base>/skills/session-save/          /session-save
  <base>/skills/session-resume/        /session-resume
  <base>/rules/session-memory.md       메모리 사용 규칙
  <base>/settings.json                 훅 등록 (병합)

프로젝트에 생기는 것
  .claude-memory/
    handoff.md        인계 노트 (최신)
    progress.md       작업 로그
    decisions.md      결정 기록
    session-log.md    세션 종료 기록
    snapshots/        압축 스냅샷, 이전 인계 노트 (git 제외)
    .runtime/         세션별 변경 파일 기록 (git 제외)
    config.json       설정 (선택)
```

## 설정 (`.claude-memory/config.json`, 없으면 기본값)

| 키 | 기본값 | 설명 |
|---|---|---|
| `context_warn_tokens` | `150000` | 이 값을 넘으면 저장을 제안합니다. 1M 컨텍스트 모델을 쓴다면 높이세요 |
| `handoff_inject_chars` | `4000` | 자동으로 넣을 인계 노트 길이 (훅 주입 한도는 약 10,000자) |
| `snapshot_keep` | `20` | 보관할 압축 스냅샷 수 |

## 제거
`<base>/settings.json`에서 `hooks/session/`이 들어간 훅을 지우고, 위 "설치되는 것" 목록의 파일을 삭제하세요.
