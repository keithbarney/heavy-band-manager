import Foundation

enum OverlapEngine {
    struct Event {
        let time: Int
        let type: Int // +1 = start, -1 = end
        let memberId: UUID
    }

    /// Phase-based sweep. Emits one window per contiguous range where the active member set
    /// is stable, filtered to ranges with at least `minMembers` active. Each window's
    /// `freeMembers` is exactly the set present for that entire window.
    static func compute(slots: [AvailabilitySlot], totalMembers: Int, minMembers: Int) -> [OverlapWindow] {
        guard minMembers > 0, !slots.isEmpty else { return [] }

        var slotsByDate: [String: [AvailabilitySlot]] = [:]
        for slot in slots {
            slotsByDate[slot.date, default: []].append(slot)
        }

        var windows: [OverlapWindow] = []

        for (date, dateSlots) in slotsByDate {
            var events: [Event] = []
            for slot in dateSlots {
                events.append(Event(time: slot.startMinutes, type: 1, memberId: slot.memberId))
                events.append(Event(time: slot.endMinutes, type: -1, memberId: slot.memberId))
            }
            events.sort { a, b in
                if a.time != b.time { return a.time < b.time }
                return a.type > b.type
            }

            var activeMembers = Set<UUID>()
            var phaseStart = events.first?.time ?? 0

            for event in events {
                if event.time > phaseStart && activeMembers.count >= minMembers {
                    windows.append(OverlapWindow(
                        date: date,
                        startMinutes: phaseStart,
                        endMinutes: event.time,
                        duration: event.time - phaseStart,
                        freeMembers: Array(activeMembers),
                        totalMembers: totalMembers
                    ))
                }
                if event.type == 1 {
                    activeMembers.insert(event.memberId)
                } else {
                    activeMembers.remove(event.memberId)
                }
                phaseStart = event.time
            }
        }

        return windows.sorted { a, b in
            if a.freeMembers.count != b.freeMembers.count { return a.freeMembers.count > b.freeMembers.count }
            if a.duration != b.duration { return a.duration > b.duration }
            return a.date < b.date
        }
    }

    /// Enumerates every viable practice-slot option. Walks start times in `startStep` increments
    /// and durations from `minDuration` to `maxDuration` in `durationStep` increments. A member
    /// counts as "available" for slot [s, s+d] only when one of their availability slots fully
    /// covers that range — so `freeMembers` is accurate for the entire displayed window even
    /// when the slot spans multiple internal phases.
    static func enumerateOptions(
        slots: [AvailabilitySlot],
        totalMembers: Int,
        minMembers: Int,
        minDuration: Int,
        maxDuration: Int,
        durationStep: Int = 30,
        startStep: Int = 30
    ) -> [OverlapWindow] {
        guard minMembers > 0, minDuration > 0, maxDuration >= minDuration, !slots.isEmpty else { return [] }

        var slotsByDateMember: [String: [UUID: [(Int, Int)]]] = [:]
        for slot in slots {
            slotsByDateMember[slot.date, default: [:]][slot.memberId, default: []].append((slot.startMinutes, slot.endMinutes))
        }

        var result: [OverlapWindow] = []
        for (date, memberSlots) in slotsByDateMember {
            for d in stride(from: minDuration, through: maxDuration, by: durationStep) {
                let maxStart = 1440 - d
                guard maxStart >= 0 else { continue }
                for s in stride(from: 0, through: maxStart, by: startStep) {
                    let end = s + d
                    var available: [UUID] = []
                    for (memberId, ranges) in memberSlots {
                        if ranges.contains(where: { $0.0 <= s && $0.1 >= end }) {
                            available.append(memberId)
                        }
                    }
                    if available.count >= minMembers {
                        result.append(OverlapWindow(
                            date: date,
                            startMinutes: s,
                            endMinutes: end,
                            duration: d,
                            freeMembers: available,
                            totalMembers: totalMembers
                        ))
                    }
                }
            }
        }

        return result.sorted { a, b in
            if a.date != b.date { return a.date < b.date }
            if a.freeMembers.count != b.freeMembers.count { return a.freeMembers.count > b.freeMembers.count }
            if a.duration != b.duration { return a.duration > b.duration }
            return a.startMinutes < b.startMinutes
        }
    }

    /// Returns overlap quality per date for month grid dots.
    /// `.full` if some enumerated option has every member; `.partial` if some has at least
    /// `minMembers` (but not all); otherwise `.none`.
    static func overlapMap(slots: [AvailabilitySlot], totalMembers: Int, minMembers: Int, minDuration: Int, maxDuration: Int) -> [String: OverlapQuality] {
        guard totalMembers > 0 else { return [:] }

        let options = enumerateOptions(
            slots: slots,
            totalMembers: totalMembers,
            minMembers: minMembers,
            minDuration: minDuration,
            maxDuration: maxDuration
        )

        var result: [String: OverlapQuality] = [:]
        for option in options {
            if option.freeMembers.count >= totalMembers {
                result[option.date] = .full
            } else if result[option.date] != .full {
                result[option.date] = .partial
            }
        }
        return result
    }
}
