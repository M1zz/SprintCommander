import SwiftUI

struct AddTaskSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    var projectId: UUID? = nil
    var sprintName: String = ""

    @State private var title = ""
    @State private var selectedTags: Set<String> = []
    @State private var priority: TaskItem.Priority = .medium
    @State private var storyPoints = "3"
    @State private var assignee = ""
    @State private var sprint = ""
    @State private var status: TaskItem.TaskStatus = .backlog

    let availableTags = ["Feature", "UI", "Backend", "Bug", "Core", "Integration", "Performance", "Refactor", "i18n", "UX", "Design", "iOS"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("새 태스크 추가")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider().background(Color.white.opacity(0.06))

            ScrollView {
                VStack(spacing: 16) {
                    FormField(label: "태스크 제목", text: $title, placeholder: "예: 로그인 UI 리뉴얼")

                    // Tags
                    VStack(alignment: .leading, spacing: 6) {
                        Text("태그")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                            ForEach(availableTags, id: \.self) { tag in
                                let isSelected = selectedTags.contains(tag)
                                Button {
                                    if isSelected { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                                } label: {
                                    Text(tag)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(isSelected ? .white : TagStyle.color(for: tag))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .frame(maxWidth: .infinity)
                                        .background(isSelected ? TagStyle.color(for: tag).opacity(0.4) : TagStyle.color(for: tag).opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Priority
                    FormPicker(
                        label: "우선순위",
                        options: TaskItem.Priority.allCases,
                        selection: $priority,
                        titleForOption: { "\($0.icon) \($0.label)" }
                    )

                    FormField(label: "스토리 포인트", text: $storyPoints, placeholder: "3")
                    FormField(label: "담당자", text: $assignee, placeholder: "이름 이니셜 (예: JK)")

                    // Sprint
                    sprintPicker

                    // Status
                    FormPicker(
                        label: "상태",
                        options: TaskItem.TaskStatus.allCases,
                        selection: $status,
                        titleForOption: { $0.rawValue }
                    )
                }
                .padding(20)
            }

            Divider().background(Color.white.opacity(0.06))

            // Actions
            HStack {
                Spacer()
                GhostButton(title: "취소") { dismiss() }
                PrimaryButton(title: "추가", icon: "plus") {
                    let sp = Int(storyPoints) ?? 3
                    let assigneeInitial = assignee.isEmpty ? "?" : String(assignee.prefix(2))
                    let task = TaskItem(
                        projectId: projectId,
                        title: title.isEmpty ? "새 태스크" : title,
                        tags: Array(selectedTags),
                        priority: priority,
                        storyPoints: sp,
                        assignee: assigneeInitial,
                        assigneeColor: AppStore.palette[store.kanbanTasks.count % AppStore.palette.count],
                        status: status,
                        sprint: sprint
                    )
                    store.addTask(task)
                    store.addActivity(ActivityItem(
                        icon: "📋",
                        text: "태스크가 추가되었습니다",
                        highlightedText: task.title,
                        time: "방금 전"
                    ))
                    dismiss()
                }
            }
            .padding(20)
        }
        .frame(width: 440, height: 620)
        .background(Color(hex: "1A1A2E"))
    }

    // MARK: - Sprint Picker

    private var sprintOptions: [String] {
        if let pid = projectId {
            return store.sprints(for: pid).map { $0.name }
        }
        return store.sprints.map { $0.name }
    }

    private var sprintPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("스프린트")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 6) {
                // Quick select buttons from existing sprints
                if !sprintOptions.isEmpty {
                    ForEach(sprintOptions, id: \.self) { name in
                        Button {
                            sprint = sprint == name ? "" : name
                        } label: {
                            Text(name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(sprint == name ? .white : .white.opacity(0.5))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(sprint == name ? Color(hex: "4FACFE").opacity(0.3) : Color.white.opacity(0.06))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Manual input
                TextField("스프린트 이름", text: $sprint)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
            }

            if sprint.isEmpty {
                Text("미배정 (백로그)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.25))
            }
        }
        .onAppear {
            if !sprintName.isEmpty {
                sprint = sprintName
            }
        }
    }
}
