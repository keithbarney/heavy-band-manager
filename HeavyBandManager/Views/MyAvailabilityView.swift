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
    @State private var windowStart = 960
    @State private var windowEnd = 1380
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
                .pickerStyle(.segmented)
                .controlSize(.large)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text(selectedMode == .calendar
                     ? "Share free time from your calendars."
                     : "Share the same hours each week.")
            }

            if !calendarManager.isAuthorized {
                calendarSetup
            }

            if selectedMode == .weekly {
                weeklyEditor
            } else if calendarManager.isAuthorized {
                automaticPreferences
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
        .navigationTitle("Availability")
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
            if let member = bandManager.currentMember {
                windowStart = member.practiceWindowStart
                windowEnd = member.practiceWindowEnd
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
            return windowStart < windowEnd && !calendarManager.selectedCalendarIds.isEmpty
        case .weekly:
            return !selectedDays.isEmpty && startMinutes < endMinutes
        }
    }

    private var automaticPreferences: some View {
        Section {
            NavigationLink {
                calendarSourcesList
            } label: {
                LabeledContent("Calendars", value: "\(calendarManager.selectedCalendarIds.count) selected")
            }
            NavigationLink {
                Form {
                    Picker("Start", selection: $windowStart) {
                        ForEach(times.filter { $0 < 1440 }, id: \.self) { minutes in
                            Text(TimeHelpers.formatTime(minutes)).tag(minutes)
                        }
                    }
                    Picker("End", selection: $windowEnd) {
                        ForEach(times.filter { $0 > 0 }, id: \.self) { minutes in
                            Text(TimeHelpers.formatTime(minutes)).tag(minutes)
                        }
                    }
                    Section {
                        Text("Only share free time within these hours each day. Return to Availability and tap Save to apply your changes.")
                    }
                    if windowStart >= windowEnd {
                        Text("Choose an end time after the start time.").foregroundStyle(.red)
                    }
                }
                .navigationTitle("Daily Practice Window")
                .navigationBarTitleDisplayMode(.inline)
            } label: {
                LabeledContent("Practice hours", value: "\(TimeHelpers.formatTime(windowStart)) – \(TimeHelpers.formatTime(windowEnd))")
            }
            Toggle("Refresh on open", isOn: $calendarManager.autoSync)
                .onChange(of: calendarManager.autoSync) { _, _ in calendarManager.savePrefs() }
            if calendarManager.selectedCalendarIds.isEmpty {
                Text("Select at least one calendar to find your free time.").foregroundStyle(.red)
            }
            if windowStart >= windowEnd {
                Text("Choose an end time after the start time.").foregroundStyle(.red)
            }
        } footer: {
            Text("Save updates the availability shared with your band.")
        }
    }

    private var calendarSourcesList: some View {
        List {
            Section {
                ForEach(calendarManager.deviceCalendars) { cal in
                    Button {
                        calendarManager.toggleCalendar(cal.id)
                    } label: {
                        HStack {
                            Circle().fill(Color(cgColor: cal.color)).frame(width: 12, height: 12)
                            Text(cal.title)
                            Spacer()
                            if calendarManager.selectedCalendarIds.contains(cal.id) {
                                Image(systemName: "checkmark").foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } footer: {
                Text("Selections save on this device immediately. Personal event details stay private.")
            }
        }
        .navigationTitle("Calendars to Check")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var weeklyEditor: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
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
            Text("Save updates the availability shared with your band.")
        }
    }

    private var calendarSetup: some View {
        Section {
            Button {
                if calendarManager.authStatus == .denied || calendarManager.authStatus == .restricted {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } else {
                    Task { await calendarManager.requestAccess() }
                }
            } label: {
                Label("Connect calendar", systemImage: "calendar")
            }
        } footer: {
            Text(selectedMode == .calendar
                 ? "Allow calendar access to find free time and add confirmed practices."
                 : "Allow calendar access to add confirmed practices. Your chosen hours stay the same.")
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
                if let member = bandManager.currentMember,
                   windowStart != member.practiceWindowStart || windowEnd != member.practiceWindowEnd {
                    try await bandManager.updatePracticeWindow(start: windowStart, end: windowEnd)
                }
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
