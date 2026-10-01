import Foundation
import Supabase
import WidgetKit

@MainActor
final class PracticeWidgetSync {
    static let shared = PracticeWidgetSync()
    private let store = PracticeWidgetStore()
    private var generation = UUID()
    private var accountID: UUID?
    private var hasSetAccount = false
    private var lastRefresh: Date?

    func setAccount(_ id: UUID?) {
        guard !hasSetAccount || id != accountID else { return }
        hasSetAccount = true
        accountID = id
        generation = UUID()
        lastRefresh = nil
        if store.read()?.accountID != id || id == nil {
            save(PracticeWidgetSnapshot(accountID: id))
        }
    }

    private func save(_ snapshot: PracticeWidgetSnapshot) {
        do {
            try store.write(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: PracticeWidgetStore.kind)
        } catch {
            print("Widget snapshot unavailable: \(error.localizedDescription)")
        }
    }

    /// Only call with a complete band load, never the calendar's visible range.
    func publish(band: BandWithMembers, practices: [ScheduledPractice], account: UUID) {
        setAccount(account)
        generation = UUID()
        var snapshot = store.read() ?? PracticeWidgetSnapshot(accountID: account)
        let value = PracticeWidgetBand(id: band.id, name: band.name,
            practices: practices.map(\.widgetSummary), updatedAt: Date())
        snapshot.bands.removeAll { $0.id == band.id }
        snapshot.bands.append(value)
        snapshot.preferredBandID = band.id
        save(snapshot)
    }

    func apply(_ practice: ScheduledPractice?, removing practiceID: UUID? = nil, bandID: UUID, account: UUID) {
        guard accountID == account, var snapshot = store.read(), snapshot.accountID == account,
              let index = snapshot.bands.firstIndex(where: { $0.id == bandID }) else { return }
        generation = UUID()
        snapshot.bands[index].practices.removeAll { $0.id == (practice?.id ?? practiceID) }
        if let practice { snapshot.bands[index].practices.append(practice.widgetSummary) }
        // A single mutation does not establish freshness of the rest of the band.
        save(snapshot)
    }

    func retainBands(_ bands: [BandWithMembers], account: UUID) {
        setAccount(account)
        generation = UUID()
        var snapshot = store.read() ?? PracticeWidgetSnapshot(accountID: account)
        let ids = Set(bands.map(\.id))
        snapshot.bands.removeAll { !ids.contains($0.id) }
        for band in bands {
            if let index = snapshot.bands.firstIndex(where: { $0.id == band.id }) {
                snapshot.bands[index].name = band.name
            } else {
                snapshot.bands.append(PracticeWidgetBand(id: band.id, name: band.name, practices: [], updatedAt: nil))
            }
        }
        save(snapshot)
    }

    func refresh(force: Bool = false) async {
#if DEBUG && targetEnvironment(simulator) && (ONBOARDING_PREVIEW || AVAILABILITY_TAB_PREVIEW)
        return
#else
        guard !SCREENSHOT_MODE else { return }
        let user = Config.supabase.auth.currentUser?.id
        setAccount(user)
        guard let user else { return }
        if !force, let lastRefresh, Date().timeIntervalSince(lastRefresh) < 60 { return }
        let request = UUID()
        generation = request
        do {
            let memberships: [BandMember] = try await Config.supabase.from("band_members")
                .select().eq("user_id", value: user.uuidString).execute().value
            let ids = memberships.map { $0.bandId.uuidString }
            let bands: [Band]
            if ids.isEmpty { bands = [] } else {
                bands = try await Config.supabase.from("bands").select().in("id", values: ids).execute().value
            }
            guard generation == request, Config.supabase.auth.currentUser?.id == user else { return }
            var snapshot = store.read() ?? PracticeWidgetSnapshot(accountID: user)
            snapshot.bands.removeAll { cached in !bands.contains { $0.id == cached.id } }
            // Commit membership removal even if a subsequent practice request fails.
            save(snapshot)
            for band in bands {
                var practices: [ScheduledPractice] = []
                var offset = 0
                while true {
                    try Task.checkCancellation()
                    let page: [ScheduledPractice] = try await Config.supabase.from("scheduled_practices")
                        .select().eq("band_id", value: band.id.uuidString)
                        .gte("date", value: PracticeDate.string(Date()))
                        .order("date").order("start_minutes").order("id")
                        .range(from: offset, to: offset + 499).execute().value
                    practices += page
                    if page.count < 500 { break }
                    offset += page.count
                }
                guard generation == request, Config.supabase.auth.currentUser?.id == user else { return }
                snapshot.bands.removeAll { $0.id == band.id }
                snapshot.bands.append(PracticeWidgetBand(id: band.id, name: band.name,
                    practices: practices.map(\.widgetSummary), updatedAt: Date()))
                save(snapshot)
            }
            lastRefresh = Date()
        } catch {
            // Preserve the last good schedule and its original freshness timestamp.
            print("Widget refresh deferred: \(error.localizedDescription)")
        }
#endif
    }
}

extension ScheduledPractice {
    var widgetSummary: PracticeSummary {
        PracticeSummary(id: id, bandId: bandId, date: date, startMinutes: startMinutes,
                        endMinutes: endMinutes, location: location)
    }
}

/// Persist only the explicit review opt-in so a cold widget launch restores the same fixtures.
/// Store captures and all non-review builds ignore this setting.
enum WidgetReviewMode {
    static var isEnabled: Bool {
#if DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--screenshot-mode") { return false }
        if arguments.contains("--disable-widget-review") {
            UserDefaults.standard.set(false, forKey: "widgetReviewEnabled")
            return false
        }
        if arguments.contains("--widget-review") {
            UserDefaults.standard.set(true, forKey: "widgetReviewEnabled")
        }
        return UserDefaults.standard.bool(forKey: "widgetReviewEnabled")
#else
        return false
#endif
    }
}
