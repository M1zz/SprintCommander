import SwiftUI

struct BoardView: View {
    @EnvironmentObject var store: AppStore
    @State private var statusFilter: TaskItem.TaskStatus? = nil
    @State private var priorityFilter: TaskItem.Priority? = nil
    @State private var selectedTask: TaskItem? = nil
    @State private var showAddTask = false

    private var filteredTasks: [TaskItem] {
        var result = store.kanbanTasks
        if let s = statusFilter { result = result.filter { $0.status == s } }
        if let p = priorityFilter { result = result.filter { $0.priority == p } }
        return result
    }

    /// Group tasks by project; tasks without a project go under nil
    private var grouped: [(project: Project?, tasks: [TaskItem])] {
        let dict = Dictionary(grouping: filteredTasks) { $0.projectId }
        var result: [(Project?, [TaskItem])] = []
        // Projects with tasks first (in store order)
        for project in store.projects {
            if let tasks = dict[project.id], !tasks.isEmpty {
                result.append((project, tasks))
            }
        }
        // Unlinked tasks
        if let orphan = dict[nil], !orphan.isEmpty {
            result.append((nil, orphan))
        }
        return result
    }

    private var statusCounts: [(TaskItem.TaskStatus, Int)] {
        TaskItem.TaskStatus.allCases.map { status in
            (status, store.kanbanTasks.filter { $0.status == status }.count)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(
                title: "내 태스크",
                subtitle: "전체 \(store.kanbanTasks.count)개 태스크 · \(store.kanbanTasks.filter { $0.status == .done }.count)개 완료",
                primaryAction: "태스크",
                primaryIcon: "plus",
                onPrimary: { showAddTask = true }
            )

            // Status summary chips
            HStack(spacing: 8) {
                StatusChip(label: "전체", count: store.kanbanTasks.count, color: Color(hex: "4FACFE"), isSelected: statusFilter == nil) {
                    statusFilter = nil
                }
                ForEach(statusCounts, id: \.0) { status, count in
                    StatusChip(label: status.rawValue, count: count, color: status.color, isSelected: statusFilter == status) {
                        statusFilter = statusFilter == status ? nil : status
                    }
                }

                Spacer()

                // Priority filter
                HStack(spacing: 4) {
                    Text("우선순위")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                    ForEach(TaskItem.Priority.allCases, id: \.self) { p in
                        Button {
                            priorityFilter = priorityFilter == p ? nil : p
                        } label: {
                            Text(p.icon)
                                .font(.system(size: 11))
                                .padding(4)
                                .background(priorityFilter == p ? p.color.opacity(0.3) : Color.white.opacity(0.04))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Task list grouped by project
            if grouped.isEmpty {
                VStack(spacing: 12) {
                    Text("태스크가 없습니다")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                    Text("프로젝트에서 태스크를 추가해보세요")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.2))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                            ProjectTaskGroup(
                                project: group.project,
                                tasks: group.tasks,
                                onTaskTap: { selectedTask = $0 },
                                onStatusChange: { task, newStatus in
                                    store.updateTaskStatus(id: task.id, newStatus: newStatus)
                                },
                                onDelete: { task in
                                    store.deleteTask(id: task.id)
                                }
                            )
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet()
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheet(task: task)
        }
    }
}

// MARK: - Status Chip

private struct StatusChip: View {
    let label: String
    let count: Int
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.3))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(isSelected ? color.opacity(0.3) : Color.white.opacity(0.06))
                    .cornerRadius(8)
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.12) : Color.white.opacity(0.03))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color.opacity(0.3) : Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Project Task Group

private struct ProjectTaskGroup: View {
    let project: Project?
    let tasks: [TaskItem]
    var onTaskTap: ((TaskItem) -> Void)? = nil
    var onStatusChange: ((TaskItem, TaskItem.TaskStatus) -> Void)? = nil
    var onDelete: ((TaskItem) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Project header
            HStack(spacing: 8) {
                if let project {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(project.color)
                        .frame(width: 4, height: 16)
                    Text(project.icon)
                        .font(.system(size: 14))
                    Text(project.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    VersionBadge(version: project.version, color: project.color)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray)
                        .frame(width: 4, height: 16)
                    Text("미연결 태스크")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Text("\(tasks.count)개")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().background(Color.white.opacity(0.04)).padding(.horizontal, 12)

            // Task rows
            ForEach(tasks) { task in
                TaskRow(task: task, projectColor: project?.color ?? .gray)
                    .onTapGesture { onTaskTap?(task) }
                    .contextMenu {
                        ForEach(TaskItem.TaskStatus.allCases, id: \.self) { newStatus in
                            Button {
                                onStatusChange?(task, newStatus)
                            } label: {
                                Label(newStatus.rawValue, systemImage: newStatus == .done ? "checkmark.circle" : "arrow.right.circle")
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            onDelete?(task)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }

                if task.id != tasks.last?.id {
                    Divider().background(Color.white.opacity(0.02)).padding(.horizontal, 16)
                }
            }
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    let task: TaskItem
    let projectColor: Color
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Image(systemName: statusIcon)
                .font(.system(size: 14))
                .foregroundColor(task.status.color)
                .frame(width: 24)

            // Title + tags
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(task.status == .done ? .white.opacity(0.35) : .white.opacity(0.85))
                    .strikethrough(task.status == .done, color: .white.opacity(0.2))
                    .lineLimit(1)

                if !task.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(task.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(TagStyle.color(for: tag).opacity(0.8))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(TagStyle.color(for: tag).opacity(0.1))
                                .cornerRadius(3)
                        }
                    }
                }
            }

            Spacer()

            // Priority
            HStack(spacing: 2) {
                Text(task.priority.icon)
                    .font(.system(size: 9))
                Text(task.priority.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(task.priority.color)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(task.priority.color.opacity(0.1))
            .cornerRadius(4)

            // Story points
            Text("\(task.storyPoints) SP")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
                .frame(width: 36, alignment: .trailing)

            // Assignee
            Text(task.assignee)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(task.assigneeColor)
                .clipShape(Circle())

            // Status badge
            Text(task.status.rawValue)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(task.status.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(task.status.color.opacity(0.12))
                .cornerRadius(4)
                .frame(width: 56)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovered ? Color.white.opacity(0.03) : Color.clear)
        .onHover { isHovered = $0 }
    }

    private var statusIcon: String {
        switch task.status {
        case .backlog: return "tray"
        case .todo: return "circle"
        case .inProgress: return "circle.dotted.circle"
        case .done: return "checkmark.circle.fill"
        }
    }
}
