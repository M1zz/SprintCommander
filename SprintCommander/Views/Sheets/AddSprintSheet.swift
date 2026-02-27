import SwiftUI

struct AddSprintSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    let project: Project

    @State private var name = ""
    @State private var goal = ""
    @State private var targetVersion = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date()) ?? Date()
    @State private var duration = 2 // weeks

    private var suggestedName: String {
        let existing = store.sprints(for: project.id)
        let number = existing.count + 1
        return "Sprint \(number)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("새 스프린트")
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
                            Text("새 스프린트를 추가합니다")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)

                    // Sprint name
                    FormField(label: "스프린트 이름", text: $name, placeholder: suggestedName)

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

                    // Info
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "4FACFE").opacity(0.6))
                        Text("스프린트를 만든 후 태스크를 배정할 수 있습니다")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "4FACFE").opacity(0.06))
                    .cornerRadius(8)
                }
                .padding(20)
            }

            Divider().background(Color.white.opacity(0.06))

            // Actions
            HStack {
                Spacer()
                GhostButton(title: "취소") { dismiss() }
                PrimaryButton(title: "생성", icon: "flag.fill") {
                    let sprintName = name.isEmpty ? suggestedName : name
                    let sprint = Sprint(
                        projectId: project.id,
                        name: sprintName,
                        goal: goal,
                        startDate: startDate,
                        endDate: endDate,
                        isActive: true,
                        targetVersion: targetVersion
                    )
                    store.addSprint(sprint)
                    store.addActivity(ActivityItem(
                        icon: "🏁",
                        text: "스프린트가 생성되었습니다",
                        highlightedText: sprintName,
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
