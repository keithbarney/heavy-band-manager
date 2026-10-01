import XCTest
import EventKit
@testable import HeavyBandManager

@MainActor
final class LocalCalendarIsolationTests: XCTestCase {
    func testLocalNamesKeepSuffixWhenCustomized() {
        XCTAssertEqual(CalendarManager.calendarName("Band Practice", isLocalBuild: true), "Band Practice (L)")
        XCTAssertEqual(CalendarManager.calendarName("My Band Practice", isLocalBuild: true), "My Band Practice (L)")
        XCTAssertEqual(CalendarManager.calendarName("My Band Practice (L)", isLocalBuild: true), "My Band Practice (L)")
        XCTAssertEqual(CalendarManager.calendarName("My Band Practice", isLocalBuild: false), "My Band Practice")
    }

    func testLocalIdentifiersCannotAdoptProductionEvents() {
        for title in ["Band Practice", "My Band Practice", "Personal", nil] {
            XCTAssertFalse(CalendarManager.canAccessCalendar(title: title, isLocalBuild: true))
        }
        XCTAssertTrue(CalendarManager.canAccessCalendar(title: "My Band Practice (L)", isLocalBuild: true))
        XCTAssertTrue(CalendarManager.canAccessCalendar(title: "My Band Practice", isLocalBuild: false))
    }
    func testLocalSimulatorDoesNotAdoptOrDeleteProductionIdentifier() async throws {
        guard CalendarManager.isLocalBuild,
              EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw XCTSkip("Requires calendar-authorized local Simulator app.")
        }
        let store = EKEventStore()
        guard let source = store.defaultCalendarForNewEvents?.source, source.sourceType == .local else {
            throw XCTSkip("Requires an isolated Simulator-local default calendar.")
        }
        let name = "Isolation Test \(UUID().uuidString) Practice"
        let production = EKCalendar(for: .event, eventStore: store)
        production.title = name
        production.source = source
        try store.saveCalendar(production, commit: true)
        defer { try? store.removeCalendar(production, commit: true) }
        let event = EKEvent(eventStore: store)
        event.calendar = production
        event.title = "Fictional isolation test practice"
        event.startDate = Date().addingTimeInterval(86400)
        event.endDate = event.startDate.addingTimeInterval(3600)
        try store.save(event, span: .thisEvent)
        let productionID = try XCTUnwrap(event.eventIdentifier)
        let suite = "CalendarIsolation.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let manager = CalendarManager(eventStore: store, preferences: preferences)
        manager.initialize()
        manager.renameCalendar(to: name)
        let local = try manager.getOrCreateBandCalendar()
        defer { try? store.removeCalendar(local, commit: true) }
        XCTAssertEqual(local.title, name + " (L)")
        let practiceID = UUID()
        let localID = try await manager.createPracticeEvent(practiceId: practiceID, bandId: UUID(),
            legacyEventIdentifier: productionID, date: event.startDate,
            startMinutes: 1140, endMinutes: 1200, bandName: "Fictional isolation test", location: nil)
        XCTAssertNotEqual(localID, productionID)
        XCTAssertEqual(store.event(withIdentifier: productionID)?.title, "Fictional isolation test practice")
        XCTAssertEqual(store.event(withIdentifier: localID)?.calendar.calendarIdentifier, local.calendarIdentifier)
        try await manager.deletePracticeEvent(practiceId: practiceID)
        XCTAssertNotNil(store.event(withIdentifier: productionID))
        XCTAssertNil(store.event(withIdentifier: localID))
    }

}
