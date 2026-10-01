#if DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW
import SwiftUI

/// Opt-in, in-memory review of the current design with a separate availability tab.
enum AvailabilityTabScenario: String, CaseIterable, Identifiable {
    case typical = "Calendar overview"
    case automatic = "Automatic availability"
    case manual = "Manual availability"
    case settings = "Settings"
    case band = "Band"
    case bandMember = "Band member"
    case empty = "No matching times"
    case setup = "Setup needed"
    case failure = "Save failure"
    case longNames = "Long names"
    var id: String { rawValue }
    var initialTab: Int {
        switch self {
        case .settings: return 3
        case .band, .bandMember: return 2
        case .automatic, .manual, .failure: return 1
        default: return 0
        }
    }
}

@MainActor
final class AvailabilityTabReviewStore {
    let band = BandManager()
    let calendar = CalendarManager()

    init(_ scenario: AvailabilityTabScenario) {
        band.loadAvailabilityTabPreview(scenario: scenario.rawValue)
        if scenario == .automatic || scenario == .settings {
            band.updateOnboardingPreviewAvailability(.calendar, complete: true)
        } else if scenario == .setup {
            band.updateOnboardingPreviewAvailability(.weekly, complete: false)
            band.weeklyRules = []
        }
        calendar.checkAuthorization()
    }
}

@MainActor
final class AvailabilityTabReviewSession: ObservableObject {
    private var stores: [AvailabilityTabScenario: AvailabilityTabReviewStore] = [:]
    func store(_ scenario: AvailabilityTabScenario) -> AvailabilityTabReviewStore {
        if let store = stores[scenario] { return store }
        let store = AvailabilityTabReviewStore(scenario)
        stores[scenario] = store
        return store
    }
    func reset(_ scenario: AvailabilityTabScenario) { stores.removeValue(forKey: scenario) }
}

struct AvailabilityTabPreviewView: View {
    @StateObject private var session = AvailabilityTabReviewSession()
    @EnvironmentObject private var toastManager: ToastManager
    @State private var scenario: AvailabilityTabScenario = Self.initialScreenshotScenario
    @State private var revision = 0
    private var screenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
    }

    private static var initialScreenshotScenario: AvailabilityTabScenario {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--screenshot-screen=") }) else {
            return .typical
        }

        switch argument.split(separator: "=", maxSplits: 1).last {
        case "automatic": return .automatic
        case "manual": return .manual
        case "band": return .band
        case "settings": return .settings
        default: return .typical
        }
    }

    var body: some View {
        let store = session.store(scenario)
        let content = AvailabilityTabReviewContent(scenario: scenario, band: store.band, calendar: store.calendar)
            .environmentObject(store.band).environmentObject(store.calendar)
            .id("\(scenario.rawValue)-\(revision)")

        Group {
            if screenshotMode {
                content
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Label("Mock data", systemImage: "testtube.2").font(.caption)
                        Button("Reset scenario", systemImage: "arrow.counterclockwise") {
                            session.reset(scenario)
                            toastManager.message = nil
                            revision += 1
                        }
                        .labelStyle(.iconOnly)
                        Spacer()
                        Picker("Review scenario", selection: $scenario) {
                            ForEach(AvailabilityTabScenario.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .accessibilityIdentifier("mock-review-scenario")
                        .pickerStyle(.menu).font(.subheadline)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .dynamicTypeSize(.large)
                    .padding(.horizontal).padding(.vertical, 8)
                    .background(.regularMaterial)
                    content
                }
            }
        }
        .onChange(of: scenario) { _, value in
            toastManager.message = nil
            session.store(value).band.error = nil
        }
    }
}

private struct AvailabilityTabReviewContent: View {
    let scenario: AvailabilityTabScenario
    @ObservedObject var band: BandManager
    @ObservedObject var calendar: CalendarManager
    @State private var showAvailabilitySheet = false

    var body: some View {
        VStack(spacing: 0) {
            if scenario == .failure {
                Toggle("Simulate failed save", isOn: $band.previewSaveFails)
                    .padding(.horizontal).dynamicTypeSize(.large)
                Button("Review availability in sheet") { showAvailabilitySheet = true }
            }
            BandTabs(initialTab: scenario.initialTab)
        }
        .sheet(isPresented: $showAvailabilitySheet) {
            NavigationStack { MyAvailabilityView() }
        }
        .confirmationDialog("Calendar access (mock)", isPresented: $calendar.previewPermissionPrompt, titleVisibility: .visible) {
            Button("Allow full access") { calendar.setPreviewAuthorization(.fullAccess) }
            Button("Don’t allow", role: .destructive) { calendar.setPreviewAuthorization(.denied) }
        }
    }
}
extension BandManager {
    func loadAvailabilityTabPreview(scenario: String = "Typical band") {
        let now = Date()
        let minorThreat = ProcessInfo.processInfo.arguments.contains("--screenshot-band=minor-threat")
        let widgetReview = WidgetReviewMode.isEnabled
        let marketingStory = ProcessInfo.processInfo.arguments.contains("--screenshot-story")
        let bandID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let names = scenario == "Long names" ? ["Alexandra Montgomery-Williams", "Christopher Rivera-Sanchez", "Sam", "Jamie"] : minorThreat ? ["Ian MacKaye", "Lyle Preslar", "Brian Baker", "Jeff Nelson"] : ["Alex", "Riley", "Sam", "Jamie"]
        let members = names.enumerated().map { index, name in
            BandMember(id: UUID(), bandId: bandID, userId: index == 0 ? Self.onboardingPreviewUserId : UUID(), name: name,
                       instrument: ["Vocals", "Guitar", "Bass", "Drums"][index], color: "#007AFF",
                       practiceWindowStart: 1080, practiceWindowEnd: 1320, avatarUrl: minorThreat ? "mock-artwork://" + ["ian", "lyle", "brian", "jeff"][index] : nil,
                       availabilityMode: .weekly, availabilitySetupComplete: !(scenario == "Setup needed" && index > 1), joinedAt: now)
        }
        let band = BandWithMembers(id: bandID, name: scenario == "Long names" ? "The Extraordinary Midnight Rehearsal Collective" : minorThreat ? "Minor Threat" : "The Night Shift",
            creatorId: Self.onboardingPreviewUserId, leaderId: scenario == "Band member" ? members[1].userId : Self.onboardingPreviewUserId,
            defaultPracticeLocation: "Studio 4, Riverside Rehearsal Rooms", inviteCode: minorThreat ? "THREAT" : "NIGHT24", logoUrl: minorThreat ? "mock-artwork://logo" : nil, createdAt: now,
            minPracticeMinutes: 60, maxPracticeMinutes: 120, minMembersRequired: 3, bandMembers: members)
        bands = [band]
        currentBand = band
        error = nil
        isLoading = false
        previewSaveFails = scenario == "Save failure"
        func day(_ offset: Int) -> String { TimeHelpers.dateString(from: Calendar.current.date(byAdding: .day, value: offset, to: now)!) }
        slots = []
        if scenario != "No matching times" {
            let fullDays = [2, 4, 7, 8, 11, 15, 17, 19, 22, 25, 29, 32]
            let partialDays = [1, 3, 5, 9, 12, 14, 16, 18, 21, 24, 27, 30, 34]
            let offsets = marketingStory ? (fullDays + partialDays).sorted() : [1, 2, 4, 5, 7, 9, 12]
            for offset in offsets {
                let missingMember = marketingStory ? (partialDays.contains(offset) ? offset % 4 : -1) : (offset == 1 ? 3 : -1)
                for (index, member) in members.enumerated() where member.availabilitySetupComplete && index != missingMember {
                    let hours = marketingStory ? [(1140, 1320), (1080, 1260), (1140, 1290), (1110, 1320)][index] : (1140, 1320)
                    slots.append(AvailabilitySlot(id: UUID(), memberId: member.id, bandId: bandID, date: day(offset), startMinutes: hours.0, endMinutes: hours.1, confirmed: true))
                }
            }
        }
        let practiceOffsets = scenario == "Setup needed" || scenario == "No matching times" ? [] : marketingStory ? [8, 11, 15, 17] : widgetReview ? [1, 3, 5, 8, 11, 15] : [4]
        practices = practiceOffsets.map { offset in
            ScheduledPractice(id: UUID(uuidString: String(format: "20000000-0000-0000-0000-%012d", offset))!, bandId: bandID, date: day(offset), startMinutes: 1140, endMinutes: 1260,
                location: band.defaultPracticeLocation, scheduledBy: Self.onboardingPreviewUserId, scheduledAt: now, calendarEventId: nil)
        }
        if widgetReview {
            let saved = PracticeWidgetStore().read()?.bands.first { $0.id == bandID }
            if let saved, scenario != "No matching times", scenario != "Setup needed",
               !ProcessInfo.processInfo.arguments.contains("--reset-widget-review") {
                practices = saved.practices.map {
                    ScheduledPractice(id: $0.id, bandId: $0.bandId, date: $0.date, startMinutes: $0.startMinutes,
                        endMinutes: $0.endMinutes, location: $0.location, scheduledBy: Self.onboardingPreviewUserId,
                        scheduledAt: now, calendarEventId: nil)
                }
            }
            let secondID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
            let secondMembers = members.map { member in
                BandMember(id: UUID(), bandId: secondID, userId: member.userId, name: member.name,
                    instrument: member.instrument, color: member.color, practiceWindowStart: member.practiceWindowStart,
                    practiceWindowEnd: member.practiceWindowEnd, avatarUrl: member.avatarUrl,
                    availabilityMode: member.availabilityMode, availabilitySetupComplete: member.availabilitySetupComplete,
                    availabilityRevision: member.availabilityRevision,
                    joinedAt: member.joinedAt)
            }
            let second = BandWithMembers(id: secondID, name: "Sunday Static", creatorId: band.creatorId,
                leaderId: band.leaderId, defaultPracticeLocation: "Eastside Studio", inviteCode: "MOCK02",
                logoUrl: nil, createdAt: now, minPracticeMinutes: 60, maxPracticeMinutes: 120,
                minMembersRequired: 3, bandMembers: secondMembers)
            bands.append(second)
            let secondPractices = [2, 6, 10].enumerated().map { index, offset in
                ScheduledPractice(id: UUID(uuidString: String(format: "30000000-0000-0000-0000-%012d", index + 1))!,
                    bandId: secondID, date: day(offset), startMinutes: 1080, endMinutes: 1200,
                    location: "Eastside Studio", scheduledBy: band.creatorId, scheduledAt: now, calendarEventId: nil)
            }
            PracticeWidgetSync.shared.publish(band: second, practices: secondPractices, account: Self.onboardingPreviewUserId)
            PracticeWidgetSync.shared.publish(band: band, practices: practices, account: Self.onboardingPreviewUserId)
        }
        weeklyRules = [1, 4].map { WeeklyAvailabilityRule(id: UUID(), memberId: members[0].id, bandId: bandID, dayOfWeek: $0, startMinutes: 1140, endMinutes: 1320) }
    }

    func updateReviewBand(name: String? = nil, logoURL: String? = nil, minimum: Int? = nil, maximum: Int? = nil, requiredMembers: Int? = nil) {
        guard let band = currentBand else { return }
        let updated = BandWithMembers(
            id: band.id, name: name ?? band.name, creatorId: band.creatorId, leaderId: band.leaderId,
            defaultPracticeLocation: band.defaultPracticeLocation, inviteCode: band.inviteCode,
            logoUrl: logoURL ?? band.logoUrl, createdAt: band.createdAt,
            minPracticeMinutes: minimum ?? band.minPracticeMinutes,
            maxPracticeMinutes: maximum ?? band.maxPracticeMinutes,
            minMembersRequired: requiredMembers ?? band.minMembersRequired, bandMembers: band.bandMembers
        )
        currentBand = updated
        bands = bands.map { $0.id == band.id ? updated : $0 }
    }

    func updateReviewMember(_ memberID: UUID, name: String? = nil, instrument: String? = nil, avatarURL: String? = nil) {
        guard let band = currentBand,
              let member = band.bandMembers.first(where: { $0.id == memberID }) else { return }
        let updatedMember = BandMember(
            id: member.id, bandId: member.bandId, userId: member.userId,
            name: name ?? member.name, instrument: instrument ?? member.instrument,
            color: member.color, practiceWindowStart: member.practiceWindowStart,
            practiceWindowEnd: member.practiceWindowEnd, avatarUrl: avatarURL ?? member.avatarUrl,
            availabilityMode: member.availabilityMode,
            availabilitySetupComplete: member.availabilitySetupComplete,
            availabilityRevision: member.availabilityRevision, joinedAt: member.joinedAt
        )
        let updatedBand = BandWithMembers(
            id: band.id, name: band.name, creatorId: band.creatorId, leaderId: band.leaderId,
            defaultPracticeLocation: band.defaultPracticeLocation, inviteCode: band.inviteCode,
            logoUrl: band.logoUrl, createdAt: band.createdAt,
            minPracticeMinutes: band.minPracticeMinutes, maxPracticeMinutes: band.maxPracticeMinutes,
            minMembersRequired: band.minMembersRequired,
            bandMembers: band.bandMembers.map { $0.id == memberID ? updatedMember : $0 }
        )
        currentBand = updatedBand
        bands = bands.map { $0.id == band.id ? updatedBand : $0 }
    }

}
#endif
