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

            FullTimelineView(projects: store.projects, viewMode: viewMode) { id, newStart in
                store.updateProjectSchedule(id: id, startWeek: newStart)
            }
        }
    }
}

// MARK: - Month definition (label + weeks in that month)

struct MonthColumn: Identifiable {
    let id = UUID()
    let label: String
    let weeks: Int
}

func monthColumns(for viewMode: Int) -> [MonthColumn] {
    let year = Calendar.current.component(.year, from: Date())
    switch viewMode {
    case 0: // 월간 (6개월, 현재 월 기준)
        return monthColumnsFromNow(count: 6, year: year)
    case 1: // 분기 (4분기)
        return [
            MonthColumn(label: "Q1", weeks: 13),
            MonthColumn(label: "Q2", weeks: 13),
            MonthColumn(label: "Q3", weeks: 13),
            MonthColumn(label: "Q4", weeks: 13),
        ]
    default: // 연간 (12개월)
        return monthColumnsForYear(year)
    }
}

/// 해당 연도의 각 월 실제 주 수 계산
private func monthColumnsForYear(_ year: Int) -> [MonthColumn] {
    let labels = ["1월","2월","3월","4월","5월","6월","7월","8월","9월","10월","11월","12월"]
    return (1...12).map { month in
        MonthColumn(label: labels[month - 1], weeks: weeksInMonth(year: year, month: month))
    }
}

/// 현재 월부터 count개월
private func monthColumnsFromNow(count: Int, year: Int) -> [MonthColumn] {
    let labels = ["1월","2월","3월","4월","5월","6월","7월","8월","9월","10월","11월","12월"]
    let currentMonth = Calendar.current.component(.month, from: Date())
    return (0..<count).map { offset in
        let m = ((currentMonth - 1 + offset) % 12) + 1
        let y = year + (currentMonth - 1 + offset) / 12
        return MonthColumn(label: labels[m - 1], weeks: weeksInMonth(year: y, month: m))
    }
}

private func weeksInMonth(year: Int, month: Int) -> Int {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2 // Monday
    guard let range = cal.range(of: .day, in: .month, for: cal.date(from: DateComponents(year: year, month: month))!) else { return 4 }
    return max(4, (range.count + 6) / 7)
}

/// 올해 1월 1일부터 오늘까지의 주 오프셋 (0-based)
func todayWeekOffset(for viewMode: Int) -> CGFloat? {
    let cal = Calendar.current
    let now = Date()
    let year = cal.component(.year, from: now)

    switch viewMode {
    case 0: // 월간: 현재 월 시작부터
        let currentMonth = cal.component(.month, from: now)
        let startOfMonth = cal.date(from: DateComponents(year: year, month: currentMonth, day: 1))!
        let daysSinceMonthStart = cal.dateComponents([.day], from: startOfMonth, to: now).day ?? 0
        return CGFloat(daysSinceMonthStart) / 7.0
    case 1: // 분기: 1월 1일부터
        let jan1 = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
        let daysSinceJan1 = cal.dateComponents([.day], from: jan1, to: now).day ?? 0
        return CGFloat(daysSinceJan1) / 7.0
    default: // 연간: 1월 1일부터
        let jan1 = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
        let daysSinceJan1 = cal.dateComponents([.day], from: jan1, to: now).day ?? 0
        return CGFloat(daysSinceJan1) / 7.0
    }
}

// MARK: - FullTimelineView

struct FullTimelineView: View {
    let projects: [Project]
    let viewMode: Int
    var onMoveProject: (UUID, Int) -> Void = { _, _ in }

    private var columns: [MonthColumn] { monthColumns(for: viewMode) }
    private var totalWeeks: Int { columns.reduce(0) { $0 + $1.weeks } }

    var body: some View {
        CardContainer {
            VStack(spacing: 0) {
                // Two-row header: month labels + week ticks
                TimelineHeader(columns: columns, totalWeeks: totalWeeks)

                Divider().background(Color.white.opacity(0.06))

                // Project rows with today line overlay
                ZStack(alignment: .leading) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(projects) { project in
                                FullTimelineRow(
                                    project: project,
                                    totalWeeks: totalWeeks,
                                    columns: columns,
                                    onMove: { newStart in
                                        onMoveProject(project.id, newStart)
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 600)

                    // Today line
                    TodayLineOverlay(viewMode: viewMode, totalWeeks: totalWeeks)
                        .allowsHitTesting(false)
                }

                // Today indicator label
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

// MARK: - Today Line Overlay

private struct TodayLineOverlay: View {
    let viewMode: Int
    let totalWeeks: Int

    var body: some View {
        GeometryReader { geo in
            if let weekOffset = todayWeekOffset(for: viewMode) {
                let projectLabelWidth: CGFloat = 200
                let barAreaWidth = geo.size.width - projectLabelWidth
                let weekWidth = barAreaWidth / CGFloat(totalWeeks)
                let x = projectLabelWidth + weekOffset * weekWidth

                ZStack(alignment: .top) {
                    // Line
                    Rectangle()
                        .fill(Color(hex: "EF4444").opacity(0.7))
                        .frame(width: 1.5)

                    // Top diamond
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 7))
                        .foregroundColor(Color(hex: "EF4444"))
                        .offset(y: -4)
                }
                .frame(maxHeight: .infinity)
                .position(x: x, y: geo.size.height / 2)
            }
        }
    }
}

// MARK: - Timeline Header

private struct TimelineHeader: View {
    let columns: [MonthColumn]
    let totalWeeks: Int

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: Month labels
            HStack(spacing: 0) {
                Text("프로젝트")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 200, alignment: .leading)

                GeometryReader { geo in
                    let weekWidth = geo.size.width / CGFloat(totalWeeks)
                    HStack(spacing: 0) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { i, col in
                            Text(col.label)
                                .font(.system(size: 11, weight: i == 1 ? .semibold : .regular))
                                .foregroundColor(i == 1 ? Color(hex: "4FACFE") : .white.opacity(0.3))
                                .frame(width: weekWidth * CGFloat(col.weeks), alignment: .center)
                        }
                    }
                }
            }
            .frame(height: 20)

            // Row 2: Week tick marks
            HStack(spacing: 0) {
                Color.clear.frame(width: 200)

                GeometryReader { geo in
                    let weekWidth = geo.size.width / CGFloat(totalWeeks)
                    ZStack(alignment: .leading) {
                        // Week numbers inside each month
                        var weekOffset = 0
                        ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                            let start = weekOffset
                            let _ = (weekOffset += col.weeks)
                            ForEach(0..<col.weeks, id: \.self) { w in
                                let x = CGFloat(start + w) * weekWidth
                                Text("\(w + 1)")
                                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.15))
                                    .frame(width: weekWidth)
                                    .position(x: x + weekWidth / 2, y: 8)
                            }
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

            // Month boundary lines (stronger)
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

            // Individual week lines (subtle)
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

// MARK: - FullTimelineRow

struct FullTimelineRow: View {
    let project: Project
    let totalWeeks: Int
    let columns: [MonthColumn]
    var onMove: (Int) -> Void = { _ in }

    @State private var isHovered = false
    @State private var isDragging = false
    @State private var dragOffsetX: CGFloat = 0
    @State private var previewWeek: Int? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Project info
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(project.color)
                    .frame(width: 8, height: 8)

                Text("\(project.icon) \(project.name)")
                    .font(.system(size: 12))
                    .foregroundColor(isHovered ? .white : .white.opacity(0.6))
                    .lineLimit(1)

                VersionBadge(version: project.version, color: project.color)

                Spacer()

                Text(project.progressPercent)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(project.color)
            }
            .frame(width: 200)
            .padding(.trailing, 12)

            // Gantt bar area
            GeometryReader { geo in
                let weekWidth = geo.size.width / CGFloat(totalWeeks)
                let barStart = CGFloat(project.startWeek) * weekWidth
                let barWidth = max(CGFloat(project.durationWeeks) * weekWidth, 36)

                ZStack(alignment: .leading) {
                    // Week gridlines
                    WeekGridOverlay(totalWeeks: totalWeeks, columns: columns)

                    // Snap preview ghost (shows where bar will land)
                    if isDragging, let pw = previewWeek, pw != project.startWeek {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(project.color.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .frame(width: barWidth, height: 22)
                            .offset(x: CGFloat(pw) * weekWidth)
                    }

                    // Draggable bar
                    RoundedRectangle(cornerRadius: 6)
                        .fill(project.color.opacity(isDragging ? 1.0 : (isHovered ? 0.9 : 0.7)))
                        .frame(width: barWidth, height: isDragging ? 28 : (isHovered ? 26 : 22))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.2))
                                .frame(width: max(barWidth * project.progress / 100, 6))
                        }
                        .overlay {
                            HStack(spacing: 4) {
                                Text(project.sprint)
                                    .font(.system(size: 9, weight: .semibold))
                                if barWidth > 80 {
                                    Text("· \(project.progressPercent)")
                                        .font(.system(size: 9))
                                        .opacity(0.7)
                                }
                                if isDragging, let pw = previewWeek {
                                    Text("W\(pw + 1)")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.black.opacity(0.3))
                                        .cornerRadius(3)
                                }
                            }
                            .foregroundColor(.white)
                        }
                        .shadow(color: isDragging ? project.color.opacity(0.4) : .clear, radius: 8, y: 2)
                        .offset(x: barStart + dragOffsetX)
                        .gesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { value in
                                    isDragging = true
                                    // Snap to nearest week while dragging
                                    let weeksMoved = Int(round(value.translation.width / weekWidth))
                                    let snapped = max(0, min(project.startWeek + weeksMoved, totalWeeks - project.durationWeeks))
                                    let snappedOffset = CGFloat(snapped - project.startWeek) * weekWidth
                                    dragOffsetX = snappedOffset
                                    previewWeek = snapped
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    let newStart = previewWeek ?? project.startWeek

                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        dragOffsetX = 0
                                        previewWeek = nil
                                    }

                                    if newStart != project.startWeek {
                                        onMove(newStart)
                                    }
                                }
                        )
                        .animation(.easeOut(duration: 0.15), value: isHovered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 28)
        }
        .padding(.vertical, 7)
        .background(isHovered ? Color.white.opacity(0.02) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.02)).frame(height: 1)
        }
        .onHover { isHovered = $0 }
    }
}
