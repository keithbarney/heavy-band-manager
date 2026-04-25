import SwiftUI

struct BandPickerSheet: View {
    @EnvironmentObject var bandManager: BandManager
    @Environment(\.dismiss) private var dismiss

    enum Destination: Hashable { case createBand, joinBand }
    @State private var path: [Destination] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // MARK: - Your Bands
                Section {
                    ForEach(bandManager.bands) { band in
                        Button {
                            Task {
                                await bandManager.selectBand(band)
                                dismiss()
                            }
                        } label: {
                            bandRow(band)
                        }
                    }
                } header: {
                    Text("Your Bands")
                }

                // MARK: - Actions
                Section {
                    Button {
                        path.append(.createBand)
                    } label: {
                        Label("Create a Band", systemImage: "plus.circle")
                    }

                    Button {
                        path.append(.joinBand)
                    } label: {
                        Label("Join a Band", systemImage: "person.badge.plus")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Bands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: Destination.self) { dest in
                switch dest {
                case .createBand: CreateBandMiniView(onComplete: { dismiss() })
                case .joinBand: JoinBandMiniView(onComplete: { dismiss() })
                }
            }
        }
    }

    // MARK: - Band Row

    private func bandRow(_ band: BandWithMembers) -> some View {
        let isCurrent = band.id == bandManager.currentBand?.id

        return HStack(spacing: 12) {
            // Logo
            if let logoUrl = band.logoUrl, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    bandInitialCircle(band)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                bandInitialCircle(band)
            }

            // Name + member count
            VStack(alignment: .leading, spacing: 2) {
                Text(band.name)
                    .font(.body.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(.primary)
                Text("\(band.bandMembers.count) member\(band.bandMembers.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isCurrent {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
    }

    private func bandInitialCircle(_ band: BandWithMembers) -> some View {
        Circle()
            .fill(Color.themeAccent.opacity(0.2))
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(band.name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.themeAccent)
            )
    }
}

// MARK: - Create Band (Mini)

struct CreateBandMiniView: View {
    @EnvironmentObject var bandManager: BandManager
    let onComplete: () -> Void

    @State private var bandName = ""
    @State private var practiceLocation = ""
    @State private var showLocationSearch = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Band Name", text: $bandName)

                Button {
                    showLocationSearch = true
                } label: {
                    HStack {
                        Text("Practice Location")
                            .foregroundStyle(practiceLocation.isEmpty ? .blue : .primary)
                        Spacer()
                        Text(practiceLocation.isEmpty ? "Optional" : practiceLocation)
                            .foregroundStyle(practiceLocation.isEmpty ? .tertiary : .secondary)
                    }
                }
                .sheet(isPresented: $showLocationSearch) {
                    LocationSearchView(selectedLocation: $practiceLocation)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Create a Band")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await createBand() }
            } label: {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Create")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .disabled(bandName.isEmpty || isSubmitting)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func createBand() async {
        isSubmitting = true
        errorMessage = nil
        do {
            // Get current user's existing member name from any band
            let memberName = bandManager.currentMember?.name ?? "Member"
            try await bandManager.createBand(
                name: bandName,
                userName: memberName,
                instrument: bandManager.currentMember?.instrument
            )
            if !practiceLocation.isEmpty {
                await bandManager.updatePracticeLocation(practiceLocation)
            }
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

// MARK: - Join Band (Mini)

struct JoinBandMiniView: View {
    @EnvironmentObject var bandManager: BandManager
    let onComplete: () -> Void

    @State private var inviteCode = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Invite Code", text: $inviteCode)
                    .textInputAutocapitalization(.characters)
                    .font(.body.monospaced())
            } footer: {
                Text("Ask your bandmate for the invite code from their Settings screen.")
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Join a Band")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await joinBand() }
            } label: {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Join")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .disabled(inviteCode.isEmpty || isSubmitting)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func joinBand() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let memberName = bandManager.currentMember?.name ?? "Member"
            try await bandManager.joinBand(
                inviteCode: inviteCode,
                userName: memberName,
                instrument: bandManager.currentMember?.instrument
            )
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
