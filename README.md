# Sprint Commander

macOS 네이티브 스프린트 관리 앱. 프로젝트 칸반 보드, 타임라인, 분석을 한 화면에서 관리합니다.

## 빌드 & 실행

1. `SprintCommander.xcodeproj`를 Xcode 15+에서 열기
2. **⌘R**로 빌드 & 실행

> macOS 14.0+ | Swift 5.9+ | SwiftUI

## 화면 구성

| 탭 | 설명 |
|---|---|
| **대시보드** | 핵심 KPI, 타임라인, Velocity 차트, 번다운 차트, 활동 피드, 팀 워크로드 |
| **타임라인** | 프로젝트 전체 간트 차트 (월간/분기/연간 뷰, 드래그로 일정 조정) |
| **내 태스크** | 4단계 칸반 보드 (백로그 → 할 일 → 진행 중 → 완료) + 스토리 포인트 |
| **프로젝트** | 프로젝트 카드 그리드, 검색, 정렬, 프로젝트별 칸반 보드 |
| **분석** | 월별 완료량, 시간 분배, 목표 달성률, 프로젝트 건강도 |

## 주요 기능

- **프로젝트 소스 스캔** — 디렉토리를 지정하면 프로젝트 타입, 언어, 버전을 자동 감지
- **프로젝트 편집** — 이름, 아이콘, 색상, 설명, 스프린트, 소스 경로 변경
- **CloudKit 동기화** — 여러 Mac 간 실시간 데이터 동기화
- **파일 기반 AI 연동** — `.sprintcommander/tasks.json`을 외부 도구(Claude Code 등)가 수정하면 앱에 즉시 반영

## 프로젝트 구조

```
SprintCommander/
├── SprintCommanderApp.swift
├── Models/
│   ├── Models.swift              # Project, TaskItem, TeamMember 등
│   ├── AppStore.swift            # 앱 상태 관리 + auto-save
│   └── AppData.swift             # CloudKit 동기화용 데이터 컨테이너
├── Views/
│   ├── ContentView.swift
│   ├── SidebarView.swift
│   ├── Dashboard/DashboardView.swift
│   ├── Timeline/TimelineView.swift
│   ├── Board/BoardView.swift
│   ├── Projects/
│   │   ├── ProjectsView.swift
│   │   └── ProjectDetailView.swift
│   ├── Analytics/AnalyticsView.swift
│   └── Sheets/
│       ├── AddProjectSheet.swift
│       ├── EditProjectSheet.swift
│       ├── AddTaskSheet.swift
│       ├── TaskDetailSheet.swift
│       └── SearchOverlay.swift
├── Services/
│   ├── ProjectScanner.swift      # 소스 디렉토리 자동 분석
│   ├── ProjectFileManager.swift  # .sprintcommander/ 파일 관리 + 감시
│   └── CloudSyncManager.swift    # CloudKit 동기화
└── Components/
    └── SharedComponents.swift
```

---

## Claude Code 연동

SprintCommander는 프로젝트 소스 디렉토리 내 `.sprintcommander/tasks.json`을 실시간 감시합니다.
Claude Code가 이 파일을 수정하면 칸반 보드에 즉시 반영됩니다.

### 동작 구조

```
프로젝트 소스 디렉토리/
└── .sprintcommander/
    ├── _schema.json     ← Claude가 참고할 태스크 스키마 + projectId
    ├── project.json     ← 프로젝트 메타 (읽기 전용)
    └── tasks.json       ← 칸반 태스크 배열 (Claude가 수정)
```

SprintCommander에서 프로젝트를 추가하면 `.sprintcommander/` 디렉토리가 자동 생성됩니다.
`tasks.json`이 외부에서 변경되면 앱이 0.3초 내 자동 감지하여 칸반 보드에 반영하고,
CloudKit을 통해 다른 기기에도 동기화됩니다.

### 셋업: `~/CLAUDE.md` 등록

`~/CLAUDE.md`에 규칙을 등록하면, 어떤 프로젝트에서든 Claude Code에게 **"백로그 만들어"** 한마디로 스프린트 백로그를 자동 생성할 수 있습니다.

```bash
bash docs/setup-claude-md.sh
```

이 스크립트는:
- `~/CLAUDE.md`가 없으면 새로 생성
- 이미 있으면 기존 내용 뒤에 SprintCommander 규칙을 추가
- 이미 SprintCommander 규칙이 있으면 중복 추가하지 않음

> `~/CLAUDE.md`는 모든 프로젝트에 전역 적용됩니다.
> 특정 프로젝트에만 적용하려면 해당 프로젝트 루트에 `CLAUDE.md`를 넣으면 됩니다.

### 사용법

셋업 완료 후, 원하는 프로젝트 디렉토리에서 Claude Code를 열고:

```
백로그 만들어줘
```

Claude가 소스 코드를 분석하여 TODO/FIXME, 버그, 개선점, 누락 기능 등을 도출하고
`.sprintcommander/tasks.json`에 10~20개의 태스크를 추가합니다.

특정 영역에 집중하고 싶으면:

```
이 프로젝트에서 UI/UX 개선점에 해당하는 백로그만 만들어줘
```

### 태스크 포맷

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | string | UUID (태스크마다 고유값) |
| `projectId` | string | `_schema.json`의 `_projectId` 값 (필수) |
| `title` | string | 태스크 제목 |
| `tags` | string[] | `Feature`, `UI`, `Backend`, `Bug`, `Core`, `Performance`, `Refactor`, `Design`, `iOS` 등 |
| `priority` | string | `high` \| `medium` \| `low` |
| `storyPoints` | integer | 피보나치 (1, 2, 3, 5, 8, 13) |
| `assignee` | string | 2글자 이니셜 |
| `assigneeColorHex` | string | 6자리 hex 색상 코드 |
| `status` | string | `백로그` \| `할 일` \| `진행 중` \| `완료` |

<details>
<summary>tasks.json 예시</summary>

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

</details>

### 주의사항

| 항목 | 설명 |
|------|------|
| **projectId 필수** | `_schema.json`에서 읽은 값을 정확히 사용. 틀리면 앱에서 표시되지 않음 |
| **기존 태스크 보존** | `tasks.json`을 덮어쓰면 기존 태스크가 사라짐. 반드시 기존 배열을 읽고 추가할 것 |
| **status 한글** | `백로그`, `할 일`, `진행 중`, `완료` — 영문은 인식되지 않음 |

### 여러 머신에서 사용하기

SprintCommander는 `sourcePath`를 `~/Documents/workspace/code/...` 형태로 저장합니다.
`~`는 각 머신의 홈으로 자동 치환되므로, 다른 Mac에서도 경로 충돌 없이 동작합니다.

새 머신에서는 셋업 스크립트만 실행하면 됩니다:

```bash
bash docs/setup-claude-md.sh
```

```
머신 A (leeo)                          머신 B (hyunholee)
/Users/leeo/                           /Users/hyunholee/
├── CLAUDE.md          ← 동일 내용 →   ├── CLAUDE.md
└── Documents/workspace/code/          └── Documents/workspace/code/
    └── MyProject/                         └── MyProject/
        └── .sprintcommander/                  └── .sprintcommander/
            ├── _schema.json                       ├── _schema.json
            └── tasks.json   ← CloudKit 동기화 →   └── tasks.json
```
