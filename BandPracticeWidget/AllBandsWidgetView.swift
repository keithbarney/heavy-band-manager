import SwiftUI
import WidgetKit

struct AllBandsWidgetView: View {
    let bands: [PracticeWidgetBand]
    let date: Date
    let message: String?
    @Environment(\.widgetFamily) private var family
    @Environment(\.dynamicTypeSize) private var typeSize

    private var groups: [PracticeAgendaGroup] {
        let maximumBands = family == .systemSmall ? 1 : (family == .systemMedium ? 2 : 3)
        let accessibleLimit = family == .systemMedium ? 1 : 2
        let bandLimit = typeSize.isAccessibilitySize ? min(maximumBands, accessibleLimit) : maximumBands
        let rows = typeSize.isAccessibilitySize ? 1 : (family == .systemLarge && bands.count <= 2 ? 3 : 2)
        return PracticeAgendaGroup.groups(bands: bands, at: date, maxBands: bandLimit, perBand: rows)
    }
    private var stale: Bool { bands.contains { $0.needsRefresh(at: date) } }
    private var allBandsLabel: String { bands.count == 1 ? "View all practices" : "View all \(bands.count) bands" }
    private var nextPractice: PracticeSummary? { groups.first?.practices.first }
    private var openURL: URL {
        if family == .systemSmall, let practice = nextPractice {
            return PracticeRoute(bandID: practice.bandId, practiceID: practice.id).url
        }
        return PracticeRoute.allBandsURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemMedium ? 4 : 8) {
            Label(family == .systemSmall ? "Next · All bands" : "All bands", systemImage: "calendar")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
            if let message {
                Text(message).font(.subheadline)
            } else if family == .systemSmall {
                if let group = groups.first {
                    Text(group.band.name).font(.caption.bold()).lineLimit(1).widgetAccentable()
                    if let practice = group.practices.first {
                        if let start = practice.start() {
                            Text(start, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                .font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        time(practice).font(.subheadline.weight(.semibold))
                            .lineLimit(typeSize.isAccessibilitySize ? 2 : 1).minimumScaleFactor(0.8)
                        if let location = practice.location, !location.isEmpty {
                            Text(location).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    } else { emptyState(group.band) }
                }
            } else if family == .systemMedium {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(groups) { group in
                        bandSection(group)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            } else {
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    if index > 0 { Divider() }
                    bandSection(group)
                }
            }
            Spacer(minLength: 0)
            if family != .systemSmall {
                Link(destination: PracticeRoute.allBandsURL) {
                    Text(stale ? "Refresh · \(allBandsLabel)" : allBandsLabel)
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            } else if stale {
                Text("Open to refresh").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
        .widgetURL(openURL)
    }

    private func bandSection(_ group: PracticeAgendaGroup) -> some View {
        VStack(alignment: .leading, spacing: family == .systemMedium ? 4 : 6) {
            Text(group.band.name).font(.caption.bold()).lineLimit(1).widgetAccentable()
            if group.practices.isEmpty { emptyState(group.band) }
            ForEach(group.practices) { practice in
                Link(destination: PracticeRoute(bandID: group.band.id, practiceID: practice.id).url) {
                    if family == .systemMedium {
                        VStack(alignment: .leading, spacing: 1) {
                            dateLabel(practice).font(.caption2.weight(.semibold))
                            time(practice).font(.caption2)
                            location(practice)
                        }
                        .lineLimit(1).minimumScaleFactor(0.8)
                    } else {
                        HStack(alignment: .top, spacing: 10) {
                            dateLabel(practice).font(.caption.weight(.semibold))
                                .frame(width: typeSize.isAccessibilitySize ? 90 : 66, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                time(practice).font(.caption.weight(.semibold))
                                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                                location(practice)
                            }
                            Spacer(minLength: 0)
                        }
                        .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private func emptyState(_ band: PracticeWidgetBand) -> some View {
        Text(band.updatedAt == nil ? "Open to load practices" : "No upcoming practices")
            .font(.caption2).foregroundStyle(.secondary)
    }

    private func dateLabel(_ practice: PracticeSummary) -> some View {
        Group {
            if let start = practice.start() {
                Text(start, format: .dateTime.month(.abbreviated).day())
            }
        }
    }

    private func time(_ practice: PracticeSummary) -> some View {
        Group {
            if let start = practice.start(), let end = practice.end() {
                Text("\(start, format: .dateTime.hour().minute())–\(end, format: .dateTime.hour().minute())")
            }
        }
    }

    private func location(_ practice: PracticeSummary) -> some View {
        Group {
            if let location = practice.location, !location.isEmpty {
                Text(location).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
