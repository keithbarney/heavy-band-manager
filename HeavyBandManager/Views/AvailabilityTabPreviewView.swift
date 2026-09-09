#if DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW
import SwiftUI

/// Opt-in, in-memory review of the current design with a separate availability tab.
enum AvailabilityTabScenario: String, CaseIterable, Identifiable {
    case typical = "Calendar overview"
    case automatic = "Automatic availability"
    case empty = "No matching times"
    case setup = "Setup needed"
    case failure = "Save failure"
    case longNames = "Long names"
    var id: String { rawValue }
    var initialTab: Int { self == .automatic || self == .failure ? 1 : 0 }
}

@MainActor
final class AvailabilityTabReviewStore {
    let band = BandManager()
    let calendar = CalendarManager()

    init(_ scenario: AvailabilityTabScenario) {
        band.loadAvailabilityTabPreview(scenario: scenario.rawValue)
        if scenario == .automatic {
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
    @State private var scenario: AvailabilityTabScenario = .typical
    @State private var revision = 0

    var body: some View {
        let store = session.store(scenario)
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
                .pickerStyle(.menu).font(.subheadline)
                .fixedSize(horizontal: true, vertical: false)
            }
            .dynamicTypeSize(.large)
            .padding(.horizontal).padding(.vertical, 8)
            .background(.regularMaterial)
            AvailabilityTabReviewContent(scenario: scenario, band: store.band, calendar: store.calendar)
                .environmentObject(store.band).environmentObject(store.calendar)
                .id("\(scenario.rawValue)-\(revision)")
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

    var body: some View {
        VStack(spacing: 0) {
            if scenario == .failure {
                Toggle("Simulate failed save", isOn: $band.previewSaveFails)
                    .padding(.horizontal).dynamicTypeSize(.large)
            }
            BandTabs(initialTab: scenario.initialTab)
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
        let bandID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let names = scenario == "Long names" ? ["Alexandra Montgomery-Williams", "Christopher Rivera-Sanchez", "Sam", "Jamie"] : ["Alex", "Riley", "Sam", "Jamie"]
        let members = names.enumerated().map { index, name in
            BandMember(id: UUID(), bandId: bandID, userId: index == 0 ? Self.onboardingPreviewUserId : UUID(), name: name,
                       instrument: ["Vocals", "Guitar", "Bass", "Drums"][index], color: "#007AFF",
                       practiceWindowStart: 1080, practiceWindowEnd: 1320, avatarUrl: nil,
                       availabilityMode: .weekly, availabilitySetupComplete: !(scenario == "Setup needed" && index > 1), joinedAt: now)
        }
        let band = BandWithMembers(id: bandID, name: scenario == "Long names" ? "The Extraordinary Midnight Rehearsal Collective" : "The Night Shift",
            creatorId: Self.onboardingPreviewUserId, leaderId: Self.onboardingPreviewUserId,
            defaultPracticeLocation: "Studio 4, Riverside Rehearsal Rooms", inviteCode: "MOCK-ONLY", logoUrl: nil, createdAt: now,
            minPracticeMinutes: 60, maxPracticeMinutes: 120, minMembersRequired: 3, bandMembers: members)
        bands = [band]
        currentBand = band
        error = nil
        isLoading = false
        previewSaveFails = scenario == "Save failure"
        func day(_ offset: Int) -> String { TimeHelpers.dateString(from: Calendar.current.date(byAdding: .day, value: offset, to: now)!) }
        slots = []
        if scenario != "No matching times" {
            for offset in [1, 2, 4, 5, 7, 9, 12] {
                for (index, member) in members.enumerated() where member.availabilitySetupComplete && !(offset == 1 && index == 3) {
                    slots.append(AvailabilitySlot(id: UUID(), memberId: member.id, bandId: bandID, date: day(offset), startMinutes: 1140, endMinutes: 1320, confirmed: true))
                }
            }
        }
        practices = scenario == "Setup needed" || scenario == "No matching times" ? [] : [
            ScheduledPractice(id: UUID(), bandId: bandID, date: day(4), startMinutes: 1140, endMinutes: 1260,
                location: band.defaultPracticeLocation, scheduledBy: Self.onboardingPreviewUserId, scheduledAt: now, calendarEventId: nil)
        ]
        weeklyRules = [1, 4].map { WeeklyAvailabilityRule(id: UUID(), memberId: members[0].id, bandId: bandID, dayOfWeek: $0, startMinutes: 1140, endMinutes: 1320) }
    }
}
#endif
