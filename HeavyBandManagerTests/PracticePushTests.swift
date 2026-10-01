import XCTest
@testable import HeavyBandManager

final class PracticePushTests: XCTestCase {
    func testEveryPracticeNotificationRoutesThroughMembershipCheckedPracticeNavigation() throws {
        let band = UUID(), practice = UUID()
        for kind in ["practice_scheduled", "practice_updated", "practice_location_changed", "practice_cancelled"] {
            let push = try XCTUnwrap(PracticePush(userInfo: ["notification_type": kind,
                "band_id": band.uuidString, "practice_id": practice.uuidString]))
            let route = try XCTUnwrap(PracticeRoute(url: XCTUnwrap(push.url)))
            XCTAssertEqual(route.bandID, band)
            XCTAssertEqual(route.practiceID, practice)
        }
    }

    func testUnrelatedAndMalformedPayloadsCannotTriggerCalendarSync() {
        XCTAssertNil(PracticePush(userInfo: [:]))
        XCTAssertNil(PracticePush(userInfo: ["notification_type": "friend_joined",
            "band_id": UUID().uuidString, "practice_id": UUID().uuidString]))
        XCTAssertNil(PracticePush(userInfo: ["notification_type": "practice_updated",
            "band_id": "invalid", "practice_id": UUID().uuidString]))
    }
}
