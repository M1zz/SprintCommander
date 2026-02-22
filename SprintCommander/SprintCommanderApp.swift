import SwiftUI

@main
struct SprintCommanderApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1200, minHeight: 780)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)

        Settings {
            SettingsView()
        }
    }
}
