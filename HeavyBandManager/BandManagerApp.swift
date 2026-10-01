import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct BandManagerApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var practiceNavigation = PracticeNavigation()
    @StateObject private var authManager = AuthManager()
    @StateObject private var bandManager = BandManager()
    @StateObject private var calendarManager = PracticeCalendarSync.calendar
    @StateObject private var practicePush = PracticePushManager.shared
    @StateObject private var toastManager = ToastManager()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
#if DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW
                AvailabilityTabPreviewView()
#else
                AuthGate()
#endif
            }
                .modifier(FeedbackLifecycle())
                .environmentObject(practiceNavigation)
                .onOpenURL { practiceNavigation.open($0) }
                .onChange(of: practicePush.pendingRoute) { _, url in
                    if let url {
                        practiceNavigation.open(url)
                        practicePush.pendingRoute = nil
                    }
                }
                .environmentObject(authManager)
                .environmentObject(bandManager)
                .environmentObject(calendarManager)
                .environmentObject(toastManager)
                .preferredColorScheme(screenshotColorScheme ?? appearanceMode.colorScheme)
                .overlay(alignment: .bottom) {
                    ToastView()
                        .environmentObject(toastManager)
                }
                .task {
#if DEBUG && targetEnvironment(simulator) && (ONBOARDING_PREVIEW || AVAILABILITY_TAB_PREVIEW)
                    calendarManager.initialize()
#else
                    await authManager.initialize()
                    PracticeWidgetSync.shared.setAccount(authManager.user?.id)
                    calendarManager.initialize()
                    practicePush.refreshRegistration()
                    if let route = practicePush.pendingRoute {
                        practiceNavigation.open(route)
                        practicePush.pendingRoute = nil
                    }
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
                    // Practice alerts come from the server, avoiding a second local
                    // alert when the same change arrives over Realtime.
                    bandManager.onPracticeDeleted = { practiceId in
                        Task {
                            try? await calendarManager.deletePracticeEvent(practiceId: practiceId)
                        }
                    }
                    bandManager.onPracticeListChanged = {
                        Task {
                            _ = await bandManager.syncMissingCalendarEvents(
                                calendarManager: calendarManager,
                                reconcileStaleEvents: true
                            )
                        }
                    }
#endif
                }
                .onChange(of: authManager.user) { oldUser, newUser in
                    practicePush.accountChanged(preservePendingRoute: oldUser == nil && newUser != nil)
                    PracticeWidgetSync.shared.setAccount(newUser?.id)
                    if newUser != nil {
                        Task {
                            if await bandManager.loadBands() {
                                _ = await bandManager.syncMissingCalendarEvents(
                                    calendarManager: calendarManager,
                                    reconcileStaleEvents: true
                                )
                            }
                        }
                    } else {
                        bandManager.cleanup()
                    }
                }
                .onChange(of: calendarManager.isAuthorized) { _, authorized in
                    if authorized, authManager.user != nil {
                        Task {
                            _ = await bandManager.syncMissingCalendarEvents(
                                calendarManager: calendarManager,
                                reconcileStaleEvents: true
                            )
                        }
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            practicePush.refreshRegistration()
                            await PracticeWidgetSync.shared.refresh()
                            _ = await PracticeCalendarSync.refresh(force: false)
                            if authManager.user != nil, await bandManager.loadPractices() {
                                _ = await bandManager.syncMissingCalendarEvents(calendarManager: calendarManager, reconcileStaleEvents: true)
                            }
                            await autoSyncIfNeeded()
                        }
                    }
                }
        }
    }

    init() {
#if !(DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW)
        BackgroundSyncManager.register()
#endif

        // One-time migration: reset appearance to system default
        if UserDefaults.standard.string(forKey: "appearanceMigrated") == nil {
            UserDefaults.standard.removeObject(forKey: "appearanceMode")
            UserDefaults.standard.set("done", forKey: "appearanceMigrated")
        }
    }

    private var screenshotColorScheme: ColorScheme? {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--screenshot-appearance=") }) else {
            return nil
        }

        switch argument.split(separator: "=", maxSplits: 1).last {
        case "light": return .light
        case "dark": return .dark
        default: return nil
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
        let end = calendar.date(byAdding: .month, value: 6, to: start)!
        do {
            try await bandManager.syncCalendar(calendarManager: calendarManager, from: start, to: end)
        } catch {
            bandManager.error = "Automatic availability could not refresh. Your previous availability is still published."
        }
        BackgroundSyncManager.scheduleNext()
    }
}

// Show notifications even when the app is in the foreground
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PracticePushManager.shared.receivedToken(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in PracticePushManager.shared.registrationFailed() }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard PracticePush(userInfo: userInfo) != nil else { completionHandler(.noData); return }
        Task { @MainActor in
            var completed = false
            let operation = Task { @MainActor in
                let success = await PracticeCalendarSync.refresh()
                guard !Task.isCancelled, !completed else { return }
                completed = true
                completionHandler(success ? .newData : .failed)
                await PracticeWidgetSync.shared.refresh(force: true)
            }
            // Finish within iOS's background notification budget, including slow/offline requests.
            try? await Task.sleep(for: .seconds(25))
            guard !completed else { return }
            completed = true
            operation.cancel()
            completionHandler(.failed)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let push = PracticePush(userInfo: response.notification.request.content.userInfo) else { return }
        await MainActor.run { PracticePushManager.shared.pendingRoute = push.url }
        _ = await PracticeCalendarSync.refresh()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
