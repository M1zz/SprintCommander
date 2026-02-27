import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject var store: AppStore
    let project: Project

    @State private var showAddTask = false
    @State private var showAddSprint = false
    @State private var selectedTask: TaskItem? = nil
    @State private var showDeleteConfirm = false
    @State private var showEditProject = false
    @State private var sprintFilter: String? = nil // nil = 전체, "_unassigned" = 미배정, else = sprint name

    private var projectSprints: [Sprint] {
        store.sprints(for: project.id)
    }

    private var activeSprints: [Sprint] {
        projectSprints.filter { $0.isActive }
    }

    private var allProjectTasks: [TaskItem] {
        store.kanbanTasks.filter { $0.projectId == project.id }
    }

    private var filteredTasks: [TaskItem] {
        guard let filter = sprintFilter else { return allProjectTasks }
        if filter == "_unassigned" {
            return allProjectTasks.filter { $0.sprint.isEmpty }
        }
        return allProjectTasks.filter { $0.sprint == filter }
    }

    private var doneCount: Int { filteredTasks.filter { $0.status == .done }.count }
    private var inProgressCount: Int { filteredTasks.filter { $0.status == .inProgress }.count }
    private var totalSP: Int { filteredTasks.reduce(0) { $0 + $1.storyPoints } }
    private var doneSP: Int { filteredTasks.filter { $0.status == .done }.reduce(0) { $0 + $1.storyPoints } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.06))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Sprint filter chips + sprint management
                    sprintFilterSection

                    // Stats Row
                    statsRow

                    // Kanban Board
                    kanbanSection
                }
                .padding(28)
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet(projectId: project.id, sprintName: sprintFilter == "_unassigned" ? "" : (sprintFilter ?? ""))
        }
        .sheet(isPresented: $showAddSprint) {
            AddSprintSheet(project: project)
        }
        .sheet(isPresented: $showEditProject) {
            EditProjectSheet(project: project)
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
                store.selectedSprint = nil
                store.selectedProject = nil
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\"\(project.name)\" 프로젝트를 삭제하시겠습니까?")
        }
        .onAppear {
            // Sidebar에서 selectedSprint로 진입한 경우 필터 설정
            if let sprint = store.selectedSprint {
                sprintFilter = sprint.name
            }
        }
        .onChange(of: store.selectedSprint) { newSprint in
            if let sprint = newSprint {
                sprintFilter = sprint.name
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.selectedSprint = nil
                    store.selectedProject = nil
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("프로젝트")
                        .font(.system(size: 13))
                }
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Text(project.icon)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(project.color.opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(project.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    VersionBadge(version: project.version, color: project.color)
                }
                Text(project.desc)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                Button { showEditProject = true } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button { showAddSprint = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flag")
                            .font(.system(size: 10))
                        Text("스프린트")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)

                Button { showAddTask = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("태스크")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(
                            colors: [project.color, project.color.opacity(0.7)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)

                Button { showDeleteConfirm = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "EF4444").opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(Color(hex: "EF4444").opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }

    // MARK: - Sprint Filter Section

    private var sprintFilterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                // 전체 chip
                sprintChip(label: "전체", count: allProjectTasks.count, isSelected: sprintFilter == nil) {
                    sprintFilter = nil
                }

                // 미배정 chip
                let unassignedCount = allProjectTasks.filter { $0.sprint.isEmpty }.count
                if unassignedCount > 0 {
                    sprintChip(label: "미배정", count: unassignedCount, isSelected: sprintFilter == "_unassigned", color: .gray) {
                        sprintFilter = sprintFilter == "_unassigned" ? nil : "_unassigned"
                    }
                }

                // Active sprint chips
                ForEach(activeSprints) { sprint in
                    let count = allProjectTasks.filter { $0.sprint == sprint.name }.count
                    sprintChip(
                        label: sprint.name,
                        count: count,
                        isSelected: sprintFilter == sprint.name,
                        color: project.color,
                        daysRemaining: sprint.daysRemaining
                    ) {
                        sprintFilter = sprintFilter == sprint.name ? nil : sprint.name
                    }
                }

                // Completed sprint chips (collapsed)
                let completedSprints = projectSprints.filter { !$0.isActive }
                if !completedSprints.isEmpty {
                    Menu {
                        ForEach(completedSprints) { sprint in
                            let count = allProjectTasks.filter { $0.sprint == sprint.name }.count
                            Button {
                                sprintFilter = sprintFilter == sprint.name ? nil : sprint.name
                            } label: {
                                Label("\(sprint.name) (\(count))", systemImage: sprintFilter == sprint.name ? "checkmark" : "archivebox")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 9))
                            Text("완료 \(completedSprints.count)")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            // Active sprint info bar
            if let filterName = sprintFilter, filterName != "_unassigned",
               let sprint = projectSprints.first(where: { $0.name == filterName }) {
                sprintInfoBar(sprint: sprint)
            }
        }
    }

    private func sprintChip(label: String, count: Int, isSelected: Bool, color: Color = Color(hex: "4FACFE"), daysRemaining: Int? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.3))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(isSelected ? color.opacity(0.3) : Color.white.opacity(0.06))
                    .cornerRadius(8)
                if let days = daysRemaining {
                    Text("\(days)d")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(days <= 3 ? Color(hex: "EF4444") : Color(hex: "FB923C"))
                }
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

    private func sprintInfoBar(sprint: Sprint) -> some View {
        let fmt = DateFormatter()
        fmt.dateFormat = "M.d"
        return HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: sprint.isActive ? "flame.fill" : "checkmark.seal.fill")
                    .font(.system(size: 11))
                    .foregroundColor(sprint.isActive ? Color(hex: "FB923C") : Color(hex: "34D399"))
                Text(sprint.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }

            if !sprint.goal.isEmpty {
                Text(sprint.goal)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                Text("\(fmt.string(from: sprint.startDate)) - \(fmt.string(from: sprint.endDate))")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }

            if sprint.isActive {
                Text("\(sprint.daysRemaining)일 남음")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(sprint.daysRemaining <= 3 ? Color(hex: "EF4444") : Color(hex: "FB923C"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((sprint.daysRemaining <= 3 ? Color(hex: "EF4444") : Color(hex: "FB923C")).opacity(0.12))
                    .cornerRadius(4)

                Button {
                    store.completeSprint(id: sprint.id)
                    sprintFilter = nil
                } label: {
                    Text("완료")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "34D399"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "34D399").opacity(0.12))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            miniStat(label: "전체 태스크", value: "\(filteredTasks.count)", color: Color(hex: "4FACFE"))
            miniStat(label: "진행 중", value: "\(inProgressCount)", color: .orange)
            miniStat(label: "완료", value: "\(doneCount)", color: Color(hex: "34D399"))
            miniStat(label: "스토리 포인트", value: "\(doneSP)/\(totalSP) SP", color: Color(hex: "A78BFA"))
        }
    }

    private func miniStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Kanban Section

    private var kanbanSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeaderView(title: "칸반 보드")
                Spacer()
                if sprintFilter != nil {
                    Button {
                        sprintFilter = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8))
                            Text("필터 해제")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                ForEach(TaskItem.TaskStatus.allCases, id: \.self) { status in
                    let tasks = filteredTasks.filter { $0.status == status }
                    DetailKanbanColumn(
                        status: status,
                        tasks: tasks,
                        projectColor: project.color,
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
            .frame(minHeight: 300)
        }
    }
}

// MARK: - Detail Kanban Column

private struct DetailKanbanColumn: View {
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
                            DetailTaskCard(task: task, accentColor: projectColor)
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

// MARK: - Detail Task Card

private struct DetailTaskCard: View {
    let task: TaskItem
    let accentColor: Color
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Tags
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

            // Sprint badge
            if !task.sprint.isEmpty {
                Text(task.sprint)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: "4FACFE").opacity(0.7))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color(hex: "4FACFE").opacity(0.1))
                    .cornerRadius(3)
            }

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
