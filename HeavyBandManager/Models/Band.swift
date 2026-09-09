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
    let availabilityMode: AvailabilityMode
    let availabilitySetupComplete: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, instrument, color
        case bandId = "band_id"
        case userId = "user_id"
        case practiceWindowStart = "practice_window_start"
        case practiceWindowEnd = "practice_window_end"
        case avatarUrl = "avatar_url"
        case availabilityMode = "availability_mode"
        case availabilitySetupComplete = "availability_setup_complete"
        case joinedAt = "joined_at"
    }

    init(
        id: UUID,
        bandId: UUID,
        userId: UUID,
        name: String,
        instrument: String?,
        color: String,
        practiceWindowStart: Int,
        practiceWindowEnd: Int,
        avatarUrl: String?,
        availabilityMode: AvailabilityMode = .calendar,
        availabilitySetupComplete: Bool = true,
        joinedAt: Date
    ) {
        self.id = id
        self.bandId = bandId
        self.userId = userId
        self.name = name
        self.instrument = instrument
        self.color = color
        self.practiceWindowStart = practiceWindowStart
        self.practiceWindowEnd = practiceWindowEnd
        self.avatarUrl = avatarUrl
        self.availabilityMode = availabilityMode
        self.availabilitySetupComplete = availabilitySetupComplete
        self.joinedAt = joinedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        bandId = try container.decode(UUID.self, forKey: .bandId)
        userId = try container.decode(UUID.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        instrument = try container.decodeIfPresent(String.self, forKey: .instrument)
        color = try container.decode(String.self, forKey: .color)
        practiceWindowStart = try container.decodeIfPresent(Int.self, forKey: .practiceWindowStart) ?? 960
        practiceWindowEnd = try container.decodeIfPresent(Int.self, forKey: .practiceWindowEnd) ?? 1380
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        availabilityMode = try container.decodeIfPresent(AvailabilityMode.self, forKey: .availabilityMode) ?? .calendar
        availabilitySetupComplete = try container.decodeIfPresent(Bool.self, forKey: .availabilitySetupComplete) ?? true
        joinedAt = try container.decodeIfPresent(Date.self, forKey: .joinedAt) ?? Date()
    }
}

enum AvailabilityMode: String, Codable, CaseIterable, Identifiable {
    case weekly
    case calendar

    var id: String { rawValue }
}

struct WeeklyAvailabilityRule: Identifiable, Codable, Hashable {
    let id: UUID
    let memberId: UUID
    let bandId: UUID
    let dayOfWeek: Int
    let startMinutes: Int
    let endMinutes: Int

    enum CodingKeys: String, CodingKey {
        case id
        case memberId = "member_id"
        case bandId = "band_id"
        case dayOfWeek = "day_of_week"
        case startMinutes = "start_minutes"
        case endMinutes = "end_minutes"
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
