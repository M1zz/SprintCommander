import SwiftUI

struct ProjectDetailSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let project: Project

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("프로젝트 상세")
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
                VStack(alignment: .leading, spacing: 20) {
                    // Icon + Name
                    HStack(spacing: 14) {
                        Text(project.icon)
                            .font(.system(size: 36))
                            .frame(width: 56, height: 56)
                            .background(project.color.opacity(0.15))
                            .cornerRadius(12)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text(project.sprint)
                                .font(.system(size: 13))
                                .foregroundColor(project.color)
                        }
                    }

                    // Description
                    if !project.desc.isEmpty {
                        Text(project.desc)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(3)
                    }

                    // Progress
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("진행률")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text(project.progressPercent)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(project.color)
                        }
                        ProgressBarView(progress: project.progress, color: project.color, height: 8)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)

                    // Task stats
                    VStack(spacing: 12) {
                        DetailRow(label: "총 태스크", value: "\(project.totalTasks)", color: .white)
                        DetailRow(label: "완료 태스크", value: "\(project.doneTasks)", color: Color(hex: "34D399"))
                        DetailRow(label: "남은 태스크", value: "\(project.totalTasks - project.doneTasks)", color: Color(hex: "FB923C"))
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)

                    Spacer()

                    // Delete
                    Button {
                        store.deleteProject(id: project.id)
                        store.addActivity(ActivityItem(
                            icon: "🗑️",
                            text: "프로젝트가 삭제되었습니다",
                            highlightedText: project.name,
                            time: "방금 전"
                        ))
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("프로젝트 삭제")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "EF4444"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "EF4444").opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 480)
        .background(Color(hex: "1A1A2E"))
    }
}
