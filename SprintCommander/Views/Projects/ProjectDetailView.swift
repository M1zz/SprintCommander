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
    @State private var showProjectInfo = true
    @State private var editingSprint: Sprint? = nil
    @State private var deletingSprintId: UUID? = nil
    @State private var showSprintDeleteConfirm = false

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

                    // Project Info (collapsible)
                    projectInfoSection

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
        .sheet(item: $editingSprint) { sprint in
            EditSprintSheet(sprint: sprint, project: project)
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
        .alert("스프린트 삭제", isPresented: $showSprintDeleteConfirm) {
            Button("삭제", role: .destructive) {
                if let id = deletingSprintId {
                    store.deleteSprint(id: id)
                    sprintFilter = nil
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            if let id = deletingSprintId,
               let sprint = store.sprints.first(where: { $0.id == id }) {
                Text("\"\(sprint.name)\" 스프린트를 삭제하시겠습니까?")
            } else {
                Text("스프린트를 삭제하시겠습니까?")
            }
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

                // Completed sprint chips (collapsed, excluding hidden)
                let completedSprints = projectSprints.filter { !$0.isActive && !$0.isHidden }
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
                VersionBadge(version: sprint.targetVersion, color: project.color)
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

            Menu {
                Button { editingSprint = sprint } label: {
                    Label("편집", systemImage: "pencil")
                }
                if sprint.isActive {
                    Button {
                        store.completeSprint(id: sprint.id)
                        sprintFilter = nil
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
                        sprintFilter = nil
                    } label: {
                        Label("감추기", systemImage: "eye.slash")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    deletingSprintId = sprint.id
                    showSprintDeleteConfirm = true
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
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

    // MARK: - Project Info Section

    private var projectInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Collapsible header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showProjectInfo.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    SectionHeaderView(title: "프로젝트 상세 정보")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                        .rotationEffect(.degrees(showProjectInfo ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showProjectInfo {
                // 2x2 card grid
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    // Card 1: 경로 & 링크
                    pathAndLinksCard
                    // Card 2: 가격 정보
                    pricingCard
                    // Card 3: 지원 언어
                    languagesCard
                    // Card 4: 프로젝트 메타
                    projectMetaCard
                    // Card 5: 릴리즈 노트
                    releaseNotesCard
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var pathAndLinksCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("경로 & 링크")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            if !project.sourcePath.isEmpty {
                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.sourcePath)
                } label: {
                    HStack(spacing: 6) {
                        Text("📁")
                            .font(.system(size: 11))
                        Text("소스 경로")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        HStack(spacing: 3) {
                            Text(shortenPath(project.sourcePath))
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "4FACFE"))
                                .lineLimit(1)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8))
                                .foregroundColor(Color(hex: "4FACFE").opacity(0.6))
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                infoDetailRow(icon: "📁", label: "소스 경로", value: "미설정", isEmpty: true)
            }

            if !project.landingURL.isEmpty {
                urlRow(icon: "🌐", label: "랜딩 페이지", url: project.landingURL)
            } else {
                infoDetailRow(icon: "🌐", label: "랜딩 페이지", value: "미설정", isEmpty: true)
            }

            if !project.appStoreURL.isEmpty {
                urlRow(icon: "🛍️", label: "앱스토어", url: project.appStoreURL)
            } else {
                infoDetailRow(icon: "🛍️", label: "앱스토어", value: "미설정", isEmpty: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var pricingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("가격 정보")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            if project.pricing.isEmpty {
                Text("가격 미설정")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.2))
            } else {
                pricingDetailRow(icon: "⬇️", label: "다운로드", value: project.pricing.downloadPrice)
                pricingDetailRow(icon: "📅", label: "월 구독", value: project.pricing.monthlyPrice)
                pricingDetailRow(icon: "📅", label: "연 구독", value: project.pricing.yearlyPrice)
                pricingDetailRow(icon: "♾️", label: "평생", value: project.pricing.lifetimePrice)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var languagesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("지원 언어 (\(project.languages.count)개)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            if project.languages.isEmpty {
                Text("다국어 미설정")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.2))
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(project.languages, id: \.self) { lang in
                        Text(lang)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var projectMetaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("프로젝트 메타")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            infoDetailRow(icon: "🕐", label: "최종 수정", value: formatDate(project.lastModified), isEmpty: false)

            // 활성 스프린트 - 클릭으로 바로 이동
            HStack(spacing: 6) {
                Text("🏁")
                    .font(.system(size: 11))
                Text("활성 스프린트")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                if activeSprints.isEmpty {
                    Text("없음")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.2))
                } else {
                    ForEach(activeSprints) { sprint in
                        Button {
                            sprintFilter = sprint.name
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(project.color)
                                    .frame(width: 5, height: 5)
                                Text(sprint.name)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(sprintFilter == sprint.name ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(sprintFilter == sprint.name ? project.color.opacity(0.2) : Color.white.opacity(0.06))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 완료 스프린트
            let completedSprints = projectSprints.filter { !$0.isActive && !$0.isHidden }
            if !completedSprints.isEmpty {
                HStack(spacing: 6) {
                    Text("📦")
                        .font(.system(size: 11))
                    Text("완료 스프린트")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    ForEach(completedSprints) { sprint in
                        Button {
                            sprintFilter = sprint.name
                        } label: {
                            Text(sprint.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(sprintFilter == sprint.name ? .white : .white.opacity(0.4))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(sprintFilter == sprint.name ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if projectSprints.isEmpty {
                infoDetailRow(icon: "📦", label: "총 스프린트", value: "없음", isEmpty: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    @State private var releaseNotesCopied = false

    /// 릴리즈 노트에 사용할 스프린트 (필터 우선 → 활성 스프린트)
    private var releaseNoteSprint: Sprint? {
        if let filterName = sprintFilter, filterName != "_unassigned" {
            return projectSprints.first(where: { $0.name == filterName })
        }
        return activeSprints.first
    }

    /// 릴리즈 노트에 표시할 버전: 스프린트 targetVersion 우선, 없으면 프로젝트 version
    private var releaseNoteVersion: String {
        let tv = releaseNoteSprint?.targetVersion ?? ""
        return tv.isEmpty ? project.version : tv
    }

    /// 릴리즈 노트에 표시할 완료 태스크 (스프린트별 필터)
    private var releaseNoteCompletedTasks: [TaskItem] {
        let name = releaseNoteSprint?.name ?? ""
        if name.isEmpty {
            return allProjectTasks.filter { $0.status == .done }
        }
        return allProjectTasks.filter { $0.status == .done && $0.sprint == name }
    }

    private var releaseNotesCard: some View {
        let displayVersion = releaseNoteVersion
        let completed = releaseNoteCompletedTasks
        let sprintName = releaseNoteSprint?.name ?? ""

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("릴리즈 노트")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                if !displayVersion.isEmpty && !completed.isEmpty {
                    Button {
                        let text = releaseNotesText(version: displayVersion, tasks: completed)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        withAnimation { releaseNotesCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { releaseNotesCopied = false }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: releaseNotesCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 9))
                            Text(releaseNotesCopied ? "복사됨" : "복사")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(releaseNotesCopied ? Color(hex: "34D399") : .white.opacity(0.4))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(releaseNotesCopied ? Color(hex: "34D399").opacity(0.12) : Color.white.opacity(0.06))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !displayVersion.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "34D399"))
                    Text("v\(displayVersion)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    if !sprintName.isEmpty {
                        Text(sprintName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(3)
                    }
                }

                if completed.isEmpty {
                    Text("완료된 태스크가 없습니다")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.2))
                } else {
                    ForEach(completed.prefix(5)) { task in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "34D399").opacity(0.6))
                            Text(task.title)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                    if completed.count > 5 {
                        Text("외 \(completed.count - 5)개 완료")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.25))
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.15))
                    Text("버전 정보가 없습니다")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.2))
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func releaseNotesText(version: String, tasks: [TaskItem]) -> String {
        var lines = ["v\(version)", ""]
        for task in tasks {
            lines.append("- \(task.title)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Info Helpers

    @ViewBuilder
    private func infoDetailRow(icon: String, label: String, value: String, isEmpty: Bool) -> some View {
        HStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 11))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 11))
                .foregroundColor(isEmpty ? .white.opacity(0.2) : .white.opacity(0.7))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func urlRow(icon: String, label: String, url: String) -> some View {
        HStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 11))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
            Button {
                if let u = URL(string: url) {
                    NSWorkspace.shared.open(u)
                }
            } label: {
                HStack(spacing: 3) {
                    Text(url)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "4FACFE"))
                        .lineLimit(1)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: "4FACFE").opacity(0.6))
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func pricingDetailRow(icon: String, label: String, value: String) -> some View {
        if !value.isEmpty {
            HStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    private func shortenPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.M.d HH:mm"
        return formatter.string(from: date)
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
                        sprintsForTask: { store.availableSprintsForTask($0) },
                        onTaskTap: { selectedTask = $0 },
                        onStatusChange: { task, newStatus in
                            store.updateTaskStatus(id: task.id, newStatus: newStatus)
                        },
                        onSprintAssign: { task, sprintName in
                            store.assignTaskToSprint(taskId: task.id, sprintName: sprintName)
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
    var sprintsForTask: ((TaskItem) -> [Sprint])? = nil
    var onTaskTap: ((TaskItem) -> Void)? = nil
    var onStatusChange: ((TaskItem, TaskItem.TaskStatus) -> Void)? = nil
    var onSprintAssign: ((TaskItem, String?) -> Void)? = nil
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
                                    Section("상태 변경") {
                                        ForEach(TaskItem.TaskStatus.allCases, id: \.self) { newStatus in
                                            Button {
                                                onStatusChange?(task, newStatus)
                                            } label: {
                                                Label(newStatus.rawValue, systemImage: newStatus == .done ? "checkmark.circle" : "arrow.right.circle")
                                            }
                                        }
                                    }

                                    let availableSprints = sprintsForTask?(task) ?? []
                                    if !availableSprints.isEmpty {
                                        Menu("스프린트 배정") {
                                            ForEach(availableSprints) { sprint in
                                                Button {
                                                    onSprintAssign?(task, sprint.name)
                                                } label: {
                                                    HStack {
                                                        Text(sprint.name)
                                                        if task.sprint == sprint.name {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                            if !task.sprint.isEmpty {
                                                Divider()
                                                Button("스프린트 해제") {
                                                    onSprintAssign?(task, nil)
                                                }
                                            }
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
