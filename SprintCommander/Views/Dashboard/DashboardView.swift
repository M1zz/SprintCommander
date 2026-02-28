import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @State private var timelineTab = 0
    @State private var showAddProject = false
    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            PageHeader(
                title: "Sprint Commander",
                subtitle: "\(store.projects.count)개 프로젝트 · \(store.activeSprintNames.count)개 활성 스프린트",
                primaryAction: "새 프로젝트",
                primaryIcon: "plus",
                onPrimary: { showAddProject = true },
                secondaryAction: "⚙️ 설정"
            )

            // Empty state
            if store.projects.isEmpty && store.kanbanTasks.isEmpty {
                VStack(spacing: 16) {
                    Text("🚀")
                        .font(.system(size: 48))
                    Text("시작하기")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("프로젝트와 태스크를 추가하거나\n샘플 데이터로 시작해보세요")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        PrimaryButton(title: "샘플 데이터 로드", icon: "square.and.arrow.down") {
                            SampleDataProvider.loadSampleData(into: store)
                        }
                        GhostButton(title: "새 프로젝트") {
                            showAddProject = true
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }

            // Stats Grid
            HStack {
                Spacer()
                Button {
                    isRefreshing = true
                    store.reloadAllTaskFiles()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isRefreshing = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 0.5) : .default, value: isRefreshing)
                        Text("새로고침")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 14) {
                StatCard(
                    label: "총 프로젝트", value: "\(store.projects.count)",
                    color: Color(hex: "4FACFE"), change: "\(store.activeSprintNames.count)개 활성 스프린트",
                    accentGradient: [Color(hex: "4FACFE"), Color(hex: "22D3EE")]
                )
                StatCard(
                    label: "완료된 태스크", value: "\(store.totalDoneTasks)",
                    color: Color(hex: "34D399"), change: "전체 \(store.totalTasks)개 중",
                    accentGradient: [Color(hex: "34D399"), Color(hex: "6EE7B7")]
                )
                StatCard(
                    label: "진행 중", value: "\(store.inProgressCount)",
                    color: Color(hex: "FB923C"), change: "전체 \(store.kanbanTasks.count)개 태스크",
                    accentGradient: [Color(hex: "FB923C"), Color(hex: "FBBF24")]
                )
                StatCard(
                    label: "평균 Velocity", value: "\(store.averageVelocity)",
                    color: Color(hex: "A78BFA"), change: "\(store.velocityData.count)개 스프린트 기준",
                    accentGradient: [Color(hex: "A78BFA"), Color(hex: "F472B6")]
                )
                StatCard(
                    label: "지연 태스크", value: "\(store.overdueCount)",
                    color: Color(hex: "EF4444"), change: store.overdueCount > 0 ? "확인 필요" : "",
                    accentGradient: [Color(hex: "EF4444"), Color(hex: "FB923C")]
                )
            }

            // Timeline Section
            SectionHeaderView(
                title: "📅 스프린트 타임라인",
                tabs: ["이번 달", "분기", "전체"],
                selectedTab: $timelineTab
            )
            SprintTimelineView()

            // Charts Row
            HStack(spacing: 14) {
                VelocityChartView()
                BurndownChartView()
            }

            // Bottom Row
            HStack(alignment: .top, spacing: 14) {
                ActivityFeedView()
                    .frame(maxWidth: .infinity)
                WorkloadView()
                    .frame(width: 300)
            }
        }
        .sheet(isPresented: $showAddProject) {
            AddProjectSheet()
        }
    }
}

// MARK: - Sprint Timeline

struct SprintTimelineView: View {
    @EnvironmentObject var store: AppStore

    private var timelineRange: (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let startOfMonth = cal.date(from: comps) ?? now
        let start = cal.date(byAdding: .month, value: -1, to: startOfMonth)!
        let end = cal.date(byAdding: .month, value: 5, to: startOfMonth)!
        return (start, end)
    }

    private var monthLabels: [(String, Bool)] {
        let cal = Calendar.current
        let now = Date()
        let currentMonth = cal.component(.month, from: now)
        let comps = cal.dateComponents([.year, .month], from: now)
        let startOfMonth = cal.date(from: comps) ?? now
        let rangeStart = cal.date(byAdding: .month, value: -1, to: startOfMonth)!
        var result: [(String, Bool)] = []
        for i in 0..<6 {
            let date = cal.date(byAdding: .month, value: i, to: rangeStart)!
            let month = cal.component(.month, from: date)
            result.append(("\(month)월", month == currentMonth))
        }
        return result
    }

    /// 겹치지 않는 스프린트는 같은 줄에 배치
    private func layoutRows(_ sprints: [Sprint]) -> [[Sprint]] {
        var rows: [[Sprint]] = []
        for sprint in sprints {
            var placed = false
            for i in rows.indices {
                let lastEnd = rows[i].last?.endDate ?? .distantPast
                if sprint.startDate >= lastEnd {
                    rows[i].append(sprint)
                    placed = true
                    break
                }
            }
            if !placed {
                rows.append([sprint])
            }
        }
        return rows
    }

    private var projectData: [(project: Project, rows: [[Sprint]])] {
        store.projects.compactMap { project in
            let projectSprints = store.sprints
                .filter { $0.projectId == project.id && !$0.isHidden }
                .sorted { $0.startDate < $1.startDate }
            guard !projectSprints.isEmpty else { return nil }
            return (project, layoutRows(projectSprints))
        }
    }

    private var totalDays: Double {
        max(timelineRange.end.timeIntervalSince(timelineRange.start) / 86400, 1)
    }

    var body: some View {
        CardContainer {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    Text("프로젝트")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 160, alignment: .leading)

                    HStack(spacing: 0) {
                        ForEach(Array(monthLabels.enumerated()), id: \.offset) { _, item in
                            Text(item.0)
                                .font(.system(size: 11, weight: item.1 ? .semibold : .regular))
                                .foregroundColor(item.1 ? Color(hex: "4FACFE") : .white.opacity(0.3))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.06))

                if projectData.isEmpty {
                    Text("스프린트가 없습니다")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.25))
                        .padding(.vertical, 20)
                } else {
                    ForEach(projectData, id: \.project.id) { item in
                        DashboardProjectRow(
                            project: item.project,
                            rows: item.rows,
                            rangeStart: timelineRange.start,
                            totalDays: totalDays
                        )
                    }
                }
            }
        }
    }
}

private struct DashboardProjectRow: View {
    @EnvironmentObject var store: AppStore
    let project: Project
    let rows: [[Sprint]]
    let rangeStart: Date
    let totalDays: Double

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, sprintsInRow in
                HStack(spacing: 0) {
                    // Project label only on first row
                    if rowIdx == 0 {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(project.color)
                                .frame(width: 5, height: 5)
                            Text("\(project.icon) \(project.name)")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        .frame(width: 160, alignment: .leading)
                    } else {
                        Color.clear.frame(width: 160)
                    }

                    // Sprint bars on this row
                    GeometryReader { geo in
                        let w = geo.size.width
                        ZStack(alignment: .leading) {
                            ForEach(sprintsInRow) { sprint in
                                DashboardSprintBar(
                                    sprint: sprint,
                                    project: project,
                                    totalDays: totalDays,
                                    rangeStart: rangeStart,
                                    areaWidth: w
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }
                    .frame(height: 18)
                }
                .padding(.vertical, rowIdx == 0 ? 8 : 3)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
        }
    }
}

private struct DashboardSprintBar: View {
    @EnvironmentObject var store: AppStore
    let sprint: Sprint
    let project: Project
    let totalDays: Double
    let rangeStart: Date
    let areaWidth: CGFloat

    private var progress: Double {
        let tasks = store.kanbanTasks.filter { $0.projectId == project.id && $0.sprint == sprint.name }
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter { $0.status == .done }.count) / Double(tasks.count)
    }

    private var barOffset: CGFloat {
        let startDays = max(sprint.startDate.timeIntervalSince(rangeStart) / 86400, 0)
        return CGFloat(startDays / totalDays) * areaWidth
    }

    private var barWidth: CGFloat {
        let startDays = max(sprint.startDate.timeIntervalSince(rangeStart) / 86400, 0)
        let endDays = min(sprint.endDate.timeIntervalSince(rangeStart) / 86400, totalDays)
        let duration = max(endDays - startDays, 1)
        return max(CGFloat(duration / totalDays) * areaWidth, 36)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(sprint.isActive ? project.color.opacity(0.7) : Color(hex: "64748B").opacity(0.4))
            .frame(width: barWidth, height: 18)
            .overlay(alignment: .leading) {
                if progress > 0 {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: max(barWidth * progress, 4))
                }
            }
            .overlay {
                Text(sprint.name)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .offset(x: barOffset)
    }
}

// MARK: - Velocity Chart
struct VelocityChartView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("🚀 스프린트 Velocity")
                    .font(.system(size: 14, weight: .semibold))

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(store.velocityData) { point in
                        VStack(spacing: 4) {
                            HStack(alignment: .bottom, spacing: 3) {
                                // Planned bar
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: "4FACFE").opacity(0.25))
                                    .frame(height: CGFloat(point.planned) / 50 * 160)
                                // Completed bar
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "4FACFE"), Color(hex: "667EEA")],
                                            startPoint: .bottom, endPoint: .top
                                        )
                                    )
                                    .frame(height: CGFloat(point.completed) / 50 * 160)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 160, alignment: .bottom)

                            Text(point.sprint)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                }

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "4FACFE").opacity(0.25))
                            .frame(width: 12, height: 8)
                        Text("계획").font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "4FACFE"))
                            .frame(width: 12, height: 8)
                        Text("완료").font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
                    }
                }
            }
        }
    }
}

// MARK: - Burndown Chart
struct BurndownChartView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("🔥 번다운 차트 (현재 스프린트)")
                    .font(.system(size: 14, weight: .semibold))

                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let maxY: Double = 50
                    let days = max(store.burndownIdeal.count, 2)

                    let toX = { (i: Int) -> CGFloat in
                        CGFloat(i) / CGFloat(days - 1) * w
                    }
                    let toY = { (v: Double) -> CGFloat in
                        (1 - v / maxY) * h
                    }

                    Canvas { ctx, size in
                        // Grid lines
                        for i in 0...4 {
                            let y = toY(Double(i * 12))
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: w, y: y))
                            ctx.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 1)
                        }

                        // Ideal line (dashed)
                        var idealPath = Path()
                        for (i, v) in store.burndownIdeal.enumerated() {
                            let pt = CGPoint(x: toX(i), y: toY(v))
                            if i == 0 { idealPath.move(to: pt) } else { idealPath.addLine(to: pt) }
                        }
                        ctx.stroke(idealPath, with: .color(.white.opacity(0.15)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                        // Actual area fill
                        var areaPath = Path()
                        for (i, v) in store.burndownActual.enumerated() {
                            let pt = CGPoint(x: toX(i), y: toY(v))
                            if i == 0 { areaPath.move(to: pt) } else { areaPath.addLine(to: pt) }
                        }
                        areaPath.addLine(to: CGPoint(x: toX(days - 1), y: h))
                        areaPath.addLine(to: CGPoint(x: 0, y: h))
                        areaPath.closeSubpath()
                        ctx.fill(areaPath, with: .color(Color(hex: "4FACFE").opacity(0.08)))

                        // Actual line
                        var actualPath = Path()
                        for (i, v) in store.burndownActual.enumerated() {
                            let pt = CGPoint(x: toX(i), y: toY(v))
                            if i == 0 { actualPath.move(to: pt) } else { actualPath.addLine(to: pt) }
                        }
                        ctx.stroke(actualPath, with: .color(Color(hex: "4FACFE")), lineWidth: 2)

                        // Dots
                        for (i, v) in store.burndownActual.enumerated() {
                            let pt = CGPoint(x: toX(i), y: toY(v))
                            let circle = Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6))
                            ctx.fill(circle, with: .color(Color(hex: "4FACFE")))
                            let ring = Path(ellipseIn: CGRect(x: pt.x - 4.5, y: pt.y - 4.5, width: 9, height: 9))
                            ctx.stroke(ring, with: .color(Color(hex: "1A1A2E")), lineWidth: 1.5)
                        }
                    }

                    // Day labels
                    HStack(spacing: 0) {
                        ForEach(0..<days, id: \.self) { i in
                            Text("D\(i + 1)")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.2))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .offset(y: h + 4)
                }
                .frame(height: 180)

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 16, height: 1.5)
                        Text("이상").font(.system(size: 10)).foregroundColor(.white.opacity(0.3))
                    }
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color(hex: "4FACFE"))
                            .frame(width: 16, height: 2)
                        Text("실제").font(.system(size: 10)).foregroundColor(Color(hex: "4FACFE"))
                    }
                }
            }
        }
    }
}

// MARK: - Activity Feed
struct ActivityFeedView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("📢 최근 활동")
                    .font(.system(size: 14, weight: .semibold))

                ForEach(store.activities) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Text(item.icon)
                            .font(.system(size: 16))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(14)

                        VStack(alignment: .leading, spacing: 2) {
                            (Text(item.highlightedText).fontWeight(.medium).foregroundColor(.white) +
                             Text(" \(item.text)").foregroundColor(.white.opacity(0.5)))
                                .font(.system(size: 12))
                                .lineLimit(2)

                            Text(item.time)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.25))
                        }
                    }
                    .padding(.vertical, 6)

                    if item.id != store.activities.last?.id {
                        Divider().background(Color.white.opacity(0.03))
                    }
                }
            }
        }
    }
}

// MARK: - Workload
struct WorkloadView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Text("👥 팀 워크로드")
                    .font(.system(size: 14, weight: .semibold))

                ForEach(store.teamMembers) { member in
                    HStack(spacing: 10) {
                        Text(String(member.name.prefix(1)))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(member.color)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))

                            ProgressBarView(
                                progress: member.workload,
                                color: workloadColor(member.workload),
                                height: 6
                            )
                        }

                        Text("\(Int(member.workload))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(workloadColor(member.workload))
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
    }

    func workloadColor(_ load: Double) -> Color {
        if load > 80 { return Color(hex: "EF4444") }
        if load > 60 { return Color(hex: "FB923C") }
        return Color(hex: "34D399")
    }
}
