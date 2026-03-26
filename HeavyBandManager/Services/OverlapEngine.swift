import Foundation

enum OverlapEngine {
    struct Event {
        let time: Int
        let type: Int // +1 = start, -1 = end
        let memberId: UUID
    }

    static func compute(slots: [AvailabilitySlot], totalMembers: Int, minMembers: Int) -> [OverlapWindow] {
        guard minMembers > 0, !slots.isEmpty else { return [] }

        // Group slots by date
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
            var overlapStart = -1

            for event in events {
                if event.type == 1 {
                    activeMembers.insert(event.memberId)
                    if activeMembers.count >= minMembers && overlapStart == -1 {
                        overlapStart = event.time
                    }
                } else {
                    if activeMembers.count >= minMembers && overlapStart != -1 {
                        let duration = event.time - overlapStart
                        if duration > 0 {
                            windows.append(OverlapWindow(
                                date: date,
                                startMinutes: overlapStart,
                                endMinutes: event.time,
                                duration: duration,
                                freeMembers: Array(activeMembers),
                                totalMembers: totalMembers
                            ))
                        }
                        overlapStart = -1
                    }
                    activeMembers.remove(event.memberId)
                    if activeMembers.count >= minMembers {
                        overlapStart = event.time
                    }
                }
            }
        }

        // Sort by date, then duration descending
        return windows.sorted { a, b in
            if a.date != b.date { return a.date < b.date }
            return a.duration > b.duration
        }
    }

    /// Returns overlap quality per date for month grid dots
    static func overlapMap(slots: [AvailabilitySlot], totalMembers: Int) -> [String: OverlapQuality] {
        guard totalMembers > 0 else { return [:] }

        // Group by date, find unique members per date
        var membersByDate: [String: Set<UUID>] = [:]
        for slot in slots {
            membersByDate[slot.date, default: []].insert(slot.memberId)
        }

        var result: [String: OverlapQuality] = [:]
        let halfThreshold = max(1, totalMembers / 2)

        for (date, members) in membersByDate {
            // Check if actual overlap exists (not just individual availability)
            let dateSlots = slots.filter { $0.date == date }
            let windows = compute(slots: dateSlots, totalMembers: totalMembers, minMembers: 2)

            if windows.isEmpty {
                result[date] = .none
            } else {
                let maxMembers = windows.map(\.freeMembers.count).max() ?? 0
                if maxMembers >= totalMembers {
                    result[date] = .full
                } else if maxMembers >= halfThreshold {
                    result[date] = .partial
                } else {
                    result[date] = .none
                }
            }
        }

        return result
    }
}
