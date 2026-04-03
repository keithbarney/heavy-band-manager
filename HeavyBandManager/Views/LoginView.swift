import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Branding
            VStack(spacing: 12) {
                Text("🎸")
                    .font(.system(size: 64))

                Text("Heavy Band Manager")
                    .font(.title2.bold())
                    .foregroundStyle(Color.themeTextPrimary)

                Text("Find practice times that work for everyone.")
                    .font(.subheadline)
                    .foregroundStyle(Color.themeTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Sign In
            VStack(spacing: 16) {
                Button(action: {
                    authManager.signInWithApple()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .medium))
                        Text("Sign in with Apple")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.black)
                    .cornerRadius(12)
                }

                if let error = authManager.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.themeDanger)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)

            #if DEBUG
            DevUserPicker()
                .padding(.top, 8)
            #endif

            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.themeBg)
    }
}
