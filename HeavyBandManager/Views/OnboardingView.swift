import SwiftUI

struct OnboardingView: View {
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    switch step {
                    case .welcome: welcomeContent
                    case .create: createContent
                    case .join: joinContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
            }
            .background(Color.themeBg)
        }
    }

    // MARK: - Welcome

    private var welcomeContent: some View {
        VStack(spacing: 32) {
            Text("🎸")
                .font(.system(size: 56))
            Text("Heavy Band Manager")
                .font(.largeTitle).bold()
                .foregroundColor(.themeTextPrimary)
            Text("Find practice times that work for everyone.")
                .font(.body)
                .foregroundColor(.themeTextSecondary)

            VStack(spacing: 12) {
                actionCard(title: "Create a Band", subtitle: "Start a new band and invite members", icon: "plus.circle.fill", color: .themeAccent) {
                    step = .create
                }
                actionCard(title: "Join a Band", subtitle: "Enter an invite code from your bandmate", icon: "person.badge.plus", color: .themeSuccess) {
                    step = .join
                }
            }
        }
    }

    // MARK: - Create

    private var createContent: some View {
        VStack(spacing: 24) {
            Text("Create a Band")
                .font(.largeTitle).bold()
                .foregroundColor(.themeTextPrimary)

            VStack(spacing: 0) {
                formField("Band Name", text: $bandName)
                Divider().background(Color.themeBorder)
                formField("Your Name", text: $userName)
                Divider().background(Color.themeBorder)
                formField("Instrument", text: $instrument, placeholder: "Optional")
            }
            .background(Color.themeBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if let error = errorMessage {
                Text(error).font(.footnote).foregroundColor(.themeDanger)
            }

            HStack(spacing: 12) {
                Button("Back") { step = .welcome }
                    .foregroundColor(.themeAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.themeBgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    Task { await createBand() }
                } label: {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Get Started")
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(bandName.isEmpty || userName.isEmpty ? Color.themeAccent.opacity(0.3) : Color.themeAccent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(bandName.isEmpty || userName.isEmpty || isSubmitting)
            }
        }
    }

    // MARK: - Join

    private var joinContent: some View {
        VStack(spacing: 24) {
            Text("Join a Band")
                .font(.largeTitle).bold()
                .foregroundColor(.themeTextPrimary)

            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Invite Code")
                        .font(.footnote)
                        .foregroundColor(.themeTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("HBM-XXXX", text: $inviteCode)
                        .font(.title2.bold().monospaced())
                        .multilineTextAlignment(.center)
                        .autocapitalization(.allCharacters)
                        .foregroundColor(.themeTextPrimary)
                }
                .padding()

                Divider().background(Color.themeBorder)
                formField("Your Name", text: $userName)
                Divider().background(Color.themeBorder)
                formField("Instrument", text: $instrument, placeholder: "Optional")
            }
            .background(Color.themeBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if let error = errorMessage {
                Text(error).font(.footnote).foregroundColor(.themeDanger)
            }

            HStack(spacing: 12) {
                Button("Back") { step = .welcome }
                    .foregroundColor(.themeAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.themeBgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    Task { await joinBand() }
                } label: {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Join Band")
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(inviteCode.isEmpty || userName.isEmpty ? Color.themeSuccess.opacity(0.3) : Color.themeSuccess)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(inviteCode.isEmpty || userName.isEmpty || isSubmitting)
            }
        }
    }

    // MARK: - Components

    private func actionCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundColor(.themeTextPrimary)
                    Text(subtitle).font(.subheadline).foregroundColor(.themeTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.themeTextTertiary)
            }
            .padding()
            .background(Color.themeBgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func formField(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote)
                .foregroundColor(.themeTextSecondary)
            TextField(placeholder.isEmpty ? label : placeholder, text: text)
                .foregroundColor(.themeTextPrimary)
        }
        .padding()
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
