import SwiftUI

struct TaskDetailSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let task: TaskItem

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("태스크 상세")
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
                    // Title
                    Text(task.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    // Tags
                    HStack(spacing: 6) {
                        ForEach(task.tags, id: \.self) { tag in
                            TagBadge(text: tag)
                        }
                    }

                    // Info grid
                    VStack(spacing: 12) {
                        DetailRow(label: "상태", value: task.status.rawValue, color: task.status.color)
                        DetailRow(label: "우선순위", value: "\(task.priority.icon) \(task.priority.label)", color: task.priority.color)
                        DetailRow(label: "스토리 포인트", value: "\(task.storyPoints) SP", color: .white)
                        DetailRow(label: "담당자", value: task.assignee, color: task.assigneeColor)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)

                    // Status change buttons
                    VStack(alignment: .leading, spacing: 8) {
                        Text("상태 변경")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        HStack(spacing: 6) {
                            ForEach(TaskItem.TaskStatus.allCases, id: \.self) { status in
                                Button {
                                    store.updateTaskStatus(id: task.id, newStatus: status)
                                    store.addActivity(ActivityItem(
                                        icon: "🔄",
                                        text: "상태가 \(status.rawValue)(으)로 변경되었습니다",
                                        highlightedText: task.title,
                                        time: "방금 전"
                                    ))
                                    dismiss()
                                } label: {
                                    Text(status.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(task.status == status ? .white : status.color)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(task.status == status ? status.color.opacity(0.5) : status.color.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Priority change
                    VStack(alignment: .leading, spacing: 8) {
                        Text("우선순위 변경")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        HStack(spacing: 6) {
                            ForEach(TaskItem.Priority.allCases, id: \.self) { p in
                                Button {
                                    store.updateTaskPriority(id: task.id, newPriority: p)
                                    dismiss()
                                } label: {
                                    Text("\(p.icon) \(p.label)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(task.priority == p ? .white : p.color)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(task.priority == p ? p.color.opacity(0.5) : p.color.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer()

                    // Delete button
                    Button {
                        store.deleteTask(id: task.id)
                        store.addActivity(ActivityItem(
                            icon: "🗑️",
                            text: "태스크가 삭제되었습니다",
                            highlightedText: task.title,
                            time: "방금 전"
                        ))
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("태스크 삭제")
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
        .frame(width: 400, height: 520)
        .background(Color(hex: "1A1A2E"))
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(color)
        }
    }
}
