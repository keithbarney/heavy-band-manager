#if !(DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW)
import XCTest
import EventKit
@testable import HeavyBandManager

@MainActor
final class PracticeCalendarIntegrationTests: XCTestCase {
    func testLocationUpdateAndClearPersistWithoutDuplicatingLocalEvent() async throws {
        // Explicit CI-host permission and a local-only source are prerequisites.
        // This test never creates a calendar in an iCloud/CalDAV account.
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw XCTSkip("Grant calendar access to the isolated CI host to run the EventKit integration test.")
        }
        let store = EKEventStore()
        guard let source = store.sources.first(where: { $0.sourceType == .local }) else {
            throw XCTSkip("Requires a Simulator-local calendar source.")
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "Band Practice location test \(UUID().uuidString)"
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        defer { try? store.removeCalendar(calendar, commit: true) }
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = "Test Practice"
        event.location = "Old test studio"
        event.notes = "Preserve these test notes"
        let day = Calendar.current.startOfDay(for: Date())
        event.startDate = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: day)!
        event.endDate = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: day)!
        event.addAlarm(EKAlarm(relativeOffset: -1800))
        try store.save(event, span: .thisEvent)
        let identifier = try XCTUnwrap(event.eventIdentifier)
        let suite = "PracticeCalendarTest.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = CalendarManager(eventStore: store, preferences: defaults)
        manager.checkAuthorization()
        let practiceID = UUID(), bandID = UUID()
        let updatedID = try await manager.createPracticeEvent(practiceId: practiceID, bandId: bandID,
            legacyEventIdentifier: identifier, date: day, startMinutes: 1140, endMinutes: 1260,
            bandName: "Test", location: "New test studio")
        XCTAssertEqual(updatedID, identifier)
        let verificationStore = EKEventStore()
        let updated = try XCTUnwrap(verificationStore.event(withIdentifier: identifier))
        XCTAssertEqual(updated.location, "New test studio")
        XCTAssertEqual(updated.notes, "Preserve these test notes")
        XCTAssertEqual(updated.alarms?.count, 1)
        _ = try await manager.createPracticeEvent(practiceId: practiceID, bandId: bandID,
            date: day, startMinutes: 1140, endMinutes: 1260, bandName: "Test", location: "")
        let finalStore = EKEventStore()
        XCTAssertNil(finalStore.event(withIdentifier: identifier)?.location)
        let predicate = finalStore.predicateForEvents(withStart: day,
            end: Calendar.current.date(byAdding: .day, value: 1, to: day)!, calendars: [calendar])
        XCTAssertEqual(finalStore.events(matching: predicate).count, 1)
    }
}
#endif
