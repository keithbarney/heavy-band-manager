import SwiftUI
import UIKit

/// Band-wide details and scheduling rules live independently of device settings.
struct BandSettingsView: View {
    @EnvironmentObject private var bandManager: BandManager
    @EnvironmentObject private var toastManager: ToastManager
    @State private var showBandPicker = false
    @State private var editingBandName = false
    @State private var bandNameText = ""
    @State private var showLogoPicker = false
    @State private var isUploadingLogo = false
    @State private var showLeaveConfirmation = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
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

                    if bandManager.isLeader, let band = bandManager.currentBand {
                        InviteMembersButton(
                            invitation: BandInvitation(
                                bandName: band.name,
                                inviteCode: band.inviteCode
                            )
                        )
                    }
                } header: {
                    Text("Band")
                }

                // MARK: - Band scheduling
                if bandManager.isLeader {
                    Section("Scheduling") {
                        NavigationLink {
                            practiceDurationPicker
                        } label: {
                            LabeledContent("Practice Duration") {
                                if let band = bandManager.currentBand {
                                    Text("\(TimeHelpers.formatDuration(band.minPracticeMinutes)) – \(TimeHelpers.formatDuration(band.maxPracticeMinutes))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        NavigationLink {
                            minMembersPicker
                        } label: {
                            LabeledContent("Minimum Members") {
                                if let band = bandManager.currentBand {
                                    Text("\(band.minMembersRequired) of \(bandManager.members.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

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

                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Band")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Switch band", systemImage: "arrow.left.arrow.right") { showBandPicker = true }
                }
            }
            .sheet(isPresented: $showBandPicker) { BandPickerSheet() }
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

    // MARK: - Practice Duration Picker
    private var practiceDurationPicker: some View {
        let durations = Array(stride(from: 30, through: 480, by: 30))
        return Form {
            Section {
                Picker("Minimum", selection: Binding(
                    get: { bandManager.currentBand?.minPracticeMinutes ?? 60 },
                    set: { newMin in
                        let curMax = bandManager.currentBand?.maxPracticeMinutes ?? 240
                        let newMax = curMax < newMin ? newMin : curMax
                        Task { await bandManager.updatePracticeDuration(min: newMin, max: newMax) }
                    }
                )) {
                    ForEach(durations, id: \.self) { d in
                        Text(TimeHelpers.formatDuration(d)).tag(d)
                    }
                }

                Picker("Maximum", selection: Binding(
                    get: { bandManager.currentBand?.maxPracticeMinutes ?? 240 },
                    set: { newMax in
                        let curMin = bandManager.currentBand?.minPracticeMinutes ?? 60
                        let newMin = curMin > newMax ? newMax : curMin
                        Task { await bandManager.updatePracticeDuration(min: newMin, max: newMax) }
                    }
                )) {
                    ForEach(durations, id: \.self) { d in
                        Text(TimeHelpers.formatDuration(d)).tag(d)
                    }
                }
            } footer: {
                Text("Best Windows only suggests practice slots within this duration range.")
            }
        }
        .navigationTitle("Practice Duration")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Minimum Members Picker
    private var minMembersPicker: some View {
        let total = max(bandManager.members.count, 1)
        return Form {
            Section {
                Picker("Minimum Members", selection: Binding(
                    get: { min(max(bandManager.currentBand?.minMembersRequired ?? 2, 1), total) },
                    set: { newVal in Task { await bandManager.updateMinMembersRequired(newVal) } }
                )) {
                    ForEach(1...total, id: \.self) { n in
                        Text(n == total ? "\(n) (all)" : "\(n)").tag(n)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text("Days with at least this many members available show a yellow dot. Days where everyone is available show green.")
            }
        }
        .navigationTitle("Minimum Members")
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

