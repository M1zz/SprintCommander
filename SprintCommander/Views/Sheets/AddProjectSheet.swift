import SwiftUI

struct AddProjectSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var icon = "📱"
    @State private var desc = ""
    @State private var sprint = "Sprint 1"
    @State private var totalTasks = "10"
    @State private var selectedColorIndex = 0

    let emojiOptions = ["📱", "🌐", "🔧", "📊", "🎨", "🚀", "💬", "🛒", "🔒", "📦", "🎮", "📡"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("새 프로젝트 추가")
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
                    // Icon selection
                    VStack(alignment: .leading, spacing: 6) {
                        Text("아이콘")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 6), count: 6), spacing: 6) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Button {
                                    icon = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 20))
                                        .frame(width: 36, height: 36)
                                        .background(icon == emoji ? Color(hex: "4FACFE").opacity(0.3) : Color.white.opacity(0.06))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    FormField(label: "프로젝트 이름", text: $name, placeholder: "예: 모바일 앱 리뉴얼")
                    FormField(label: "설명", text: $desc, placeholder: "프로젝트에 대한 간단한 설명")
                    FormField(label: "스프린트", text: $sprint, placeholder: "Sprint 1")
                    FormField(label: "총 태스크 수", text: $totalTasks, placeholder: "10")

                    // Color selection
                    VStack(alignment: .leading, spacing: 6) {
                        Text("색상")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 6), count: 10), spacing: 6) {
                            ForEach(AppStore.palette.indices, id: \.self) { index in
                                Circle()
                                    .fill(AppStore.palette[index])
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColorIndex == index ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColorIndex = index
                                    }
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider().background(Color.white.opacity(0.06))

            // Actions
            HStack {
                Spacer()
                GhostButton(title: "취소") { dismiss() }
                PrimaryButton(title: "추가", icon: "plus") {
                    let tasks = Int(totalTasks) ?? 10
                    let project = Project(
                        name: name.isEmpty ? "새 프로젝트" : name,
                        icon: icon,
                        desc: desc,
                        progress: 0,
                        sprint: sprint,
                        totalTasks: tasks,
                        doneTasks: 0,
                        color: AppStore.palette[selectedColorIndex],
                        startWeek: store.projects.count % 10,
                        durationWeeks: 4
                    )
                    store.addProject(project)
                    store.addActivity(ActivityItem(
                        icon: "📁",
                        text: "프로젝트가 생성되었습니다",
                        highlightedText: project.name,
                        time: "방금 전"
                    ))
                    dismiss()
                }
            }
            .padding(20)
        }
        .frame(width: 420, height: 560)
        .background(Color(hex: "1A1A2E"))
    }
}
