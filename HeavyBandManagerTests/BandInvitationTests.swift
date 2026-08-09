import XCTest
@testable import HeavyBandManager

final class BandInvitationTests: XCTestCase {
    func testInvitationNormalizesInputs() {
        let invitation = BandInvitation(
            bandName: "  Duhkha  ",
            inviteCode: " hbm-ab12 "
        )

        XCTAssertEqual(invitation.bandName, "Duhkha")
        XCTAssertEqual(invitation.inviteCode, "HBM-AB12")
    }

    func testInvitationIncludesEverythingNeededToJoin() {
        let invitation = BandInvitation(
            bandName: "Duhkha",
            inviteCode: "HBM-AB12"
        )

        XCTAssertEqual(invitation.subject, "Join Duhkha on Band Practice")
        XCTAssertTrue(invitation.messageBody.contains("Join Duhkha on Band Practice"))
        XCTAssertTrue(invitation.messageBody.contains("enter this invite code when prompted"))
        XCTAssertTrue(invitation.messageBody.contains("On Calendar, tap your band name"))
        XCTAssertTrue(invitation.messageBody.contains("Join a Band"))
        XCTAssertTrue(invitation.messageBody.contains("HBM-AB12"))
        XCTAssertTrue(
            invitation.messageBody.contains(BandInvitation.appStoreURL.absoluteString)
        )
    }
}
