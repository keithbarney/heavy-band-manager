import XCTest
@testable import HeavyBandManager

final class PracticeEventRegistryTests: XCTestCase {
    func testRegistryKeepsIdentifiersSeparateByPractice() {
        let firstPractice = UUID()
        let secondPractice = UUID()
        let bandId = UUID()
        var registry = PracticeEventRegistry()

        registry.record("event-one", for: firstPractice, bandId: bandId)
        registry.record("event-two", for: secondPractice, bandId: bandId)

        XCTAssertEqual(registry.identifier(for: firstPractice), "event-one")
        XCTAssertEqual(registry.identifier(for: secondPractice), "event-two")
    }

    func testRemovingOneIdentifierDoesNotAffectAnotherPractice() {
        let firstPractice = UUID()
        let secondPractice = UUID()
        let bandId = UUID()
        var registry = PracticeEventRegistry()
        registry.record("event-one", for: firstPractice, bandId: bandId)
        registry.record("event-two", for: secondPractice, bandId: bandId)

        XCTAssertEqual(registry.removeIdentifier(for: firstPractice), "event-one")
        XCTAssertNil(registry.identifier(for: firstPractice))
        XCTAssertEqual(registry.identifier(for: secondPractice), "event-two")
    }

    func testValidLegacyIdentifierIsAdoptedForCurrentDeviceAndBand() {
        let practiceId = UUID()
        let bandId = UUID()
        var registry = PracticeEventRegistry()

        let resolved = registry.resolveIdentifier(
            for: practiceId,
            bandId: bandId,
            legacyIdentifier: "legacy-event",
            eventExists: { $0 == "legacy-event" }
        )

        XCTAssertEqual(resolved, "legacy-event")
        XCTAssertEqual(registry.identifier(for: practiceId), "legacy-event")
        XCTAssertEqual(registry.practiceIds(for: bandId), [practiceId])
    }

    func testLegacyIdentifierFromAnotherDeviceIsNotAdopted() {
        let practiceId = UUID()
        let bandId = UUID()
        var registry = PracticeEventRegistry()

        let resolved = registry.resolveIdentifier(
            for: practiceId,
            bandId: bandId,
            legacyIdentifier: "other-device-event",
            eventExists: { _ in false }
        )

        XCTAssertNil(resolved)
        XCTAssertNil(registry.identifier(for: practiceId))
        XCTAssertTrue(registry.practiceIds(for: bandId).isEmpty)
    }

    func testBandOwnershipSupportsScopedStalePracticeReconciliation() {
        let firstBand = UUID()
        let secondBand = UUID()
        let activePractice = UUID()
        let stalePractice = UUID()
        let otherBandPractice = UUID()
        var registry = PracticeEventRegistry()
        registry.record("active", for: activePractice, bandId: firstBand)
        registry.record("stale", for: stalePractice, bandId: firstBand)
        registry.record("other", for: otherBandPractice, bandId: secondBand)

        let staleIds = registry
            .practiceIds(for: firstBand)
            .subtracting([activePractice])

        XCTAssertEqual(staleIds, [stalePractice])
        XCTAssertEqual(registry.practiceIds(for: secondBand), [otherBandPractice])
    }

    func testLegacyCalendarPreferencesDecodeWithoutRegistry() throws {
        let legacyJSON = Data(#"{"selectedCalendarIds":["calendar-one"]}"#.utf8)

        let preferences = try JSONDecoder().decode(CalendarPrefs.self, from: legacyJSON)

        XCTAssertEqual(preferences.selectedCalendarIds, ["calendar-one"])
        XCTAssertNil(preferences.practiceEventRegistry)
    }

    func testRegistryRoundTripsThroughCalendarPreferences() throws {
        let practiceId = UUID()
        let bandId = UUID()
        var registry = PracticeEventRegistry()
        registry.record("local-event", for: practiceId, bandId: bandId)
        let preferences = CalendarPrefs(
            selectedCalendarIds: [],
            lastSyncDate: nil,
            calendarName: "Band Practice",
            autoSync: true,
            calendarColorHex: "#0000FF",
            calendarIdentifier: "practice-calendar",
            practiceEventRegistry: registry
        )

        let encoded = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(CalendarPrefs.self, from: encoded)

        XCTAssertEqual(decoded.practiceEventRegistry?.identifier(for: practiceId), "local-event")
        XCTAssertEqual(decoded.practiceEventRegistry?.practiceIds(for: bandId), [practiceId])
    }

}
