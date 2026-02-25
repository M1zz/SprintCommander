# SprintCommander x Claude Code 연동 가이드

SprintCommander는 프로젝트 소스 디렉토리 내 `.sprintcommander/tasks.json`을 실시간 감시합니다.
Claude Code가 이 파일을 수정하면 칸반 보드에 즉시 반영됩니다.

이 문서는 Claude Code를 활용해 스프린트 백로그를 자동 생성하는 방법을 안내합니다.

---

## 1. 구조

SprintCommander에서 프로젝트를 추가하면 소스 디렉토리에 아래 구조가 자동 생성됩니다.

```
프로젝트 소스 디렉토리/
├── CLAUDE.md                ← (선택) Claude Code 규칙 파일
├── .sprintcommander/
│   ├── _schema.json         ← 태스크 스키마 + projectId
│   ├── project.json         ← 프로젝트 메타 (읽기 전용)
│   └── tasks.json           ← 칸반 태스크 배열 (Claude가 수정)
└── (소스 코드)
```

- `_schema.json` — Claude가 태스크 포맷과 projectId를 확인하는 참조 파일
- `tasks.json` — Claude가 읽고 수정하는 태스크 배열. 변경되면 앱이 0.3초 내 자동 감지
- 변경된 태스크는 CloudKit을 통해 다른 기기에도 동기화됨

---

## 2. 설정 방법

### 방법 A: 전역 설정 (모든 프로젝트에 적용)

`~/CLAUDE.md`에 규칙을 작성하면 어떤 프로젝트에서 Claude Code를 열든 자동 적용됩니다.

**파일 위치:** `~/CLAUDE.md`

```markdown
## 스프린트 백로그 생성

사용자가 "백로그 만들어", "스프린트 분석해", "태스크 생성해"라고 하면:

1. `.sprintcommander/_schema.json`에서 projectId와 포맷 확인
2. `.sprintcommander/tasks.json`에서 기존 태스크 확인 (중복 금지, 기존 태스크 반드시 유지)
3. 소스 코드를 탐색해서 아래 기준으로 태스크 도출:
   - TODO/FIXME/HACK 주석
   - 에러 핸들링이 부족한 곳 (try? 남용, 빈 catch 등)
   - 테스트가 없는 핵심 로직
   - 접근성(Accessibility) 미비
   - 성능 개선 포인트 (불필요한 re-render, 무거운 연산 등)
   - 사용자 경험 개선 (UI/UX 버그, 누락된 기능)
   - 리팩토링이 필요한 복잡한 함수
4. `.sprintcommander/tasks.json`에 기존 배열을 유지하면서 새 태스크를 추가 저장
5. 포맷은 `_schema.json`의 example을 따름
6. 기본값: status=`"백로그"`, assignee=`"ME"`, assigneeColorHex=`"4FACFE"`
7. 우선순위: high=버그/크래시/데이터손실, medium=기능개선/리팩토링, low=코드정리/문서화
8. 스토리 포인트는 피보나치(1, 2, 3, 5, 8, 13), 대부분 1~5 범위
9. 태스크 수는 10~20개, 각각 하나의 PR로 처리 가능한 크기로 쪼갤 것
10. 각 태스크의 id는 새 UUID를 생성, projectId는 `_schema.json`의 값을 정확히 사용
11. 저장 후 추가한 태스크 목록을 요약해서 보여줄 것
```

### 방법 B: 프로젝트별 설정

특정 프로젝트에만 적용하려면 해당 프로젝트 루트에 `CLAUDE.md`를 넣습니다.
내용은 방법 A와 동일합니다.

**파일 위치:** `프로젝트루트/CLAUDE.md`

> 전역(`~/CLAUDE.md`)과 프로젝트별(`프로젝트루트/CLAUDE.md`) 규칙은 동시에 적용됩니다.
> 전역에 공통 규칙을, 프로젝트별로 추가 규칙을 넣는 것도 가능합니다.

### CLAUDE.md 적용 범위 정리

| 위치 | 범위 |
|------|------|
| `~/CLAUDE.md` | 모든 프로젝트에 전역 적용 |
| `프로젝트루트/CLAUDE.md` | 해당 프로젝트에서만 적용 |
| `프로젝트루트/.claude/CLAUDE.md` | 동일 (대안 경로) |

---

## 3. 사용법

### 기본: 한마디로 백로그 생성

CLAUDE.md를 설정한 뒤, 프로젝트 디렉토리에서 Claude Code를 열고:

```
백로그 만들어줘
```

이것만으로 Claude가 코드베이스를 분석하고 `.sprintcommander/tasks.json`에 태스크를 추가합니다.

### 상세: 직접 프롬프트 입력

CLAUDE.md 없이도 아래 프롬프트를 직접 입력하면 동작합니다.

```
이 프로젝트의 코드베이스를 분석해서 스프린트 백로그를 만들어줘.

## 규칙
1. `.sprintcommander/_schema.json`을 먼저 읽어서 projectId와 태스크 포맷을 확인해
2. `.sprintcommander/tasks.json`을 읽어서 기존 태스크를 확인해 (중복 생성 금지)
3. 프로젝트 소스 코드를 탐색해서 다음 기준으로 태스크를 도출해:
   - TODO/FIXME/HACK 주석
   - 에러 핸들링이 부족한 곳 (try? 남용, 빈 catch 등)
   - 테스트가 없는 핵심 로직
   - 접근성(Accessibility) 미비
   - 성능 개선 포인트 (불필요한 re-render, 무거운 연산 등)
   - 사용자 경험 개선 (UI/UX 버그, 누락된 기능)
   - 리팩토링이 필요한 복잡한 함수
4. 각 태스크는 실행 가능한 단위로 쪼개 (하나의 PR로 처리 가능한 크기)
5. 스토리 포인트는 피보나치(1,2,3,5,8,13)로 매기고 대부분 1~5 범위로 해
6. 우선순위 기준:
   - high: 버그, 크래시, 데이터 손실 위험
   - medium: 기능 개선, 리팩토링
   - low: 코드 정리, 문서화, 미래 개선
7. 태그는 이 중에서 선택: Feature, UI, Backend, Bug, Core, Performance, Refactor, Design, iOS
8. assignee는 "ME"로, assigneeColorHex는 "4FACFE"로 통일
9. 모든 태스크의 status는 "백로그"로 설정

## 출력
- `.sprintcommander/tasks.json`에 기존 태스크를 유지하면서 새 태스크를 추가해서 저장해
- 태스크 수는 10~20개 사이로 해
- 각 태스크의 id는 새 UUID를 생성해서 넣어
- 저장 후 추가한 태스크 목록을 요약해서 보여줘
```

### 특정 영역에 집중

```
이 프로젝트에서 {영역}에 해당하는 스프린트 백로그만 만들어줘.
나머지 규칙은 .sprintcommander/_schema.json을 참고하고,
기존 tasks.json 태스크는 유지하면서 추가해줘.
```

`{영역}` 예시:

| 키워드 | 도출 대상 |
|--------|-----------|
| UI/UX 개선점 | 사용자 경험 관련 이슈 |
| 버그와 안정성 | 크래시, 에러 핸들링 미비 |
| 성능 최적화 | 무거운 연산, 메모리 누수 |
| 테스트 커버리지 | 테스트가 없는 핵심 로직 |

---

## 4. 태스크 데이터 스펙

### 필드 정의

| 필드 | 타입 | 설명 | 예시 |
|------|------|------|------|
| `id` | string | UUID (태스크마다 고유값) | `"550e8400-e29b-41d4-a716-446655440000"` |
| `projectId` | string | `_schema.json`의 `_projectId` 값 **(필수)** | `"BA74DF5F-549C-46B1-AA8E-B8CC2232CF97"` |
| `title` | string | 태스크 제목 | `"로그인 에러 핸들링 추가"` |
| `tags` | string[] | 태그 배열 | `["Bug", "Backend"]` |
| `priority` | string | `high` \| `medium` \| `low` | `"high"` |
| `storyPoints` | integer | 피보나치 (1, 2, 3, 5, 8, 13) | `3` |
| `assignee` | string | 2글자 이니셜 | `"ME"` |
| `assigneeColorHex` | string | 6자리 hex 색상 코드 | `"4FACFE"` |
| `status` | string | `백로그` \| `할 일` \| `진행 중` \| `완료` | `"백로그"` |

### 사용 가능한 태그

`Feature`, `UI`, `Backend`, `Bug`, `Core`, `Integration`, `Performance`, `Marketing`, `Refactor`, `Design`, `iOS`, `i18n`, `UX`

### 우선순위 기준

| 우선순위 | 대상 |
|----------|------|
| `high` | 버그, 크래시, 데이터 손실 위험, 보안 이슈 |
| `medium` | 기능 개선, 리팩토링, UX 개선 |
| `low` | 코드 정리, 문서화, 미래 개선 사항 |

### tasks.json 예시

```json
[
  {
    "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
    "projectId": "BA74DF5F-549C-46B1-AA8E-B8CC2232CF97",
    "title": "네트워크 에러 시 사용자에게 재시도 옵션 제공",
    "tags": ["Feature", "UX"],
    "priority": "high",
    "storyPoints": 3,
    "assignee": "ME",
    "assigneeColorHex": "4FACFE",
    "status": "백로그"
  },
  {
    "id": "B2C3D4E5-F6A7-8901-BCDE-F12345678901",
    "projectId": "BA74DF5F-549C-46B1-AA8E-B8CC2232CF97",
    "title": "SettingsView 접근성 레이블 추가",
    "tags": ["UI", "iOS"],
    "priority": "low",
    "storyPoints": 1,
    "assignee": "ME",
    "assigneeColorHex": "4FACFE",
    "status": "백로그"
  }
]
```

---

## 5. 주의사항

| 항목 | 설명 |
|------|------|
| **projectId 필수** | `_schema.json`에서 읽은 값을 정확히 사용해야 합니다. 틀리면 앱에서 해당 프로젝트에 태스크가 표시되지 않습니다. |
| **기존 태스크 보존** | `tasks.json`을 덮어쓰면 기존 태스크가 사라집니다. 반드시 기존 배열을 읽고 append해야 합니다. |
| **UUID 고유성** | 각 태스크의 `id`는 고유한 UUID여야 합니다. 중복 ID는 데이터 충돌을 일으킵니다. |
| **JSON 유효성** | 파일이 유효한 JSON이 아니면 앱이 무시합니다. 저장 전 포맷을 확인하세요. |
| **status 한글** | status 값은 반드시 한글(`백로그`, `할 일`, `진행 중`, `완료`)이어야 합니다. 영문은 인식되지 않습니다. |
| **앱 실행 필요** | 파일 감시는 SprintCommander 앱이 실행 중일 때만 동작합니다. 앱이 꺼져 있으면 다음 실행 시 반영됩니다. |

---

## 6. 여러 머신에서 사용하기

### 왜 그냥 되나요?

- **SprintCommander 앱**: `sourcePath`를 `~/Documents/workspace/code/...` 형태로 저장합니다. `~`는 각 머신의 홈 디렉토리로 자동 치환되므로, CloudKit으로 동기화해도 경로 충돌이 없습니다.
- **`~/CLAUDE.md`**: `~`가 각 머신의 홈으로 치환되므로 내용만 동일하면 어디서든 동작합니다.

### 새 머신 셋업

SprintCommander 프로젝트에 포함된 셋업 스크립트를 실행하면 `~/CLAUDE.md`가 생성됩니다.

```bash
bash docs/setup-claude-md.sh
```

- 이미 `~/CLAUDE.md`가 있으면 기존 내용 뒤에 SprintCommander 규칙을 추가합니다.
- 이미 SprintCommander 규칙이 있으면 중복 추가하지 않습니다.

### 예시: 머신 2대 구성

```
머신 A (leeo)                          머신 B (hyunholee)
/Users/leeo/                           /Users/hyunholee/
├── CLAUDE.md          ← 동일 내용 →   ├── CLAUDE.md
└── Documents/workspace/code/          └── Documents/workspace/code/
    ├── PixelMe/                           ├── PixelMe/
    │   └── .sprintcommander/              │   └── .sprintcommander/
    │       ├── _schema.json               │       ├── _schema.json
    │       └── tasks.json                 │       └── tasks.json
    └── LeaveWise/                         └── LeaveWise/
        └── .sprintcommander/                  └── .sprintcommander/
            ├── _schema.json                       ├── _schema.json
            └── tasks.json                         └── tasks.json
```

- 각 머신에서 `~/CLAUDE.md`의 `~`는 로컬 홈으로 치환
- `.sprintcommander/` 안의 `sourcePath`도 `~` 상대경로로 저장되어 머신 간 호환
- CloudKit이 프로젝트 데이터를 양쪽에 동기화
