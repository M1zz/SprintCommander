import SwiftUI
import Foundation

// MARK: - Relative Path Helpers
private enum PathHelper {
    static let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

    static func toRelative(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        if path.hasPrefix(homeDir) {
            return "~" + path.dropFirst(homeDir.count)
        }
        return path
    }

    static func toAbsolute(_ path: String) -> String {
        guard path.hasPrefix("~") else { return path }
        return homeDir + path.dropFirst(1)
    }
}

// MARK: - Pricing
struct PricingInfo: Codable, Hashable {
    var downloadPrice: String   // 다운로드 가격 (무료 / ₩4,900 등)
    var monthlyPrice: String    // 월별 구독
    var yearlyPrice: String     // 연간 구독
    var lifetimePrice: String   // 1회 평생구매

    init(downloadPrice: String = "", monthlyPrice: String = "", yearlyPrice: String = "", lifetimePrice: String = "") {
        self.downloadPrice = downloadPrice
        self.monthlyPrice = monthlyPrice
        self.yearlyPrice = yearlyPrice
        self.lifetimePrice = lifetimePrice
    }

    var isEmpty: Bool {
        downloadPrice.isEmpty && monthlyPrice.isEmpty && yearlyPrice.isEmpty && lifetimePrice.isEmpty
    }

    var summary: String {
        var parts: [String] = []
        if !downloadPrice.isEmpty { parts.append(downloadPrice) }
        if !monthlyPrice.isEmpty { parts.append("\(monthlyPrice)/월") }
        if !yearlyPrice.isEmpty { parts.append("\(yearlyPrice)/년") }
        if !lifetimePrice.isEmpty { parts.append("\(lifetimePrice) 평생") }
        return parts.joined(separator: " · ")
    }

    var filledCount: Int {
        [downloadPrice, monthlyPrice, yearlyPrice, lifetimePrice].filter { !$0.isEmpty }.count
    }
}

// MARK: - ProjectPatch (외부 수정용)
/// project.json에서 외부 수정 가능한 필드만 포함
struct ProjectPatch: Codable {
    var id: UUID
    var name: String?
    var icon: String?
    var desc: String?
    var version: String?
    var landingURL: String?
    var appStoreURL: String?
    var pricing: PricingInfo?
    var languages: [String]?
    var lastModified: Date?  // 롤백 방지용 타임스탬프

    enum CodingKeys: String, CodingKey {
        case id, name, icon, desc, version, landingURL, appStoreURL, pricing, languages, lastModified
    }
}

// MARK: - Project
struct Project: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var desc: String
    var progress: Double
    var sprint: String
    var totalTasks: Int
    var doneTasks: Int
    var color: Color
    var startWeek: Int    // 0-based week offset for timeline
    var durationWeeks: Int
    var sourcePath: String
    var version: String
    var landingURL: String
    var appStoreURL: String
    var pricing: PricingInfo
    var languages: [String]
    var lastModified: Date  // 롤백 방지용 타임스탬프

    init(id: UUID = UUID(), name: String, icon: String, desc: String, progress: Double, sprint: String, totalTasks: Int, doneTasks: Int, color: Color, startWeek: Int = 0, durationWeeks: Int = 4, sourcePath: String = "", version: String = "", landingURL: String = "", appStoreURL: String = "", pricing: PricingInfo = PricingInfo(), languages: [String] = [], lastModified: Date = Date()) {
        self.id = id
        self.name = name
        self.icon = icon
        self.desc = desc
        self.progress = progress
        self.sprint = sprint
        self.totalTasks = totalTasks
        self.doneTasks = doneTasks
        self.color = color
        self.startWeek = startWeek
        self.durationWeeks = durationWeeks
        self.sourcePath = sourcePath
        self.version = version
        self.landingURL = landingURL
        self.appStoreURL = appStoreURL
        self.pricing = pricing
        self.languages = languages
        self.lastModified = lastModified
    }

    var progressPercent: String {
        "\(Int(progress))%"
    }

    // MARK: Codable
    enum CodingKeys: String, CodingKey {
        case id, name, icon, desc, progress, sprint, totalTasks, doneTasks
        case colorHex, startWeek, durationWeeks, sourcePath, version
        case landingURL, appStoreURL, pricing, languages, lastModified
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(icon, forKey: .icon)
        try c.encode(desc, forKey: .desc)
        try c.encode(progress, forKey: .progress)
        try c.encode(sprint, forKey: .sprint)
        try c.encode(totalTasks, forKey: .totalTasks)
        try c.encode(doneTasks, forKey: .doneTasks)
        try c.encode(color.toHex(), forKey: .colorHex)
        try c.encode(startWeek, forKey: .startWeek)
        try c.encode(durationWeeks, forKey: .durationWeeks)
        try c.encode(PathHelper.toRelative(sourcePath), forKey: .sourcePath)
        try c.encode(version, forKey: .version)
        try c.encode(landingURL, forKey: .landingURL)
        try c.encode(appStoreURL, forKey: .appStoreURL)
        try c.encode(pricing, forKey: .pricing)
        try c.encode(languages, forKey: .languages)
        try c.encode(lastModified, forKey: .lastModified)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        icon = try c.decode(String.self, forKey: .icon)
        desc = try c.decode(String.self, forKey: .desc)
        progress = try c.decode(Double.self, forKey: .progress)
        sprint = try c.decode(String.self, forKey: .sprint)
        totalTasks = try c.decode(Int.self, forKey: .totalTasks)
        doneTasks = try c.decode(Int.self, forKey: .doneTasks)
        let hex = try c.decode(String.self, forKey: .colorHex)
        color = Color(hex: hex)
        startWeek = try c.decode(Int.self, forKey: .startWeek)
        durationWeeks = try c.decode(Int.self, forKey: .durationWeeks)
        let raw = try c.decode(String.self, forKey: .sourcePath)
        sourcePath = PathHelper.toAbsolute(raw)
        version = try c.decodeIfPresent(String.self, forKey: .version) ?? ""
        landingURL = try c.decodeIfPresent(String.self, forKey: .landingURL) ?? ""
        appStoreURL = try c.decodeIfPresent(String.self, forKey: .appStoreURL) ?? ""
        // 하위 호환: 기존 String → PricingInfo 마이그레이션
        if let pricingObj = try? c.decodeIfPresent(PricingInfo.self, forKey: .pricing) {
            pricing = pricingObj
        } else if let oldStr = try? c.decodeIfPresent(String.self, forKey: .pricing), !oldStr.isEmpty {
            pricing = PricingInfo(downloadPrice: oldStr)
        } else {
            pricing = PricingInfo()
        }
        languages = try c.decodeIfPresent([String].self, forKey: .languages) ?? []
        lastModified = try c.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
    }
}

// MARK: - Sprint
struct Sprint: Identifiable, Hashable, Codable {
    let id: UUID
    var projectId: UUID
    var name: String
    var goal: String
    var startDate: Date
    var endDate: Date
    var isActive: Bool

    init(id: UUID = UUID(), projectId: UUID, name: String, goal: String = "", startDate: Date = Date(), endDate: Date = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date()) ?? Date(), isActive: Bool = true) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.goal = goal
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
    }

    var isCompleted: Bool {
        !isActive && endDate < Date()
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0)
    }

    var totalDays: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
    }

    var progressByTime: Double {
        let elapsed = Date().timeIntervalSince(startDate)
        let total = endDate.timeIntervalSince(startDate)
        guard total > 0 else { return 0 }
        return min(max(elapsed / total, 0), 1.0) * 100
    }
}

// MARK: - Task
struct TaskItem: Identifiable, Hashable, Codable {
    let id: UUID
    var projectId: UUID?
    var title: String
    var tags: [String]
    var priority: Priority
    var storyPoints: Int
    var assignee: String
    var assigneeColor: Color
    var status: TaskStatus
    var sprint: String

    init(id: UUID = UUID(), projectId: UUID? = nil, title: String, tags: [String], priority: Priority, storyPoints: Int, assignee: String, assigneeColor: Color, status: TaskStatus, sprint: String = "") {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.tags = tags
        self.priority = priority
        self.storyPoints = storyPoints
        self.assignee = assignee
        self.assigneeColor = assigneeColor
        self.status = status
        self.sprint = sprint
    }

    enum Priority: String, CaseIterable, Codable {
        case high, medium, low

        var label: String {
            switch self {
            case .high: return "High"
            case .medium: return "Med"
            case .low: return "Low"
            }
        }
        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .green
            }
        }
        var icon: String {
            switch self {
            case .high: return "🔴"
            case .medium: return "🟡"
            case .low: return "🟢"
            }
        }
    }

    enum TaskStatus: String, CaseIterable, Codable {
        case backlog = "백로그"
        case todo = "할 일"
        case inProgress = "진행 중"
        case done = "완료"

        var color: Color {
            switch self {
            case .backlog: return .gray
            case .todo: return .blue
            case .inProgress: return .orange
            case .done: return .green
            }
        }
    }

    // MARK: Codable
    enum CodingKeys: String, CodingKey {
        case id, projectId, title, tags, priority, storyPoints, assignee, assigneeColorHex, status, sprint
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(projectId, forKey: .projectId)
        try c.encode(title, forKey: .title)
        try c.encode(tags, forKey: .tags)
        try c.encode(priority, forKey: .priority)
        try c.encode(storyPoints, forKey: .storyPoints)
        try c.encode(assignee, forKey: .assignee)
        try c.encode(assigneeColor.toHex(), forKey: .assigneeColorHex)
        try c.encode(status, forKey: .status)
        try c.encode(sprint, forKey: .sprint)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        projectId = try c.decodeIfPresent(UUID.self, forKey: .projectId)
        title = try c.decode(String.self, forKey: .title)
        tags = try c.decode([String].self, forKey: .tags)
        priority = try c.decode(Priority.self, forKey: .priority)
        storyPoints = try c.decode(Int.self, forKey: .storyPoints)
        assignee = try c.decode(String.self, forKey: .assignee)
        let hex = try c.decode(String.self, forKey: .assigneeColorHex)
        assigneeColor = Color(hex: hex)
        status = try c.decode(TaskStatus.self, forKey: .status)
        sprint = try c.decodeIfPresent(String.self, forKey: .sprint) ?? ""
    }
}

// MARK: - Velocity
struct VelocityPoint: Identifiable, Codable {
    let id: UUID
    let sprint: String
    let planned: Int
    let completed: Int

    init(id: UUID = UUID(), sprint: String, planned: Int, completed: Int) {
        self.id = id
        self.sprint = sprint
        self.planned = planned
        self.completed = completed
    }
}

// MARK: - Activity
struct ActivityItem: Identifiable, Codable {
    let id: UUID
    let icon: String
    let text: String
    let highlightedText: String
    let time: String

    init(id: UUID = UUID(), icon: String, text: String, highlightedText: String, time: String) {
        self.id = id
        self.icon = icon
        self.text = text
        self.highlightedText = highlightedText
        self.time = time
    }
}

// MARK: - Team Member
struct TeamMember: Identifiable, Codable {
    let id: UUID
    let name: String
    let color: Color
    let workload: Double // 0-100

    init(id: UUID = UUID(), name: String, color: Color, workload: Double) {
        self.id = id
        self.name = name
        self.color = color
        self.workload = workload
    }

    // MARK: Codable
    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, workload
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(color.toHex(), forKey: .colorHex)
        try c.encode(workload, forKey: .workload)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        let hex = try c.decode(String.self, forKey: .colorHex)
        color = Color(hex: hex)
        workload = try c.decode(Double.self, forKey: .workload)
    }
}

// MARK: - Navigation
enum SidebarTab: String, CaseIterable, Identifiable {
    case dashboard = "대시보드"
    case timeline = "타임라인"
    case board = "내 태스크"
    case projects = "프로젝트"
    case analytics = "분석"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .timeline: return "calendar.badge.clock"
        case .board: return "person.crop.rectangle.stack"
        case .projects: return "folder"
        case .analytics: return "chart.xyaxis.line"
        }
    }

    var emoji: String {
        switch self {
        case .dashboard: return "📊"
        case .timeline: return "📅"
        case .board: return "✅"
        case .projects: return "📁"
        case .analytics: return "📈"
        }
    }
}

// MARK: - Tag Colors
struct TagStyle {
    static func color(for tag: String) -> Color {
        switch tag {
        case "Feature": return .blue
        case "UI": return .purple
        case "Backend": return .green
        case "Bug": return .red
        case "Core": return .orange
        case "Integration": return .cyan
        case "Performance": return .pink
        case "Marketing": return .yellow
        case "Refactor": return .indigo
        case "i18n": return .mint
        case "UX": return .purple
        case "Design": return .pink
        case "iOS": return .blue
        default: return .gray
        }
    }
}
