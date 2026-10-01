import XCTest
@testable import HeavyBandManager

final class FeedbackTests: XCTestCase {
    func testFeedbackPrivacyAndWhitespace() {
        let diagnostics = FeedbackDiagnostics(appVersion: "1 (2)", osVersion: "26", calendarPermission: "Denied", notificationPermission: "Not requested", source: "Detail screen")
        var draft = FeedbackDraft(category: .bug, message: "  Missing event\nPlease help.  ", context: "Private context", diagnostics: diagnostics)
        XCTAssertTrue(draft.hasMessage)
        XCTAssertFalse(draft.body.contains("Private context"))
        XCTAssertFalse(draft.subject.contains("Private context"))
        XCTAssertTrue(draft.body.contains("Calendar permission: Denied"))
        draft.includeDiagnostics = false
        XCTAssertEqual(draft.body, "Category: Bug\n\nMissing event\nPlease help.")
        draft.includeContext = true
        XCTAssertTrue(draft.body.contains("Context: Private context"))
        XCTAssertFalse(draft.body.contains("Detail screen"))
        XCTAssertFalse(FeedbackDraft(category: .bug, message: " \n\t", diagnostics: diagnostics).hasMessage)
    }

    func testInterviewConsentAndMailOutcomes() {
        var progress = UserSurveyProgress()
        XCTAssertFalse(progress.draft.canSubmit)
        progress.draft.usageStyle = .notWorking
        progress.draft.replyAddress = "private@example.com"
        XCTAssertTrue(progress.draft.canSubmit)
        XCTAssertFalse(progress.draft.body.contains("private@example.com"))
        progress.draft.setInterviewOptIn(true)
        XCTAssertTrue(progress.draft.body.contains("private@example.com"))
        progress.draft.setInterviewOptIn(false)
        XCTAssertEqual(progress.draft.replyAddress, "")
        let draft = progress.draft
        for outcome in [UserSurveyEmailOutcome.cancelled, .failed, .saved] {
            progress.handleEmailOutcome(outcome, at: .now)
            XCTAssertEqual(progress.draft, draft)
            XCTAssertNil(progress.invitation.completedAt)
        }
        progress.handleEmailOutcome(.queued, at: .now)
        XCTAssertNotNil(progress.invitation.completedAt)
        XCTAssertEqual(progress.draft, UserSurveyDraft())
    }

    @MainActor
    func testSurveyPersistenceAndInvitationBoundaries() {
        let suite = "FeedbackTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let day: TimeInterval = 86400
        let store = UserSurveyStore(defaults: defaults)
        store.recordForeground(at: start)
        store.recordForeground(at: start.addingTimeInterval(3 * day))
        XCTAssertFalse(store.shouldInvite, "Repeated active events are not another session")
        store.recordBackground()
        store.recordForeground(at: start.addingTimeInterval(3 * day - 1))
        XCTAssertFalse(store.shouldInvite)
        store.recordForeground(at: start.addingTimeInterval(3 * day))
        XCTAssertTrue(store.shouldInvite)
        store.draft.usageStyle = .gettingStarted
        store.draft.frustrations = "Saved answer"
        store.deferInvitation(at: start.addingTimeInterval(3 * day))
        let reopened = UserSurveyStore(defaults: defaults)
        XCTAssertEqual(reopened.draft.frustrations, "Saved answer")
        reopened.recordForeground(at: start.addingTimeInterval(33 * day - 1))
        XCTAssertFalse(reopened.shouldInvite)
        reopened.recordForeground(at: start.addingTimeInterval(33 * day))
        XCTAssertTrue(reopened.shouldInvite)
        reopened.invitationsDisabled = true
        let optedOut = UserSurveyStore(defaults: defaults)
        optedOut.recordForeground(at: start.addingTimeInterval(365 * day))
        XCTAssertFalse(optedOut.shouldInvite)
        XCTAssertTrue(optedOut.draft.canSubmit)
        optedOut.clearDraft()
        XCTAssertFalse(UserSurveyStore(defaults: defaults).draft.hasContent)
        optedOut.handleEmailOutcome(.queued, at: start)
        optedOut.invitationsDisabled = false
        optedOut.recordForeground(at: start.addingTimeInterval(366 * day))
        XCTAssertFalse(optedOut.shouldInvite)
    }
}
