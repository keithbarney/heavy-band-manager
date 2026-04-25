import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var bandManager: BandManager
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var toastManager: ToastManager
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @State private var isSyncing = false
    @State private var editingBandName = false
    @State private var bandNameText = ""
    @State private var showLogoPicker = false
    @State private var isUploadingLogo = false
    @State private var showLeaveConfirmation = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile
                Section {
                    if let member = bandManager.currentMember {
                        HStack(spacing: 12) {
                            MemberAvatar(member: member, size: 56)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(member.name).font(.headline)
                                    if bandManager.isLeader {
                                        Text("Organizer")
                                            .font(.caption2.bold())
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                                if let email = authManager.user?.email {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Profile")
                }

                // MARK: - Band
                Section {
                    if bandManager.isLeader {
                        Button {
                            bandNameText = bandManager.currentBand?.name ?? ""
                            editingBandName = true
                        } label: {
                            HStack {
                                Text("Name")
                                Spacer()
                                Text(bandManager.currentBand?.name ?? "—")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.primary)
                    } else {
                        LabeledContent("Name", value: bandManager.currentBand?.name ?? "—")
                    }

                    if bandManager.isLeader {
                        Button {
                            showLogoPicker = true
                        } label: {
                            HStack {
                                Text("Logo")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isUploadingLogo {
                                    ProgressView()
                                } else if let logoUrl = bandManager.currentBand?.logoUrl, let url = URL(string: logoUrl) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.themeAccent.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: "camera")
                                                .font(.caption)
                                                .foregroundStyle(Color.themeAccent)
                                        )
                                }
                            }
                        }
                        .sheet(isPresented: $showLogoPicker) {
                            ImageCropPicker(isPresented: $showLogoPicker) { image in
                                Task { await handleLogoImage(image) }
                            }
                        }
                    }

                    ForEach(bandManager.members) { member in
                        NavigationLink {
                            MemberEditView(member: member)
                                .environmentObject(bandManager)
                        } label: {
                            memberBandRow(member)
                        }
                    }

                    Button {
                        UIPasteboard.general.string = bandManager.currentBand?.inviteCode
                        toastManager.show("Invite code copied")
                    } label: {
                        HStack {
                            Text("Invite Code")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(bandManager.currentBand?.inviteCode ?? "—")
                                .font(.body.monospaced())
                                .foregroundStyle(.secondary)
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("Band")
                }

                // MARK: - Calendar
                Section {
                    if !calendarManager.isAuthorized {
                        Button {
                            Task { await calendarManager.requestAccess() }
                        } label: {
                            Label("Connect Calendar", systemImage: "calendar.badge.plus")
                        }
                    } else {
                        LabeledContent("Status") {
                            HStack(spacing: 4) {
                                Circle().fill(.green).frame(width: 8, height: 8)
                                Text("Connected").foregroundStyle(.green)
                            }
                        }

                        NavigationLink {
                            calendarSourcesList
                        } label: {
                            LabeledContent("Sources", value: "\(calendarManager.selectedCalendarIds.count) selected")
                        }

                        NavigationLink {
                            practiceWindowPicker
                        } label: {
                            LabeledContent("Practice Window") {
                                if let member = bandManager.currentMember {
                                    Text("\(TimeHelpers.formatTime(member.practiceWindowStart)) – \(TimeHelpers.formatTime(member.practiceWindowEnd))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        LabeledContent("Calendar Name") {
                            Text("\(bandManager.currentBand?.name ?? "Band") Practice")
                                .foregroundStyle(.secondary)
                        }

                        Toggle("Auto-sync on open", isOn: $calendarManager.autoSync)
                            .onChange(of: calendarManager.autoSync) { _, _ in
                                calendarManager.savePrefs()
                            }

                        Button {
                            Task { await syncCalendar() }
                        } label: {
                            HStack {
                                if isSyncing {
                                    ProgressView()
                                } else {
                                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                }
                                Spacer()
                                if let lastSync = calendarManager.lastSyncDate {
                                    Text(formatLastSync(lastSync))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .disabled(isSyncing)
                    }
                } header: {
                    Text("Calendar")
                }

                // MARK: - Appearance
                Section {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("Appearance")
                }

                // MARK: - Account
                Section {
                    if !bandManager.isLeader {
                        Button(role: .destructive) {
                            showLeaveConfirmation = true
                        } label: {
                            Text("Leave Band")
                        }
                        .confirmationDialog(
                            "Leave \(bandManager.currentBand?.name ?? "this band")?",
                            isPresented: $showLeaveConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Leave Band", role: .destructive) {
                                Task { await bandManager.leaveBand() }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("You'll lose access to this band's calendar and scheduled practices. You can rejoin later with an invite code.")
                        }
                    }

                    if bandManager.isLeader {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Delete Band")
                        }
                        .confirmationDialog(
                            "Delete \(bandManager.currentBand?.name ?? "this band")?",
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Delete Forever", role: .destructive) {
                                Task { await bandManager.deleteBand() }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This permanently deletes the band, all members, availability data, and scheduled practices for everyone. This cannot be undone.")
                        }
                    }

                    Button(role: .destructive) {
                        Task {
                            bandManager.cleanup()
                            await authManager.signOut()
                        }
                    } label: {
                        Text("Sign Out")
                    }
                }

                // Version
                Section {
                    Text("Band Practice v0.1.0")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .alert("Edit Band Name", isPresented: $editingBandName) {
                TextField("Band name", text: $bandNameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    Task { await bandManager.updateBandName(bandNameText) }
                }
            }
        }
    }

    // MARK: - Member Band Row

    private func memberBandRow(_ member: BandMember) -> some View {
        HStack(spacing: 12) {
            MemberAvatar(member: member, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(member.name)
                    .font(.body)
                if let instrument = member.instrument, !instrument.isEmpty {
                    Text(instrument)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if member.userId == bandManager.currentBand?.leaderId {
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Helpers

    private func handleLogoImage(_ image: UIImage) async {
        isUploadingLogo = true
        defer { isUploadingLogo = false }
        let resized = image.resized(maxDimension: 512)
        guard let jpegData = resized.jpegData(compressionQuality: 0.7) else { return }
        await bandManager.uploadBandLogo(imageData: jpegData)
    }

    private static let lastSyncFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private func formatLastSync(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return Self.lastSyncFormatter.string(from: date)
    }

    private func syncCalendar() async {
        isSyncing = true
        let start = Date()
        let end = Calendar.current.date(byAdding: .month, value: 2, to: start) ?? start
        await bandManager.syncCalendar(calendarManager: calendarManager, from: start, to: end)
        isSyncing = false
    }

    // MARK: - Calendar Sources List
    private var calendarSourcesList: some View {
        List {
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
        }
        .navigationTitle("Calendar Sources")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Practice Window Picker
    private var practiceWindowPicker: some View {
        Form {
            Section {
                Picker("Start", selection: Binding(
                    get: { bandManager.currentMember?.practiceWindowStart ?? 960 },
                    set: { newVal in Task { try? await bandManager.updatePracticeWindow(start: newVal, end: bandManager.currentMember?.practiceWindowEnd ?? 1380) } }
                )) {
                    ForEach(Array(stride(from: 0, through: 1380, by: 30)), id: \.self) { minutes in
                        Text(TimeHelpers.formatTime(minutes)).tag(minutes)
                    }
                }

                Picker("End", selection: Binding(
                    get: { bandManager.currentMember?.practiceWindowEnd ?? 1380 },
                    set: { newVal in Task { try? await bandManager.updatePracticeWindow(start: bandManager.currentMember?.practiceWindowStart ?? 960, end: newVal) } }
                )) {
                    ForEach(Array(stride(from: 0, through: 1410, by: 30)), id: \.self) { minutes in
                        Text(TimeHelpers.formatTime(minutes)).tag(minutes)
                    }
                }
            }
        }
        .navigationTitle("Practice Window")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Member Edit View

struct MemberEditView: View {
    @EnvironmentObject var bandManager: BandManager
    let member: BandMember

    @State private var instrumentText: String = ""
    @State private var nameText: String = ""
    @State private var showPhotoPicker = false
    @State private var isUploadingPhoto = false

    private var isCurrentUser: Bool {
        member.id == bandManager.currentMember?.id
    }

    private var canEditInstrument: Bool {
        isCurrentUser || bandManager.isLeader
    }

    var body: some View {
        List {
            // Avatar + name header
            Section {
                HStack(spacing: 16) {
                    if isCurrentUser {
                        Button {
                            showPhotoPicker = true
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                MemberAvatar(member: member, size: 64)
                                if isUploadingPhoto {
                                    ProgressView()
                                        .frame(width: 64, height: 64)
                                }
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white, .tint)
                                    .offset(x: 2, y: 2)
                            }
                        }
                        .sheet(isPresented: $showPhotoPicker) {
                            ImageCropPicker(isPresented: $showPhotoPicker) { image in
                                Task { await handlePhotoImage(image) }
                            }
                        }
                    } else {
                        MemberAvatar(member: member, size: 64)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name)
                            .font(.title3.bold())
                        if let instrument = member.instrument, !instrument.isEmpty {
                            Text(instrument)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if member.userId == bandManager.currentBand?.leaderId {
                            Text("Band Leader")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Editable fields
            if isCurrentUser {
                Section("Name") {
                    TextField("Your name", text: $nameText)
                        .onSubmit {
                            Task { await bandManager.updateMemberName(nameText) }
                        }
                }
            }

            if canEditInstrument {
                Section("Instrument") {
                    TextField("Instrument", text: $instrumentText)
                        .onSubmit {
                            Task { await bandManager.updateMemberInstrument(instrumentText, memberId: member.id) }
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(isCurrentUser ? "Edit Profile" : member.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            instrumentText = member.instrument ?? ""
            nameText = member.name
        }
    }

    private func handlePhotoImage(_ image: UIImage) async {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        let resized = image.resized(maxDimension: 512)
        guard let jpegData = resized.jpegData(compressionQuality: 0.7) else { return }
        await bandManager.uploadAvatar(imageData: jpegData)
    }
}
