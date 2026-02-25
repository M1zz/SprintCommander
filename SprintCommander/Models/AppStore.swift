import SwiftUI
import Combine

final class AppStore: ObservableObject {
    @Published var selectedTab: SidebarTab = .dashboard
    @Published var selectedSprintIndex: Int = 0
    @Published var selectedProject: Project? = nil
    @Published var searchText: String = ""
    @Published var showNewSprintSheet: Bool = false
    @Published var showSearchOverlay: Bool = false

    private let syncManager = CloudSyncManager()
    private let fileManager = ProjectFileManager()
    private var autoSaveCancellable: AnyCancellable?
    private var pollTimer: AnyCancellable?
    private var isRestoring = false
    /// restore 후 잠시 동안 auto-save를 억제 (Combine 비동기 이벤트 방어)
    private var restoreCooldownUntil: Date = .distantPast

    // MARK: - Colors Palette
    static let palette: [Color] = [
        Color(hex: "4FACFE"), Color(hex: "34D399"), Color(hex: "A78BFA"),
        Color(hex: "FB923C"), Color(hex: "F472B6"), Color(hex: "22D3EE"),
        Color(hex: "FBBF24"), Color(hex: "EF4444"), Color(hex: "6366F1"),
        Color(hex: "10B981"), Color(hex: "EC4899"), Color(hex: "8B5CF6"),
        Color(hex: "F59E0B"), Color(hex: "14B8A6"), Color(hex: "E879F9"),
        Color(hex: "06B6D4"), Color(hex: "84CC16"), Color(hex: "F97316"),
        Color(hex: "64748B"), Color(hex: "DC2626")
    ]

    // MARK: - Data (비어있는 상태로 시작)
    @Published var projects: [Project] = []
    @Published var velocityData: [VelocityPoint] = []
    @Published var kanbanTasks: [TaskItem] = []
    @Published var activities: [ActivityItem] = []
    @Published var teamMembers: [TeamMember] = []
    @Published var burndownIdeal: [Double] = []
    @Published var burndownActual: [Double] = []

    // MARK: - Computed
    var totalDoneTasks: Int { projects.reduce(0) { $0 + $1.doneTasks } }
    var totalTasks: Int { projects.reduce(0) { $0 + $1.totalTasks } }
    var inProgressCount: Int { kanbanTasks.filter { $0.status == .inProgress }.count }
    var averageVelocity: Int {
        let completed = velocityData.filter { $0.completed > 0 }
        guard !completed.isEmpty else { return 0 }
        return completed.reduce(0) { $0 + $1.completed } / completed.count
    }
    var overdueCount: Int {
        kanbanTasks.filter { $0.priority == .high && $0.status != .done }.count
    }

    func tasks(for status: TaskItem.TaskStatus) -> [TaskItem] {
        kanbanTasks.filter { $0.status == status }
    }

    func tasks(for projectId: UUID) -> [TaskItem] {
        kanbanTasks.filter { $0.projectId == projectId }
    }

    func tasks(for projectId: UUID, status: TaskItem.TaskStatus) -> [TaskItem] {
        kanbanTasks.filter { $0.projectId == projectId && $0.status == status }
    }

    func totalSP(for status: TaskItem.TaskStatus) -> Int {
        tasks(for: status).reduce(0) { $0 + $1.storyPoints }
    }

    var activeSprintNames: [String] {
        let active = projects.filter { $0.progress < 100 && $0.progress > 0 }
        return active.prefix(4).map { "\($0.sprint) · \($0.name)" }
    }

    // MARK: - Computed: All Tags
    var allTags: [String] {
        let tags = kanbanTasks.flatMap { $0.tags }
        return Array(Set(tags)).sorted()
    }

    // MARK: - 데이터 추가 헬퍼
    func addProject(_ project: Project) {
        projects.append(project)
        fileManager.startWatching(project: project)
    }

    func addTask(_ task: TaskItem) {
        kanbanTasks.append(task)
    }

    func addActivity(_ activity: ActivityItem) {
        activities.insert(activity, at: 0)
    }

    func addTeamMember(_ member: TeamMember) {
        teamMembers.append(member)
    }

    // MARK: - 데이터 변경 헬퍼
    func updateTaskStatus(id: UUID, newStatus: TaskItem.TaskStatus) {
        if let idx = kanbanTasks.firstIndex(where: { $0.id == id }) {
            kanbanTasks[idx].status = newStatus
        }
    }

    func updateTaskPriority(id: UUID, newPriority: TaskItem.Priority) {
        if let idx = kanbanTasks.firstIndex(where: { $0.id == id }) {
            kanbanTasks[idx].priority = newPriority
        }
    }

    func deleteTask(id: UUID) {
        kanbanTasks.removeAll { $0.id == id }
    }

    func deleteProject(id: UUID) {
        projects.removeAll { $0.id == id }
    }

    func updateProject(_ project: Project) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
        }
    }

    func updateProjectSchedule(id: UUID, startWeek: Int, durationWeeks: Int? = nil) {
        if let idx = projects.firstIndex(where: { $0.id == id }) {
            projects[idx].startWeek = startWeek
            if let dur = durationWeeks {
                projects[idx].durationWeeks = dur
            }
        }
    }

    // MARK: - 필터링
    func filteredTasks(for status: TaskItem.TaskStatus, priorityFilter: TaskItem.Priority? = nil, tagFilter: String? = nil) -> [TaskItem] {
        var result = tasks(for: status)
        if let priority = priorityFilter {
            result = result.filter { $0.priority == priority }
        }
        if let tag = tagFilter, !tag.isEmpty {
            result = result.filter { $0.tags.contains(tag) }
        }
        return result
    }

    // MARK: - Sync

    func snapshot() -> AppData {
        AppData(
            timestamp: Date(),
            projects: projects,
            kanbanTasks: kanbanTasks,
            velocityData: velocityData,
            activities: activities,
            teamMembers: teamMembers,
            burndownIdeal: burndownIdeal,
            burndownActual: burndownActual
        )
    }

    func restore(from data: AppData) {
        isRestoring = true
        projects = data.projects
        kanbanTasks = data.kanbanTasks
        velocityData = data.velocityData
        activities = data.activities
        teamMembers = data.teamMembers
        burndownIdeal = data.burndownIdeal
        burndownActual = data.burndownActual
        isRestoring = false
        // restore 후 1초간 auto-save 억제 (Combine 비동기 이벤트 방어)
        restoreCooldownUntil = Date().addingTimeInterval(1.0)
        print("[AppStore] 🔄 restore 완료 (projects: \(projects.count), cooldown 1초)")
    }

    func save() {
        guard !isRestoring else { return }
        guard Date() > restoreCooldownUntil else {
            print("[AppStore] ⏭️ restore 쿨다운 중 → 저장 스킵")
            return
        }
        print("[AppStore] 💾 데이터 변경 감지 → 저장 (projects: \(projects.count), tasks: \(kanbanTasks.count))")
        syncManager.save(snapshot())
        fileManager.saveAll(projects: projects, tasks: kanbanTasks)
    }

    // MARK: - Version Refresh

    private let scanner = ProjectScanner()

    /// 모든 프로젝트의 sourcePath에서 버전을 다시 읽어와 업데이트
    func refreshProjectVersions() {
        Task {
            var changed = false
            for i in projects.indices {
                let project = projects[i]
                guard !project.sourcePath.isEmpty else { continue }
                if let result = await scanner.scan(path: project.sourcePath),
                   !result.version.isEmpty,
                   result.version != project.version {
                    await MainActor.run {
                        projects[i].version = result.version
                    }
                    changed = true
                }
            }
            if changed {
                await MainActor.run { save() }
            }
        }
    }

    func loadAndStartSync() {
        if let data = syncManager.load() {
            restore(from: data)
        }

        // 초기 프로젝트 파일 생성 + 감시 시작
        fileManager.saveAll(projects: projects, tasks: kanbanTasks)
        fileManager.onExternalTasksChange = { [weak self] projectId, newTasks in
            self?.applyExternalTasks(projectId: projectId, tasks: newTasks)
        }
        fileManager.startWatchingAll(projects: projects)

        // Auto-save on any data change
        autoSaveCancellable = Publishers.MergeMany(
            $projects.map { _ in () }.eraseToAnyPublisher(),
            $kanbanTasks.map { _ in () }.eraseToAnyPublisher(),
            $velocityData.map { _ in () }.eraseToAnyPublisher(),
            $activities.map { _ in () }.eraseToAnyPublisher(),
            $teamMembers.map { _ in () }.eraseToAnyPublisher(),
            $burndownIdeal.map { _ in () }.eraseToAnyPublisher(),
            $burndownActual.map { _ in () }.eraseToAnyPublisher()
        )
        .dropFirst(7) // skip initial values from restore
        .sink { [weak self] in self?.save() }

        // Monitor iCloud changes
        syncManager.startMonitoring { [weak self] data in
            self?.restore(from: data)
        }

        // 초기 버전 스캔
        refreshProjectVersions()

        // 주기적 폴링 (15초마다) - push가 안 올 때 fallback
        pollTimer = Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshFromCloud()
            }
    }

    /// 외부 도구가 tasks.json을 수정했을 때 해당 프로젝트의 태스크만 교체
    private func applyExternalTasks(projectId: UUID, tasks: [TaskItem]) {
        isRestoring = true
        kanbanTasks.removeAll { $0.projectId == projectId }
        kanbanTasks.append(contentsOf: tasks)
        isRestoring = false
        // CloudKit에도 동기화
        syncManager.save(snapshot())
    }

    func refreshFromCloud() {
        syncManager.fetchLatest()
    }

    func handleRemoteNotification(userInfo: [String: Any]) {
        syncManager.handleRemoteNotification(userInfo: userInfo)
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    func toHex() -> String {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return "000000" }
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
