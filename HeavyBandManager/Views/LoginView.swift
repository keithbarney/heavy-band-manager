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
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Sign in with Apple")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(Color.themeBg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.themeTextPrimary)
                    .cornerRadius(14)
                }
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
