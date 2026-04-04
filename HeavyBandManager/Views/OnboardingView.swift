import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var bandManager: BandManager

    enum Step { case welcome, create, join }
    @State private var step: Step = .welcome

    // Form fields
    @State private var bandName = ""
    @State private var userName = ""
    @State private var instrument = ""
    @State private var inviteCode = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didPrefill = false

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .welcome: welcomeView
                case .create: createView
                case .join: joinView
                }
            }
            .onAppear {
                if !didPrefill {
                    if let appleName = authManager.appleFullName, !appleName.isEmpty {
                        userName = appleName
                    }
                    if userName.isEmpty, let email = authManager.user?.email {
                        userName = email.components(separatedBy: "@").first ?? ""
                    }
                    didPrefill = true
                }
            }
        }
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("Band Practice")
                        .font(.largeTitle).bold()
                    Text("Find the perfect practice time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.vertical, 24)
            }

            Section {
                Button {
                    step = .create
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .foregroundStyle(.blue)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create a Band")
                                .foregroundStyle(.primary)
                            Text("Start a new band and invite your crew")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack {
                    Text("Enter your invite code")
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .layoutPriority(1)
                    Spacer(minLength: 16)
                    TextField("XXX-XXXX", text: $inviteCode)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .textInputAutocapitalization(.characters)
                        .onSubmit {
                            guard !inviteCode.isEmpty else { return }
                            Task { await joinBand() }
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Create

    private var createView: some View {
        Form {
            Section {
                TextField("Band Name", text: $bandName)
                TextField("Your Name", text: $userName)
                TextField("Instrument (optional)", text: $instrument)
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button {
                    Task { await createBand() }
                } label: {
                    if isSubmitting {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Get Started")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                }
                .disabled(bandName.isEmpty || userName.isEmpty || isSubmitting)
            }
        }
        .navigationTitle("Create a Band")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { step = .welcome }
            }
        }
    }

    // MARK: - Join

    private var joinView: some View {
        Form {
            Section(header: Text("Invite Code")) {
                TextField("HBM-XXXX", text: $inviteCode)
                    .font(.title2.bold().monospaced())
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
            }

            Section {
                TextField("Your Name", text: $userName)
                TextField("Instrument (optional)", text: $instrument)
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button {
                    Task { await joinBand() }
                } label: {
                    if isSubmitting {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Join Band")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                }
                .disabled(inviteCode.isEmpty || userName.isEmpty || isSubmitting)
            }
        }
        .navigationTitle("Join a Band")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { step = .welcome }
            }
        }
    }

    // MARK: - Actions

    private func createBand() async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await bandManager.createBand(name: bandName, userName: userName, instrument: instrument.isEmpty ? nil : instrument)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func joinBand() async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await bandManager.joinBand(inviteCode: inviteCode, userName: userName, instrument: instrument.isEmpty ? nil : instrument)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
