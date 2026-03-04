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

    // Scan-related state
    @State private var sourcePath = ""
    @State private var isScanning = false
    @State private var scanResult: ProjectScanner.ScanResult?

    private let scanner = ProjectScanner()

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
                    // MARK: - Project Path + Scan
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
                                chooseFolder()
                            } label: {
                                Image(systemName: "folder")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Button {
                                performScan()
                            } label: {
                                if isScanning {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(width: 50, height: 32)
                                } else {
                                    Text("스캔")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 32)
                                }
                            }
                            .background(Color(hex: "4FACFE").opacity(sourcePath.isEmpty ? 0.3 : 1))
                            .cornerRadius(8)
                            .buttonStyle(.plain)
                            .disabled(sourcePath.isEmpty || isScanning)
                        }
                    }

                    // MARK: - Scan Result Summary
                    if let result = scanResult {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 12))
                                Text("스캔 완료")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.green)
                            }

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                            ], spacing: 6) {
                                scanInfoBadge(label: "타입", value: result.projectType)
                                scanInfoBadge(label: "언어", value: result.language)
                                scanInfoBadge(label: "프레임워크", value: result.framework)
                                scanInfoBadge(label: "파일", value: "\(result.totalFiles)개")
                                scanInfoBadge(label: "코드 라인", value: formatNumber(result.totalLines))
                                if !result.version.isEmpty {
                                    scanInfoBadge(label: "버전", value: "v\(result.version)")
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(10)
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
                        durationWeeks: 4,
                        sourcePath: sourcePath,
                        version: scanResult?.version ?? ""
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
        .frame(width: 420, height: 620)
        .background(Color(hex: "1A1A2E"))
    }

    // MARK: - Scan Actions

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "프로젝트 폴더를 선택하세요"

        if panel.runModal() == .OK, let url = panel.url {
            sourcePath = url.path
            performScan()
        }
    }

    private func performScan() {
        guard !sourcePath.isEmpty else { return }
        isScanning = true
        scanResult = nil

        Task {
            let result = await scanner.scan(path: (sourcePath as NSString).expandingTildeInPath)
            await MainActor.run {
                isScanning = false
                scanResult = result
                if let result {
                    name = result.projectName
                    icon = result.icon
                    desc = result.desc
                }
            }
        }
    }

    // MARK: - Helpers

    private func scanInfoBadge(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000.0)
        }
        return "\(n)"
    }
}
