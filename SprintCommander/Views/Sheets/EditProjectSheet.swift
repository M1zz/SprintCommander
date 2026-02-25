import SwiftUI

struct EditProjectSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    let project: Project

    @State private var name: String
    @State private var icon: String
    @State private var desc: String
    @State private var sprint: String
    @State private var sourcePath: String
    @State private var selectedColorIndex: Int

    let emojiOptions = ["📱", "🌐", "🔧", "📊", "🎨", "🚀", "💬", "🛒", "🔒", "📦", "🎮", "📡"]

    init(project: Project) {
        self.project = project
        _name = State(initialValue: project.name)
        _icon = State(initialValue: project.icon)
        _desc = State(initialValue: project.desc)
        _sprint = State(initialValue: project.sprint)
        _sourcePath = State(initialValue: project.sourcePath)

        let colorIndex = AppStore.palette.firstIndex(where: {
            $0.toHex() == project.color.toHex()
        }) ?? 0
        _selectedColorIndex = State(initialValue: colorIndex)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("프로젝트 편집")
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
                    // Project path
                    VStack(alignment: .leading, spacing: 6) {
                        Text("프로젝트 경로")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))

                        HStack(spacing: 8) {
                            TextField("경로를 입력하거나 폴더를 선택하세요", text: $sourcePath)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)

                            Button {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.allowsMultipleSelection = false
                                panel.message = "프로젝트 폴더를 선택하세요"
                                if panel.runModal() == .OK, let url = panel.url {
                                    sourcePath = url.path
                                }
                            } label: {
                                Image(systemName: "folder")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }

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
                PrimaryButton(title: "저장", icon: "checkmark") {
                    var updated = project
                    updated.name = name.isEmpty ? project.name : name
                    updated.icon = icon
                    updated.desc = desc
                    updated.sprint = sprint
                    updated.sourcePath = sourcePath
                    updated.color = AppStore.palette[selectedColorIndex]
                    store.updateProject(updated)
                    if store.selectedProject?.id == project.id {
                        store.selectedProject = updated
                    }
                    store.addActivity(ActivityItem(
                        icon: "✏️",
                        text: "프로젝트가 수정되었습니다",
                        highlightedText: updated.name,
                        time: "방금 전"
                    ))
                    dismiss()
                }
            }
            .padding(20)
        }
        .frame(width: 420, height: 580)
        .background(Color(hex: "1A1A2E"))
    }
}
