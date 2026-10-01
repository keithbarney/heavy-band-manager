import AppIntents
import SwiftUI
import WidgetKit

struct PracticeEntry: TimelineEntry {
    let date: Date
    let band: PracticeWidgetBand?
    let message: String?
    var allBands: [PracticeWidgetBand]? = nil
}

struct PracticeProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PracticeEntry { sample }
    func snapshot(for configuration: SelectPracticeBand, in context: Context) async -> PracticeEntry {
        if context.isPreview {
            var preview = sample
            if !configuration.showsAllBands { preview.allBands = nil }
            return preview
        }
        return entry(configuration, at: Date())
    }
    func timeline(for configuration: SelectPracticeBand, in context: Context) async -> Timeline<PracticeEntry> {
        let now = Date()
        let first = entry(configuration, at: now)
        let bands = first.allBands ?? first.band.map { [$0] } ?? []
        let dates = Set([now] + bands.flatMap { $0.timelineDates(after: now) }).sorted()
        let entries = dates.map { PracticeEntry(date: $0, band: first.band, message: first.message, allBands: first.allBands) }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(60 * 60)))
    }
    private func entry(_ configuration: SelectPracticeBand, at date: Date) -> PracticeEntry {
        guard let snapshot = PracticeWidgetStore().read() else {
            return PracticeEntry(date: date, band: nil, message: "Open Band Practice to load practices.")
        }
        guard snapshot.accountID != nil else {
            return PracticeEntry(date: date, band: nil, message: "Open Band Practice to sign in.")
        }
        // A removed configured band must never silently fall back to another band.
        if configuration.showsAllBands {
            return PracticeEntry(date: date, band: nil,
                message: snapshot.bands.isEmpty ? "Join a band to see upcoming practices." : nil,
                allBands: snapshot.orderedBands(at: date))
        }
        guard let band = configuration.selectedBand(in: snapshot) else {
            return PracticeEntry(date: date, band: nil, message: "Choose a band in Edit Widget.")
        }
        guard band.updatedAt != nil else {
            return PracticeEntry(date: date, band: band, message: "Open Band Practice to load practices.")
        }
        return PracticeEntry(date: date, band: band, message: nil)
    }
    private var sample: PracticeEntry {
        let now = Date()
        let bandID = UUID()
        let practices = (1...6).map { offset in
            PracticeSummary(id: UUID(), bandId: bandID,
                date: PracticeDate.string(Calendar.current.date(byAdding: .day, value: offset * 3, to: now)!),
                startMinutes: 1140, endMinutes: 1260, location: "Riverside Rehearsal Rooms")
        }
        let first = PracticeWidgetBand(id: bandID, name: "The Night Shift", practices: practices, updatedAt: now)
        let secondID = UUID()
        let second = PracticeWidgetBand(id: secondID, name: "Sunday Static", practices: (1...3).map { offset in
            PracticeSummary(id: UUID(), bandId: secondID,
                date: PracticeDate.string(Calendar.current.date(byAdding: .day, value: offset * 4, to: now)!),
                startMinutes: 1080, endMinutes: 1200, location: "Eastside Studio")
        }, updatedAt: now)
        return PracticeEntry(date: now, band: first, message: nil, allBands: [first, second])
    }
}

struct UpcomingPracticesView: View {
    let entry: PracticeEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.dynamicTypeSize) private var typeSize
    private var practices: [PracticeSummary] { entry.band?.upcoming(at: entry.date) ?? [] }
    private var isStale: Bool { entry.band?.needsRefresh(at: entry.date) == true }
    private var capacity: Int {
        if family == .systemSmall { return 1 }
        if family == .systemMedium { return typeSize.isAccessibilitySize || isStale ? 2 : 3 }
        return typeSize.isAccessibilitySize ? 3 : (isStale ? 5 : 6)
    }
    private var openURL: URL {
        if let practice = practices.first {
            return PracticeRoute(bandID: practice.bandId, practiceID: practice.id).url
        }
        return URL(string: "\(PracticeRoute.scheme)://calendar")!
    }

    var body: some View {
        if let bands = entry.allBands {
            AllBandsWidgetView(bands: bands, date: entry.date, message: entry.message)
        } else {
            singleBandBody
        }
    }

    private var singleBandBody: some View {
        VStack(alignment: .leading, spacing: family == .systemMedium ? 4 : (family == .systemSmall ? 6 : 8)) {
            HStack(spacing: 5) {
                Image(systemName: "calendar").widgetAccentable()
                Text(entry.band?.name ?? "Band Practice").lineLimit(1)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            if let message = entry.message {
                Text(message).font(.subheadline)
                Spacer(minLength: 0)
            } else if practices.isEmpty {
                Text(entry.band?.needsRefresh(at: entry.date) == true ? "Open app to refresh practices" : "No upcoming practices")
                    .font(.headline)
                Spacer(minLength: 0)
            } else if family == .systemSmall, let practice = practices.first {
                smallPractice(practice)
                Spacer(minLength: 0)
            } else {
                ForEach(Array(practices.prefix(capacity).enumerated()), id: \.element.id) { index, practice in
                    Link(destination: PracticeRoute(bandID: practice.bandId, practiceID: practice.id).url) {
                        agendaRow(practice, emphasized: family == .systemLarge && index == 0)
                    }
                    if family == .systemLarge && index < min(practices.count, capacity) - 1 { Divider() }
                }
                Spacer(minLength: 0)
            }
            if let band = entry.band, band.needsRefresh(at: entry.date), let updated = band.updatedAt {
                Text("Updated \(updated, style: .relative) ago · Open to refresh")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
        .widgetURL(openURL)
    }

    private func smallPractice(_ practice: PracticeSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let start = practice.start() {
                Text(start, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.headline).lineLimit(2).widgetAccentable()
                if start <= entry.date { Text("Now").font(.caption.bold()) }
            }
            timeLabel(practice).font(.subheadline.weight(.semibold))
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1).minimumScaleFactor(0.8)
            if let location = practice.location, !location.isEmpty {
                Text(location).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(isStale || typeSize.isAccessibilitySize ? 1 : 2)
            }
        }
    }

    private func agendaRow(_ practice: PracticeSummary, emphasized: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let start = practice.start() {
                VStack(spacing: 0) {
                    Text(start, format: .dateTime.month(.abbreviated)).font(.caption2)
                    Text(start, format: .dateTime.day()).font(emphasized ? .title2.bold() : .headline)
                }
                .frame(width: 34).widgetAccentable()
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if let start = practice.start(), start <= entry.date { Text("Now").font(.caption.bold()) }
                    timeLabel(practice).font(emphasized ? .headline : (family == .systemMedium ? .caption.weight(.semibold) : .subheadline.weight(.medium)))
                }
                .lineLimit(1).minimumScaleFactor(0.8)
                if let location = practice.location, !location.isEmpty {
                    Text(location).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary)
    }

    private func timeLabel(_ practice: PracticeSummary) -> some View {
        Group {
            if let start = practice.start(), let end = practice.end() {
                Text("\(start, format: .dateTime.hour().minute())–\(end, format: .dateTime.hour().minute())")
            }
        }
    }
}

@main
struct UpcomingPracticesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: PracticeWidgetStore.kind, intent: SelectPracticeBand.self, provider: PracticeProvider()) { entry in
            UpcomingPracticesView(entry: entry)
        }
        .configurationDisplayName("Upcoming Practices")
        .description("Upcoming practices for all your bands, or one band you choose.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
