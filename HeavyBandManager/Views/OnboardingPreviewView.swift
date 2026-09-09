#if DEBUG && targetEnvironment(simulator) && ONBOARDING_PREVIEW
import SwiftUI

/// Enabled only for the separately identified simulator onboarding build.
struct OnboardingPreviewView: View {
    @EnvironmentObject private var bandManager: BandManager
    @AppStorage("onboardingAvailabilityPending") private var availabilityPending = false
    @State private var runID = UUID()
    @State private var preview = "onboarding"
    @StateObject private var settingsCalendar = CalendarManager()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Preview", selection: $preview) {
                    Text("Onboarding").tag("onboarding")
                    Text("Settings: Manual").tag("manual")
                    Text("Settings: Automatic").tag("automatic")
                }
                .pickerStyle(.menu)
                .fixedSize(horizontal: true, vertical: false)
                Spacer()
                Button("Restart") { restart() }
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.regularMaterial)

            if preview == "onboarding" {
                BandGate()
                    .id(runID)
            } else {
                SettingsView(startsAtAvailability: true)
                    .environmentObject(settingsCalendar)
            }
        }
        .onAppear { restart() }
        .onChange(of: preview) { _, selection in
            guard selection != "onboarding" else { return }
            if bandManager.currentBand == nil {
                bandManager.configureOnboardingPreview(name: "Test Band", userName: "Test Member", instrument: "Drums")
            }
            bandManager.updateOnboardingPreviewAvailability(selection == "manual" ? .weekly : .calendar, complete: true)
            if let member = bandManager.currentMember, bandManager.weeklyRules.isEmpty {
                bandManager.weeklyRules = [1, 4].map {
                    WeeklyAvailabilityRule(id: UUID(), memberId: member.id, bandId: member.bandId,
                                           dayOfWeek: $0, startMinutes: 1140, endMinutes: 1320)
                }
            }
            // A connected-calendar fixture for comparing both layouts without requesting access.
            settingsCalendar.isAuthorized = true
            settingsCalendar.authStatus = .fullAccess
            settingsCalendar.deviceCalendars = ["Personal", "Work", "Band Practice"].map {
                CalendarManager.DeviceCalendar(id: $0, title: $0, color: UIColor.systemBlue.cgColor, source: "Preview")
            }
            settingsCalendar.selectedCalendarIds = ["Personal", "Work"]
            availabilityPending = false
        }
    }

    private func restart() {
        preview = "onboarding"
        availabilityPending = false
        bandManager.currentBand = nil
        bandManager.bands = []
        bandManager.weeklyRules = []
        bandManager.slots = []
        bandManager.practices = []
        bandManager.error = nil
        bandManager.isLoading = false
        runID = UUID()
    }
}

extension BandManager {
    static let onboardingPreviewUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    func configureOnboardingPreview(name: String, userName: String, instrument: String?, location: String? = nil) {
        let bandId = currentBand?.id ?? UUID()
        let member = BandMember(
            id: currentMember?.id ?? UUID(), bandId: bandId, userId: Self.onboardingPreviewUserId,
            name: userName, instrument: instrument, color: "#0A84FF",
            practiceWindowStart: 960, practiceWindowEnd: 1380, avatarUrl: nil,
            availabilityMode: .weekly, availabilitySetupComplete: false, joinedAt: Date()
        )
        let band = BandWithMembers(
            id: bandId, name: name, creatorId: Self.onboardingPreviewUserId,
            leaderId: Self.onboardingPreviewUserId, defaultPracticeLocation: location,
            inviteCode: "TEST123", logoUrl: nil, createdAt: Date(),
            minPracticeMinutes: 60, maxPracticeMinutes: 240, minMembersRequired: 1,
            bandMembers: [member]
        )
        currentBand = band
        bands = [band]
        isLoading = false
    }

    func updateOnboardingPreviewAvailability(_ mode: AvailabilityMode, complete: Bool) {
        guard let band = currentBand, let member = currentMember else { return }
        let updatedMember = BandMember(
            id: member.id, bandId: member.bandId, userId: member.userId,
            name: member.name, instrument: member.instrument, color: member.color,
            practiceWindowStart: member.practiceWindowStart, practiceWindowEnd: member.practiceWindowEnd,
            avatarUrl: member.avatarUrl, availabilityMode: mode,
            availabilitySetupComplete: complete, joinedAt: member.joinedAt
        )
        let updatedBand = BandWithMembers(
            id: band.id, name: band.name, creatorId: band.creatorId, leaderId: band.leaderId,
            defaultPracticeLocation: band.defaultPracticeLocation, inviteCode: band.inviteCode,
            logoUrl: band.logoUrl, createdAt: band.createdAt,
            minPracticeMinutes: band.minPracticeMinutes, maxPracticeMinutes: band.maxPracticeMinutes,
            minMembersRequired: band.minMembersRequired, bandMembers: [updatedMember]
        )
        currentBand = updatedBand
        bands = [updatedBand]
    }

    func projectOnboardingPreviewSlots() {
        guard let member = currentMember else { return }
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .month, value: 6, to: day)!
        slots = []
        while day < end {
            for rule in weeklyRules where rule.dayOfWeek == calendar.component(.weekday, from: day) - 1 {
                slots.append(AvailabilitySlot(
                    id: UUID(), memberId: member.id, bandId: member.bandId,
                    date: TimeHelpers.dateString(from: day), startMinutes: rule.startMinutes,
                    endMinutes: rule.endMinutes, confirmed: true
                ))
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
    }
}
#endif
