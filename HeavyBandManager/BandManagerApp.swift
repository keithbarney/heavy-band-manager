import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct BandManagerApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var authManager = AuthManager()
    @StateObject private var bandManager = BandManager()
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var toastManager = ToastManager()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AuthGate()
                .environmentObject(authManager)
                .environmentObject(bandManager)
                .environmentObject(calendarManager)
                .environmentObject(toastManager)
                .preferredColorScheme(appearanceMode.colorScheme)
                .overlay(alignment: .bottom) {
                    ToastView()
                        .environmentObject(toastManager)
                }
                .task {
                    await authManager.initialize()
                    calendarManager.initialize()
                    await requestNotificationPermission()
                    bandManager.onMemberJoined = { name in
                        toastManager.show("\(name) joined the band")
                        sendLocalNotification(
                            title: "New Band Member",
                            body: "\(name) joined the band"
                        )
                    }
                    bandManager.onBandCreated = { name in
                        toastManager.show("\(name) created")
                    }
                    bandManager.onBandDeleted = { name in
                        toastManager.show("\(name) deleted")
                    }
                }
                .onChange(of: authManager.user) { _, newUser in
                    if newUser != nil {
                        Task {
                            await bandManager.loadBands()
                            await bandManager.syncMissingCalendarEvents(calendarManager: calendarManager)
                        }
                    } else {
                        bandManager.cleanup()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await autoSyncIfNeeded() }
                    }
                }
        }
    }

    init() {
        BackgroundSyncManager.register()

        // One-time migration: reset appearance to system default
        if UserDefaults.standard.string(forKey: "appearanceMigrated") == nil {
            UserDefaults.standard.removeObject(forKey: "appearanceMode")
            UserDefaults.standard.set("done", forKey: "appearanceMigrated")
        }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func autoSyncIfNeeded() async {
        guard calendarManager.isAuthorized,
              calendarManager.autoSync,
              authManager.user != nil,
              bandManager.currentBand != nil else { return }

        // Only auto-sync if last sync was more than 10 minutes ago
        let minInterval: TimeInterval = 10 * 60
        if let last = calendarManager.lastSyncDate, Date().timeIntervalSince(last) < minInterval { return }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .month, value: 2, to: start)!
        await bandManager.syncCalendar(calendarManager: calendarManager, from: start, to: end)
        BackgroundSyncManager.scheduleNext()
    }
}

// Show notifications even when the app is in the foreground
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
