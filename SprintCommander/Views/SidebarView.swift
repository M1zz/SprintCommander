import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Navigation
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "Navigation")

                    ForEach(SidebarTab.allCases) { tab in
                        SidebarNavItem(
                            tab: tab,
                            isSelected: store.selectedTab == tab && store.selectedProject == nil,
                            badge: badgeFor(tab)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.selectedSprint = nil
                                store.selectedProject = nil
                                store.selectedTab = tab
                            }
                        }
                    }
                }

                // Projects
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "Projects (\(store.projects.count))")

                    ForEach(store.projects.prefix(12)) { project in
                        ProjectListItem(project: project, isSelected: store.selectedProject?.id == project.id)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    store.selectedSprint = nil
                                    store.selectedProject = project
                                }
                            }
                    }

                    if store.projects.count > 12 {
                        HStack(spacing: 8) {
                            Text("+ 더보기 (\(store.projects.count - 12))")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                    }
                }

                // Active Sprints
                if !store.activeSprints.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel(text: "Active Sprints (\(store.activeSprints.count))")

                        ForEach(Array(store.activeSprints.enumerated()), id: \.element.id) { index, sprint in
                            let projectName = store.projects.first(where: { $0.id == sprint.projectId })?.name ?? ""
                            let sprintColor = store.projects.first(where: { $0.id == sprint.projectId })?.color ?? .gray
                            let isSelected = store.selectedSprint?.id == sprint.id
                            SprintListItem(
                                color: sprintColor,
                                text: "\(sprint.name) · \(projectName)",
                                isSelected: isSelected
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if let project = store.projects.first(where: { $0.id == sprint.projectId }) {
                                        store.selectedProject = project
                                        store.selectedSprint = sprint
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 240)
        .background(Color(hex: "16213E").opacity(0.95))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1)
        }
    }

    func badgeFor(_ tab: SidebarTab) -> String? {
        switch tab {
        case .board:
            let count = store.kanbanTasks.filter { $0.status == .inProgress }.count
            return count > 0 ? "\(count)" : nil
        case .projects:
            return store.projects.isEmpty ? nil : "\(store.projects.count)"
        default: return nil
        }
    }
}

// MARK: - Section Label
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(.white.opacity(0.25))
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
    }
}

// MARK: - Nav Item
struct SidebarNavItem: View {
    let tab: SidebarTab
    let isSelected: Bool
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                    .foregroundColor(isSelected ? Color(hex: "4FACFE") : .white.opacity(0.5))

                Text(tab.rawValue)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? Color(hex: "4FACFE") : .white.opacity(0.6))

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color(hex: "4FACFE").opacity(0.12) : Color.clear)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "4FACFE"))
                        .frame(width: 3, height: 16)
                        .offset(x: -1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sprint List Item
struct SprintListItem: View {
    let color: Color
    let text: String
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? color : .white.opacity(0.5))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? color.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Project List Item
struct ProjectListItem: View {
    let project: Project
    var isSelected: Bool = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(project.color)
                .frame(width: 7, height: 7)
            Text("\(project.icon) \(project.name)")
                .font(.system(size: 11))
                .foregroundColor(isSelected ? project.color : (isHovered ? .white.opacity(0.8) : .white.opacity(0.5)))
                .lineLimit(1)
            Spacer()
            if !project.version.isEmpty {
                Text("v\(project.version)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? project.color.opacity(0.12) : (isHovered ? Color.white.opacity(0.06) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
