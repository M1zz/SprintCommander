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
    var pricing: String

    init(id: UUID = UUID(), name: String, icon: String, desc: String, progress: Double, sprint: String, totalTasks: Int, doneTasks: Int, color: Color, startWeek: Int = 0, durationWeeks: Int = 4, sourcePath: String = "", version: String = "", landingURL: String = "", pricing: String = "") {
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
        self.pricing = pricing
    }

    var progressPercent: String {
        "\(Int(progress))%"
    }

    // MARK: Codable
    enum CodingKeys: String, CodingKey {
        case id, name, icon, desc, progress, sprint, totalTasks, doneTasks
        case colorHex, startWeek, durationWeeks, sourcePath, version
        case landingURL, pricing
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
        try c.encode(pricing, forKey: .pricing)
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
        pricing = try c.decodeIfPresent(String.self, forKey: .pricing) ?? ""
    }
}

// MARK: - Sprint
struct Sprint: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let projectName: String
    let color: Color
    let startDate: Date
    let endDate: Date
    var isActive: Bool
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
