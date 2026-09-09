#if DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW
import XCTest
@testable import HeavyBandManager

@MainActor
final class AvailabilityTabReviewTests: XCTestCase {
    func testSavedHoursPersistAcrossScenarioSwitchAndPreserveOtherMembers() async throws {
        let session = AvailabilityTabReviewSession()
        let typical = session.store(.typical)
        let otherSlots = typical.band.slots.filter { $0.memberId != typical.band.currentMember?.id }
        try await typical.band.saveWeeklyAvailability([2: (start: 1080, end: 1260)])
        _ = session.store(.automatic)
        let returned = session.store(.typical)
        XCTAssertTrue(returned === typical)
        XCTAssertEqual(returned.band.weeklyRules.map(\.dayOfWeek), [2])
        XCTAssertEqual(returned.band.slots.filter { $0.memberId != returned.band.currentMember?.id }.count, otherSlots.count)
        XCTAssertEqual(returned.band.members.count, 4)
        session.reset(.automatic)
        XCTAssertTrue(session.store(.typical) === typical)
    }

    func testFailedSaveKeepsRulesAndRetryUpdatesThem() async throws {
        let store = AvailabilityTabReviewStore(.failure)
        let originalDays = store.band.weeklyRules.map(\.dayOfWeek)
        do {
            try await store.band.saveWeeklyAvailability([3: (start: 1140, end: 1260)])
            XCTFail("Expected the simulated failure")
        } catch {
            XCTAssertEqual(store.band.weeklyRules.map(\.dayOfWeek), originalDays)
        }
        store.band.previewSaveFails = false
        try await store.band.saveWeeklyAvailability([3: (start: 1140, end: 1260)])
        XCTAssertEqual(store.band.weeklyRules.map(\.dayOfWeek), [3])
    }

    func testCalendarWritesAndPermissionsStaySimulated() async throws {
        let store = AvailabilityTabReviewStore(.typical)
        let preferences = UserDefaults.standard.data(forKey: CalendarPreferenceKeys.preferences)
        store.calendar.renameCalendar(to: "Mock practice calendar")
        store.calendar.savePrefs()
        XCTAssertEqual(UserDefaults.standard.data(forKey: CalendarPreferenceKeys.preferences), preferences)
        let id = try await store.calendar.createPracticeEvent(practiceId: UUID(), bandId: UUID(), date: Date(), startMinutes: 1140, endMinutes: 1260, bandName: "Mock", location: nil)
        XCTAssertTrue(id.hasPrefix("mock-"))
        store.calendar.setPreviewAuthorization(.denied)
        await store.calendar.requestAccess()
        XCTAssertTrue(store.calendar.previewPermissionPrompt)
        XCTAssertFalse(store.calendar.isAuthorized)
    }
}
#endif
