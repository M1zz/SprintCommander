import SwiftUI
import Foundation

// MARK: - Project
struct Project: Identifiable, Hashable {
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

    init(id: UUID = UUID(), name: String, icon: String, desc: String, progress: Double, sprint: String, totalTasks: Int, doneTasks: Int, color: Color, startWeek: Int = 0, durationWeeks: Int = 4) {
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
    }

    var progressPercent: String {
        "\(Int(progress))%"
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
struct TaskItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var tags: [String]
    var priority: Priority
    var storyPoints: Int
    var assignee: String
    var assigneeColor: Color
    var status: TaskStatus

    init(id: UUID = UUID(), title: String, tags: [String], priority: Priority, storyPoints: Int, assignee: String, assigneeColor: Color, status: TaskStatus) {
        self.id = id
        self.title = title
        self.tags = tags
        self.priority = priority
        self.storyPoints = storyPoints
        self.assignee = assignee
        self.assigneeColor = assigneeColor
        self.status = status
    }

    enum Priority: String, CaseIterable {
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

    enum TaskStatus: String, CaseIterable {
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
}

// MARK: - Velocity
struct VelocityPoint: Identifiable {
    let id = UUID()
    let sprint: String
    let planned: Int
    let completed: Int
}

// MARK: - Activity
struct ActivityItem: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let highlightedText: String
    let time: String
}

// MARK: - Team Member
struct TeamMember: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let workload: Double // 0-100
}

// MARK: - Navigation
enum SidebarTab: String, CaseIterable, Identifiable {
    case dashboard = "대시보드"
    case timeline = "타임라인"
    case board = "스프린트 보드"
    case projects = "프로젝트"
    case analytics = "분석"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .timeline: return "calendar.badge.clock"
        case .board: return "list.bullet.rectangle"
        case .projects: return "folder"
        case .analytics: return "chart.xyaxis.line"
        }
    }

    var emoji: String {
        switch self {
        case .dashboard: return "📊"
        case .timeline: return "📅"
        case .board: return "📋"
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
