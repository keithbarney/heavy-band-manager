import Foundation

struct Band: Identifiable, Codable {
    let id: UUID
    let name: String
    let creatorId: UUID
    let leaderId: UUID
    let defaultPracticeLocation: String?
    let inviteCode: String
    let logoUrl: String?
    let createdAt: Date
    let minPracticeMinutes: Int
    let maxPracticeMinutes: Int
    let minMembersRequired: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case creatorId = "creator_id"
        case leaderId = "leader_id"
        case defaultPracticeLocation = "default_practice_location"
        case inviteCode = "invite_code"
        case logoUrl = "logo_url"
        case createdAt = "created_at"
        case minPracticeMinutes = "min_practice_minutes"
        case maxPracticeMinutes = "max_practice_minutes"
        case minMembersRequired = "min_members_required"
    }
}

struct BandMember: Identifiable, Codable {
    let id: UUID
    let bandId: UUID
    let userId: UUID
    let name: String
    let instrument: String?
    let color: String
    let practiceWindowStart: Int
    let practiceWindowEnd: Int
    let avatarUrl: String?
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, instrument, color
        case bandId = "band_id"
        case userId = "user_id"
        case practiceWindowStart = "practice_window_start"
        case practiceWindowEnd = "practice_window_end"
        case avatarUrl = "avatar_url"
        case joinedAt = "joined_at"
    }
}

struct AvailabilitySlot: Identifiable, Codable {
    let id: UUID
    let memberId: UUID
    let bandId: UUID
    let date: String
    let startMinutes: Int
    let endMinutes: Int
    let confirmed: Bool

    enum CodingKeys: String, CodingKey {
        case id, date, confirmed
        case memberId = "member_id"
        case bandId = "band_id"
        case startMinutes = "start_minutes"
        case endMinutes = "end_minutes"
    }
}

struct ScheduledPractice: Identifiable, Codable {
    let id: UUID
    let bandId: UUID
    let date: String
    let startMinutes: Int
    let endMinutes: Int
    let location: String?
    let scheduledBy: UUID
    let scheduledAt: Date
    let calendarEventId: String?

    enum CodingKeys: String, CodingKey {
        case id, date, location
        case bandId = "band_id"
        case startMinutes = "start_minutes"
        case endMinutes = "end_minutes"
        case scheduledBy = "scheduled_by"
        case scheduledAt = "scheduled_at"
        case calendarEventId = "calendar_event_id"
    }
}

struct OverlapWindow: Identifiable {
    let id = UUID()
    let date: String
    let startMinutes: Int
    let endMinutes: Int
    let duration: Int
    let freeMembers: [UUID]
    let totalMembers: Int
}

enum OverlapQuality {
    case none, partial, full
}

// MARK: - Band with members (joined query result)

struct BandWithMembers: Identifiable, Codable {
    let id: UUID
    let name: String
    let creatorId: UUID
    let leaderId: UUID
    let defaultPracticeLocation: String?
    let inviteCode: String
    let logoUrl: String?
    let createdAt: Date
    let minPracticeMinutes: Int
    let maxPracticeMinutes: Int
    let minMembersRequired: Int
    let bandMembers: [BandMember]

    enum CodingKeys: String, CodingKey {
        case id, name
        case creatorId = "creator_id"
        case leaderId = "leader_id"
        case defaultPracticeLocation = "default_practice_location"
        case inviteCode = "invite_code"
        case logoUrl = "logo_url"
        case createdAt = "created_at"
        case minPracticeMinutes = "min_practice_minutes"
        case maxPracticeMinutes = "max_practice_minutes"
        case minMembersRequired = "min_members_required"
        case bandMembers = "band_members"
    }
}
