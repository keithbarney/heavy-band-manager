import EventKit

/// Shared reconciliation logic preserves event identity, calendar, alarms, and user notes.
struct PracticeCalendarFields: Equatable {
    let title: String?
    let location: String?
    let start: Date?
    let end: Date?

    init(title: String?, location: String?, start: Date?, end: Date?) {
        self.title = title
        self.location = location.flatMap { $0.isEmpty ? nil : $0 }
        self.start = start
        self.end = end
    }

    init(event: EKEvent) {
        self.init(title: event.title, location: event.location, start: event.startDate, end: event.endDate)
    }

    func apply(to event: EKEvent) {
        event.title = title
        event.location = location
        event.startDate = start
        event.endDate = end
    }
}
