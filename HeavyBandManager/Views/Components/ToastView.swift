import SwiftUI

// MARK: - Toast Message

struct ToastMessage: Equatable {
    let text: String
    let type: ToastType

    enum ToastType {
        case success, error, info

        var color: Color {
            switch self {
            case .success: return .themeSuccess
            case .error: return .themeDanger
            case .info: return .themeAccent
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
}

// MARK: - Toast Manager

@MainActor
final class ToastManager: ObservableObject {
    @Published var message: ToastMessage?

    private var dismissTask: Task<Void, Never>?

    func show(_ text: String, type: ToastMessage.ToastType = .info) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.3)) {
            message = ToastMessage(text: text, type: type)
        }
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3)) {
                message = nil
            }
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    @EnvironmentObject var toastManager: ToastManager

    var body: some View {
        if let message = toastManager.message {
            HStack(spacing: 10) {
                Image(systemName: message.type.icon)
                    .foregroundStyle(message.type.color)
                Text(message.text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.themeTextPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(message.type.color.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
