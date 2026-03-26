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
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { _ in
                    // Handled by AuthManager's Apple Sign-In flow
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(12)
                .onTapGesture {
                    authManager.signInWithApple()
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
