import SwiftUI
import UIKit
import UserNotifications

struct BandTabs: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var showCalendarPrompt = false
    @State private var showNotifPrompt = false
    @State private var notifAuthStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        TabView {
            CalendarMonthView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(Color.themeAccent)
        .task { await checkPermissions() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await checkPermissions() }
            }
        }
        .onChange(of: showCalendarPrompt) { _, isShown in
            if !isShown {
                Task { await checkPermissions() }
            }
        }
        .alert("Connect Your Calendar", isPresented: $showCalendarPrompt) {
            Button(calendarManager.authStatus == .notDetermined ? "Connect" : "Open Settings") {
                Task {
                    if calendarManager.authStatus == .notDetermined {
                        await calendarManager.requestAccess()
                    } else if let url = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(url)
                    }
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Band Practice needs your calendar to find times when everyone is free. Without it, the app can't work.")
        }
        .alert("Enable Notifications", isPresented: $showNotifPrompt) {
            Button(notifAuthStatus == .notDetermined ? "Enable" : "Open Settings") {
                Task {
                    if notifAuthStatus == .notDetermined {
                        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                        await checkPermissions()
                    } else if let url = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(url)
                    }
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Get notified when bandmates join and when practices are scheduled. Optional.")
        }
    }

    private func checkPermissions() async {
        calendarManager.checkAuthorization()
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notifAuthStatus = settings.authorizationStatus
        let notifAuthorized = notifAuthStatus == .authorized || notifAuthStatus == .provisional

        if !calendarManager.isAuthorized {
            if !showCalendarPrompt { showCalendarPrompt = true }
        } else if !notifAuthorized {
            if !showNotifPrompt { showNotifPrompt = true }
        }
    }
}
