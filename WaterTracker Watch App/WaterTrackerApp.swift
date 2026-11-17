import SwiftUI
import UserNotifications

@main
struct WaterTrackerApp: App {
    @StateObject private var store = WaterStore.shared

    init() {
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
