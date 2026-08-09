import Foundation

struct BandInvitation: Equatable {
    static let appStoreURL = URL(
        string: "https://apps.apple.com/us/app/band-practice-calendar/id6763776073"
    )!

    let bandName: String
    let inviteCode: String

    init(bandName: String, inviteCode: String) {
        self.bandName = bandName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.inviteCode = inviteCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    var subject: String {
        "Join \(bandName) on Band Practice"
    }

    var messageBody: String {
        """
        Join \(bandName) on Band Practice.

        Download the app: \(Self.appStoreURL.absoluteString)

        New to Band Practice? Sign in, then enter this invite code when prompted: \(inviteCode)

        Already use the app? On Calendar, tap your band name, choose Join a Band, and enter the same code.
        """
    }
}
