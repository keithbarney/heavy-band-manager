import Foundation
import MessageUI

/// Mock feedback never opens Mail or shares survey state with personal use.
@MainActor
enum FeedbackEnvironment {
    static var isMock: Bool {
        #if DEBUG && targetEnvironment(simulator) && (AVAILABILITY_TAB_PREVIEW || ONBOARDING_PREVIEW)
        return true
        #else
        return false
        #endif
    }

    static var defaults: UserDefaults {
        guard isMock else { return .standard }
        let suite = "HeavyBandManager.feedback.mock"
        let defaults = UserDefaults(suiteName: suite)!
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-feedback-reset") {
            defaults.removePersistentDomain(forName: suite)
        }
        #endif
        return defaults
    }

    static var canSendMail: Bool {
        !isMock && MFMailComposeViewController.canSendMail()
    }
}
