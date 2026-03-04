import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var store: AppStore
    @State private var sortMode = 0
    @State private var searchText = ""
    @State private var showAddProject = false
    @State private var isGridView = true
    private var sortLabel: String {
        switch sortMode {
        case 1: return "이름순"
        case 2: return "진행률순"
        default: return "정렬"
        }
    }

    var filteredProjects: [Project] {
        var result: [Project]
        if searchText.isEmpty {
            result = store.projects
        } else {
            result = store.projects.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.desc.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortMode {
        case 1: result.sort { $0.name < $1.name }
        case 2: result.sort { $0.progress > $1.progress }
        default: break
        }
        return result
    }

    let columns = [
        GridItem(.adaptive(minimum: 250, maximum: 320), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(
                title: "프로젝트",
                subtitle: "\(store.projects.count)개 프로젝트 관리",
                primaryAction: "새 프로젝트",
                primaryIcon: "plus",
                onPrimary: { showAddProject = true },
                secondaryAction: sortLabel,
                onSecondary: { sortMode = (sortMode + 1) % 3 }
            )

            // Search bar + view toggle
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.3))
                    .font(.system(size: 13))
                TextField("프로젝트 검색...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .frame(height: 16)
                    .background(Color.white.opacity(0.1))

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isGridView = true }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 12))
                        .foregroundColor(isGridView ? .white.opacity(0.8) : .white.opacity(0.3))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isGridView = false }
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 12))
                        .foregroundColor(!isGridView ? .white.opacity(0.8) : .white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            if isGridView {
                // Grid
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredProjects) { project in
                        ProjectCard(project: project)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    store.selectedSprint = nil
                                    store.selectedProject = project
                                }
                            }
                    }
                }
            } else {
                // List
                VStack(spacing: 2) {
                    // Header row
                    HStack(spacing: 0) {
                        Text("프로젝트")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("버전")
                            .frame(width: 70, alignment: .center)
                        Text("태스크")
                            .frame(width: 70, alignment: .center)
                        Text("백로그")
                            .frame(width: 60, alignment: .center)
                        Text("스프린트")
                            .frame(width: 70, alignment: .center)
                        Text("체크리스트")
                            .frame(width: 120, alignment: .center)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                    Divider().background(Color.white.opacity(0.06))

                    ForEach(filteredProjects) { project in
                        ProjectListRow(project: project)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    store.selectedSprint = nil
                                    store.selectedProject = project
                                }
                            }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddProject) {
            AddProjectSheet()
        }
        .onAppear {
            store.refreshProjectVersions()
        }
    }
}

// MARK: - Project List Row
struct ProjectListRow: View {
    @EnvironmentObject var store: AppStore
    let project: Project
    @State private var isHovered = false

    private var backlogCount: Int {
        store.kanbanTasks.filter { $0.projectId == project.id && $0.status == .backlog }.count
    }

    private var sprintCount: Int {
        store.sprints(for: project.id).filter { $0.isActive }.count
    }

    private var checkCount: Int {
        var count = 0
        if !project.landingURL.isEmpty { count += 1 }
        if !project.appStoreURL.isEmpty { count += 1 }
        if !project.pricing.isEmpty { count += 1 }
        if !project.languages.isEmpty { count += 1 }
        return count
    }

    var body: some View {
        HStack(spacing: 0) {
            // Project name
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(project.color)
                    .frame(width: 4, height: 28)
                Text(project.icon)
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Text(project.desc)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Version
            Group {
                if !project.version.isEmpty {
                    VersionBadge(version: project.version, color: project.color)
                } else {
                    Text("-")
                        .foregroundColor(.white.opacity(0.15))
                }
            }
            .frame(width: 70, alignment: .center)

            // Tasks
            Text("\(project.doneTasks)/\(project.totalTasks)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 70, alignment: .center)

            // Backlog
            Group {
                if backlogCount > 0 {
                    Text("\(backlogCount)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    Text("-")
                        .foregroundColor(.white.opacity(0.15))
                }
            }
            .frame(width: 60, alignment: .center)

            // Sprint
            Group {
                if sprintCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 8))
                        Text("\(sprintCount)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.45))
                } else {
                    Text("-")
                        .foregroundColor(.white.opacity(0.15))
                }
            }
            .frame(width: 70, alignment: .center)

            // Checklist
            HStack(spacing: 3) {
                listCheckDot(done: !project.landingURL.isEmpty)
                listCheckDot(done: !project.appStoreURL.isEmpty)
                listCheckDot(done: !project.pricing.isEmpty)
                listCheckDot(done: !project.languages.isEmpty)
                Text("\(checkCount)/4")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
            }
            .frame(width: 120, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    private func listCheckDot(done: Bool) -> some View {
        Circle()
            .fill(done ? Color(hex: "34D399") : Color.white.opacity(0.1))
            .frame(width: 6, height: 6)
    }
}

// MARK: - Project Card
struct ProjectCard: View {
    @EnvironmentObject var store: AppStore
    let project: Project
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon + Name
            HStack(spacing: 0) {
                Text(project.icon)
                    .font(.system(size: 22))
                Spacer()
                let backlogCount = store.kanbanTasks.filter { $0.projectId == project.id && $0.status == .backlog }.count
                if backlogCount > 0 {
                    Text("\(backlogCount)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.trailing, 6)
                }
                VersionBadge(version: project.version, color: project.color)
            }
            .padding(.bottom, 10)

            Text(project.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.bottom, 2)

            Text(project.desc)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.35))
                .lineLimit(1)
                .padding(.bottom, 14)

            // Stats
            HStack {
                Text("\(project.doneTasks)/\(project.totalTasks) 태스크")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
            }
            .padding(.bottom, 8)

            // Checklist badges
            HStack(spacing: 6) {
                cardCheckBadge(done: !project.landingURL.isEmpty, label: "랜딩")
                cardCheckBadge(done: !project.appStoreURL.isEmpty, label: "스토어")
                cardCheckBadge(done: !project.pricing.isEmpty, label: "가격\(project.pricing.isEmpty ? "" : "(\(project.pricing.filledCount))")")
                cardCheckBadge(done: !project.languages.isEmpty, label: "다국어\(project.languages.isEmpty ? "" : "(\(project.languages.count))")")
                Spacer()
                let sprintCount = store.sprints(for: project.id).filter { $0.isActive }.count
                HStack(spacing: 3) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 8))
                    Text(sprintCount > 0 ? "\(sprintCount)개 스프린트" : "스프린트 없음")
                }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(sprintCount > 0 ? .white.opacity(0.45) : .white.opacity(0.2))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.white.opacity(0.07) : Color.white.opacity(0.04))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(project.color)
                .frame(width: 4)
                .padding(.vertical, 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.white.opacity(0.1) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private func cardCheckBadge(done: Bool, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 9))
                .foregroundColor(done ? Color(hex: "34D399") : .white.opacity(0.2))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(done ? .white.opacity(0.5) : .white.opacity(0.2))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(done ? Color(hex: "34D399").opacity(0.1) : Color.white.opacity(0.03))
        .cornerRadius(4)
    }
}
