import Foundation

/// Pushes are hints, never authoritative calendar data or proof of membership.
struct PracticePush: Equatable {
    let bandID: UUID
    let practiceID: UUID
    let kind: String

    init?(userInfo: [AnyHashable: Any]) {
        guard let kind = userInfo["notification_type"] as? String,
              ["practice_scheduled", "practice_updated", "practice_location_changed", "practice_cancelled"].contains(kind),
              let band = userInfo["band_id"] as? String, let bandID = UUID(uuidString: band),
              let practice = userInfo["practice_id"] as? String, let practiceID = UUID(uuidString: practice) else { return nil }
        self.bandID = bandID
        self.practiceID = practiceID
        self.kind = kind
    }

    var url: URL? {
        PracticeRoute(bandID: bandID, practiceID: practiceID).url
    }
}
