import SwiftUI

struct ProjectSprintListView: View {
    @EnvironmentObject var store: AppStore
    let project: Project

    @State private var showAddSprint = false
    @State private var showEditProject = false
    @State private var showDeleteConfirm = false

    private var projectSprints: [Sprint] {
        store.sprints(for: project.id).sorted { s1, s2 in
            if s1.isActive != s2.isActive { return s1.isActive }
            return s1.startDate > s2.startDate
        }
    }

    private var activeSprints: [Sprint] {
        projectSprints.filter { $0.isActive && !$0.isHidden }
    }

    private var completedSprints: [Sprint] {
        projectSprints.filter { !$0.isActive && !$0.isHidden }
    }

    private var hiddenSprints: [Sprint] {
        projectSprints.filter { $0.isHidden }
    }

    private var projectTasks: [TaskItem] { store.tasks(for: project.id) }
    private var totalSP: Int { projectTasks.reduce(0) { $0 + $1.storyPoints } }
    private var doneSP: Int { projectTasks.filter { $0.status == .done }.reduce(0) { $0 + $1.storyPoints } }
    private var doneTaskCount: Int { projectTasks.filter { $0.status == .done }.count }
    private var overallProgress: Double {
        guard !projectTasks.isEmpty else { return 0 }
        return Double(doneTaskCount) / Double(projectTasks.count) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.06))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Project info
                    projectInfoSection

                    // Project summary stats
                    projectSummary

                    // Active sprints
                    if !activeSprints.isEmpty {
                        sprintSection(title: "진행 중인 스프린트", sprints: activeSprints, isEmpty: false)
                    }

                    // Empty state
                    if projectSprints.isEmpty {
                        emptyState
                    }

                    // Completed sprints
                    if !completedSprints.isEmpty {
                        sprintSection(title: "완료된 스프린트", sprints: completedSprints, isEmpty: false)
                    }

                    // Hidden sprints
                    if !hiddenSprints.isEmpty {
                        hiddenSprintSection
                    }
                }
                .padding(28)
            }
        }
        .sheet(isPresented: $showAddSprint) {
            AddSprintSheet(project: project)
        }
        .sheet(isPresented: $showEditProject) {
            EditProjectSheet(project: project)
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
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
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
                Menu {
                    Button { showEditProject = true } label: {
                        Label("프로젝트 편집", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("프로젝트 삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                PrimaryButton(title: "새 스프린트", icon: "plus") {
                    showAddSprint = true
                }
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
                        Text("전체 진행률")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        Text("\(Int(overallProgress))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(project.color)
                    }
                    ProgressBarView(progress: overallProgress, color: project.color, height: 6)
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

            // Right: Release Notes
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

                        let completed = projectTasks.filter { $0.status == .done }
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

    private var checklistRow: some View {
        HStack(spacing: 12) {
            checkBadge(
                label: "랜딩 페이지",
                value: project.landingURL,
                doneColor: Color(hex: "34D399"),
                isURL: true
            )
            checkBadge(
                label: "앱스토어",
                value: project.appStoreURL,
                doneColor: Color(hex: "6366F1"),
                isURL: true
            )
            checkBadge(
                label: "가격",
                value: project.pricing.summary,
                doneColor: Color(hex: "4FACFE"),
                isURL: false
            )
            checkBadge(
                label: "다국어",
                value: project.languages.isEmpty ? "" : project.languages.joined(separator: ", "),
                doneColor: Color(hex: "F472B6"),
                isURL: false
            )
        }
        .padding(.top, 4)
    }

    private func checkBadge(label: String, value: String, doneColor: Color, isURL: Bool) -> some View {
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

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    // MARK: - Project Summary

    private var projectSummary: some View {
        HStack(spacing: 12) {
            summaryCard(
                icon: "flame.fill",
                label: "스프린트",
                value: "\(activeSprints.count)개 활성",
                color: Color(hex: "FB923C")
            )
            summaryCard(
                icon: "checkmark.circle.fill",
                label: "전체 태스크",
                value: "\(doneTaskCount)/\(projectTasks.count)",
                color: Color(hex: "34D399")
            )
            summaryCard(
                icon: "star.fill",
                label: "스토리 포인트",
                value: "\(doneSP)/\(totalSP) SP",
                color: Color(hex: "A78BFA")
            )
            summaryCard(
                icon: "archivebox.fill",
                label: "완료 스프린트",
                value: "\(completedSprints.count)개",
                color: Color(hex: "64748B")
            )
        }
    }

    private func summaryCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
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

    // MARK: - Sprint Section

    private func sprintSection(title: String, sprints: [Sprint], isEmpty: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: title)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 500), spacing: 12)], spacing: 12) {
                ForEach(sprints) { sprint in
                    SprintCard(sprint: sprint, project: project)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.selectedSprint = sprint
                            }
                        }
                }
            }
        }
    }

    // MARK: - Hidden Sprint Section

    @State private var showHiddenSprints = false

    private var hiddenSprintSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHiddenSprints.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: showHiddenSprints ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                    Image(systemName: "eye.slash")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                    Text("숨겨진 스프린트")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                    Text("\(hiddenSprints.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.25))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                }
            }
            .buttonStyle(.plain)

            if showHiddenSprints {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 500), spacing: 12)], spacing: 12) {
                    ForEach(hiddenSprints) { sprint in
                        SprintCard(sprint: sprint, project: project)
                            .opacity(0.6)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    store.selectedSprint = sprint
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.2.crossed")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.1))

            Text("아직 스프린트가 없습니다")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))

            Text("스프린트를 만들어 태스크를 관리하세요")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.25))

            PrimaryButton(title: "첫 스프린트 만들기", icon: "plus") {
                showAddSprint = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color.white.opacity(0.02))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }
}

// MARK: - Sprint Card

struct SprintCard: View {
    @EnvironmentObject var store: AppStore
    let sprint: Sprint
    let project: Project
    @State private var isHovered = false
    @State private var showDeleteConfirm = false
    @State private var showEditSprint = false

    private var sprintTasks: [TaskItem] {
        store.tasks(for: sprint)
    }

    private var doneCount: Int {
        sprintTasks.filter { $0.status == .done }.count
    }

    private var progress: Double {
        guard !sprintTasks.isEmpty else { return 0 }
        return Double(doneCount) / Double(sprintTasks.count) * 100
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M.d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: name + status
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: sprint.isActive ? "flame.fill" : "checkmark.seal.fill")
                        .font(.system(size: 13))
                        .foregroundColor(sprint.isActive ? Color(hex: "FB923C") : Color(hex: "34D399"))

                    Text(sprint.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))

                    VersionBadge(version: sprint.targetVersion, color: project.color)
                }

                Spacer()

                HStack(spacing: 8) {
                    if sprint.isActive {
                        Text("\(sprint.daysRemaining)일 남음")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(sprint.daysRemaining <= 3 ? Color(hex: "EF4444") : Color(hex: "FB923C"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (sprint.daysRemaining <= 3 ? Color(hex: "EF4444") : Color(hex: "FB923C")).opacity(0.12)
                            )
                            .cornerRadius(6)
                    } else {
                        Text("완료")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "34D399"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "34D399").opacity(0.12))
                            .cornerRadius(6)
                    }

                    // Context menu trigger
                    Menu {
                        Button {
                            showEditSprint = true
                        } label: {
                            Label("편집", systemImage: "pencil")
                        }
                        if sprint.isActive {
                            Button {
                                store.completeSprint(id: sprint.id)
                            } label: {
                                Label("스프린트 완료", systemImage: "checkmark.circle")
                            }
                        } else {
                            Button {
                                store.reactivateSprint(id: sprint.id)
                            } label: {
                                Label("다시 진행", systemImage: "arrow.counterclockwise")
                            }
                        }
                        if sprint.isHidden {
                            Button {
                                store.unhideSprint(id: sprint.id)
                            } label: {
                                Label("다시 보이기", systemImage: "eye")
                            }
                        } else {
                            Button {
                                store.hideSprint(id: sprint.id)
                            } label: {
                                Label("감추기", systemImage: "eye.slash")
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Goal
            if !sprint.goal.isEmpty {
                Text(sprint.goal)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(2)
            }

            // Date range
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                Text("\(Self.dateFormatter.string(from: sprint.startDate)) - \(Self.dateFormatter.string(from: sprint.endDate))")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Progress
            VStack(spacing: 6) {
                HStack {
                    Text("태스크 진행률")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                    Text("\(doneCount)/\(sprintTasks.count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(project.color)
                }
                ProgressBarView(progress: progress, color: project.color, height: 5)
            }

            // Task status breakdown
            HStack(spacing: 8) {
                ForEach(TaskItem.TaskStatus.allCases, id: \.self) { status in
                    let count = sprintTasks.filter { $0.status == status }.count
                    if count > 0 {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(status.color)
                                .frame(width: 6, height: 6)
                            Text("\(status.rawValue) \(count)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                }
                Spacer()
                let sp = sprintTasks.reduce(0) { $0 + $1.storyPoints }
                if sp > 0 {
                    Text("\(sp) SP")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.25))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.white.opacity(0.07) : Color.white.opacity(0.04))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(sprint.isActive ? project.color : Color(hex: "64748B"))
                .frame(width: 4)
                .padding(.vertical, 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? project.color.opacity(0.2) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        .sheet(isPresented: $showEditSprint) {
            EditSprintSheet(sprint: sprint, project: project)
        }
        .alert("스프린트 삭제", isPresented: $showDeleteConfirm) {
            Button("삭제", role: .destructive) {
                store.deleteSprint(id: sprint.id)
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\"\(sprint.name)\" 스프린트를 삭제하시겠습니까?")
        }
    }
}
