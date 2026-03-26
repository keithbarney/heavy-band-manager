import SwiftUI

@main
struct BandManagerApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var bandManager = BandManager()
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var toastManager = ToastManager()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .light

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
                        Task { await bandManager.loadBands() }
                    } else {
                        bandManager.cleanup()
                    }
                }
        }
    }
}
