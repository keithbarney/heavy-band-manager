import Foundation

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug = "Bug"
    case scheduling = "Scheduling Problem"
    case calendarSync = "Calendar Sync Problem"
    case feature = "Feature Request"
    case general = "General Feedback"

    var id: String { rawValue }
}

struct FeedbackDiagnostics {
    let appVersion: String
    let osVersion: String
    let calendarPermission: String
    let notificationPermission: String
    let source: String

    var text: String {
        """
        App: Band Practice \(appVersion)
        iOS: \(osVersion)
        Calendar permission: \(calendarPermission)
        Notifications: \(notificationPermission)
        Opened from: \(source)
        """
    }
}

struct FeedbackDraft {
    let category: FeedbackCategory
    let message: String
    var context: String? = nil
    var includeContext = false
    let diagnostics: FeedbackDiagnostics
    var includeDiagnostics = true

    var hasMessage: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var subject: String { "Band Practice — \(category.rawValue)" }

    var body: String {
        var sections = ["Category: \(category.rawValue)", message.trimmingCharacters(in: .whitespacesAndNewlines)]
        if includeContext, let context {
            sections.append("Context: \(context)")
        }
        if includeDiagnostics { sections.append(diagnostics.text) }
        return sections.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}
