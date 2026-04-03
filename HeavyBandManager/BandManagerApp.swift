import SwiftUI
import BackgroundTasks

@main
struct BandManagerApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var bandManager = BandManager()
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var toastManager = ToastManager()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dark
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
