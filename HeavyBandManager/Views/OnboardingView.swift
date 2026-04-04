import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var bandManager: BandManager

    enum Step { case welcome, createBand, createProfile }
    @State private var step: Step = .welcome

    // Band fields
    @State private var bandName = ""
    @State private var practiceLocation = ""
    @State private var showLogoPicker = false
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
        NavigationStack {
            Group {
                switch step {
                case .welcome: welcomeView
                case .createBand: createBandView
                case .createProfile: createProfileView
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
                    step = .createBand
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

                TextField("Practice Location", text: $practiceLocation)
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
                    guard !bandName.isEmpty else { return }
                    withAnimation { step = .createProfile }
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .bold()
                        .foregroundStyle(.white)
                        .padding(.vertical, 12)
                        .background(bandName.isEmpty ? Color.blue.opacity(0.4) : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(bandName.isEmpty)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Create a band")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    step = .welcome
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
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

            Section {
                Button {
                    Task { await finishOnboarding() }
                } label: {
                    if isSubmitting {
                        HStack {
                            Spacer()
                            ProgressView().tint(.white)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(12)
                    } else {
                        Text("Get Started")
                            .frame(maxWidth: .infinity)
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.vertical, 12)
                            .background(userName.isEmpty ? Color.blue.opacity(0.4) : Color.blue)
                            .cornerRadius(12)
                    }
                }
                .disabled(userName.isEmpty || isSubmitting)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Create your profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    step = .createBand
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
    }

    // MARK: - Actions

    /// Join via invite code from Welcome, then go to profile step
    private func joinWithCode() async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await bandManager.joinBand(inviteCode: inviteCode, userName: userName, instrument: nil)
            // After joining, go to profile step to fill in details
            withAnimation { step = .createProfile }
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
                    let resized = resizedImage(logoImage, maxDimension: 512)
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
                let resized = resizedImage(photoImage, maxDimension: 512)
                if let jpegData = resized.jpegData(compressionQuality: 0.7) {
                    await bandManager.uploadAvatar(imageData: jpegData)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    // MARK: - Helpers

    private func resizedImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
