import Foundation
import Combine

@MainActor
final class UserSurveyStore: ObservableObject {
    private static let storageKey = "userResearch.survey.v1"
    private let defaults: UserDefaults
    private var isForeground = false
    @Published private(set) var now = Date()
    @Published private var progress: UserSurveyProgress

    init(defaults: UserDefaults? = nil) {
        let defaults = defaults ?? FeedbackEnvironment.defaults
        self.defaults = defaults
        progress = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(UserSurveyProgress.self, from: $0) } ?? UserSurveyProgress()
        #if DEBUG
        if FeedbackEnvironment.isMock && ProcessInfo.processInfo.arguments.contains("-feedback-invitation") {
            progress.invitation.firstObservedUse = Date().addingTimeInterval(-4 * 24 * 60 * 60)
            progress.invitation.foregroundSessions = 2
        }
        #endif
    }

    var draft: UserSurveyDraft {
        get { progress.draft }
        set {
            progress.draft = newValue
            persist()
        }
    }

    var invitationsDisabled: Bool {
        get { progress.invitation.invitationsDisabled }
        set {
            progress.invitation.invitationsDisabled = newValue
            persist()
        }
    }

    var shouldInvite: Bool { progress.invitation.isEligible(at: now) }

    func recordForeground(at date: Date = Date()) {
        now = date
        guard !isForeground else { return }
        isForeground = true
        progress.invitation.recordForeground(at: date)
        persist()
    }

    func recordBackground() { isForeground = false }

    func deferInvitation(at date: Date = Date()) {
        now = date
        progress.invitation.deferInvitation(at: date)
        persist()
    }

    func handleEmailOutcome(_ outcome: UserSurveyEmailOutcome, at date: Date = Date()) {
        progress.handleEmailOutcome(outcome, at: date)
        persist()
    }

    func clearDraft() { draft = UserSurveyDraft() }

    private func persist() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
