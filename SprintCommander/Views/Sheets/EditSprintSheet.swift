import SwiftUI

struct EditSprintSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    let sprint: Sprint
    let project: Project

    @State private var name: String
    @State private var goal: String
    @State private var targetVersion: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var duration: Int

    init(sprint: Sprint, project: Project) {
        self.sprint = sprint
        self.project = project
        _name = State(initialValue: sprint.name)
        _goal = State(initialValue: sprint.goal)
        _targetVersion = State(initialValue: sprint.targetVersion)
        _startDate = State(initialValue: sprint.startDate)
        _endDate = State(initialValue: sprint.endDate)

        let weeks = max(1, Calendar.current.dateComponents([.weekOfYear], from: sprint.startDate, to: sprint.endDate).weekOfYear ?? 2)
        _duration = State(initialValue: min(weeks, 4))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("스프린트 편집")
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
                    // Project info
                    HStack(spacing: 10) {
                        Text(project.icon)
                            .font(.system(size: 20))
                            .frame(width: 36, height: 36)
                            .background(project.color.opacity(0.15))
                            .cornerRadius(8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            Text("스프린트를 편집합니다")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)

                    // Sprint name
                    FormField(label: "스프린트 이름", text: $name, placeholder: sprint.name)

                    // Goal
                    VStack(alignment: .leading, spacing: 6) {
                        Text("스프린트 목표")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        TextField("이번 스프린트에서 달성할 목표", text: $goal)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }

                    // Target version
                    FormField(label: "목표 버전", text: $targetVersion, placeholder: project.version)

                    // Duration picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("스프린트 기간")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))

                        HStack(spacing: 4) {
                            ForEach([1, 2, 3, 4], id: \.self) { weeks in
                                Button {
                                    duration = weeks
                                    endDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: startDate) ?? startDate
                                } label: {
                                    Text("\(weeks)주")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(duration == weeks ? .white : .white.opacity(0.4))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(duration == weeks ? project.color.opacity(0.4) : Color.white.opacity(0.06))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Dates
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("시작일")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .datePickerStyle(.field)
                                .labelsHidden()
                                .onChange(of: startDate) { _, newValue in
                                    endDate = Calendar.current.date(byAdding: .weekOfYear, value: duration, to: newValue) ?? newValue
                                }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("종료일")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .datePickerStyle(.field)
                                .labelsHidden()
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
                    var updated = sprint
                    updated.name = name.isEmpty ? sprint.name : name
                    updated.goal = goal
                    updated.targetVersion = targetVersion
                    updated.startDate = startDate
                    updated.endDate = endDate
                    store.updateSprint(updated)
                    store.addActivity(ActivityItem(
                        icon: "✏️",
                        text: "스프린트가 수정되었습니다",
                        highlightedText: updated.name,
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
