import SwiftUI

@main
struct SprintCommanderApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1200, minHeight: 780)
                .onAppear { store.loadAndStartSync() }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Sync when app becomes active (user switched back)
                        store.refreshFromCloud()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)

        Settings {
            SettingsView()
        }
    }
}
