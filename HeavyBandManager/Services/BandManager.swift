import SwiftUI
import Supabase

@MainActor
final class BandManager: ObservableObject {
    @Published var bands: [BandWithMembers] = []
    @Published var currentBand: BandWithMembers?
    var members: [BandMember] { currentBand?.bandMembers ?? [] }
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
            let userId = try currentUserId()

            // Step 1: Find which bands the user belongs to via band_members
            let myMemberships: [BandMember] = try await Config.supabase
                .from("band_members")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            guard let membership = myMemberships.first else {
                bands = []
                currentBand = nil
                return
            }

            // Step 2: Fetch that band
            let fetchedBands: [Band] = try await Config.supabase
                .from("bands")
                .select()
                .eq("id", value: membership.bandId.uuidString)
                .execute()
                .value

            if let first = fetchedBands.first {
                // Step 3: Fetch all members of this band
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
                    logoUrl: first.logoUrl,
                    createdAt: first.createdAt,
                    bandMembers: fetchedMembers
                )

                bands = [bandWithMembers]
                currentBand = bandWithMembers
                async let slotsLoad: Void = loadSlots()
                async let practicesLoad: Void = loadPractices()
                _ = await (slotsLoad, practicesLoad)
                subscribeToChanges()
            }
        } catch {
            self.error = error.localizedDescription
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
        // Use SECURITY DEFINER function to bypass RLS for atomic band + member creation
        let params: [String: AnyJSON] = [
            "p_band_name": .string(name),
            "p_member_name": .string(userName),
            "p_instrument": instrument.map { .string($0) } ?? .null,
            "p_color": .string(MemberColors.palette[0].hexString),
        ]

        try await Config.supabase
            .rpc("create_band_with_member", params: params)
            .execute()

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

    func schedulePractice(date: String, startMinutes: Int, endMinutes: Int, location: String?, calendarManager: CalendarManager? = nil) async {
        guard let bandId = currentBand?.id else { return }
        let bandName = currentBand?.name ?? "Band"
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
            let practice: ScheduledPractice = try await Config.supabase
                .from("scheduled_practices")
                .insert(data)
                .select()
                .single()
                .execute()
                .value

            // Create Apple Calendar event if calendar manager is available
            if let cm = calendarManager, let practiceDate = TimeHelpers.date(from: date) {
                do {
                    let eventId = try await cm.createPracticeEvent(
                        date: practiceDate,
                        startMinutes: startMinutes,
                        endMinutes: endMinutes,
                        bandName: bandName,
                        location: location
                    )
                    // Save the calendar_event_id back to Supabase
                    try await Config.supabase
                        .from("scheduled_practices")
                        .update(["calendar_event_id": AnyJSON.string(eventId)])
                        .eq("id", value: practice.id.uuidString)
                        .execute()
                } catch {
                    // Calendar event creation failed — practice is still saved to Supabase
                    print("Calendar event creation skipped: \(error.localizedDescription)")
                }
            }

            await loadPractices()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func cancelPractice(_ practiceId: UUID, calendarManager: CalendarManager? = nil) async {
        do {
            // Find the practice to get its calendar_event_id before deleting
            if let cm = calendarManager,
               let practice = practices.first(where: { $0.id == practiceId }),
               let eventId = practice.calendarEventId {
                try? await cm.deletePracticeEvent(eventIdentifier: eventId)
            }

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

    // MARK: - Calendar Sync for Existing Practices

    /// Creates calendar events for any scheduled practices that are missing a calendar_event_id.
    /// Call this on app launch after practices have been loaded.
    func syncMissingCalendarEvents(calendarManager: CalendarManager) async {
        guard let bandName = currentBand?.name else { return }
        guard calendarManager.isAuthorized else { return }

        let needsSync = practices.filter { $0.calendarEventId == nil }
        guard !needsSync.isEmpty else { return }

        for practice in needsSync {
            guard let practiceDate = TimeHelpers.date(from: practice.date) else { continue }
            do {
                let eventId = try await calendarManager.createPracticeEvent(
                    date: practiceDate,
                    startMinutes: practice.startMinutes,
                    endMinutes: practice.endMinutes,
                    bandName: bandName,
                    location: practice.location
                )
                try await Config.supabase
                    .from("scheduled_practices")
                    .update(["calendar_event_id": AnyJSON.string(eventId)])
                    .eq("id", value: practice.id.uuidString)
                    .execute()
            } catch {
                print("Failed to sync calendar event for practice \(practice.id): \(error.localizedDescription)")
            }
        }
        // Reload to pick up the updated calendar_event_id values
        await loadPractices()
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

            // Insert new slots in a single batch
            if !newSlots.isEmpty {
                let rows: [[String: AnyJSON]] = newSlots.map { slot in
                    [
                        "member_id": .string(member.id.uuidString),
                        "band_id": .string(bandId.uuidString),
                        "date": .string(slot.date),
                        "start_minutes": .integer(slot.startMinutes),
                        "end_minutes": .integer(slot.endMinutes),
                        "confirmed": .bool(true),
                    ]
                }
                try await Config.supabase
                    .from("availability_slots")
                    .insert(rows)
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
        slots = []
        practices = []
    }

    // MARK: - Avatar Upload

    func uploadAvatar(imageData: Data) async {
        guard let member = currentMember else { return }
        let path = "\(member.id.uuidString).jpg"

        do {
            // Upload to storage
            try await Config.supabase.storage
                .from("avatars")
                .upload(path, data: imageData, options: .init(contentType: "image/jpeg", upsert: true))

            // Get public URL
            let publicURL = try Config.supabase.storage
                .from("avatars")
                .getPublicURL(path: path)

            // Update band_members row
            try await Config.supabase
                .from("band_members")
                .update(["avatar_url": AnyJSON.string(publicURL.absoluteString)])
                .eq("id", value: member.id.uuidString)
                .execute()

            await loadBands()
        } catch {
            self.error = error.localizedDescription
            print("Avatar upload error: \(error)")
        }
    }

    // MARK: - Practice Window

    func updatePracticeWindow(start: Int, end: Int) async throws {
        guard let member = currentMember else { return }
        try await Config.supabase
            .from("band_members")
            .update(["practice_window_start": AnyJSON.integer(start), "practice_window_end": AnyJSON.integer(end)])
            .eq("id", value: member.id.uuidString)
            .execute()
        await loadBands()
    }

    func updateMemberName(_ name: String) async {
        guard let member = currentMember, !name.isEmpty else { return }
        do {
            try await Config.supabase
                .from("band_members")
                .update(["name": AnyJSON.string(name)])
                .eq("id", value: member.id.uuidString)
                .execute()
            await loadBands()
        } catch { print("Update name error: \(error)") }
    }

    func updateMemberInstrument(_ instrument: String, memberId: UUID? = nil) async {
        let targetId = memberId ?? currentMember?.id
        guard let id = targetId else { return }
        do {
            try await Config.supabase
                .from("band_members")
                .update(["instrument": AnyJSON.string(instrument)])
                .eq("id", value: id.uuidString)
                .execute()
            await loadBands()
        } catch { print("Update instrument error: \(error)") }
    }

    func updateBandName(_ name: String) async {
        guard let band = currentBand, !name.isEmpty, isLeader else { return }
        do {
            try await Config.supabase
                .from("bands")
                .update(["name": AnyJSON.string(name)])
                .eq("id", value: band.id.uuidString)
                .execute()
            await loadBands()
        } catch { print("Update band name error: \(error)") }
    }

    func uploadBandLogo(imageData: Data) async {
        guard let band = currentBand, isLeader else { return }
        let path = "bands/\(band.id.uuidString)/logo.jpg"
        do {
            try await Config.supabase.storage
                .from("avatars")
                .upload(path, data: imageData, options: .init(contentType: "image/jpeg", upsert: true))
            let publicURL = try Config.supabase.storage
                .from("avatars")
                .getPublicURL(path: path)
            try await Config.supabase
                .from("bands")
                .update(["logo_url": AnyJSON.string(publicURL.absoluteString)])
                .eq("id", value: band.id.uuidString)
                .execute()
            await loadBands()
        } catch { print("Upload band logo error: \(error)") }
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
