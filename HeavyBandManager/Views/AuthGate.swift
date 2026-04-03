import SwiftUI

// TEMP: Set to true to bypass login for screenshots
let SCREENSHOT_MODE = false

struct AuthGate: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var bandManager: BandManager

    var body: some View {
        Group {
            if SCREENSHOT_MODE {
                BandTabs()
                    .onAppear { bandManager.loadMockData() }
            } else if authManager.isLoading {
                ProgressView()
                    .tint(.themeAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.themeBg)
            } else if authManager.user != nil {
                BandGate()
            } else {
                LoginView()
            }
        }
    }
}
