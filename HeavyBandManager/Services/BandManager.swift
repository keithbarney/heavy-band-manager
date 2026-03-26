import SwiftUI
import Supabase

@MainActor
final class BandManager: ObservableObject {
    @Published var bands: [BandWithMembers] = []
    @Published var currentBand: BandWithMembers?
    @Published var members: [BandMember] = []
    @Published var slots: [AvailabilitySlot] = []
    @Published var practices: [ScheduledPractice] = []
    @Published var isLoading = true
    @Published var error: String?

    private var slotsChannel: RealtimeChannelV2?
    private var practicesChannel: RealtimeChannelV2?

    // MARK: - Current member helper

    var currentMember: BandMember? {
        guard let userId = try? currentUserId() else { return nil }
        return members.first { $0.userId == userId }
    }

    var isLeader: Bool {
        guard let userId = try? currentUserId(), let band = currentBand else { return false }
        return band.leaderId == userId
    }

    private func currentUserId() throws -> UUID {
        guard let user = Config.supabase.auth.currentUser else {
            throw NSError(domain: "BandManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        return user.id
    }

    // MARK: - Load

    func loadBands() async {
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            let fetchedBands: [Band] = try await Config.supabase
                .from("bands")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            if let first = fetchedBands.first {
                let fetchedMembers: [BandMember] = try await Config.supabase
                    .from("band_members")
                    .select()
                    .eq("band_id", value: first.id.uuidString)
                    .order("joined_at")
                    .execute()
                    .value

                let bandWithMembers = BandWithMembers(
                    id: first.id,
                    name: first.name,
                    creatorId: first.creatorId,
                    leaderId: first.leaderId,
                    defaultPracticeLocation: first.defaultPracticeLocation,
                    inviteCode: first.inviteCode,
                    createdAt: first.createdAt,
                    bandMembers: fetchedMembers
                )

                bands = [bandWithMembers]
                currentBand = bandWithMembers
                members = fetchedMembers
                await loadSlots()
                await loadPractices()
                subscribeToChanges()
            }
        } catch {
            self.error = error.localizedDescription
            print("BandManager loadBands error: \(error)")
        }
    }

    func loadSlots(from startDate: String? = nil, to endDate: String? = nil) async {
        guard let bandId = currentBand?.id else { return }
        do {
            var query = Config.supabase
                .from("availability_slots")
                .select()
                .eq("band_id", value: bandId.uuidString)

            if let start = startDate {
                query = query.gte("date", value: start)
            }
            if let end = endDate {
                query = query.lte("date", value: end)
            }

            slots = try await query.execute().value
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadPractices(from startDate: String? = nil, to endDate: String? = nil) async {
        guard let bandId = currentBand?.id else { return }
        do {
            var query = Config.supabase
                .from("scheduled_practices")
                .select()
                .eq("band_id", value: bandId.uuidString)

            if let start = startDate {
                query = query.gte("date", value: start)
            }
            if let end = endDate {
                query = query.lte("date", value: end)
            }

            practices = try await query.order("date").execute().value
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Create Band

    func createBand(name: String, userName: String, instrument: String?) async throws {
        let userId = try currentUserId()
        let inviteCode = generateInviteCode()

        let bandData: [String: AnyJSON] = [
            "name": .string(name),
            "creator_id": .string(userId.uuidString),
            "leader_id": .string(userId.uuidString),
            "invite_code": .string(inviteCode),
        ]

        let band: Band = try await Config.supabase
            .from("bands")
            .insert(bandData)
            .select()
            .single()
            .execute()
            .value

        let memberData: [String: AnyJSON] = [
            "band_id": .string(band.id.uuidString),
            "user_id": .string(userId.uuidString),
            "name": .string(userName),
            "instrument": instrument.map { .string($0) } ?? .null,
            "color": .string(MemberColors.palette[0].hexString),
        ]

        let _: BandMember = try await Config.supabase
            .from("band_members")
            .insert(memberData)
            .select()
            .single()
            .execute()
            .value

        await loadBands()
    }

    // MARK: - Join Band

    func joinBand(inviteCode: String, userName: String, instrument: String?) async throws {
        let userId = try currentUserId()
        let code = inviteCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Fetch band + members separately to avoid nested Codable issues
        let matchingBands: [Band] = try await Config.supabase
            .from("bands")
            .select()
            .eq("invite_code", value: code)
            .execute()
            .value

        guard let band = matchingBands.first else {
            throw NSError(domain: "BandManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No band found with that invite code"])
        }

        let existingMembers: [BandMember] = try await Config.supabase
            .from("band_members")
            .select()
            .eq("band_id", value: band.id.uuidString)
            .execute()
            .value

        if existingMembers.contains(where: { $0.userId == userId }) {
            throw NSError(domain: "BandManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "You're already in this band"])
        }

        let colorIndex = existingMembers.count % MemberColors.palette.count
        let memberData: [String: AnyJSON] = [
            "band_id": .string(band.id.uuidString),
            "user_id": .string(userId.uuidString),
            "name": .string(userName),
            "instrument": instrument.map { .string($0) } ?? .null,
            "color": .string(MemberColors.palette[colorIndex].hexString),
        ]

        let _: BandMember = try await Config.supabase
            .from("band_members")
            .insert(memberData)
            .select()
            .single()
            .execute()
            .value

        await loadBands()
    }

    // MARK: - Schedule Practice

    func schedulePractice(date: String, startMinutes: Int, endMinutes: Int, location: String?) async {
        guard let bandId = currentBand?.id else { return }
        let userId = try? currentUserId()
        let data: [String: AnyJSON] = [
            "band_id": .string(bandId.uuidString),
            "date": .string(date),
            "start_minutes": .integer(startMinutes),
            "end_minutes": .integer(endMinutes),
            "location": location.map { .string($0) } ?? .null,
            "scheduled_by": .string(userId?.uuidString ?? ""),
        ]
        do {
            let _: ScheduledPractice = try await Config.supabase
                .from("scheduled_practices")
                .insert(data)
                .select()
                .single()
                .execute()
                .value
            await loadPractices()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func cancelPractice(_ practiceId: UUID) async {
        do {
            try await Config.supabase
                .from("scheduled_practices")
                .delete()
                .eq("id", value: practiceId.uuidString)
                .execute()
            await loadPractices()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Calendar Sync

    func syncCalendar(calendarManager: CalendarManager, from startDate: Date, to endDate: Date) async {
        guard let member = currentMember, let bandId = currentBand?.id else { return }

        let events = calendarManager.getEvents(from: startDate, to: endDate)
        let newSlots = calendarManager.invertEventsToSlots(
            events: events,
            from: startDate,
            to: endDate,
            windowStart: member.practiceWindowStart,
            windowEnd: member.practiceWindowEnd,
            memberId: member.id
        )

        let startStr = TimeHelpers.dateString(from: startDate)
        let endStr = TimeHelpers.dateString(from: endDate)

        do {
            // Delete existing slots for this member in the date range
            try await Config.supabase
                .from("availability_slots")
                .delete()
                .eq("member_id", value: member.id.uuidString)
                .eq("band_id", value: bandId.uuidString)
                .gte("date", value: startStr)
                .lte("date", value: endStr)
                .execute()

            // Insert new slots
            for slot in newSlots {
                let data: [String: AnyJSON] = [
                    "member_id": .string(member.id.uuidString),
                    "band_id": .string(bandId.uuidString),
                    "date": .string(slot.date),
                    "start_minutes": .integer(slot.startMinutes),
                    "end_minutes": .integer(slot.endMinutes),
                    "confirmed": .bool(true),
                ]
                try await Config.supabase
                    .from("availability_slots")
                    .insert(data)
                    .execute()
            }

            calendarManager.lastSyncDate = Date()
            calendarManager.savePrefs()
            await loadSlots(from: startStr, to: endStr)
        } catch {
            self.error = error.localizedDescription
            print("Sync error: \(error)")
        }
    }

    // MARK: - Overlap

    func computeOverlap(minMembers: Int? = nil) -> [OverlapWindow] {
        OverlapEngine.compute(slots: slots, totalMembers: members.count, minMembers: minMembers ?? members.count)
    }

    func overlapMap() -> [String: OverlapQuality] {
        OverlapEngine.overlapMap(slots: slots, totalMembers: members.count)
    }

    // MARK: - Realtime

    private func subscribeToChanges() {
        guard let bandId = currentBand?.id else { return }

        if let old = slotsChannel { Task { await old.unsubscribe() } }
        if let old = practicesChannel { Task { await old.unsubscribe() } }

        let newSlots = Config.supabase.realtimeV2.channel("slots-\(bandId.uuidString)")
        let newPractices = Config.supabase.realtimeV2.channel("practices-\(bandId.uuidString)")
        slotsChannel = newSlots
        practicesChannel = newPractices

        Task {
            let changes = newSlots.postgresChange(AnyAction.self, table: "availability_slots")
            await newSlots.subscribe()
            for await _ in changes {
                await loadSlots()
            }
        }

        Task {
            let changes = newPractices.postgresChange(AnyAction.self, table: "scheduled_practices")
            await newPractices.subscribe()
            for await _ in changes {
                await loadPractices()
            }
        }
    }

    func cleanup() {
        if let ch = slotsChannel { Task { await ch.unsubscribe() } }
        if let ch = practicesChannel { Task { await ch.unsubscribe() } }
        slotsChannel = nil
        practicesChannel = nil
        bands = []
        currentBand = nil
        members = []
        slots = []
        practices = []
    }

    // MARK: - Helpers

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code = String((0..<4).map { _ in chars.randomElement()! })
        return "HBM-\(code)"
    }
}

// MARK: - Color hex string helper

extension Color {
    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
