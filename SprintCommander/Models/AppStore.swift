import SwiftUI
import Combine

final class AppStore: ObservableObject {
    @Published var selectedTab: SidebarTab = .dashboard
    @Published var selectedSprintIndex: Int = 0
    @Published var selectedProject: Project? = nil
    @Published var searchText: String = ""
    @Published var showNewSprintSheet: Bool = false
    @Published var showSearchOverlay: Bool = false
    @Published var selectedSprint: Sprint? = nil

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
    @Published var sprints: [Sprint] = []

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
        let active = sprints.filter { $0.isActive }
        return active.map { sprint in
            let projectName = projects.first(where: { $0.id == sprint.projectId })?.name ?? ""
            return "\(sprint.name) · \(projectName)"
        }
    }

    // MARK: - Sprint helpers

    func sprints(for projectId: UUID) -> [Sprint] {
        sprints.filter { $0.projectId == projectId }
    }

    func activeSprint(for projectId: UUID) -> Sprint? {
        sprints.first(where: { $0.projectId == projectId && $0.isActive })
    }

    func addSprint(_ sprint: Sprint) {
        sprints.append(sprint)
        syncProjectFields()
    }

    func updateSprint(_ sprint: Sprint) {
        if let idx = sprints.firstIndex(where: { $0.id == sprint.id }) {
            sprints[idx] = sprint
        }
        syncProjectFields()
    }

    func deleteSprint(id: UUID) {
        sprints.removeAll { $0.id == id }
        syncProjectFields()
    }

    func completeSprint(id: UUID) {
        if let idx = sprints.firstIndex(where: { $0.id == id }) {
            sprints[idx].isActive = false
        }
        syncProjectFields()
    }

    /// project.sprint / project.progress / project.totalTasks / project.doneTasks 를
    /// 실제 Sprint 객체 및 태스크 데이터와 동기화
    func syncProjectFields() {
        for i in projects.indices {
            let pid = projects[i].id

            // sprint 이름: 활성 스프린트 이름들을 표시
            let active = sprints.filter { $0.projectId == pid && $0.isActive }
            if let first = active.first {
                if active.count == 1 {
                    projects[i].sprint = first.name
                } else {
                    projects[i].sprint = "\(first.name) 외 \(active.count - 1)개"
                }
            } else {
                let all = sprints.filter { $0.projectId == pid }
                if all.isEmpty {
                    projects[i].sprint = ""
                } else {
                    projects[i].sprint = "완료됨"
                }
            }

            // 태스크 수 및 진행률
            let tasks = kanbanTasks.filter { $0.projectId == pid }
            let done = tasks.filter { $0.status == .done }.count
            projects[i].totalTasks = tasks.count
            projects[i].doneTasks = done
            projects[i].progress = tasks.isEmpty ? 0 : Double(done) / Double(tasks.count) * 100
        }

        // selectedProject도 동기화
        if let sel = selectedProject,
           let updated = projects.first(where: { $0.id == sel.id }) {
            selectedProject = updated
        }
    }

    func sprintProgress(for sprint: Sprint) -> Double {
        let sprintTasks = kanbanTasks.filter { $0.projectId == sprint.projectId && $0.sprint == sprint.name }
        guard !sprintTasks.isEmpty else { return 0 }
        let done = sprintTasks.filter { $0.status == .done }.count
        return Double(done) / Double(sprintTasks.count) * 100
    }

    func tasks(for sprint: Sprint) -> [TaskItem] {
        kanbanTasks.filter { $0.projectId == sprint.projectId && $0.sprint == sprint.name }
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
        syncProjectFields()
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
        syncProjectFields()
    }

    func updateTaskPriority(id: UUID, newPriority: TaskItem.Priority) {
        if let idx = kanbanTasks.firstIndex(where: { $0.id == id }) {
            kanbanTasks[idx].priority = newPriority
        }
    }

    func deleteTask(id: UUID) {
        kanbanTasks.removeAll { $0.id == id }
        syncProjectFields()
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
            burndownActual: burndownActual,
            sprints: sprints
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
        sprints = data.sprints
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

        // 기존 project.sprint / task.sprint 데이터를 Sprint 객체로 마이그레이션
        migrateSprintsIfNeeded()

        // 초기 프로젝트 파일 생성 + 감시 시작
        fileManager.saveAll(projects: projects, tasks: kanbanTasks)
        fileManager.onExternalTasksChange = { [weak self] projectId, newTasks in
            self?.applyExternalTasks(projectId: projectId, tasks: newTasks)
        }
        fileManager.onExternalProjectChange = { [weak self] projectId, patch in
            self?.applyExternalProject(projectId: projectId, patch: patch)
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
            $burndownActual.map { _ in () }.eraseToAnyPublisher(),
            $sprints.map { _ in () }.eraseToAnyPublisher()
        )
        .dropFirst(8) // skip initial values from restore
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

    // MARK: - Sprint Migration

    /// 기존 project.sprint 및 task.sprint 문자열에서 Sprint 객체를 자동 생성
    private func migrateSprintsIfNeeded() {
        var created = false
        let existingSprintKeys = Set(sprints.map { "\($0.projectId)-\($0.name)" })

        for project in projects {
            // project.sprint 필드에서 스프린트 이름 수집
            var sprintNames = Set<String>()
            if !project.sprint.isEmpty {
                sprintNames.insert(project.sprint)
            }
            // 해당 프로젝트의 태스크에서 스프린트 이름 수집
            for task in kanbanTasks where task.projectId == project.id {
                if !task.sprint.isEmpty {
                    sprintNames.insert(task.sprint)
                }
            }

            // 아직 Sprint 객체가 없으면 생성
            for name in sprintNames {
                let key = "\(project.id)-\(name)"
                guard !existingSprintKeys.contains(key) else { continue }

                let sprint = Sprint(
                    projectId: project.id,
                    name: name,
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date()) ?? Date(),
                    isActive: true
                )
                sprints.append(sprint)
                created = true
            }
        }

        if created {
            print("[AppStore] 🔄 기존 스프린트 데이터 마이그레이션 완료 (\(sprints.count)개)")
            syncProjectFields()
            // 쿨다운 이후 저장되도록 잠시 대기
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.save()
            }
        } else {
            // 마이그레이션 없어도 프로젝트 필드 동기화
            syncProjectFields()
        }
    }

    /// 외부 도구가 tasks.json을 수정했을 때 해당 프로젝트의 태스크만 교체
    private func applyExternalTasks(projectId: UUID, tasks: [TaskItem]) {
        isRestoring = true
        kanbanTasks.removeAll { $0.projectId == projectId }
        kanbanTasks.append(contentsOf: tasks)
        isRestoring = false
        syncProjectFields()
        // CloudKit에도 동기화
        syncManager.save(snapshot())
    }

    private func applyExternalProject(projectId: UUID, patch: ProjectPatch) {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        isRestoring = true
        if let name = patch.name { projects[idx].name = name }
        if let icon = patch.icon { projects[idx].icon = icon }
        if let desc = patch.desc { projects[idx].desc = desc }
        if let version = patch.version { projects[idx].version = version }
        if let landingURL = patch.landingURL { projects[idx].landingURL = landingURL }
        if let appStoreURL = patch.appStoreURL { projects[idx].appStoreURL = appStoreURL }
        if let pricing = patch.pricing { projects[idx].pricing = pricing }
        if let languages = patch.languages { projects[idx].languages = languages }
        isRestoring = false
        print("[AppStore] 외부 프로젝트 변경 적용: \(projects[idx].name)")
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
