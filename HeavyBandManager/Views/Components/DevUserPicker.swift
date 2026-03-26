import SwiftUI

#if DEBUG
struct DevUserPicker: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var loadingUserId: UUID?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text("DEV USERS")
                .font(.caption.bold())
                .foregroundStyle(Color.themeTextTertiary)
                .tracking(1.5)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(devUsers) { user in
                    Button {
                        loadingUserId = user.id
                        Task {
                            await authManager.signInWithEmail(user.email, password: user.password)
                            loadingUserId = nil
                        }
                    } label: {
                        VStack(spacing: 6) {
                            if loadingUserId == user.id {
                                ProgressView()
                                    .tint(user.color)
                                    .frame(height: 32)
                            } else {
                                Text(user.emoji)
                                    .font(.title2)
                            }
                            Text(user.name)
                                .font(.caption.bold())
                                .foregroundStyle(Color.themeTextPrimary)
                            Text(user.instrument)
                                .font(.caption2)
                                .foregroundStyle(Color.themeTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.themeBgSecondary)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(user.color.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .disabled(loadingUserId != nil)
                }
            }
        }
        .padding(.horizontal, 24)
    }
}
#endif
