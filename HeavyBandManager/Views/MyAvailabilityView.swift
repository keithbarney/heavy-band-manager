import SwiftUI
import EventKit

struct MyAvailabilityView: View {
    @EnvironmentObject private var bandManager: BandManager
    @EnvironmentObject private var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var onFinished: (() -> Void)? = nil
    var isOnboarding = false

    @State private var selectedMode: AvailabilityMode = .calendar
    @State private var selectedDays: Set<Int> = []
    @State private var startMinutes = 1140
    @State private var endMinutes = 1320
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let times = Array(stride(from: 0, through: 1440, by: 30))

    var body: some View {
        Form {
            Section {
                Picker("Share availability", selection: $selectedMode) {
                    Text("Automatic").tag(AvailabilityMode.calendar)
                    Text("Manual").tag(AvailabilityMode.weekly)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("How do you want to share your availability?")
            } footer: {
                Text("You can change this any time. Each band member can choose their own method.")
            }

            calendarSetup

            if selectedMode == .weekly {
                weeklyEditor
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .disabled(isSaving)
        .navigationTitle("My Availability")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSaving)
        .toolbar {
            if !isOnboarding {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!canSave)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isOnboarding {
                Button {
                    Task { await save() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Get Started").bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .disabled(!canSave)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            calendarManager.checkAuthorization()
            if let member = bandManager.currentMember, member.availabilitySetupComplete {
                selectedMode = member.availabilityMode
            }
            await bandManager.loadWeeklyRules()
            if !bandManager.weeklyRules.isEmpty {
                selectedDays = Set(bandManager.weeklyRules.map(\.dayOfWeek))
                startMinutes = bandManager.weeklyRules.map(\.startMinutes).min() ?? startMinutes
                endMinutes = bandManager.weeklyRules.map(\.endMinutes).max() ?? endMinutes
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { calendarManager.checkAuthorization() }
        }
    }

    private var canSave: Bool {
        guard didLoad, !isSaving, calendarManager.isAuthorized else { return false }
        switch selectedMode {
        case .calendar:
            return true
        case .weekly:
            return !selectedDays.isEmpty && startMinutes < endMinutes
        }
    }

    private var weeklyEditor: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("When can you usually practice?")
                    .font(.headline)

                Text("Choose the days you’re free to practice.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { day in
                        Button {
                            if selectedDays.contains(day) {
                                selectedDays.remove(day)
                            } else {
                                selectedDays.insert(day)
                            }
                        } label: {
                            Text(dayNames[day])
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedDays.contains(day) ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedDays.contains(day) ? Color.accentColor : Color.secondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(dayNames[day])
                        .accessibilityValue(selectedDays.contains(day) ? "Selected" : "Not selected")
                    }
                }

                Text("Choose a start and end time for those days.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                HStack {
                    Picker("Start", selection: $startMinutes) {
                        ForEach(times, id: \.self) { minutes in
                            Text(TimeHelpers.formatTime(minutes)).tag(minutes)
                        }
                    }
                    Picker("End", selection: $endMinutes) {
                        ForEach(times, id: \.self) { minutes in
                            Text(TimeHelpers.formatTime(minutes)).tag(minutes)
                        }
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)

                if startMinutes >= endMinutes {
                    Text("Choose an end time after the start time.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 8)
        } footer: {
            Text("These hours repeat each week. Your band sees the times you share, not your personal calendar.")
        }
    }

    private var calendarSetup: some View {
        Section {
            if calendarManager.isAuthorized {
                Label("Calendar connected", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    if calendarManager.authStatus == .denied || calendarManager.authStatus == .restricted {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } else {
                        Task { await calendarManager.requestAccess() }
                    }
                } label: {
                    Label("Connect my calendar", systemImage: "calendar")
                }
                if calendarManager.authStatus == .denied || calendarManager.authStatus == .restricted {
                    Text("Allow calendar access in Settings so scheduled practices can be added to your calendar.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(selectedMode == .calendar ? "Find openings around your calendar events" : "Put practices on your calendar")
        } footer: {
            Text(selectedMode == .calendar
                 ? "Scheduled practices are added automatically. Your personal event names and details stay on your device."
                 : "Scheduled practices are added automatically. Your availability still follows the days and hours you choose.")
        }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            guard calendarManager.isAuthorized else {
                throw NSError(domain: "Availability", code: 1, userInfo: [NSLocalizedDescriptionKey: "Connect your calendar so scheduled practices can be added."])
            }
            if selectedMode == .weekly {
                guard startMinutes < endMinutes else {
                    throw NSError(domain: "Availability", code: 422, userInfo: [NSLocalizedDescriptionKey: "End time must be after start time."])
                }
                let ranges = Dictionary(uniqueKeysWithValues: selectedDays.map { ($0, (start: startMinutes, end: endMinutes)) })
                try await bandManager.saveWeeklyAvailability(ranges)
            } else {
                try await bandManager.setAvailabilityMode(.calendar)
                let calendar = Calendar.current
                let start = calendar.startOfDay(for: Date())
                let end = calendar.date(byAdding: .month, value: 6, to: start)!
                await bandManager.syncCalendar(calendarManager: calendarManager, from: start, to: end)
            }
            await bandManager.syncMissingCalendarEvents(calendarManager: calendarManager)
            if let onFinished {
                onFinished()
            } else {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
