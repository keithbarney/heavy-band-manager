import SwiftUI

struct DayDetailSheet: View {
    @EnvironmentObject var bandManager: BandManager
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss

    let date: String

    @State private var showScheduleAlert = false
    @State private var selectedWindow: OverlapWindow?
    @State private var showRemoveAlert = false
    @State private var practiceToEdit: ScheduledPractice?
    @State private var showLocationWarning = false
    @State private var locationWarning: String?
    @State private var practiceToRemove: ScheduledPractice?
    @State private var isMutatingPractice = false
    @State private var mutationError: PracticeMutationAlert?
    @State private var retryAction: PracticeRetryAction?
    @EnvironmentObject var toastManager: ToastManager

    private var dayPractices: [ScheduledPractice] {
        bandManager.practices.filter { $0.date == date }
    }

    private var daySlots: [AvailabilitySlot] {
        bandManager.slots.filter { $0.date == date }
    }

    private var dayWindows: [OverlapWindow] {
        let total = bandManager.members.count
        let threshold = min(max(bandManager.currentBand?.minMembersRequired ?? 2, 1), max(total, 1))
        let minDur = bandManager.currentBand?.minPracticeMinutes ?? 60
        let maxDur = bandManager.currentBand?.maxPracticeMinutes ?? 240
        return OverlapEngine.enumerateOptions(
            slots: daySlots,
            totalMembers: total,
            minMembers: threshold,
            minDuration: minDur,
            maxDuration: maxDur
        ).filter { window in
            !dayPractices.contains {
                $0.startMinutes == window.startMinutes && $0.endMinutes == window.endMinutes
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Scheduled practices
                if !dayPractices.isEmpty {
                    Section {
                        ForEach(dayPractices) { practice in
                            practiceRow(practice)
                        }
                    } header: {
                        Text("Scheduled")
                    }
                }

                // Member availability
                Section {
                    ForEach(bandManager.members) { member in
                        memberRow(member)
                    }
                } header: {
                    Text("Availability")
                }

                // Best windows
                if !dayWindows.isEmpty {
                    Section {
                        ForEach(dayWindows) { window in
                            windowRow(window)
                        }
                    } header: {
                        Text("Best Windows")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(TimeHelpers.fullDisplayDate(date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .sheet(item: $practiceToEdit, onDismiss: { showLocationWarning = locationWarning != nil }) { practice in
            PracticeLocationEditor(title: "Practice Location", location: practice.location,
                explanation: "Changes only this practice. Your band's default location stays the same.") { location in
                let warning = try await bandManager.setPracticeLocation(practice, location: location, calendarManager: calendarManager)
                if let warning { locationWarning = warning }
                else { toastManager.show("Practice location saved", type: .success) }
            }
        }
        .alert("Location saved", isPresented: $showLocationWarning) {
            Button("OK") { locationWarning = nil }
        } message: { Text(locationWarning ?? "") }
        .alert("Schedule Practice", isPresented: $showScheduleAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Schedule") {
                if let w = selectedWindow {
                    retryAction = .schedule(w)
                    performPracticeMutation()
                }
            }
        } message: {
            if let w = selectedWindow {
                Text("\(TimeHelpers.formatTime(w.startMinutes)) – \(TimeHelpers.formatTime(w.endMinutes)) (\(TimeHelpers.formatDuration(w.duration)))")
            }
        }
        .alert("Remove Practice", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let practice = practiceToRemove {
                    retryAction = .remove(practice)
                    performPracticeMutation()
                }
            }
        } message: {
            Text("This will remove the scheduled practice and delete the calendar event.")
        }
        .alert(item: $mutationError) { alert in
            if alert.allowsRetry {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Try Again"), action: performPracticeMutation),
                    secondaryButton: .cancel()
                )
            } else {
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func performPracticeMutation() {
        guard !isMutatingPractice, let retryAction else { return }
        isMutatingPractice = true
        Task {
            defer { isMutatingPractice = false }
            do {
                switch retryAction {
                case .schedule(let window):
                    try await bandManager.schedulePractice(
                        date: date,
                        startMinutes: window.startMinutes,
                        endMinutes: window.endMinutes,
                        location: bandManager.currentBand?.defaultPracticeLocation,
                        calendarManager: calendarManager
                    )
                    toastManager.show("Practice scheduled", type: .success)
                case .remove(let practice):
                    try await bandManager.cancelPractice(practice.id, calendarManager: calendarManager)
                    toastManager.show("Practice removed", type: .success)
                }
                self.retryAction = nil
                dismiss()
            } catch PracticeMutationError.duplicate {
                _ = await bandManager.loadPractices()
                self.retryAction = nil
                mutationError = PracticeMutationAlert(
                    title: "Practice already scheduled",
                    message: "The schedule was refreshed to show the existing practice.",
                    allowsRetry: false
                )
            } catch {
                let title: String
                switch retryAction {
                case .schedule: title = "Couldn't schedule practice"
                case .remove: title = "Couldn't remove practice"
                }
                mutationError = PracticeMutationAlert(
                    title: title,
                    message: "\(error.localizedDescription) Refresh the schedule before retrying if the result is unclear."
                )
            }
        }
    }

    // MARK: - Member Row

    private func memberRow(_ member: BandMember) -> some View {
        let memberSlots = daySlots.filter { $0.memberId == member.id }

        return HStack(spacing: 12) {
            MemberAvatar(member: member, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.body)

                if !member.availabilitySetupComplete {
                    Text("Availability not set")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if memberSlots.isEmpty {
                    Text("Not available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text(memberSlots.map { "\(TimeHelpers.formatTime($0.startMinutes)) – \(TimeHelpers.formatTime($0.endMinutes))" }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !memberSlots.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary.opacity(0.4))
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Practice Row

    private func practiceRow(_ practice: ScheduledPractice) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.green)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(TimeHelpers.formatTime(practice.startMinutes)) – \(TimeHelpers.formatTime(practice.endMinutes))")
                    .font(.headline)
                if let loc = practice.location, !loc.isEmpty {
                    Text(loc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if bandManager.isLeader {
                Menu {
                    Button("Edit Location", systemImage: "mappin.and.ellipse") { practiceToEdit = practice }
                        .accessibilityIdentifier("edit-practice-location")
                    Button("Remove", role: .destructive) {
                        practiceToRemove = practice
                        showRemoveAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3)
                }
                .accessibilityLabel("Practice options")

            }
        }
    }

    // MARK: - Window Row

    private func windowRow(_ window: OverlapWindow) -> some View {
        let freeMembers = bandManager.members.filter { window.freeMembers.contains($0.id) }
        let isFullAttendance = window.freeMembers.count >= window.totalMembers
        let accent: Color = isFullAttendance ? .themeSuccess : .themeWarning

        return Button {
            guard bandManager.isLeader else { return }
            selectedWindow = window
            showScheduleAlert = true
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 4, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(TimeHelpers.formatTime(window.startMinutes)) – \(TimeHelpers.formatTime(window.endMinutes))")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(TimeHelpers.formatDuration(window.duration)) · \(window.freeMembers.count) of \(window.totalMembers)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: -6) {
                    ForEach(freeMembers) { member in
                        MemberAvatar(member: member, size: 22)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color(.systemBackground), lineWidth: 1.5)
                            )
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practice-window-\(window.startMinutes)-\(window.endMinutes)")
        .disabled(!bandManager.isLeader || isMutatingPractice)
    }
}

private struct PracticeMutationAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var allowsRetry = true
}

private enum PracticeRetryAction {
    case schedule(OverlapWindow)
    case remove(ScheduledPractice)
}
