import SwiftUI

struct ProjectDetailSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let project: Project

    @State private var showAddTask = false
    @State private var selectedTask: TaskItem? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text(project.icon)
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .background(project.color.opacity(0.15))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(project.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        VersionBadge(version: project.version, color: project.color)
                    }
                    Text(project.sprint)
                        .font(.system(size: 12))
                        .foregroundColor(project.color)
                }

                Spacer()

                // Task count summary
                let projectTasks = store.tasks(for: project.id)
                let doneTasks = projectTasks.filter { $0.status == .done }.count
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text("\(projectTasks.count)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("태스크")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    VStack(spacing: 2) {
                        Text("\(doneTasks)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "34D399"))
                        Text("완료")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        showAddTask = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("태스크")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(project.color.opacity(0.6))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button { showDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "EF4444").opacity(0.6))
                            .frame(width: 28, height: 28)
                            .background(Color(hex: "EF4444").opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)

            Divider().background(Color.white.opacity(0.06))

            // Kanban board
            HStack(alignment: .top, spacing: 10) {
                ForEach(TaskItem.TaskStatus.allCases, id: \.self) { status in
                    let tasks = store.tasks(for: project.id, status: status)
                    ProjectKanbanColumn(
                        status: status,
                        tasks: tasks,
                        projectColor: project.color,
                        onTaskTap: { task in selectedTask = task },
                        onStatusChange: { task, newStatus in
                            store.updateTaskStatus(id: task.id, newStatus: newStatus)
                        },
                        onDelete: { task in
                            store.deleteTask(id: task.id)
                        }
                    )
                }
            }
            .padding(16)
        }
        .frame(minWidth: 900, minHeight: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "1A1A2E"))
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet(projectId: project.id)
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheet(task: task)
        }
        .alert("프로젝트 삭제", isPresented: $showDeleteConfirm) {
            Button("삭제", role: .destructive) {
                store.deleteProject(id: project.id)
                store.addActivity(ActivityItem(
                    icon: "🗑️",
                    text: "프로젝트가 삭제되었습니다",
                    highlightedText: project.name,
                    time: "방금 전"
                ))
                dismiss()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\"\(project.name)\" 프로젝트를 삭제하시겠습니까?")
        }
    }
}

// MARK: - Project Kanban Column

private struct ProjectKanbanColumn: View {
    let status: TaskItem.TaskStatus
    let tasks: [TaskItem]
    let projectColor: Color
    var onTaskTap: ((TaskItem) -> Void)? = nil
    var onStatusChange: ((TaskItem, TaskItem.TaskStatus) -> Void)? = nil
    var onDelete: ((TaskItem) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 7, height: 7)
                    Text(status.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Text("\(tasks.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().background(Color.white.opacity(0.04)).padding(.horizontal, 8)

            // Task cards
            ScrollView {
                if tasks.isEmpty {
                    VStack(spacing: 6) {
                        Text("비어 있음")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.15))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(tasks) { task in
                            MiniTaskCard(task: task, accentColor: projectColor)
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
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.02))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Mini Task Card (compact for project kanban)

private struct MiniTaskCard: View {
    let task: TaskItem
    let accentColor: Color
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Tags (compact)
            if !task.tags.isEmpty {
                HStack(spacing: 3) {
                    ForEach(task.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(TagStyle.color(for: tag))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(TagStyle.color(for: tag).opacity(0.12))
                            .cornerRadius(3)
                    }
                    if task.tags.count > 2 {
                        Text("+\(task.tags.count - 2)")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }

            // Title
            Text(task.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)

            // Meta
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Text(task.priority.icon)
                        .font(.system(size: 8))
                    Text(task.priority.label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(task.priority.color)
                }

                Spacer()

                Text("\(task.storyPoints) SP")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))

                Text(task.assignee)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(task.assigneeColor)
                    .clipShape(Circle())
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isHovered ? accentColor.opacity(0.2) : Color.white.opacity(0.04), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}
