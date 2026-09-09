import XCTest
@testable import HeavyBandManager

@MainActor
final class AvailabilitySetupTests: XCTestCase {
    func testLegacyCalendarOptOutDoesNotSurvivePreferencesMigration() throws {
        let data = Data(#"{"selectedCalendarIds":["personal"],"calendarName":"Rehearsals","addPracticesToCalendar":false}"#.utf8)
        let prefs = try JSONDecoder().decode(CalendarPrefs.self, from: data)
        XCTAssertEqual(prefs.calendarName, "Rehearsals")
        XCTAssertEqual(prefs.selectedCalendarIds, ["personal"])
        let saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(prefs)) as? [String: Any]
        XCTAssertNil(saved?["addPracticesToCalendar"])
    }

    func testCalendarSetupDoesNotSucceedWithoutMember() async {
        let manager = BandManager()
        do {
            try await manager.setAvailabilityMode(.calendar)
            XCTFail("Missing membership must not be reported as completed setup.")
        } catch {
            XCTAssertEqual((error as NSError).code, 401)
        }
    }

    func testManualSetupDoesNotSucceedWithoutMember() async {
        let manager = BandManager()
        do {
            try await manager.saveWeeklyAvailability([1: (start: 1140, end: 1320)])
            XCTFail("Missing membership must not be reported as completed setup.")
        } catch {
            XCTAssertEqual((error as NSError).code, 401)
        }
    }
}
