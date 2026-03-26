import SwiftUI

struct DayDetailSheet: View {
    @EnvironmentObject var bandManager: BandManager
    @Environment(\.dismiss) private var dismiss

    let date: String

    @State private var showScheduleAlert = false
    @State private var selectedWindow: OverlapWindow?

    private var dayPractices: [ScheduledPractice] {
        bandManager.practices.filter { $0.date == date }
    }

    private var dayWindows: [OverlapWindow] {
        let daySlots = bandManager.slots.filter { $0.date == date }
        return OverlapEngine.compute(
            slots: daySlots,
            totalMembers: bandManager.members.count,
            minMembers: 2
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Scheduled practices
                    if !dayPractices.isEmpty {
                        sectionHeader("SCHEDULED")
                        VStack(spacing: 0) {
                            ForEach(dayPractices) { practice in
                                practiceRow(practice)
                                if practice.id != dayPractices.last?.id {
                                    Divider().background(Color.themeBorder).padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color.themeBgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Overlap windows
                    if dayWindows.isEmpty {
                        VStack(spacing: 8) {
                            Text("No overlap found")
                                .font(.headline)
                                .foregroundColor(.themeTextPrimary)
                            Text("Members need to sync their calendars")
                                .font(.subheadline)
                                .foregroundColor(.themeTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                    } else {
                        sectionHeader("AVAILABLE WINDOWS")
                        VStack(spacing: 12) {
                            ForEach(dayWindows) { window in
                                windowCard(window)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.themeBg)
            .navigationTitle(TimeHelpers.fullDisplayDate(date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert("Schedule Practice", isPresented: $showScheduleAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Schedule") {
                if let w = selectedWindow {
                    Task {
                        await bandManager.schedulePractice(
                            date: date,
                            startMinutes: w.startMinutes,
                            endMinutes: w.endMinutes,
                            location: bandManager.currentBand?.defaultPracticeLocation
                        )
                    }
                }
            }
        } message: {
            if let w = selectedWindow {
                Text("\(TimeHelpers.formatTime(w.startMinutes)) – \(TimeHelpers.formatTime(w.endMinutes)) (\(TimeHelpers.formatDuration(w.duration)))")
            }
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.bold())
            .foregroundColor(.themeTextTertiary)
    }

    private func practiceRow(_ practice: ScheduledPractice) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.themeSuccess)
                .frame(width: 4, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(TimeHelpers.formatTime(practice.startMinutes)) – \(TimeHelpers.formatTime(practice.endMinutes))")
                    .font(.headline)
                    .foregroundColor(.themeTextPrimary)
                if let loc = practice.location, !loc.isEmpty {
                    Text(loc)
                        .font(.subheadline)
                        .foregroundColor(.themeTextSecondary)
                }
            }
            Spacer()
            if bandManager.isLeader {
                Button {
                    Task { await bandManager.cancelPractice(practice.id) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.themeDanger)
                }
            }
        }
        .padding()
    }

    private func windowCard(_ window: OverlapWindow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(TimeHelpers.formatTime(window.startMinutes)) – \(TimeHelpers.formatTime(window.endMinutes))")
                            .font(.headline)
                        Text("(\(TimeHelpers.formatDuration(window.duration)))")
                            .font(.subheadline)
                            .foregroundColor(.themeTextTertiary)
                    }
                    .foregroundColor(.themeTextPrimary)
                }
                Spacer()
                Text("\(window.freeMembers.count)/\(window.totalMembers)")
                    .font(.subheadline.bold())
                    .foregroundColor(.themeTextSecondary)
            }

            if window.freeMembers.count == window.totalMembers {
                Text("Everyone free")
                    .font(.caption.bold())
                    .foregroundColor(.themeSuccess)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.themeSuccess.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Member dots
            HStack(spacing: 8) {
                ForEach(bandManager.members) { member in
                    let isFree = window.freeMembers.contains(member.id)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: member.color).opacity(isFree ? 1 : 0.3))
                            .frame(width: 10, height: 10)
                        Text(member.name.components(separatedBy: " ").first ?? member.name)
                            .font(.caption2)
                            .foregroundColor(isFree ? .themeTextSecondary : .themeTextTertiary)
                    }
                }
            }

            if bandManager.isLeader {
                Button {
                    selectedWindow = window
                    showScheduleAlert = true
                } label: {
                    Text("Schedule This")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.themeAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color.themeBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
