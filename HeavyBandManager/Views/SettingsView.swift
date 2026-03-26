import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var bandManager: BandManager
    @EnvironmentObject var calendarManager: CalendarManager
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .light
    @State private var showCalendarPicker = false
    @State private var showPracticeWindowPicker = false
    @State private var isSyncing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.largeTitle).bold()
                    .foregroundColor(.themeTextPrimary)
                    .padding(.horizontal, 20)

                // Profile
                sectionHeader("PROFILE")
                profileCard
                    .padding(.horizontal, 20)

                // Calendar
                sectionHeader("CALENDAR")
                calendarCard
                    .padding(.horizontal, 20)

                // Band
                sectionHeader("BAND")
                bandCard
                    .padding(.horizontal, 20)

                // Dev User Picker (DEBUG only)
                #if DEBUG
                sectionHeader("DEV USERS")
                devUserSection
                    .padding(.horizontal, 20)
                #endif

                // Appearance
                sectionHeader("APPEARANCE")
                VStack(spacing: 0) {
                    Picker("", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20)

                // Account
                sectionHeader("ACCOUNT")
                VStack(spacing: 0) {
                    Button {
                        Task {
                            bandManager.cleanup()
                            await authManager.signOut()
                        }
                    } label: {
                        HStack {
                            Text("Sign Out")
                                .foregroundColor(.themeDanger)
                            Spacer()
                        }
                        .padding()
                    }
                }
                .background(Color.themeBgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20)

                // Version
                Text("Heavy Band Manager v0.1.0")
                    .font(.caption)
                    .foregroundColor(.themeTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(Color.themeBg)
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.bold())
            .foregroundColor(.themeTextTertiary)
            .padding(.horizontal, 20)
    }

    private var profileCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let member = bandManager.currentMember {
                    Circle()
                        .fill(Color(hex: member.color))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(member.name.prefix(1)).uppercased())
                                .font(.headline.bold())
                                .foregroundColor(.white)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(member.name)
                                .font(.headline)
                                .foregroundColor(.themeTextPrimary)
                            if bandManager.isLeader {
                                Text("Leader")
                                    .font(.caption2.bold())
                                    .foregroundColor(.themeWarning)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.themeWarning.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        if let instrument = member.instrument, !instrument.isEmpty {
                            Text(instrument)
                                .font(.subheadline)
                                .foregroundColor(.themeTextSecondary)
                        }
                    }
                }
                Spacer()
            }
            .padding()

            if let email = authManager.user?.email {
                Divider().background(Color.themeBorder)
                HStack {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.themeTextSecondary)
                    Spacer()
                }
                .padding()
            }
        }
        .background(Color.themeBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var bandCard: some View {
        VStack(spacing: 0) {
            settingsRow("Name", value: bandManager.currentBand?.name ?? "—")
            Divider().background(Color.themeBorder).padding(.leading, 16)

            // Members list
            ForEach(bandManager.members) { member in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: member.color))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(member.name.prefix(1)).uppercased())
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                        )
                    Text(member.name)
                        .foregroundColor(.themeTextPrimary)
                    if member.userId == bandManager.currentBand?.leaderId {
                        Text("👑")
                    }
                    Spacer()
                    if let instrument = member.instrument, !instrument.isEmpty {
                        Text(instrument)
                            .font(.caption)
                            .foregroundColor(.themeTextTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                Divider().background(Color.themeBorder).padding(.leading, 56)
            }

            // Invite code
            HStack {
                Text("Invite Code")
                    .foregroundColor(.themeTextPrimary)
                Spacer()
                Text(bandManager.currentBand?.inviteCode ?? "—")
                    .font(.body.bold().monospaced())
                    .foregroundColor(.themeTextSecondary)
                Button {
                    UIPasteboard.general.string = bandManager.currentBand?.inviteCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.themeAccent)
                }
            }
            .padding()
        }
        .background(Color.themeBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    #if DEBUG
    private var devUserSection: some View {
        VStack(spacing: 8) {
            ForEach(devUsers) { user in
                Button {
                    Task {
                        bandManager.cleanup()
                        await authManager.signInWithEmail(user.email, password: user.password)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(user.emoji)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name)
                                .font(.subheadline.bold())
                                .foregroundColor(user.color)
                            Text(user.instrument)
                                .font(.caption)
                                .foregroundColor(.themeTextSecondary)
                        }
                        Spacer()
                        Text("Switch")
                            .font(.caption.bold())
                            .foregroundColor(.themeAccent)
                    }
                    .padding()
                    .background(Color.themeSurfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
    #endif

    // MARK: - Calendar

    private var calendarCard: some View {
        VStack(spacing: 0) {
            if !calendarManager.isAuthorized {
                // Not connected
                Button {
                    Task { await calendarManager.requestAccess() }
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.themeAccent)
                        Text("Connect Calendar")
                            .foregroundColor(.themeAccent)
                        Spacer()
                    }
                    .padding()
                }
            } else {
                // Status
                HStack {
                    Text("Status")
                        .foregroundColor(.themeTextPrimary)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Color.themeSuccess).frame(width: 8, height: 8)
                        Text("Connected")
                            .foregroundColor(.themeSuccess)
                    }
                }
                .padding()

                Divider().background(Color.themeBorder).padding(.leading, 16)

                // Sources
                Button {
                    showCalendarPicker = true
                } label: {
                    HStack {
                        Text("Sources")
                            .foregroundColor(.themeTextPrimary)
                        Spacer()
                        Text("\(calendarManager.selectedCalendarIds.count) selected")
                            .foregroundColor(.themeTextSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.themeTextTertiary)
                    }
                    .padding()
                }

                Divider().background(Color.themeBorder).padding(.leading, 16)

                // Practice Window
                Button {
                    showPracticeWindowPicker = true
                } label: {
                    HStack {
                        Text("Practice Window")
                            .foregroundColor(.themeTextPrimary)
                        Spacer()
                        if let member = bandManager.currentMember {
                            Text("\(TimeHelpers.formatTime(member.practiceWindowStart)) – \(TimeHelpers.formatTime(member.practiceWindowEnd))")
                                .foregroundColor(.themeTextSecondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.themeTextTertiary)
                    }
                    .padding()
                }

                Divider().background(Color.themeBorder).padding(.leading, 16)

                // Calendar Name
                HStack {
                    Text("Calendar Name")
                        .foregroundColor(.themeTextPrimary)
                    Spacer()
                    TextField("Band Practice", text: $calendarManager.practiceCalendarName)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.themeTextSecondary)
                        .frame(maxWidth: 180)
                        .onChange(of: calendarManager.practiceCalendarName) { _, _ in
                            calendarManager.savePrefs()
                        }
                }
                .padding()

                Divider().background(Color.themeBorder).padding(.leading, 16)

                // Auto-sync toggle
                Toggle(isOn: $calendarManager.autoSync) {
                    Text("Auto-sync on open")
                        .foregroundColor(.themeTextPrimary)
                }
                .tint(.themeAccent)
                .padding()
                .onChange(of: calendarManager.autoSync) { _, _ in
                    calendarManager.savePrefs()
                }

                Divider().background(Color.themeBorder).padding(.leading, 16)

                // Sync Now
                Button {
                    Task { await syncCalendar() }
                } label: {
                    HStack {
                        if isSyncing {
                            ProgressView().tint(.themeAccent)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.themeAccent)
                        }
                        Text("Sync Now")
                            .foregroundColor(.themeAccent)
                        Spacer()
                        if let lastSync = calendarManager.lastSyncDate {
                            Text(lastSync, style: .relative)
                                .font(.caption)
                                .foregroundColor(.themeTextTertiary)
                        }
                    }
                    .padding()
                }
                .disabled(isSyncing)
            }
        }
        .background(Color.themeBgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .sheet(isPresented: $showCalendarPicker) {
            calendarPickerSheet
        }
        .sheet(isPresented: $showPracticeWindowPicker) {
            practiceWindowSheet
        }
    }

    private func syncCalendar() async {
        isSyncing = true
        defer { isSyncing = false }

        // Sync current month
        let calendar = Calendar.current
        let now = Date()
        let comps = calendar.dateComponents([.year, .month], from: now)
        let monthStart = calendar.date(from: comps)!
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!

        await bandManager.syncCalendar(calendarManager: calendarManager, from: monthStart, to: monthEnd)
    }

    // MARK: - Calendar Picker Sheet

    private var calendarPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(calendarManager.deviceCalendars) { cal in
                    Button {
                        calendarManager.toggleCalendar(cal.id)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(cgColor: cal.color))
                                .frame(width: 12, height: 12)
                            Text(cal.title)
                                .foregroundColor(.themeTextPrimary)
                            Spacer()
                            if calendarManager.selectedCalendarIds.contains(cal.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.themeAccent)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Calendar Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showCalendarPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Practice Window Sheet

    @State private var tempWindowStart = 960
    @State private var tempWindowEnd = 1380

    private var practiceWindowSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack {
                    Text("Start").foregroundColor(.themeTextSecondary)
                    Spacer()
                    Picker("", selection: $tempWindowStart) {
                        ForEach(Array(stride(from: 0, through: 1410, by: 30)), id: \.self) { minutes in
                            Text(TimeHelpers.formatTime(minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.themeAccent)
                }
                .padding(.horizontal)

                HStack {
                    Text("End").foregroundColor(.themeTextSecondary)
                    Spacer()
                    Picker("", selection: $tempWindowEnd) {
                        ForEach(Array(stride(from: 0, through: 1410, by: 30)), id: \.self) { minutes in
                            Text(TimeHelpers.formatTime(minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.themeAccent)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Practice Window")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPracticeWindowPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if let member = bandManager.currentMember {
                                try? await Config.supabase
                                    .from("band_members")
                                    .update(["practice_window_start": AnyJSON.integer(tempWindowStart), "practice_window_end": AnyJSON.integer(tempWindowEnd)])
                                    .eq("id", value: member.id.uuidString)
                                    .execute()
                                await bandManager.loadBands()
                            }
                            showPracticeWindowPicker = false
                        }
                    }
                }
            }
            .onAppear {
                if let member = bandManager.currentMember {
                    tempWindowStart = member.practiceWindowStart
                    tempWindowEnd = member.practiceWindowEnd
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func settingsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.themeTextPrimary)
            Spacer()
            Text(value).foregroundColor(.themeTextSecondary)
        }
        .padding()
    }
}
