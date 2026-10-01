import Foundation
import Supabase

/// Independent of selected band, navigation, and automatic/manual availability.
@MainActor
enum PracticeCalendarSync {
    static let calendar = CalendarManager()
    private static var inFlight: Task<Bool, Never>?
    private static var refreshAgain = false
    private static var initialized = false
    private static var lastRefresh: Date?
    private static var lastAccount: UUID?

    static func refresh(force: Bool = true) async -> Bool {
#if DEBUG && targetEnvironment(simulator) && (ONBOARDING_PREVIEW || AVAILABILITY_TAB_PREVIEW)
        return false
#else
        guard !SCREENSHOT_MODE else { return false }
        let account = Config.supabase.auth.currentUser?.id
        if !force, let account, account == lastAccount,
           let lastRefresh, Date().timeIntervalSince(lastRefresh) < 10 * 60 { return true }
        if let inFlight {
            refreshAgain = true
            return await withTaskCancellationHandler {
                await inFlight.value
            } onCancel: { inFlight.cancel() }
        }
        let task = Task {
            var success = true
            repeat {
                refreshAgain = false
                success = await performRefresh() && success
            } while refreshAgain && !Task.isCancelled
            return success
        }
        inFlight = task
        let result = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        inFlight = nil
        if result, let account, Config.supabase.auth.currentUser?.id == account {
            lastAccount = account
            lastRefresh = Date()
        }
        UserDefaults.standard.set(result ? "" : "Practice calendar updates could not refresh. Your existing events are kept; the app will retry.",
                                  forKey: "practiceCalendarSync.error")
        return result
#endif
    }

    private static func performRefresh() async -> Bool {
        do {
            // A cold background launch must restore/refresh auth before fetching.
            let account = try await Config.supabase.auth.session.user.id
            let memberships: [BandMember] = try await Config.supabase.from("band_members")
                .select().eq("user_id", value: account.uuidString).execute().value
            try Task.checkCancellation()
            if !initialized {
                calendar.initialize()
                initialized = true
            } else { calendar.checkAuthorization() }
            guard calendar.isAuthorized else { return true } // Never request access in background.
            var allSucceeded = true
            for membership in memberships {
                do {
                    let band: Band = try await Config.supabase.from("bands").select()
                        .eq("id", value: membership.bandId.uuidString).single().execute().value
                    var practices: [ScheduledPractice] = []
                    var offset = 0
                    while true {
                        try Task.checkCancellation()
                        let page: [ScheduledPractice] = try await Config.supabase.from("scheduled_practices")
                            .select().eq("band_id", value: band.id.uuidString).order("id")
                            .range(from: offset, to: offset + 499).execute().value
                        practices.append(contentsOf: page)
                        if page.count < 500 { break }
                        offset += 500
                    }
                    // Recheck account and membership after network suspension, before any EventKit writes.
                    guard Config.supabase.auth.currentUser?.id == account else { return false }
                    let stillMember: [BandMember] = try await Config.supabase.from("band_members")
                        .select().eq("band_id", value: band.id.uuidString)
                        .eq("user_id", value: account.uuidString).execute().value
                    guard !stillMember.isEmpty, Config.supabase.auth.currentUser?.id == account else { continue }
                    for practice in practices {
                        try Task.checkCancellation()
                        guard Config.supabase.auth.currentUser?.id == account else { return false }
                        guard let date = TimeHelpers.date(from: practice.date) else { throw CalendarError.invalidDate }
                        _ = try await calendar.createPracticeEvent(practiceId: practice.id, bandId: band.id,
                            legacyEventIdentifier: practice.calendarEventId, date: date,
                            startMinutes: practice.startMinutes, endMinutes: practice.endMinutes,
                            bandName: band.name, location: practice.location)
                    }
                    try Task.checkCancellation()
                    guard Config.supabase.auth.currentUser?.id == account else { return false }
                    try await calendar.reconcilePracticeEvents(for: band.id, activePracticeIds: Set(practices.map(\.id)))
                } catch {
                    allSucceeded = false
                    if Task.isCancelled { return false }
                }
            }
            return allSucceeded
        } catch {
            // Keep events and retry through the next push, background refresh, or foreground.
            return false
        }
    }
}
