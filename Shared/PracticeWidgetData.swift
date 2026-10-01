import Foundation

/// Shared display data only. Authentication and calendar data stay in the app.
struct PracticeSummary: Codable, Identifiable, Equatable {
    let id: UUID
    let bandId: UUID
    let date: String
    let startMinutes: Int
    let endMinutes: Int
    let location: String?

    func start(in calendar: Calendar = .current) -> Date? {
        PracticeDate.date(date, minutes: startMinutes, calendar: calendar)
    }

    func end(in calendar: Calendar = .current) -> Date? {
        PracticeDate.date(date, minutes: endMinutes, calendar: calendar)
    }
}

enum PracticeDate {
    static func date(_ value: String, minutes: Int, calendar: Calendar = .current) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (0...1440).contains(minutes) else { return nil }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let day = gregorian.date(from: components),
              gregorian.dateComponents([.year, .month, .day], from: day) == components else { return nil }
        if minutes == 1440 { return gregorian.date(byAdding: .day, value: 1, to: day) }
        return gregorian.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)
    }

    static func string(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct PracticeWidgetBand: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var practices: [PracticeSummary]
    var updatedAt: Date?

    func upcoming(at date: Date, calendar: Calendar = .current) -> [PracticeSummary] {
        practices.filter { practice in
            guard let start = practice.start(in: calendar), let end = practice.end(in: calendar) else { return false }
            return end > date && end > start
        }.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.startMinutes != $1.startMinutes { return $0.startMinutes < $1.startMinutes }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func needsRefresh(at date: Date) -> Bool {
        guard let updatedAt else { return true }
        return date.timeIntervalSince(updatedAt) >= 24 * 60 * 60
    }

    func timelineDates(after now: Date, calendar: Calendar = .current) -> [Date] {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let limit = calendar.date(byAdding: .day, value: 7, to: now)!
        var dates = [now, tomorrow]
        for practice in upcoming(at: now, calendar: calendar).prefix(60) {
            dates += [practice.start(in: calendar), practice.end(in: calendar)].compactMap { $0 }.filter { $0 > now && $0 <= limit }
        }
        if let updatedAt {
            let staleDate = updatedAt.addingTimeInterval(24 * 60 * 60)
            if staleDate > now && staleDate <= limit { dates.append(staleDate) }
        }
        return Array(Set(dates)).sorted()
    }
}

struct PracticeWidgetSnapshot: Codable, Equatable {
    var version = 1
    var accountID: UUID?
    var preferredBandID: UUID?
    var bands: [PracticeWidgetBand] = []

    /// Bands with the soonest practice come first; empty/unloaded bands remain visible.
    func orderedBands(at date: Date, calendar: Calendar = .current) -> [PracticeWidgetBand] {
        bands.sorted {
            let lhs = $0.upcoming(at: date, calendar: calendar).first?.start(in: calendar) ?? .distantFuture
            let rhs = $1.upcoming(at: date, calendar: calendar).first?.start(in: calendar) ?? .distantFuture
            if lhs != rhs { return lhs < rhs }
            if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}

/// Keep a fair share of the limited widget space for every displayed band.
struct PracticeAgendaGroup: Identifiable {
    let band: PracticeWidgetBand
    let practices: [PracticeSummary]
    var id: UUID { band.id }

    static func groups(bands: [PracticeWidgetBand], at date: Date, maxBands: Int, perBand: Int,
                       calendar: Calendar = .current) -> [PracticeAgendaGroup] {
        let ordered = PracticeWidgetSnapshot(bands: bands).orderedBands(at: date, calendar: calendar)
        return ordered.prefix(max(0, maxBands)).map {
            PracticeAgendaGroup(band: $0, practices: Array($0.upcoming(at: date, calendar: calendar).prefix(max(0, perBand))))
        }
    }
}

struct PracticeWidgetStore {
    static let kind = "UpcomingPractices"
    let fileURL: URL?

    init(fileURL: URL? = nil) {
        if let fileURL { self.fileURL = fileURL; return }
        guard let group = Bundle.main.object(forInfoDictionaryKey: "WidgetAppGroup") as? String,
              let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            self.fileURL = nil
            return
        }
#if DEBUG && targetEnvironment(simulator) && (ONBOARDING_PREVIEW || AVAILABILITY_TAB_PREVIEW)
        self.fileURL = directory.appendingPathComponent("practices-mock.json")
#else
        self.fileURL = directory.appendingPathComponent("practices.json")
#endif
    }

    func read() -> PracticeWidgetSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(PracticeWidgetSnapshot.self, from: data),
              snapshot.version == 1 else { return nil }
        return snapshot
    }

    func write(_ snapshot: PracticeWidgetSnapshot) throws {
        guard let fileURL else { throw CocoaError(.fileNoSuchFile) }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

struct PracticeRoute: Equatable {
    let bandID: UUID
    let practiceID: UUID
    static var allBandsURL: URL { URL(string: "\(scheme)://practices")! }

    static var scheme: String {
#if DEBUG
        "bandpractice-local"
#else
        "bandpractice"
#endif
    }

    var url: URL {
        URL(string: "\(Self.scheme)://practice/\(bandID.uuidString)/\(practiceID.uuidString)")!
    }

    init(bandID: UUID, practiceID: UUID) {
        self.bandID = bandID
        self.practiceID = practiceID
    }

    init?(url: URL) {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard url.scheme == Self.scheme, url.host == "practice", parts.count == 2,
              let band = UUID(uuidString: parts[0]), let practice = UUID(uuidString: parts[1]) else { return nil }
        self.init(bandID: band, practiceID: practice)
    }
}
