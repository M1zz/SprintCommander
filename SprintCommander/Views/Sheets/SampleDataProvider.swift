import SwiftUI

struct SampleDataProvider {
    static func loadSampleData(into store: AppStore) {
        // Projects
        let sampleProjects: [Project] = [
            Project(name: "모바일 앱 리뉴얼", icon: "📱", desc: "iOS/Android 앱 전면 리디자인", progress: 72, sprint: "Sprint 3", totalTasks: 24, doneTasks: 17, color: AppStore.palette[0], startWeek: 0, durationWeeks: 6),
            Project(name: "웹 대시보드", icon: "🌐", desc: "관리자 대시보드 v2.0 개발", progress: 45, sprint: "Sprint 2", totalTasks: 18, doneTasks: 8, color: AppStore.palette[1], startWeek: 2, durationWeeks: 5),
            Project(name: "API 리팩토링", icon: "🔧", desc: "RESTful API → GraphQL 전환", progress: 88, sprint: "Sprint 4", totalTasks: 12, doneTasks: 11, color: AppStore.palette[2], startWeek: 1, durationWeeks: 4),
            Project(name: "데이터 분석 플랫폼", icon: "📊", desc: "실시간 분석 대시보드 구축", progress: 30, sprint: "Sprint 1", totalTasks: 20, doneTasks: 6, color: AppStore.palette[3], startWeek: 4, durationWeeks: 8),
            Project(name: "디자인 시스템", icon: "🎨", desc: "공통 컴포넌트 라이브러리 구축", progress: 60, sprint: "Sprint 2", totalTasks: 15, doneTasks: 9, color: AppStore.palette[4], startWeek: 3, durationWeeks: 5),
        ]

        // Tasks (linked to projects by projectId)
        let p0 = sampleProjects[0].id
        let p1 = sampleProjects[1].id
        let p2 = sampleProjects[2].id
        let p3 = sampleProjects[3].id
        let p4 = sampleProjects[4].id

        let sampleTasks: [TaskItem] = [
            // 모바일 앱 리뉴얼
            TaskItem(projectId: p0, title: "로그인 화면 리디자인", tags: ["UI", "Feature"], priority: .high, storyPoints: 5, assignee: "JK", assigneeColor: AppStore.palette[0], status: .inProgress),
            TaskItem(projectId: p0, title: "푸시 알림 시스템 구현", tags: ["Feature", "Backend"], priority: .medium, storyPoints: 5, assignee: "MJ", assigneeColor: AppStore.palette[2], status: .todo),
            TaskItem(projectId: p0, title: "다크모드 테마 적용", tags: ["UI", "Design"], priority: .low, storyPoints: 3, assignee: "YJ", assigneeColor: AppStore.palette[3], status: .todo),
            TaskItem(projectId: p0, title: "온보딩 플로우 개선", tags: ["UX", "Feature"], priority: .medium, storyPoints: 3, assignee: "MJ", assigneeColor: AppStore.palette[2], status: .done),
            // 웹 대시보드
            TaskItem(projectId: p1, title: "사용자 프로필 API 연동", tags: ["Backend", "Integration"], priority: .high, storyPoints: 8, assignee: "SH", assigneeColor: AppStore.palette[1], status: .inProgress),
            TaskItem(projectId: p1, title: "차트 컴포넌트 리팩토링", tags: ["Refactor", "UI"], priority: .medium, storyPoints: 3, assignee: "JK", assigneeColor: AppStore.palette[0], status: .todo),
            // API 리팩토링
            TaskItem(projectId: p2, title: "검색 성능 최적화", tags: ["Performance", "Backend"], priority: .medium, storyPoints: 5, assignee: "SH", assigneeColor: AppStore.palette[1], status: .done),
            TaskItem(projectId: p2, title: "결제 모듈 버그 수정", tags: ["Bug", "Core"], priority: .high, storyPoints: 8, assignee: "JK", assigneeColor: AppStore.palette[0], status: .backlog),
            // 데이터 분석 플랫폼
            TaskItem(projectId: p3, title: "다국어 지원 추가", tags: ["i18n", "Feature"], priority: .low, storyPoints: 5, assignee: "YJ", assigneeColor: AppStore.palette[3], status: .backlog),
            // 디자인 시스템
            TaskItem(projectId: p4, title: "iOS 위젯 개발", tags: ["iOS", "Feature"], priority: .low, storyPoints: 8, assignee: "SH", assigneeColor: AppStore.palette[1], status: .backlog),
        ]

        // Team Members
        let sampleTeam: [TeamMember] = [
            TeamMember(name: "김준혁", color: AppStore.palette[0], workload: 85),
            TeamMember(name: "이서현", color: AppStore.palette[1], workload: 72),
            TeamMember(name: "박민준", color: AppStore.palette[2], workload: 55),
            TeamMember(name: "최유진", color: AppStore.palette[3], workload: 40),
        ]

        // Velocity
        let sampleVelocity: [VelocityPoint] = [
            VelocityPoint(sprint: "S1", planned: 30, completed: 28),
            VelocityPoint(sprint: "S2", planned: 35, completed: 32),
            VelocityPoint(sprint: "S3", planned: 28, completed: 26),
            VelocityPoint(sprint: "S4", planned: 40, completed: 35),
            VelocityPoint(sprint: "S5", planned: 32, completed: 30),
        ]

        // Burndown
        let idealBurndown: [Double] = [50, 45, 40, 35, 30, 25, 20, 15, 10, 5, 0]
        let actualBurndown: [Double] = [50, 47, 43, 38, 35, 30, 27, 22, 16, 10, 4]

        // Activities
        let sampleActivities: [ActivityItem] = [
            ActivityItem(icon: "✅", text: "태스크를 완료했습니다", highlightedText: "검색 성능 최적화", time: "2시간 전"),
            ActivityItem(icon: "🔄", text: "상태가 진행 중으로 변경되었습니다", highlightedText: "로그인 화면 리디자인", time: "3시간 전"),
            ActivityItem(icon: "📋", text: "새 태스크가 추가되었습니다", highlightedText: "iOS 위젯 개발", time: "5시간 전"),
            ActivityItem(icon: "📁", text: "프로젝트가 생성되었습니다", highlightedText: "디자인 시스템", time: "어제"),
            ActivityItem(icon: "👤", text: "팀원이 추가되었습니다", highlightedText: "최유진", time: "2일 전"),
        ]

        // Load all
        for project in sampleProjects { store.addProject(project) }
        for task in sampleTasks { store.addTask(task) }
        for member in sampleTeam { store.addTeamMember(member) }
        store.velocityData = sampleVelocity
        store.burndownIdeal = idealBurndown
        store.burndownActual = actualBurndown
        for activity in sampleActivities { store.addActivity(activity) }
    }
}
