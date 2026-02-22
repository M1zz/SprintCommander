import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(
                title: "분석",
                subtitle: "프로젝트 성과 및 생산성 분석"
            )

            // Row 1
            HStack(spacing: 14) {
                MonthlyTasksChart()
                TimeDistributionChart()
            }

            // Row 2
            HStack(spacing: 14) {
                GoalAchievementChart()
                ProjectHealthChart()
            }
        }
    }
}

// MARK: - Monthly Tasks Chart
struct MonthlyTasksChart: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("📊 완료 태스크 현황")
                    .font(.system(size: 14, weight: .semibold))

                if store.projects.isEmpty {
                    Text("프로젝트를 추가하면 데이터가 표시됩니다")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(store.projects.prefix(6)) { project in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "A78BFA"), Color(hex: "F472B6")],
                                            startPoint: .bottom, endPoint: .top
                                        )
                                    )
                                    .frame(height: CGFloat(project.doneTasks) / CGFloat(max(project.totalTasks, 1)) * 160)
                                    .frame(maxWidth: .infinity)

                                Text(project.icon)
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.3))

                                Text("\(project.doneTasks)")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .frame(height: 200, alignment: .bottom)
                }
            }
        }
    }
}

// MARK: - Time Distribution
struct TimeDistributionChart: View {
    @EnvironmentObject var store: AppStore

    var topProjects: [(Project, Int)] {
        let totalAllTasks = store.projects.reduce(0) { $0 + $1.totalTasks }
        guard totalAllTasks > 0 else {
            return store.projects.prefix(7).map { ($0, 0) }
        }
        return store.projects.prefix(7).map { project in
            let pct = project.totalTasks * 100 / totalAllTasks
            return (project, max(pct, 1))
        }
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("⏱️ 프로젝트별 시간 분배")
                    .font(.system(size: 14, weight: .semibold))

                VStack(spacing: 12) {
                    ForEach(topProjects, id: \.0.id) { project, pct in
                        HStack(spacing: 10) {
                            Text(project.name)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 100, alignment: .trailing)
                                .lineLimit(1)

                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(project.color)
                                    .frame(width: geo.size.width * CGFloat(pct) / 100)
                            }
                            .frame(height: 16)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(4)

                            Text("\(pct)%")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))
                                .frame(width: 32)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Goal Achievement
struct GoalAchievementChart: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("🎯 스프린트 Velocity 달성률")
                    .font(.system(size: 14, weight: .semibold))

                if store.velocityData.isEmpty {
                    Text("Velocity 데이터를 추가하면 표시됩니다")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(store.velocityData) { point in
                            let pct = point.planned > 0 ? point.completed * 100 / point.planned : 0
                            VStack(spacing: 4) {
                                Text("\(pct)%")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundColor(
                                        pct >= 90 ? Color(hex: "34D399") :
                                        pct >= 70 ? Color(hex: "FB923C") :
                                        Color(hex: "EF4444")
                                    )

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        pct >= 90 ?
                                        LinearGradient(colors: [Color(hex: "34D399"), Color(hex: "6EE7B7")], startPoint: .bottom, endPoint: .top) :
                                        pct >= 70 ?
                                        LinearGradient(colors: [Color(hex: "FB923C"), Color(hex: "FBBF24")], startPoint: .bottom, endPoint: .top) :
                                        LinearGradient(colors: [Color(hex: "EF4444"), Color(hex: "FB923C")], startPoint: .bottom, endPoint: .top)
                                    )
                                    .frame(height: CGFloat(pct) / 100 * 160)
                                    .frame(maxWidth: .infinity)

                                Text(point.sprint)
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                    }
                    .frame(height: 200, alignment: .bottom)

                    HStack(spacing: 4) {
                        Rectangle().fill(Color.white.opacity(0.2)).frame(width: 20, height: 1)
                        Text("목표: 90%")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
        }
    }
}

// MARK: - Project Health
struct ProjectHealthChart: View {
    @EnvironmentObject var store: AppStore

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("📈 프로젝트 건강도")
                    .font(.system(size: 14, weight: .semibold))

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(store.projects.prefix(8)) { project in
                        VStack(spacing: 6) {
                            Text(healthEmoji(project.progress))
                                .font(.system(size: 22))

                            Text(project.name)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)

                            Text(project.progressPercent)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(project.color)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    func healthEmoji(_ progress: Double) -> String {
        if progress > 80 { return "🟢" }
        if progress > 50 { return "🟡" }
        return "🔴"
    }
}
