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

            FullTimelineView(projects: store.projects, viewMode: viewMode)
        }
    }
}

struct FullTimelineView: View {
    let projects: [Project]
    let viewMode: Int

    var months: [String] {
        switch viewMode {
        case 0: return ["1월", "2월", "3월", "4월", "5월", "6월"]
        case 1: return ["Q1", "Q2", "Q3", "Q4"]
        default: return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        }
    }

    var totalWeeks: Int {
        switch viewMode {
        case 0: return 26
        case 1: return 52
        default: return 52
        }
    }

    var body: some View {
        CardContainer {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    Text("프로젝트")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 200, alignment: .leading)

                    HStack(spacing: 0) {
                        ForEach(months.indices, id: \.self) { i in
                            Text(months[i])
                                .font(.system(size: 11, weight: i == 1 ? .semibold : .regular))
                                .foregroundColor(i == 1 ? Color(hex: "4FACFE") : .white.opacity(0.3))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.06))

                // All project rows
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(projects) { project in
                            FullTimelineRow(project: project, totalWeeks: totalWeeks)
                        }
                    }
                }
                .frame(maxHeight: 600)

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

struct FullTimelineRow: View {
    let project: Project
    let totalWeeks: Int
    @State private var isHovered = false

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

                Spacer()

                Text(project.progressPercent)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(project.color)
            }
            .frame(width: 200)
            .padding(.trailing, 12)

            // Gantt bar
            GeometryReader { geo in
                let barStart = CGFloat(project.startWeek) / CGFloat(totalWeeks) * geo.size.width
                let barWidth = max(CGFloat(project.durationWeeks) / CGFloat(totalWeeks) * geo.size.width, 36)

                ZStack(alignment: .leading) {
                    // Bar
                    RoundedRectangle(cornerRadius: 6)
                        .fill(project.color.opacity(isHovered ? 0.9 : 0.7))
                        .frame(width: barWidth, height: isHovered ? 26 : 22)
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
                            }
                            .foregroundColor(.white)
                        }
                        .offset(x: barStart)
                        .animation(.easeOut(duration: 0.15), value: isHovered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 26)
        }
        .padding(.vertical, 7)
        .background(isHovered ? Color.white.opacity(0.02) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.02)).frame(height: 1)
        }
        .onHover { isHovered = $0 }
    }
}
