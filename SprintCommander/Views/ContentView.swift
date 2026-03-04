import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // macOS Title Bar
                TitleBarView()

                // Main Layout
                HStack(spacing: 0) {
                    SidebarView()
                    MainContentView()
                }
            }

            // Search Overlay
            if store.showSearchOverlay {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { store.showSearchOverlay = false }

                SearchOverlay()
                    .transition(.opacity)
            }
        }
        .background(Color(hex: "1A1A2E"))
        .preferredColorScheme(.dark)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) && event.keyCode == 40 { // k
                    withAnimation(.easeOut(duration: 0.2)) {
                        store.showSearchOverlay.toggle()
                    }
                    return nil
                }
                if event.keyCode == 53 && store.showSearchOverlay { // ESC
                    withAnimation(.easeOut(duration: 0.2)) {
                        store.showSearchOverlay = false
                    }
                    return nil
                }
                return event
            }
        }
    }
}

// MARK: - Title Bar
struct TitleBarView: View {
    @EnvironmentObject var store: AppStore
    @State private var isSearching = false

    var body: some View {
        HStack(spacing: 0) {
            // Space for native traffic light buttons
            Spacer()
                .frame(width: 80)

            Spacer()

            Text("Sprint Commander")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            // Search
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    store.showSearchOverlay.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                    Text("검색")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                    Text("⌘K")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.25))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
        }
        .frame(height: 52)
        .background(
            LinearGradient(
                colors: [Color(hex: "1E1E3C").opacity(0.98), Color(hex: "16213E").opacity(0.98)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Divider().background(Color.white.opacity(0.06))
        }
    }
}

// MARK: - Main Content Router
struct MainContentView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Group {
            if let project = store.selectedProject {
                ProjectDetailView(project: project)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        switch store.selectedTab {
                        case .dashboard:
                            DashboardView()
                        case .timeline:
                            TimelineView()
                        case .board:
                            BoardView()
                        case .projects:
                            ProjectsView()
                        case .analytics:
                            AnalyticsView()
                        }
                    }
                    .padding(28)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "151528"), Color(hex: "16213E")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Settings (placeholder)
struct SettingsView: View {
    var body: some View {
        Text("Sprint Commander 설정")
            .frame(width: 400, height: 300)
    }
}
