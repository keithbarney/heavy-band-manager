import Foundation

/// Device-local mapping between a shared scheduled practice and this device's
/// EventKit event identifier.
struct PracticeEventRegistry: Codable, Equatable {
    private(set) var identifiers: [String: String] = [:]
    private var bandIdentifiers: [String: String]? = nil

    func identifier(for practiceId: UUID) -> String? {
        identifiers[practiceId.uuidString]
    }

    func practiceIds(for bandId: UUID) -> Set<UUID> {
        let bandIdString = bandId.uuidString
        return Set(
            (bandIdentifiers ?? [:]).compactMap { practiceId, storedBandId in
                guard storedBandId == bandIdString else { return nil }
                return UUID(uuidString: practiceId)
            }
        )
    }

    mutating func record(_ eventIdentifier: String, for practiceId: UUID, bandId: UUID) {
        identifiers[practiceId.uuidString] = eventIdentifier
        var storedBandIdentifiers = bandIdentifiers ?? [:]
        storedBandIdentifiers[practiceId.uuidString] = bandId.uuidString
        bandIdentifiers = storedBandIdentifiers
    }

    mutating func resolveIdentifier(
        for practiceId: UUID,
        bandId: UUID,
        legacyIdentifier: String?,
        eventExists: (String) -> Bool
    ) -> String? {
        if let registeredIdentifier = identifier(for: practiceId),
           eventExists(registeredIdentifier) {
            record(registeredIdentifier, for: practiceId, bandId: bandId)
            return registeredIdentifier
        }

        if identifier(for: practiceId) != nil {
            removeIdentifier(for: practiceId)
        }

        guard let legacyIdentifier, eventExists(legacyIdentifier) else {
            return nil
        }

        record(legacyIdentifier, for: practiceId, bandId: bandId)
        return legacyIdentifier
    }

    @discardableResult
    mutating func removeIdentifier(for practiceId: UUID) -> String? {
        bandIdentifiers?.removeValue(forKey: practiceId.uuidString)
        return identifiers.removeValue(forKey: practiceId.uuidString)
    }
}
