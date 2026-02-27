import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject var store: AppStore
    let project: Project
    let sprint: Sprint

    @State private var showAddTask = false
    @State private var selectedTask: TaskItem? = nil
    @State private var showDeleteConfirm = false
    @State private var showEditProject = false

    private var sprintTasks: [TaskItem] { store.tasks(for: sprint) }
    private var doneTasks: Int { sprintTasks.filter { $0.status == .done }.count }
    private var inProgressTasks: Int { sprintTasks.filter { $0.status == .inProgress }.count }
    private var totalSP: Int { sprintTasks.reduce(0) { $0 + $1.storyPoints } }
    private var doneSP: Int { sprintTasks.filter { $0.status == .done }.reduce(0) { $0 + $1.storyPoints } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back + Header
            header

            Divider().background(Color.white.opacity(0.06))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Project Info Section
                    projectInfoSection

                    // Stats Row
                    statsRow

                    // Kanban Board
                    kanbanSection
                }
                .padding(28)
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet(projectId: project.id, sprintName: sprint.name)
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
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            // Back button - goes to sprint list
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.selectedSprint = nil
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("스프린트")
                        .font(.system(size: 13))
                }
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Project icon + name + sprint
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
                    Text(sprint.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(project.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(project.color.opacity(0.12))
                        .cornerRadius(6)
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

                Button { showAddTask = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("태스크 추가")
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

    // MARK: - Project Info

    private var projectInfoSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left: Details
            VStack(alignment: .leading, spacing: 14) {
                SectionHeaderView(title: "프로젝트 정보")

                // Sprint
                infoRow(icon: "flag.fill", label: "스프린트", value: sprint.name, color: project.color)

                // Sprint period
                sprintPeriodRow

                // Version
                if !project.version.isEmpty {
                    infoRow(icon: "tag.fill", label: "최근 버전", value: "v\(project.version)", color: Color(hex: "34D399"))
                }

                // Source path
                if !project.sourcePath.isEmpty {
                    infoRow(icon: "folder.fill", label: "소스 경로", value: shortenPath(project.sourcePath), color: Color(hex: "FBBF24"))
                }

                // Landing page & Pricing checklist
                checklistRow

                // Progress
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("진행률")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        let sprintProgress = sprintTasks.isEmpty ? 0.0 : Double(doneTasks) / Double(sprintTasks.count) * 100
                        Text("\(Int(sprintProgress))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(project.color)
                    }
                    let sprintProgress = sprintTasks.isEmpty ? 0.0 : Double(doneTasks) / Double(sprintTasks.count) * 100
                    ProgressBarView(progress: sprintProgress, color: project.color, height: 6)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            // Right: Release Notes / Recent Activity
            VStack(alignment: .leading, spacing: 14) {
                SectionHeaderView(title: "릴리즈 노트")

                if !project.version.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "34D399"))
                            Text("v\(project.version)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }

                        // Task summary as release notes
                        let completed = sprintTasks.filter { $0.status == .done }
                        if completed.isEmpty {
                            Text("완료된 태스크가 없습니다")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.3))
                        } else {
                            ForEach(completed.prefix(5)) { task in
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "34D399").opacity(0.6))
                                    Text(task.title)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(1)
                                }
                            }
                            if completed.count > 5 {
                                Text("외 \(completed.count - 5)개 완료")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.25))
                            }
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.15))
                        Text("버전 정보가 없습니다")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            miniStat(label: "전체 태스크", value: "\(sprintTasks.count)", color: Color(hex: "4FACFE"))
            miniStat(label: "진행 중", value: "\(inProgressTasks)", color: .orange)
            miniStat(label: "완료", value: "\(doneTasks)", color: Color(hex: "34D399"))
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
            SectionHeaderView(title: "칸반 보드")

            HStack(alignment: .top, spacing: 12) {
                ForEach(TaskItem.TaskStatus.allCases, id: \.self) { status in
                    let tasks = sprintTasks.filter { $0.status == status }
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

    // MARK: - Sprint Period

    private var sprintPeriodRow: some View {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.M.d"
        return HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "22D3EE").opacity(0.7))
                .frame(width: 20)
            Text("기간")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
            Text("\(fmt.string(from: sprint.startDate)) - \(fmt.string(from: sprint.endDate))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            if sprint.isActive {
                Text("\(sprint.daysRemaining)일 남음")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(sprint.daysRemaining <= 3 ? Color(hex: "EF4444") : Color(hex: "FB923C"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((sprint.daysRemaining <= 3 ? Color(hex: "EF4444") : Color(hex: "FB923C")).opacity(0.12))
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - Checklist

    private var checklistRow: some View {
        HStack(spacing: 12) {
            checkBadge(
                label: "랜딩 페이지",
                value: project.landingURL,
                doneIcon: "globe",
                emptyIcon: "globe",
                doneColor: Color(hex: "34D399"),
                isURL: true
            )
            checkBadge(
                label: "앱스토어",
                value: project.appStoreURL,
                doneIcon: "bag.fill",
                emptyIcon: "bag",
                doneColor: Color(hex: "6366F1"),
                isURL: true
            )
            checkBadge(
                label: "가격",
                value: project.pricing.summary,
                doneIcon: "dollarsign.circle.fill",
                emptyIcon: "dollarsign.circle",
                doneColor: Color(hex: "4FACFE"),
                isURL: false
            )
        }
        .padding(.top, 4)
    }

    private func checkBadge(label: String, value: String, doneIcon: String, emptyIcon: String, doneColor: Color, isURL: Bool) -> some View {
        let isDone = !value.isEmpty
        let canOpen = isURL && isDone
        
        return Button {
            if canOpen, let url = URL(string: value) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundColor(isDone ? doneColor : .white.opacity(0.2))
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(isDone ? 0.7 : 0.3))
                    if isDone {
                        Text(value)
                            .font(.system(size: 10))
                            .foregroundColor(doneColor.opacity(0.8))
                            .lineLimit(1)
                    } else {
                        Text("미설정")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
                Spacer()
                if canOpen {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9))
                        .foregroundColor(doneColor.opacity(0.5))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isDone ? doneColor.opacity(0.08) : Color.white.opacity(0.03))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDone ? doneColor.opacity(0.15) : Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(canOpen ? "클릭하여 열기" : "")
    }

    // MARK: - Helpers

    private func infoRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color.opacity(0.7))
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
        }
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
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

            // Sprint
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
