import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Content group — branding + button
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("Band Practice")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.themeTextPrimary)

                    Text("Find the perfect practice time\nfor everyone.")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.themeTextSecondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: {
                    authManager.signInWithApple()
                }) {
                    Label("Sign in with Apple", systemImage: "apple.logo")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
                .padding(.horizontal, 40)
            }

            if let error = authManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.themeDanger)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.themeBg)
    }
}
