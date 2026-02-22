import SwiftUI

struct AddTaskSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var selectedTags: Set<String> = []
    @State private var priority: TaskItem.Priority = .medium
    @State private var storyPoints = "3"
    @State private var assignee = ""
    @State private var status: TaskItem.TaskStatus = .todo

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
                        title: title.isEmpty ? "새 태스크" : title,
                        tags: Array(selectedTags),
                        priority: priority,
                        storyPoints: sp,
                        assignee: assigneeInitial,
                        assigneeColor: AppStore.palette[store.kanbanTasks.count % AppStore.palette.count],
                        status: status
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
        .frame(width: 440, height: 580)
        .background(Color(hex: "1A1A2E"))
    }
}
