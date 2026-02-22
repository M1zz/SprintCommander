import SwiftUI

struct BoardView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAddTask = false
    @State private var showFilter = false
    @State private var selectedTask: TaskItem? = nil
    @State private var priorityFilter: TaskItem.Priority? = nil
    @State private var tagFilter: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(
                title: "스프린트 보드",
                subtitle: store.activeSprintNames.first ?? "스프린트를 추가해주세요",
                primaryAction: "+ 태스크",
                primaryIcon: "plus",
                onPrimary: { showAddTask = true },
                secondaryAction: "🔍 필터",
                onSecondary: { showFilter.toggle() }
            )

            // Filter bar
            if showFilter {
                HStack(spacing: 12) {
                    // Priority filter
                    HStack(spacing: 4) {
                        Text("우선순위:")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                        Button {
                            priorityFilter = nil
                        } label: {
                            Text("전체")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(priorityFilter == nil ? .white : .white.opacity(0.4))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(priorityFilter == nil ? Color(hex: "4FACFE").opacity(0.3) : Color.white.opacity(0.06))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        ForEach(TaskItem.Priority.allCases, id: \.self) { p in
                            Button {
                                priorityFilter = priorityFilter == p ? nil : p
                            } label: {
                                Text("\(p.icon) \(p.label)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(priorityFilter == p ? .white : .white.opacity(0.4))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(priorityFilter == p ? p.color.opacity(0.3) : Color.white.opacity(0.06))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider().frame(height: 16)

                    // Tag filter
                    if !store.allTags.isEmpty {
                        HStack(spacing: 4) {
                            Text("태그:")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                            Button {
                                tagFilter = nil
                            } label: {
                                Text("전체")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(tagFilter == nil ? .white : .white.opacity(0.4))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(tagFilter == nil ? Color(hex: "4FACFE").opacity(0.3) : Color.white.opacity(0.06))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            ForEach(store.allTags.prefix(6), id: \.self) { tag in
                                Button {
                                    tagFilter = tagFilter == tag ? nil : tag
                                } label: {
                                    Text(tag)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(tagFilter == tag ? .white : TagStyle.color(for: tag))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(tagFilter == tag ? TagStyle.color(for: tag).opacity(0.3) : TagStyle.color(for: tag).opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
            }

            // Sprint selector chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.activeSprintNames.indices, id: \.self) { index in
                        SprintChip(
                            title: store.activeSprintNames[index],
                            isSelected: store.selectedSprintIndex == index
                        ) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                store.selectedSprintIndex = index
                            }
                        }
                    }
                }
            }

            // Kanban columns
            HStack(alignment: .top, spacing: 14) {
                ForEach(TaskItem.TaskStatus.allCases, id: \.self) { status in
                    let filtered = store.filteredTasks(for: status, priorityFilter: priorityFilter, tagFilter: tagFilter)
                    KanbanColumn(
                        status: status,
                        tasks: filtered,
                        totalSP: filtered.reduce(0) { $0 + $1.storyPoints },
                        onTaskTap: { task in selectedTask = task },
                        onStatusChange: { task, newStatus in
                            store.updateTaskStatus(id: task.id, newStatus: newStatus)
                            store.addActivity(ActivityItem(
                                icon: "🔄",
                                text: "상태가 \(newStatus.rawValue)(으)로 변경되었습니다",
                                highlightedText: task.title,
                                time: "방금 전"
                            ))
                        },
                        onDelete: { task in
                            store.deleteTask(id: task.id)
                            store.addActivity(ActivityItem(
                                icon: "🗑️",
                                text: "태스크가 삭제되었습니다",
                                highlightedText: task.title,
                                time: "방금 전"
                            ))
                        }
                    )
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

// MARK: - Sprint Chip
struct SprintChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? Color(hex: "4FACFE") : .white.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    isSelected ?
                    AnyShapeStyle(LinearGradient(
                        colors: [Color(hex: "4FACFE").opacity(0.15), Color(hex: "A78BFA").opacity(0.15)],
                        startPoint: .leading, endPoint: .trailing
                    )) :
                    AnyShapeStyle(Color.white.opacity(0.04))
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isSelected ? Color(hex: "4FACFE").opacity(0.3) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Kanban Column
struct KanbanColumn: View {
    let status: TaskItem.TaskStatus
    let tasks: [TaskItem]
    let totalSP: Int
    var onTaskTap: ((TaskItem) -> Void)? = nil
    var onStatusChange: ((TaskItem, TaskItem.TaskStatus) -> Void)? = nil
    var onDelete: ((TaskItem) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            HStack {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(status.color)
                        .frame(width: 8, height: 8)
                    Text(status.rawValue.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Text("\(tasks.count) · \(totalSP)pt")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 14)

            // Task cards
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tasks) { task in
                        TaskCard(task: task)
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
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.02))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .frame(minHeight: 400)
    }
}

// MARK: - Task Card
struct TaskCard: View {
    let task: TaskItem
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tags
            HStack(spacing: 4) {
                ForEach(task.tags, id: \.self) { tag in
                    TagBadge(text: tag)
                }
            }

            // Title
            Text(task.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Meta row
            HStack {
                // Priority
                HStack(spacing: 3) {
                    Text(task.priority.icon)
                        .font(.system(size: 9))
                    Text(task.priority.label)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(task.priority.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(task.priority.color.opacity(0.15))
                .cornerRadius(4)

                Spacer()

                // Story points
                Text("\(task.storyPoints) SP")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))

                // Avatar
                Text(task.assignee)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(task.assigneeColor)
                    .clipShape(Circle())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.white.opacity(0.07) : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.white.opacity(0.1) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
