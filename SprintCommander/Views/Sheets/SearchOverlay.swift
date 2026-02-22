import SwiftUI

struct SearchOverlay: View {
    @EnvironmentObject var store: AppStore
    @State private var query = ""
    @FocusState private var isFocused: Bool

    var matchedProjects: [Project] {
        guard !query.isEmpty else { return [] }
        return store.projects.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.desc.localizedCaseInsensitiveContains(query)
        }
    }

    var matchedTasks: [TaskItem] {
        guard !query.isEmpty else { return [] }
        return store.kanbanTasks.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: "4FACFE"))
                    .font(.system(size: 16))
                TextField("프로젝트, 태스크 검색...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .focused($isFocused)

                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    store.showSearchOverlay = false
                } label: {
                    Text("ESC")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.white.opacity(0.06))

            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if query.isEmpty {
                        Text("검색어를 입력하세요")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        // Projects
                        if !matchedProjects.isEmpty {
                            Text("프로젝트")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.horizontal, 16)
                                .padding(.top, 12)

                            ForEach(matchedProjects) { project in
                                Button {
                                    store.selectedTab = .projects
                                    store.showSearchOverlay = false
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(project.icon)
                                            .font(.system(size: 16))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(project.name)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.white)
                                            Text(project.desc)
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.3))
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text(project.progressPercent)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(project.color)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.02))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 8)
                            }
                        }

                        // Tasks
                        if !matchedTasks.isEmpty {
                            Text("태스크")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.horizontal, 16)
                                .padding(.top, 12)

                            ForEach(matchedTasks) { task in
                                Button {
                                    store.selectedTab = .board
                                    store.showSearchOverlay = false
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(task.priority.icon)
                                            .font(.system(size: 12))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(task.title)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.white)
                                            HStack(spacing: 4) {
                                                ForEach(task.tags, id: \.self) { tag in
                                                    Text(tag)
                                                        .font(.system(size: 9))
                                                        .foregroundColor(TagStyle.color(for: tag))
                                                }
                                            }
                                        }
                                        Spacer()
                                        Text(task.status.rawValue)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(task.status.color)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(task.status.color.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.02))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 8)
                            }
                        }

                        if matchedProjects.isEmpty && matchedTasks.isEmpty {
                            Text("검색 결과가 없습니다")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(width: 520, height: 400)
        .background(Color(hex: "1E1E3C").opacity(0.98))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
        .onAppear { isFocused = true }
        .onExitCommand { store.showSearchOverlay = false }
    }
}
