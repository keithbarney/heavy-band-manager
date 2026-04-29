import SwiftUI
import UIKit
import EventKit

@MainActor
final class CalendarManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var authStatus: EKAuthorizationStatus = .notDetermined
    @Published var deviceCalendars: [DeviceCalendar] = []
    @Published var selectedCalendarIds: Set<String> = []
    @Published var lastSyncDate: Date?
    @Published var practiceCalendarName = "Band Practice"
    @Published var autoSync = true

    private let store = EKEventStore()
    private let prefsKey = "heavy-band-manager:calendar-prefs"

    struct DeviceCalendar: Identifiable {
        let id: String
        let title: String
        let color: CGColor
        let source: String
    }

    // MARK: - Initialize

    func initialize() {
        loadPrefs()
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authStatus = status
        isAuthorized = status == .fullAccess || status == .authorized
        if isAuthorized {
            loadDeviceCalendars()
        }
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            isAuthorized = granted
            authStatus = EKEventStore.authorizationStatus(for: .event)
            if granted {
                loadDeviceCalendars()
            }
        } catch {
            print("Calendar access error: \(error)")
            authStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }

    // MARK: - Device Calendars

    func loadDeviceCalendars() {
        let calendars = store.calendars(for: .event)
        deviceCalendars = calendars
            .filter { $0.allowsContentModifications || $0.type == .calDAV || $0.type == .local }
            .map { cal in
                DeviceCalendar(
                    id: cal.calendarIdentifier,
                    title: cal.title,
                    color: cal.cgColor,
                    source: cal.source.title
                )
            }
            .sorted { $0.title < $1.title }

        if selectedCalendarIds.isEmpty {
            selectedCalendarIds = Set(deviceCalendars.map(\.id))
            savePrefs()
        }
    }

    func toggleCalendar(_ id: String) {
        if selectedCalendarIds.contains(id) {
            selectedCalendarIds.remove(id)
        } else {
            selectedCalendarIds.insert(id)
        }
        savePrefs()
    }

    // MARK: - Read Events for Date Range

    func getEvents(from startDate: Date, to endDate: Date) -> [CalendarEvent] {
        let ekCalendars = store.calendars(for: .event).filter { selectedCalendarIds.contains($0.calendarIdentifier) }
        guard !ekCalendars.isEmpty else { return [] }

        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: ekCalendars)
        let events = store.events(matching: predicate)
        let calendar = Calendar.current

        var calendarEvents: [CalendarEvent] = []

        for event in events {
            guard !event.isAllDay else { continue }
            if event.status == .canceled { continue }

            // Handle multi-day events by clipping to each day
            var dayStart = calendar.startOfDay(for: event.startDate)
            let eventEnd = event.endDate!

            while dayStart < eventEnd {
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                let clipStart = max(event.startDate, dayStart)
                let clipEnd = min(eventEnd, dayEnd)

                let startComps = calendar.dateComponents([.hour, .minute], from: clipStart)
                let endComps = calendar.dateComponents([.hour, .minute], from: clipEnd)

                let startMinutes = startComps.hour! * 60 + startComps.minute!
                var endMinutes = endComps.hour! * 60 + endComps.minute!
                if endMinutes == 0 && clipEnd == dayEnd { endMinutes = 1440 }

                if startMinutes < endMinutes {
                    calendarEvents.append(CalendarEvent(
                        date: TimeHelpers.dateString(from: dayStart),
                        startMinutes: startMinutes,
                        endMinutes: endMinutes,
                        title: event.title ?? "",
                        color: event.calendar.cgColor
                    ))
                }

                dayStart = dayEnd
            }
        }

        return calendarEvents
    }

    // MARK: - Invert Events to Free Slots

    func invertEventsToSlots(
        events: [CalendarEvent],
        from startDate: Date,
        to endDate: Date,
        windowStart: Int,
        windowEnd: Int,
        memberId: UUID
    ) -> [NewSlot] {
        let calendar = Calendar.current
        var allSlots: [NewSlot] = []
        var current = calendar.startOfDay(for: startDate)

        while current < endDate {
            let dateStr = TimeHelpers.dateString(from: current)

            let dayEvents = events
                .filter { $0.date == dateStr }
                .map { (max($0.startMinutes, windowStart), min($0.endMinutes, windowEnd)) }
                .filter { $0.0 < $0.1 }
                .sorted { $0.0 < $1.0 }

            // Merge overlapping busy intervals
            var merged: [(Int, Int)] = []
            for interval in dayEvents {
                if let last = merged.last, interval.0 <= last.1 {
                    merged[merged.count - 1] = (last.0, max(last.1, interval.1))
                } else {
                    merged.append(interval)
                }
            }

            // Walk gaps to find free time
            var cursor = windowStart
            for busy in merged {
                if cursor < busy.0 {
                    allSlots.append(NewSlot(date: dateStr, startMinutes: cursor, endMinutes: busy.0, memberId: memberId))
                }
                cursor = busy.1
            }
            if cursor < windowEnd {
                allSlots.append(NewSlot(date: dateStr, startMinutes: cursor, endMinutes: windowEnd, memberId: memberId))
            }

            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return allSlots
    }

    // MARK: - Write Practice Events

    func getOrCreateBandCalendar(bandName: String? = nil) throws -> EKCalendar {
        let calendarName = bandName.map { "\($0) Practice" } ?? practiceCalendarName

        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarName }) {
            return existing
        }

        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = calendarName
        calendar.cgColor = UIColor.systemBlue.cgColor

        if let icloud = store.sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
            calendar.source = icloud
        } else if let local = store.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = local
        } else {
            calendar.source = store.defaultCalendarForNewEvents?.source
        }

        try store.saveCalendar(calendar, commit: true)
        return calendar
    }

    /// Creates an Apple Calendar event for a scheduled practice.
    /// Returns the EKEvent identifier string for storage in Supabase.
    func createPracticeEvent(date: Date, startMinutes: Int, endMinutes: Int, bandName: String, location: String?) async throws -> String {
        if !isAuthorized {
            await requestAccess()
        }
        guard isAuthorized else {
            throw CalendarError.accessDenied
        }

        let calendar = try getOrCreateBandCalendar(bandName: bandName)

        let event = EKEvent(eventStore: store)
        event.title = "\(bandName) Practice"
        event.calendar = calendar
        event.location = location

        let cal = Calendar.current
        var startComps = cal.dateComponents([.year, .month, .day], from: date)
        startComps.hour = startMinutes / 60
        startComps.minute = startMinutes % 60
        guard let startDate = cal.date(from: startComps) else {
            throw CalendarError.invalidDate
        }
        event.startDate = startDate

        var endComps = startComps
        endComps.hour = endMinutes / 60
        endComps.minute = endMinutes % 60
        guard let endDate = cal.date(from: endComps) else {
            throw CalendarError.invalidDate
        }
        event.endDate = endDate

        // 30-minute reminder before the event
        event.addAlarm(EKAlarm(relativeOffset: -30 * 60))

        try store.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    /// Deletes an Apple Calendar event by its identifier.
    func deletePracticeEvent(eventIdentifier: String) async throws {
        guard let event = store.event(withIdentifier: eventIdentifier) else { return }
        try store.remove(event, span: .thisEvent)
    }


    // MARK: - Persistence

    private func loadPrefs() {
        guard let data = UserDefaults.standard.data(forKey: prefsKey),
              let prefs = try? JSONDecoder().decode(CalendarPrefs.self, from: data) else { return }
        selectedCalendarIds = Set(prefs.selectedCalendarIds)
        lastSyncDate = prefs.lastSyncDate
        practiceCalendarName = prefs.calendarName ?? "Band Practice"
        autoSync = prefs.autoSync ?? true
    }

    func savePrefs() {
        let prefs = CalendarPrefs(
            selectedCalendarIds: Array(selectedCalendarIds),
            lastSyncDate: lastSyncDate,
            calendarName: practiceCalendarName,
            autoSync: autoSync
        )
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: prefsKey)
        }
    }
}

// MARK: - Supporting Types

struct CalendarEvent {
    let date: String
    let startMinutes: Int
    let endMinutes: Int
    let title: String
    let color: CGColor
}

struct NewSlot {
    let date: String
    let startMinutes: Int
    let endMinutes: Int
    let memberId: UUID
}

struct CalendarPrefs: Codable {
    let selectedCalendarIds: [String]
    let lastSyncDate: Date?
    let calendarName: String?
    let autoSync: Bool?
}

enum CalendarError: LocalizedError {
    case accessDenied
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Calendar access denied"
        case .invalidDate: return "Invalid practice date"
        }
    }
}
