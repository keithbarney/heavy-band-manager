import SwiftUI
import Supabase
import UserNotifications

@MainActor
final class PracticePushManager: ObservableObject {
    static let shared = PracticePushManager()
    @Published private(set) var registrationError: String?
    @Published var pendingRoute: URL?
    private var token: String?
    private var registrationTask: Task<Void, Never>?
    private var signingOut = false
    private let installationKey = "practicePush.installationID"

    private var installationID: String {
        if let value = UserDefaults.standard.string(forKey: installationKey) { return value }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: installationKey)
        return value
    }

    func refreshRegistration() {
#if !(DEBUG && targetEnvironment(simulator) && (ONBOARDING_PREVIEW || AVAILABILITY_TAB_PREVIEW))
        guard !SCREENSHOT_MODE, !signingOut, Config.supabase.auth.currentUser != nil else { return }
        UIApplication.shared.registerForRemoteNotifications()
        registerTokenIfPossible()
#endif
    }

    func receivedToken(_ data: Data) {
        token = data.map { String(format: "%02x", $0) }.joined()
        registerTokenIfPossible()
    }

    func registrationFailed() {
        registrationError = "Practice notifications could not connect. Registration will retry when you reopen the app."
    }

    private func registerTokenIfPossible() {
#if !(DEBUG && targetEnvironment(simulator) && (ONBOARDING_PREVIEW || AVAILABILITY_TAB_PREVIEW))
        guard !SCREENSHOT_MODE, !signingOut, let token, let account = Config.supabase.auth.currentUser?.id,
              let bundle = Bundle.main.bundleIdentifier,
              let environment = Bundle.main.object(forInfoDictionaryKey: "PushEnvironment") as? String else { return }
        registrationTask?.cancel()
        registrationTask = Task {
            do {
                try Task.checkCancellation()
                try await Config.supabase.rpc("register_practice_push_device", params: [
                    "p_installation_id": AnyJSON.string(installationID),
                    "p_token": .string(token), "p_bundle_id": .string(bundle),
                    "p_environment": .string(environment)
                ]).execute()
                guard !Task.isCancelled, Config.supabase.auth.currentUser?.id == account else { return }
                registrationError = nil
            } catch {
                guard !Task.isCancelled, Config.supabase.auth.currentUser?.id == account else { return }
                registrationFailed()
            }
        }
#endif
    }

    /// Unregister before revoking the authenticated session; failures prevent sign-out
    /// from leaving a private notification destination attached to this device.
    func unregister() async throws {
#if DEBUG && targetEnvironment(simulator) && (ONBOARDING_PREVIEW || AVAILABILITY_TAB_PREVIEW)
        return
#else
        guard !SCREENSHOT_MODE, Config.supabase.auth.currentUser != nil else { return }
        signingOut = true
        registrationTask?.cancel()
        await registrationTask?.value
        try await Config.supabase.rpc("unregister_practice_push_device", params: [
            "p_installation_id": AnyJSON.string(installationID)
        ]).execute()
        pendingRoute = nil
        registrationError = nil
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
#endif
    }

    func accountChanged(preservePendingRoute: Bool = false) {
        registrationTask?.cancel()
        signingOut = false
        if !preservePendingRoute { pendingRoute = nil }
        registrationError = nil
        UserDefaults.standard.removeObject(forKey: "practiceCalendarSync.error")
        refreshRegistration()
    }

    func resumeRegistrationAfterFailedSignOut() {
        signingOut = false
        refreshRegistration()
    }
}
