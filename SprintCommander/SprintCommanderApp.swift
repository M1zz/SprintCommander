import SwiftUI

// MARK: - AppDelegate (원격 알림 수신)

class AppDelegate: NSObject, NSApplicationDelegate {
    // AppStore는 SwiftUI 쪽에서 주입
    weak var store: AppStore?

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("[CloudSync] 원격 알림 등록 성공")
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[CloudSync] 원격 알림 등록 실패: \(error.localizedDescription)")
    }

    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        store?.handleRemoteNotification(userInfo: userInfo)
    }
}

// MARK: - App

@main
struct SprintCommanderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1200, minHeight: 780)
                .onAppear {
                    appDelegate.store = store
                    store.loadAndStartSync()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
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
