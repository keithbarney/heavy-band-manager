import BackgroundTasks
import EventKit
import Supabase

enum BackgroundSyncManager {
    static let taskIdentifier = "com.keithbarney.heavybandmanager.calendar-sync"

    /// Register the background task handler. Call once at app launch.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleSync(task: refreshTask)
        }
        scheduleNext()
    }

    /// Schedule the next background refresh (~15 min minimum).
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BackgroundSync] Failed to schedule: \(error)")
        }
    }

    private static func handleSync(task: BGAppRefreshTask) {
        let syncTask = Task {
            do {
                try await performSync()
                task.setTaskCompleted(success: true)
            } catch {
                print("[BackgroundSync] Error: \(error)")
                task.setTaskCompleted(success: false)
            }
            scheduleNext()
        }

        task.expirationHandler = {
            syncTask.cancel()
        }
    }

    private static func performSync() async throws {
        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess || status == .authorized else { return }

        guard Config.supabase.auth.currentUser != nil else { return }
        let userId = Config.supabase.auth.currentUser!.id

        // Load calendar prefs
        let prefsKey = "heavy-band-manager:calendar-prefs"
        guard let data = UserDefaults.standard.data(forKey: prefsKey),
              let prefs = try? JSONDecoder().decode(CalendarPrefs.self, from: data),
              !(prefs.autoSync == false) else { return }

        let selectedIds = Set(prefs.selectedCalendarIds)
        guard !selectedIds.isEmpty else { return }

        // Fetch memberships
        let memberships: [BandMember] = try await Config.supabase
            .from("band_members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        guard !memberships.isEmpty else { return }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .month, value: 2, to: start)!

        // Read device calendar events
        let ekCalendars = store.calendars(for: .event).filter { selectedIds.contains($0.calendarIdentifier) }
        guard !ekCalendars.isEmpty else { return }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: ekCalendars)
        let ekEvents = store.events(matching: predicate)

        // Convert to CalendarEvent structs
        var calendarEvents: [CalendarEvent] = []
        for event in ekEvents {
            guard !event.isAllDay, event.status != .canceled else { continue }
            var dayStart = calendar.startOfDay(for: event.startDate)
            let eventEnd = event.endDate!
            while dayStart < eventEnd {
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                let clipStart = max(event.startDate, dayStart)
                let clipEnd = min(eventEnd, dayEnd)
                let startComps = calendar.dateComponents([.hour, .minute], from: clipStart)
                let endComps = calendar.dateComponents([.hour, .minute], from: clipEnd)
                let startMin = startComps.hour! * 60 + startComps.minute!
                var endMin = endComps.hour! * 60 + endComps.minute!
                if endMin == 0 && clipEnd == dayEnd { endMin = 1440 }
                if startMin < endMin {
                    calendarEvents.append(CalendarEvent(
                        date: TimeHelpers.dateString(from: dayStart),
                        startMinutes: startMin,
                        endMinutes: endMin,
                        title: event.title ?? "",
                        color: event.calendar.cgColor
                    ))
                }
                dayStart = dayEnd
            }
        }

        let startStr = TimeHelpers.dateString(from: start)
        let endStr = TimeHelpers.dateString(from: end)

        // Sync each membership
        for member in memberships {
            let dayEvents = calendarEvents
            // Invert events to free slots
            var allSlots: [[String: AnyJSON]] = []
            var current = start
            while current < end {
                let dateStr = TimeHelpers.dateString(from: current)
                let busy = dayEvents
                    .filter { $0.date == dateStr }
                    .map { (max($0.startMinutes, member.practiceWindowStart), min($0.endMinutes, member.practiceWindowEnd)) }
                    .filter { $0.0 < $0.1 }
                    .sorted { $0.0 < $1.0 }

                var merged: [(Int, Int)] = []
                for interval in busy {
                    if let last = merged.last, interval.0 <= last.1 {
                        merged[merged.count - 1] = (last.0, max(last.1, interval.1))
                    } else {
                        merged.append(interval)
                    }
                }

                var cursor = member.practiceWindowStart
                for b in merged {
                    if cursor < b.0 {
                        allSlots.append([
                            "member_id": .string(member.id.uuidString),
                            "band_id": .string(member.bandId.uuidString),
                            "date": .string(dateStr),
                            "start_minutes": .integer(cursor),
                            "end_minutes": .integer(b.0),
                            "confirmed": .bool(true),
                        ])
                    }
                    cursor = b.1
                }
                if cursor < member.practiceWindowEnd {
                    allSlots.append([
                        "member_id": .string(member.id.uuidString),
                        "band_id": .string(member.bandId.uuidString),
                        "date": .string(dateStr),
                        "start_minutes": .integer(cursor),
                        "end_minutes": .integer(member.practiceWindowEnd),
                        "confirmed": .bool(true),
                    ])
                }

                current = calendar.date(byAdding: .day, value: 1, to: current)!
            }

            // Delete old slots for this member in date range
            try await Config.supabase
                .from("availability_slots")
                .delete()
                .eq("member_id", value: member.id.uuidString)
                .eq("band_id", value: member.bandId.uuidString)
                .gte("date", value: startStr)
                .lte("date", value: endStr)
                .execute()

            // Insert new slots
            if !allSlots.isEmpty {
                try await Config.supabase
                    .from("availability_slots")
                    .insert(allSlots)
                    .execute()
            }
        }

        // Update last sync timestamp
        let newPrefs = CalendarPrefs(
            selectedCalendarIds: prefs.selectedCalendarIds,
            lastSyncDate: Date(),
            calendarName: prefs.calendarName,
            autoSync: prefs.autoSync
        )
        if let encoded = try? JSONEncoder().encode(newPrefs) {
            UserDefaults.standard.set(encoded, forKey: prefsKey)
        }
    }
}
