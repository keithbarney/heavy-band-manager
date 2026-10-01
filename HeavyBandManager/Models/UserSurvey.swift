import Foundation

enum AppUsageStyle: String, Codable, CaseIterable, Identifiable {
    case app = "This app"
    case calendar = "Apple Calendar"
    case widgetOrReminders = "Widget or reminders"
    case gettingStarted = "gettingStarted"
    case notWorking = "I haven’t got it working yet"

    var id: String { rawValue }

    // Keep stored values stable when the wording changes so saved drafts survive.
    var label: String {
        switch self {
        case .app: return "Find times when bandmates are available"
        case .calendar: return "Schedule practices and sync them to my calendar"
        case .widgetOrReminders: return "Set or sync my availability"
        case .gettingStarted: return "I’m still getting started"
        case .notWorking: return "I haven’t been able to get it working"
        }
    }
}

struct UserSurveyDraft: Codable, Equatable {
    var usageStyle: AppUsageStyle?
    var frustrations = ""
    var usefulChange = ""
    var interviewOptIn = false
    var replyAddress = ""

    var canSubmit: Bool { usageStyle != nil }
    var hasContent: Bool {
        usageStyle != nil || !frustrations.isEmpty || !usefulChange.isEmpty || interviewOptIn || !replyAddress.isEmpty
    }

    mutating func setInterviewOptIn(_ enabled: Bool) {
        interviewOptIn = enabled
        if !enabled { replyAddress = "" }
    }

    var subject: String { "Band Practice — Three-question survey" }

    var body: String {
        var sections = [
            "How I usually use Band Practice:\n\(usageStyle?.label ?? "Not answered")",
            "What has been frustrating or missing:\n\(answer(frustrations))",
            "One change that would make the app more useful:\n\(answer(usefulChange))"
        ]
        if interviewOptIn {
            sections.append("I’m interested in an optional 15-minute conversation about using the app.")
            let contact = replyAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(contact.isEmpty ? "Please reply to my sending email address." : "Please reply to: \(contact)")
        } else {
            sections.append("I’m not volunteering for an interview.")
        }
        return sections.joined(separator: "\n\n")
    }

    private func answer(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not answered" : trimmed
    }
}

struct UserSurveyInvitation: Codable {
    static let minimumUseInterval: TimeInterval = 3 * 24 * 60 * 60
    static let cooldownInterval: TimeInterval = 30 * 24 * 60 * 60

    var firstObservedUse: Date?
    var foregroundSessions = 0
    var lastDeferredAt: Date?
    var completedAt: Date?
    var invitationsDisabled = false

    mutating func recordForeground(at date: Date) {
        if firstObservedUse == nil { firstObservedUse = date }
        foregroundSessions += 1
    }

    func isEligible(at date: Date) -> Bool {
        guard !invitationsDisabled, completedAt == nil,
              let firstObservedUse,
              foregroundSessions >= 2,
              date.timeIntervalSince(firstObservedUse) >= Self.minimumUseInterval else { return false }
        if let lastDeferredAt, date.timeIntervalSince(lastDeferredAt) < Self.cooldownInterval { return false }
        return true
    }

    mutating func deferInvitation(at date: Date) { lastDeferredAt = date }
}

enum UserSurveyEmailOutcome {
    case queued, saved, cancelled, failed
}

struct UserSurveyProgress: Codable {
    var invitation = UserSurveyInvitation()
    var draft = UserSurveyDraft()

    mutating func handleEmailOutcome(_ outcome: UserSurveyEmailOutcome, at date: Date) {
        // Mail's sent result means queued, not confirmed delivery.
        // Copying, cancelling, and saving are never counted as completion.
        switch outcome {
        case .queued:
            invitation.completedAt = date
            draft = UserSurveyDraft()
        case .saved:
            invitation.deferInvitation(at: date)
        case .cancelled, .failed:
            break
        }
    }
}
