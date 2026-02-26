import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var store: AppStore
    @State private var sortMode = 0
    @State private var searchText = ""
    @State private var showAddProject = false
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

            // Search bar
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
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

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
        }
        .sheet(isPresented: $showAddProject) {
            AddProjectSheet()
        }
        .onAppear {
            store.refreshProjectVersions()
        }
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
