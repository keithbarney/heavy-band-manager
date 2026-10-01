import XCTest
import EventKit
@testable import HeavyBandManager

final class PracticeWidgetTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return value
    }

    func testUpcomingOrdersSameDayAndIncludesOngoingButNotEnded() throws {
        let bandID = UUID()
        func practice(_ start: Int, _ end: Int) -> PracticeSummary {
            PracticeSummary(id: UUID(), bandId: bandID, date: "2026-09-14", startMinutes: start, endMinutes: end, location: nil)
        }
        let ended = practice(900, 960), ongoing = practice(960, 1080), later = practice(1200, 1260)
        let band = PracticeWidgetBand(id: bandID, name: "Band", practices: [later, ended, ongoing], updatedAt: Date())
        let now = try XCTUnwrap(PracticeDate.date("2026-09-14", minutes: 1000, calendar: calendar))
        XCTAssertEqual(band.upcoming(at: now, calendar: calendar).map(\.id), [ongoing.id, later.id])
    }

    func testDatesValidateAndHonorMidnightAndDaylightSaving() throws {
        XCTAssertNil(PracticeDate.date("2026-02-30", minutes: 600, calendar: calendar))
        XCTAssertNil(PracticeDate.date("2026-09-14", minutes: -1, calendar: calendar))
        let end = try XCTUnwrap(PracticeDate.date("2026-03-08", minutes: 1440, calendar: calendar))
        XCTAssertEqual(PracticeDate.string(end, calendar: calendar), "2026-03-09")
        let start = try XCTUnwrap(PracticeDate.date("2026-03-08", minutes: 0, calendar: calendar))
        XCTAssertEqual(end.timeIntervalSince(start), 23 * 60 * 60)
    }

    func testTimelineContainsBoundariesAndStaleCutoff() throws {
        let now = try XCTUnwrap(PracticeDate.date("2026-09-14", minutes: 600, calendar: calendar))
        let practice = PracticeSummary(id: UUID(), bandId: UUID(), date: "2026-09-14", startMinutes: 660, endMinutes: 720, location: nil)
        let band = PracticeWidgetBand(id: practice.bandId, name: "Band", practices: [practice], updatedAt: now)
        let dates = band.timelineDates(after: now, calendar: calendar)
        XCTAssertTrue(dates.contains(try XCTUnwrap(practice.start(in: calendar))))
        XCTAssertTrue(dates.contains(try XCTUnwrap(practice.end(in: calendar))))
        XCTAssertTrue(dates.contains(now.addingTimeInterval(86400)))
        XCTAssertFalse(band.needsRefresh(at: now))
        XCTAssertTrue(band.needsRefresh(at: now.addingTimeInterval(86400)))
    }

    func testStoreRoundTripAndAccountClearDoNotRetainBandData() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = PracticeWidgetStore(fileURL: url)
        let snapshot = PracticeWidgetSnapshot(accountID: UUID(), bands: [PracticeWidgetBand(id: UUID(), name: "Private band", practices: [], updatedAt: Date())])
        try store.write(snapshot)
        XCTAssertEqual(store.read(), snapshot)
        try store.write(PracticeWidgetSnapshot())
        XCTAssertNil(store.read()?.accountID)
        XCTAssertEqual(store.read()?.bands, [])
        try Data("invalid".utf8).write(to: url)
        XCTAssertNil(store.read())
    }

    func testDeepLinksRequireValidBandAndPracticeIdentifiers() {
        let route = PracticeRoute(bandID: UUID(), practiceID: UUID())
        XCTAssertEqual(PracticeRoute(url: route.url), route)
        XCTAssertNil(PracticeRoute(url: URL(string: "https://practice/\(route.bandID)/\(route.practiceID)")!))
        XCTAssertNil(PracticeRoute(url: URL(string: "\(PracticeRoute.scheme)://practice/not-a-uuid")!))
    }

    func testWidgetSelectionDoesNotFollowAppPreferenceOrRemovedBand() {
        let selected = PracticeWidgetBand(id: UUID(), name: "Selected", practices: [], updatedAt: nil)
        let other = PracticeWidgetBand(id: UUID(), name: "Other", practices: [], updatedAt: nil)
        var snapshot = PracticeWidgetSnapshot(accountID: UUID(), preferredBandID: other.id, bands: [selected, other])
        let intent = SelectPracticeBand()
        intent.bandIdentifier = selected.id.uuidString
        XCTAssertEqual(intent.selectedBand(in: snapshot)?.id, selected.id)
        snapshot.bands.removeAll { $0.id == selected.id }
        XCTAssertNil(intent.selectedBand(in: snapshot))
        XCTAssertEqual(intent.bandIdentifier, selected.id.uuidString)
    }

    func testCalendarReconciliationChangesAndClearsLocationPreservingOtherFields() {
        let event = EKEvent(eventStore: EKEventStore())
        event.location = "Old studio"
        event.notes = "Bring cables"
        event.addAlarm(EKAlarm(relativeOffset: -1800))
        let fields = PracticeCalendarFields(title: "Practice", location: "New studio", start: Date(timeIntervalSince1970: 1800000000), end: Date(timeIntervalSince1970: 1800007200))
        fields.apply(to: event)
        XCTAssertEqual(event.location, "New studio")
        XCTAssertEqual(event.notes, "Bring cables")
        XCTAssertEqual(event.alarms?.count, 1)
        XCTAssertEqual(PracticeCalendarFields(event: event), fields)
        PracticeCalendarFields(title: fields.title, location: "", start: fields.start, end: fields.end).apply(to: event)
        XCTAssertNil(event.location)
    }

    func testAllBandsAgendaKeepsFairChronologicalGroupsAndEmptyBands() throws {
        let now = try XCTUnwrap(PracticeDate.date("2026-09-14", minutes: 600, calendar: calendar))
        func band(_ name: String, days: [String]) -> PracticeWidgetBand {
            let id = UUID()
            return PracticeWidgetBand(id: id, name: name, practices: days.map {
                PracticeSummary(id: UUID(), bandId: id, date: $0, startMinutes: 1140, endMinutes: 1260, location: name)
            }, updatedAt: now)
        }
        let busy = band("Busy", days: ["2026-09-19", "2026-09-15", "2026-09-17", "2026-09-16"])
        let second = band("Second", days: ["2026-09-20", "2026-09-18", "2026-09-21"])
        let empty = band("Empty", days: [])
        let bands = [empty, second, busy]
        let groups = PracticeAgendaGroup.groups(bands: bands, at: now, maxBands: 3, perBand: 2, calendar: calendar)
        XCTAssertEqual(groups.map(\.band.id), [busy.id, second.id, empty.id])
        XCTAssertEqual(groups.map { $0.practices.count }, [2, 2, 0])
        XCTAssertEqual(groups[0].practices.map(\.date), ["2026-09-15", "2026-09-16"])
        XCTAssertEqual(groups[1].practices.map(\.date), ["2026-09-18", "2026-09-20"])
        XCTAssertTrue(groups[1].practices.allSatisfy { $0.bandId == second.id })
        XCTAssertEqual(PracticeAgendaGroup.groups(bands: bands, at: now, maxBands: 1, perBand: 1, calendar: calendar).count, 1)
        XCTAssertEqual(PracticeWidgetSnapshot(bands: bands).orderedBands(at: now, calendar: calendar).count, 3)
    }

    func testAllBandsIsAnExplicitChoiceAndDefaultForNewWidgets() async throws {
        let intent = SelectPracticeBand()
        intent.bandIdentifier = SelectPracticeBand.allBandsIdentifier
        XCTAssertTrue(intent.showsAllBands)
        let defaultValue = await PracticeBandOptions().defaultResult()
        XCTAssertEqual(defaultValue, SelectPracticeBand.allBandsIdentifier)
        intent.bandIdentifier = UUID().uuidString
        XCTAssertFalse(intent.showsAllBands)
    }

    @MainActor
    func testAllBandsLinkAndPracticeLinkResetEachOthersDestination() {
        let navigation = PracticeNavigation()
        navigation.open(PracticeRoute.allBandsURL)
        XCTAssertTrue(navigation.showAllBands)
        XCTAssertNil(navigation.pending)
        let route = PracticeRoute(bandID: UUID(), practiceID: UUID())
        navigation.open(route.url)
        XCTAssertFalse(navigation.showAllBands)
        XCTAssertEqual(navigation.pending, route)
        navigation.open(PracticeRoute.allBandsURL)
        XCTAssertNil(navigation.pending)
        XCTAssertTrue(navigation.showAllBands)
    }
}
