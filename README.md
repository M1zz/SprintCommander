# Sprint Commander 🚀

20개 프로젝트와 스프린트를 한눈에 관리하는 macOS 네이티브 앱

## 빌드 & 실행

1. `SprintCommander.xcodeproj` 를 Xcode 15+ 에서 열기
2. **⌘R** 으로 빌드 & 실행
3. 끝!

> 타겟: macOS 14.0+ | Swift 5.9+ | SwiftUI

## 화면 구성

| 탭 | 설명 |
|---|---|
| **📊 대시보드** | 핵심 KPI 5개, 미니 타임라인, Velocity 차트, 번다운 차트, 활동 피드, 팀 워크로드 |
| **📅 타임라인** | 20개 프로젝트 전체 간트 차트 (월간/분기/연간 뷰) |
| **📋 스프린트 보드** | 4단계 칸반 보드 (백로그→할일→진행중→완료) + 스토리 포인트 |
| **📁 프로젝트** | 20개 프로젝트 카드 그리드, 검색, 진행률 시각화 |
| **📈 분석** | 월별 완료량, 시간 분배, 목표 달성률, 프로젝트 건강도 |

## 프로젝트 구조

```
SprintCommander/
├── SprintCommanderApp.swift     # @main 진입점
├── Models/
│   ├── Models.swift             # 데이터 모델 (Project, Sprint, Task 등)
│   └── AppStore.swift           # 앱 상태 관리 + 샘플 데이터
├── Views/
│   ├── ContentView.swift        # 메인 레이아웃 + 탭 라우터
│   ├── SidebarView.swift        # 사이드바 네비게이션
│   ├── Dashboard/
│   │   └── DashboardView.swift  # 대시보드 (통계, 차트, 피드)
│   ├── Timeline/
│   │   └── TimelineView.swift   # 간트 차트 타임라인
│   ├── Board/
│   │   └── BoardView.swift      # 칸반 스프린트 보드
│   ├── Projects/
│   │   └── ProjectsView.swift   # 프로젝트 그리드
│   └── Analytics/
│       └── AnalyticsView.swift  # 분석 차트
└── Components/
    └── SharedComponents.swift   # 공통 UI 컴포넌트
```

## 커스텀 포인트

- `AppStore.swift` 의 `projects` 배열에서 프로젝트 추가/수정
- `kanbanTasks` 에서 태스크 데이터 관리
- `teamMembers` 에서 팀원 구성 변경
- 색상은 `palette` 배열에서 hex 코드로 관리

## 확장 아이디어

- [ ] CoreData / SwiftData 연동으로 영속 저장
- [ ] 칸반 보드 드래그 앤 드롭
- [ ] 메뉴바 위젯
- [ ] 키보드 단축키 (⌘K 검색)
- [ ] GitHub / Jira API 연동
- [ ] iCloud 동기화
