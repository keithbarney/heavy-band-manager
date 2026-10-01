#if DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW
import XCTest
@testable import HeavyBandManager

@MainActor
final class PracticeLocationReviewTests: XCTestCase {
    func testDefaultDoesNotChangeExistingPracticeAndIndividualEditDoesNotChangeDefault() async throws {
        let store = AvailabilityTabReviewStore(.band)
        let practice = try XCTUnwrap(store.band.practices.first)
        try await store.band.setDefaultPracticeLocation("  New default  ")
        XCTAssertEqual(store.band.currentBand?.defaultPracticeLocation, "New default")
        XCTAssertEqual(store.band.practices.first?.location, practice.location)
        _ = try await store.band.setPracticeLocation(practice, location: "One-off studio", calendarManager: store.calendar)
        XCTAssertEqual(store.band.practices.first?.location, "One-off studio")
        XCTAssertEqual(store.band.currentBand?.defaultPracticeLocation, "New default")
        _ = try await store.band.setPracticeLocation(practice, location: "  ", calendarManager: store.calendar)
        XCTAssertEqual(store.band.practices.first?.location, "")
    }

    func testNonLeaderAndFailedSaveCannotChangeLocations() async throws {
        let member = AvailabilityTabReviewStore(.bandMember)
        do { try await member.band.setDefaultPracticeLocation("No"); XCTFail("Must reject") } catch {}
        let practice = try XCTUnwrap(member.band.practices.first)
        do { _ = try await member.band.setPracticeLocation(practice, location: "No", calendarManager: member.calendar); XCTFail("Must reject") } catch {}
        XCTAssertEqual(member.band.practices.first?.location, practice.location)
        let leader = AvailabilityTabReviewStore(.failure)
        let before = leader.band.currentBand?.defaultPracticeLocation
        do { try await leader.band.setDefaultPracticeLocation("No"); XCTFail("Must fail") } catch {}
        XCTAssertEqual(leader.band.currentBand?.defaultPracticeLocation, before)
        leader.band.previewSaveFails = false
        try await leader.band.setDefaultPracticeLocation("Retry")
        XCTAssertEqual(leader.band.currentBand?.defaultPracticeLocation, "Retry")
    }
}
#endif
