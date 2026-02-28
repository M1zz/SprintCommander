import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var store: AppStore
    @State private var viewMode = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeader(
                title: "타임라인",
                subtitle: "전체 프로젝트 간트 차트 · 드래그하여 일정 조정",
                primaryAction: "+ 마일스톤",
                primaryIcon: "flag",
                secondaryAction: "🔍 필터"
            )

            SectionHeaderView(
                title: "📅 프로젝트 타임라인",
                tabs: ["월간", "분기", "연간"],
                selectedTab: $viewMode
            )

            SprintGanttView(viewMode: viewMode)
        }
    }
}

// MARK: - Month definition

struct MonthColumn: Identifiable {
    let id = UUID()
    let label: String
    let weeks: Int
    let startDate: Date
    let isCurrent: Bool
}

/// viewMode에 따라 월 컬럼 생성 (월간: 1개월 전부터, 분기/연간: 연초부터)
func monthColumns(for viewMode: Int) -> [MonthColumn] {
    let cal = Calendar.current
    let year = cal.component(.year, from: Date())
    switch viewMode {
    case 0:
        return monthColumnsFromNow(pastMonths: 1, futureMonths: 7)
    case 1:
        return quarterColumns(year: year)
    default:
        return monthColumnsForYear(year)
    }
}

/// 현재 월 기준 pastMonths개월 전 ~ futureMonths개월 후
private func monthColumnsFromNow(pastMonths: Int, futureMonths: Int) -> [MonthColumn] {
    let cal = Calendar.current
    let now = Date()
    let currentMonth = cal.component(.month, from: now)
    let currentYear = cal.component(.year, from: now)
    let labels = ["1월","2월","3월","4월","5월","6월","7월","8월","9월","10월","11월","12월"]
    let totalMonths = pastMonths + futureMonths
    return (0..<totalMonths).map { offset in
        let adjustedOffset = offset - pastMonths
        let m = ((currentMonth - 1 + adjustedOffset) % 12 + 12) % 12 + 1
        let y = currentYear + (currentMonth - 1 + adjustedOffset < 0 ? -1 : (currentMonth - 1 + adjustedOffset) / 12)
        let start = cal.date(from: DateComponents(year: y, month: m, day: 1))!
        return MonthColumn(label: labels[m - 1], weeks: weeksInMonth(year: y, month: m), startDate: start, isCurrent: m == currentMonth && y == currentYear)
    }
}

private func monthColumnsForYear(_ year: Int) -> [MonthColumn] {
    let cal = Calendar.current
    let currentMonth = cal.component(.month, from: Date())
    let currentYear = cal.component(.year, from: Date())
    let labels = ["1월","2월","3월","4월","5월","6월","7월","8월","9월","10월","11월","12월"]
    return (1...12).map { month in
        let start = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        return MonthColumn(label: labels[month - 1], weeks: weeksInMonth(year: year, month: month), startDate: start, isCurrent: month == currentMonth && year == currentYear)
    }
}

private func quarterColumns(year: Int) -> [MonthColumn] {
    let cal = Calendar.current
    let now = Date()
    let currentQ = (cal.component(.month, from: now) - 1) / 3 + 1
    let currentYear = cal.component(.year, from: now)
    return [
        MonthColumn(label: "Q1", weeks: 13, startDate: cal.date(from: DateComponents(year: year, month: 1, day: 1))!, isCurrent: currentQ == 1 && year == currentYear),
        MonthColumn(label: "Q2", weeks: 13, startDate: cal.date(from: DateComponents(year: year, month: 4, day: 1))!, isCurrent: currentQ == 2 && year == currentYear),
        MonthColumn(label: "Q3", weeks: 13, startDate: cal.date(from: DateComponents(year: year, month: 7, day: 1))!, isCurrent: currentQ == 3 && year == currentYear),
        MonthColumn(label: "Q4", weeks: 13, startDate: cal.date(from: DateComponents(year: year, month: 10, day: 1))!, isCurrent: currentQ == 4 && year == currentYear),
    ]
}

private func weeksInMonth(year: Int, month: Int) -> Int {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    guard let range = cal.range(of: .day, in: .month, for: cal.date(from: DateComponents(year: year, month: month))!) else { return 4 }
    return max(4, (range.count + 6) / 7)
}

// MARK: - Sprint Gantt View

struct SprintGanttView: View {
    @EnvironmentObject var store: AppStore
    let viewMode: Int

    private var columns: [MonthColumn] { monthColumns(for: viewMode) }
    private var totalWeeks: Int { columns.reduce(0) { $0 + $1.weeks } }

    /// 주당 픽셀 너비 (수평 스크롤용)
    private let weekPixelWidth: CGFloat = 50

    private var contentWidth: CGFloat {
        CGFloat(totalWeeks) * weekPixelWidth
    }

    private var rangeStart: Date { columns.first?.startDate ?? Date() }
    private var rangeEnd: Date {
        let cal = Calendar.current
        guard let last = columns.last else { return Date() }
        return cal.date(byAdding: .weekOfYear, value: last.weeks, to: last.startDate) ?? Date()
    }

    private var totalDays: Double {
        max(rangeEnd.timeIntervalSince(rangeStart) / 86400, 1)
    }

    /// 오늘 위치의 X 좌표 (바 영역 기준)
    private var todayX: CGFloat {
        let daysSinceStart = max(Date().timeIntervalSince(rangeStart) / 86400, 0)
        return CGFloat(daysSinceStart / totalDays) * contentWidth
    }

    private var projectRows: [(project: Project, rows: [[Sprint]])] {
        store.projects.compactMap { project in
            let projectSprints = store.sprints
                .filter { $0.projectId == project.id && !$0.isHidden }
                .sorted { $0.startDate < $1.startDate }
            guard !projectSprints.isEmpty else { return nil }
            let rows = layoutSprintRows(projectSprints)
            return (project, rows)
        }
    }

    private func layoutSprintRows(_ sprints: [Sprint]) -> [[Sprint]] {
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

    var body: some View {
        CardContainer {
            VStack(spacing: 0) {
                // Fixed project labels + scrollable gantt area
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(spacing: 0) {
                            // Header
                            HStack(spacing: 0) {
                                Text("프로젝트")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.3))
                                    .frame(width: 200, alignment: .leading)

                                TimelineHeaderBar(columns: columns, totalWeeks: totalWeeks, weekPixelWidth: weekPixelWidth)
                                    .frame(width: contentWidth)
                            }

                            Divider().background(Color.white.opacity(0.06))

                            // Project rows with today line
                            HStack(spacing: 0) {
                                // Project labels (left column)
                                VStack(spacing: 0) {
                                    ForEach(projectRows, id: \.project.id) { item in
                                        ProjectLabel(project: item.project, rowCount: item.rows.count)
                                    }
                                }
                                .frame(width: 200)

                                // Gantt bars (scrollable area)
                                ZStack(alignment: .leading) {
                                    VStack(spacing: 0) {
                                        ForEach(projectRows, id: \.project.id) { item in
                                            ProjectSprintBars(
                                                project: item.project,
                                                rows: item.rows,
                                                totalWeeks: totalWeeks,
                                                columns: columns,
                                                rangeStart: rangeStart,
                                                totalDays: totalDays,
                                                areaWidth: contentWidth
                                            )
                                        }
                                    }

                                    // Today line
                                    TodayLine(x: todayX)
                                        .allowsHitTesting(false)
                                }
                                .frame(width: contentWidth)
                            }
                        }
                        .id("ganttContent")
                    }
                    .onAppear {
                        // 오늘 위치로 스크롤 (약간 왼쪽 여유)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo("ganttContent", anchor: UnitPoint(x: max(0, todayX / (contentWidth + 200) - 0.1), y: 0))
                        }
                    }
                }

                // Legend
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "EF4444")).frame(width: 6, height: 6)
                        Text("Today")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: "EF4444"))
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - Project Label (left fixed column)

private struct ProjectLabel: View {
    let project: Project
    let rowCount: Int

    private var height: CGFloat {
        let firstRow: CGFloat = 42 // 7 padding * 2 + 28 height
        let extraRows = CGFloat(max(rowCount - 1, 0)) * 34 // 3 padding * 2 + 28 height
        return firstRow + extraRows
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(project.color)
                .frame(width: 8, height: 8)
            Text("\(project.icon) \(project.name)")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
            VersionBadge(version: project.version, color: project.color)
            Spacer()
        }
        .frame(width: 200, height: height)
        .padding(.trailing, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
        }
    }
}

// MARK: - Project Sprint Bars (right scrollable area)

private struct ProjectSprintBars: View {
    @EnvironmentObject var store: AppStore
    let project: Project
    let rows: [[Sprint]]
    let totalWeeks: Int
    let columns: [MonthColumn]
    let rangeStart: Date
    let totalDays: Double
    let areaWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, sprintsInRow in
                ZStack(alignment: .leading) {
                    if rowIdx == 0 {
                        WeekGridOverlay(totalWeeks: totalWeeks, columns: columns)
                    }

                    ForEach(sprintsInRow) { sprint in
                        SprintBar(
                            sprint: sprint,
                            project: project,
                            totalDays: totalDays,
                            rangeStart: rangeStart,
                            areaWidth: areaWidth
                        )
                    }
                }
                .frame(width: areaWidth, height: 28)
                .padding(.vertical, rowIdx == 0 ? 7 : 3)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
        }
    }
}

// MARK: - Sprint Bar (draggable)

private struct SprintBar: View {
    @EnvironmentObject var store: AppStore
    let sprint: Sprint
    let project: Project
    let totalDays: Double
    let rangeStart: Date
    let areaWidth: CGFloat

    @State private var isHovered = false
    @State private var isDragging = false
    @State private var dragOffsetX: CGFloat = 0

    private var progress: Double {
        let tasks = store.kanbanTasks.filter { $0.projectId == project.id && $0.sprint == sprint.name }
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter { $0.status == .done }.count) / Double(tasks.count)
    }

    private var taskCount: Int {
        store.kanbanTasks.filter { $0.projectId == project.id && $0.sprint == sprint.name }.count
    }

    private var barOffset: CGFloat {
        let startDays = max(sprint.startDate.timeIntervalSince(rangeStart) / 86400, 0)
        return CGFloat(startDays / totalDays) * areaWidth
    }

    private var barWidth: CGFloat {
        let startDays = max(sprint.startDate.timeIntervalSince(rangeStart) / 86400, 0)
        let endDays = min(sprint.endDate.timeIntervalSince(rangeStart) / 86400, totalDays)
        let duration = max(endDays - startDays, 1)
        return max(CGFloat(duration / totalDays) * areaWidth, 40)
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(sprint.isActive ? project.color.opacity(isDragging ? 1.0 : (isHovered ? 0.9 : 0.7)) : Color(hex: "64748B").opacity(0.5))
            .frame(width: barWidth, height: isDragging ? 28 : (isHovered ? 26 : 22))
            .overlay(alignment: .leading) {
                if progress > 0 {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: max(barWidth * progress, 6))
                }
            }
            .overlay {
                HStack(spacing: 4) {
                    Text(sprint.name)
                        .font(.system(size: 9, weight: .semibold))
                    if barWidth > 80 {
                        Text("· \(Int(progress * 100))%")
                            .font(.system(size: 9))
                            .opacity(0.7)
                    }
                    if isDragging {
                        Text(Self.dateFmt.string(from: draggedStartDate))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(3)
                    }
                }
                .foregroundColor(.white)
                .lineLimit(1)
            }
            .shadow(color: isDragging ? project.color.opacity(0.4) : .clear, radius: 8, y: 2)
            .offset(x: barOffset + dragOffsetX)
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        isDragging = true
                        let dayWidth = areaWidth / CGFloat(totalDays)
                        let daysMoved = round(value.translation.width / dayWidth)
                        dragOffsetX = daysMoved * dayWidth
                    }
                    .onEnded { value in
                        isDragging = false
                        let dayWidth = areaWidth / CGFloat(totalDays)
                        let daysMoved = Int(round(value.translation.width / dayWidth))

                        let cal = Calendar.current
                        let newStart = cal.date(byAdding: .day, value: daysMoved, to: sprint.startDate) ?? sprint.startDate
                        let newEnd = cal.date(byAdding: .day, value: daysMoved, to: sprint.endDate) ?? sprint.endDate

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffsetX = 0
                        }

                        if daysMoved != 0 {
                            store.updateSprintDates(id: sprint.id, startDate: newStart, endDate: newEnd)
                        }
                    }
            )
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .help("\(sprint.name): \(Self.dateFmt.string(from: sprint.startDate)) ~ \(Self.dateFmt.string(from: sprint.endDate)) · \(taskCount)개 태스크")
    }

    private var draggedStartDate: Date {
        let dayWidth = areaWidth / CGFloat(totalDays)
        let daysMoved = Int(round(dragOffsetX / dayWidth))
        return Calendar.current.date(byAdding: .day, value: daysMoved, to: sprint.startDate) ?? sprint.startDate
    }
}

// MARK: - Today Line

private struct TodayLine: View {
    let x: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color(hex: "EF4444").opacity(0.7))
                .frame(width: 1.5)
            Image(systemName: "diamond.fill")
                .font(.system(size: 7))
                .foregroundColor(Color(hex: "EF4444"))
                .offset(y: -4)
        }
        .frame(maxHeight: .infinity)
        .offset(x: x)
    }
}

// MARK: - Timeline Header Bar

private struct TimelineHeaderBar: View {
    let columns: [MonthColumn]
    let totalWeeks: Int
    let weekPixelWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Month labels
            HStack(spacing: 0) {
                ForEach(columns) { col in
                    Text(col.label)
                        .font(.system(size: 11, weight: col.isCurrent ? .bold : .regular))
                        .foregroundColor(col.isCurrent ? Color(hex: "4FACFE") : .white.opacity(0.3))
                        .frame(width: CGFloat(col.weeks) * weekPixelWidth, alignment: .center)
                }
            }
            .frame(height: 20)

            // Week numbers
            HStack(spacing: 0) {
                ForEach(columns) { col in
                    HStack(spacing: 0) {
                        ForEach(0..<col.weeks, id: \.self) { w in
                            Text("\(w + 1)")
                                .font(.system(size: 8, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.15))
                                .frame(width: weekPixelWidth)
                        }
                    }
                }
            }
            .frame(height: 16)
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Week gridlines overlay

private struct WeekGridOverlay: View {
    let totalWeeks: Int
    let columns: [MonthColumn]

    var body: some View {
        GeometryReader { geo in
            let weekWidth = geo.size.width / CGFloat(totalWeeks)

            var cumulativeWeeks = 0
            ForEach(Array(columns.dropLast().enumerated()), id: \.offset) { _, col in
                let _ = (cumulativeWeeks += col.weeks)
                let x = CGFloat(cumulativeWeeks) * weekWidth
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)
                    .position(x: x, y: geo.size.height / 2)
                    .frame(height: geo.size.height)
            }

            ForEach(1..<totalWeeks, id: \.self) { week in
                let x = CGFloat(week) * weekWidth
                Rectangle()
                    .fill(Color.white.opacity(0.025))
                    .frame(width: 1)
                    .position(x: x, y: geo.size.height / 2)
                    .frame(height: geo.size.height)
            }
        }
    }
}
