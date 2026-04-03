import SwiftUI

struct DayDetailSheet: View {
    @EnvironmentObject var bandManager: BandManager
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss

    let date: String

    @State private var showScheduleAlert = false
    @State private var selectedWindow: OverlapWindow?
    @State private var showRemoveAlert = false
    @State private var practiceToRemove: ScheduledPractice?
    @EnvironmentObject var toastManager: ToastManager

    private var dayPractices: [ScheduledPractice] {
        bandManager.practices.filter { $0.date == date }
    }

    private var daySlots: [AvailabilitySlot] {
        bandManager.slots.filter { $0.date == date }
    }

    private var dayWindows: [OverlapWindow] {
        OverlapEngine.compute(
            slots: daySlots,
            totalMembers: bandManager.members.count,
            minMembers: 2
        )
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
        .alert("Schedule Practice", isPresented: $showScheduleAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Schedule") {
                if let w = selectedWindow {
                    Task {
                        await bandManager.schedulePractice(
                            date: date,
                            startMinutes: w.startMinutes,
                            endMinutes: w.endMinutes,
                            location: bandManager.currentBand?.defaultPracticeLocation,
                            calendarManager: calendarManager
                        )
                        toastManager.show("Practice scheduled", type: .success)
                        dismiss()
                    }
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
                    Task {
                        await bandManager.cancelPractice(practice.id, calendarManager: calendarManager)
                        toastManager.show("Practice removed")
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This will remove the scheduled practice and delete the calendar event.")
        }
    }

    // MARK: - Member Row

    private func memberRow(_ member: BandMember) -> some View {
        let memberSlots = daySlots.filter { $0.memberId == member.id }

        return HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: member.color))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(member.name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.body)

                if memberSlots.isEmpty {
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
                Button {
                    practiceToRemove = practice
                    showRemoveAlert = true
                } label: {
                    Text("Remove")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - Window Row

    private func windowRow(_ window: OverlapWindow) -> some View {
        let freeMembers = bandManager.members.filter { window.freeMembers.contains($0.id) }

        return VStack(alignment: .leading, spacing: 12) {
            Text("\(TimeHelpers.formatTime(window.startMinutes)) – \(TimeHelpers.formatTime(window.endMinutes))")
                .font(.headline)

            // Only show available members
            HStack(spacing: -6) {
                ForEach(freeMembers) { member in
                    Circle()
                        .fill(Color(hex: member.color))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Text(String(member.name.prefix(1)).uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color(.systemBackground), lineWidth: 2)
                        )
                }
            }

            if bandManager.isLeader {
                Button {
                    selectedWindow = window
                    showScheduleAlert = true
                } label: {
                    Text("Schedule This")
                        .font(.body.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
