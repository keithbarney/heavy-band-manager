import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var bandManager: BandManager

    enum Step: Hashable { case createBand, createProfile }
    @State private var path: [Step] = []

    // Band fields
    @State private var bandName = ""
    @State private var practiceLocation = ""
    @State private var showLogoPicker = false
    @State private var showLocationSearch = false
    @State private var logoImage: UIImage?

    // Profile fields
    @State private var userName = ""
    @State private var instrument = ""
    @State private var showPhotoPicker = false
    @State private var photoImage: UIImage?

    // Join field
    @State private var inviteCode = ""

    // Shared state
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didPrefill = false

    var body: some View {
        NavigationStack(path: $path) {
            welcomeView
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .createBand: createBandView
                    case .createProfile: createProfileView
                    }
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
                    path.append(.createBand)
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
                            Task { await joinWithCode() }
                        }
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
        .listStyle(.insetGrouped)
    }

    // MARK: - Create Band

    private var createBandView: some View {
        Form {
            Section {
                TextField("Name", text: $bandName)

                Button {
                    showLogoPicker = true
                } label: {
                    HStack {
                        Text("Logo")
                            .foregroundStyle(logoImage != nil ? Color.primary : Color.blue)
                        Spacer()
                        if let logoImage {
                            Image(uiImage: logoImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.themeAccent.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(bandName.prefix(1)).uppercased())
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Color.themeAccent)
                                )
                        }
                    }
                }
                .sheet(isPresented: $showLogoPicker) {
                    ImageCropPicker(isPresented: $showLogoPicker) { image in
                        logoImage = image
                    }
                }

                Button {
                    showLocationSearch = true
                } label: {
                    HStack {
                        Text("Practice Location")
                            .foregroundStyle(practiceLocation.isEmpty ? Color.blue : Color.primary)
                        Spacer()
                        Text(practiceLocation.isEmpty ? "Orbit Studios" : practiceLocation)
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
        .navigationTitle("Create a band")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            Button {
                guard !bandName.isEmpty else { return }
                path.append(.createProfile)
            } label: {
                Text("Continue")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .disabled(bandName.isEmpty)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Create Profile

    private var createProfileView: some View {
        Form {
            Section {
                Button {
                    showPhotoPicker = true
                } label: {
                    HStack {
                        Text("Photo")
                            .foregroundStyle(photoImage != nil ? Color.primary : Color.blue)
                        Spacer()
                        if let photoImage {
                            Image(uiImage: photoImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.themeAccent.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(userName.prefix(1)).uppercased())
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Color.themeAccent)
                                )
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "camera.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white, Color.themeAccent)
                                        .offset(x: 2, y: 2)
                                }
                        }
                    }
                }
                .sheet(isPresented: $showPhotoPicker) {
                    ImageCropPicker(isPresented: $showPhotoPicker) { image in
                        photoImage = image
                    }
                }

                LabeledContent("Email") {
                    Text(authManager.user?.email ?? "")
                        .foregroundStyle(.secondary)
                }

                TextField("Your Name", text: $userName)

                TextField("Instrument", text: $instrument)
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

        }
        .navigationTitle("Create your profile")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await finishOnboarding() }
            } label: {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Get Started")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .disabled(userName.isEmpty || isSubmitting)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Actions

    /// Join via invite code from Welcome, then go to profile step
    private func joinWithCode() async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await bandManager.joinBand(inviteCode: inviteCode, userName: userName, instrument: nil)
            // After joining, go directly to profile step
            path.append(.createProfile)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    /// Final step — create band (if creating) or update profile (if joining), then enter the app
    private func finishOnboarding() async {
        isSubmitting = true
        errorMessage = nil
        do {
            if bandManager.currentBand == nil {
                // Creating a new band
                try await bandManager.createBand(
                    name: bandName,
                    userName: userName,
                    instrument: instrument.isEmpty ? nil : instrument
                )

                // Upload logo if picked
                if let logoImage {
                    let resized = logoImage.resized(maxDimension: 512)
                    if let jpegData = resized.jpegData(compressionQuality: 0.7) {
                        await bandManager.uploadBandLogo(imageData: jpegData)
                    }
                }

                // Set practice location if provided
                if !practiceLocation.isEmpty {
                    await bandManager.updatePracticeLocation(practiceLocation)
                }
            } else {
                // Joined via invite code — update profile details
                await bandManager.updateMemberName(userName)
                if !instrument.isEmpty {
                    await bandManager.updateMemberInstrument(instrument)
                }
            }

            // Upload avatar photo if picked
            if let photoImage {
                let resized = photoImage.resized(maxDimension: 512)
                if let jpegData = resized.jpegData(compressionQuality: 0.7) {
                    await bandManager.uploadAvatar(imageData: jpegData)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

}
