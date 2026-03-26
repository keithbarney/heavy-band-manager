import SwiftUI

struct AuthGate: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isLoading {
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
