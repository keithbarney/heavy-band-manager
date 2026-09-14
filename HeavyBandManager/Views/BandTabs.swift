import SwiftUI
import UIKit
import UserNotifications

struct BandTabs: View {
    @EnvironmentObject var bandManager: BandManager
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject private var toastManager: ToastManager
    @State private var selectedTab: Int

    init(initialTab: Int = 0) {
        _selectedTab = State(initialValue: initialTab)
    }

    @State private var showCalendarPrompt = false
    @State private var showNotifPrompt = false
    @State private var notifAuthStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarMonthView(onOpenAvailability: { selectedTab = 1 })
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(0)

            NavigationStack {
                MyAvailabilityView(onFinished: {
                    toastManager.show("Availability saved", type: .success)
                })
            }
            .id(bandManager.currentBand?.id)
            .tabItem { Label("Availability", systemImage: "person.crop.circle.badge.clock") }
            .tag(1)

            BandSettingsView()
                .id(bandManager.currentBand?.id)
                .tabItem { Label("Band", systemImage: "person.3") }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(Color.themeAccent)
        .task { await checkPermissions() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await checkPermissions() }
            }
        }
        .alert("Connect Your Calendar", isPresented: $showCalendarPrompt) {
            Button(calendarManager.authStatus == .notDetermined ? "Continue" : "Open Settings") {
                Task {
                    if calendarManager.authStatus == .notDetermined {
                        await calendarManager.requestAccess()
                        await checkPermissions()
                    } else if let url = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(url)
                    }
                }
            }
            if calendarManager.authStatus != .notDetermined {
                Button("Cancel", role: .cancel) {}
            }
        } message: {
            Text("Connect your calendar so scheduled practices are added automatically. Your availability method stays the same.")
        }
        .alert("Enable Notifications", isPresented: $showNotifPrompt) {
            Button(notifAuthStatus == .notDetermined ? "Continue" : "Open Settings") {
                Task {
                    if notifAuthStatus == .notDetermined {
                        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                        await checkPermissions()
                    } else if let url = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(url)
                    }
                }
            }
            if notifAuthStatus != .notDetermined {
                Button("Cancel", role: .cancel) {}
            }
        } message: {
            Text("Get notified when bandmates join and when practices are scheduled. Optional.")
        }
    }

    private func checkPermissions() async {
#if DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW
        return
#else
        calendarManager.checkAuthorization()
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notifAuthStatus = settings.authorizationStatus
        let notifAuthorized = notifAuthStatus == .authorized || notifAuthStatus == .provisional

        if !calendarManager.isAuthorized {
            if !showCalendarPrompt { showCalendarPrompt = true }
        } else if !notifAuthorized {
            if !showNotifPrompt { showNotifPrompt = true }
        }
#endif
    }
}
