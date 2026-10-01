import SwiftUI
import EventKit
import MessageUI
import UserNotifications

struct FeedbackView: View {
    static let supportEmail = "keithbarneydesign@gmail.com"

    @Environment(\.dismiss) private var dismiss
    @State var category: FeedbackCategory
    let source: String
    let context: String?

    @State private var message = ""
    @State private var includeContext = false
    @State private var includeDiagnostics = true
    @State private var notificationPermission = "Not checked"
    @State private var showMail = false
    @State private var showSubmissionOptions = false
    @State private var mailOutcome: MFMailComposeResult?
    @State private var status: String?
    @State private var showStatus = false
    @State private var confirmDiscard = false
    @FocusState private var isEditingMessage: Bool

    private var hasMessage: Bool { draft.hasMessage }

    private var calendarPermission: String {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return "Not requested"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .fullAccess: return "Full access"
        case .writeOnly: return "Write only"
        default: return "Other"
        }
    }

    private var draft: FeedbackDraft {
        FeedbackDraft(
            category: category,
            message: message,
            context: context,
            includeContext: includeContext,
            diagnostics: FeedbackDiagnostics(
                appVersion: "\(Bundle.main.marketingVersion) (\(Bundle.main.buildNumber))",
                osVersion: UIDevice.current.systemVersion,
                calendarPermission: calendarPermission,
                notificationPermission: notificationPermission,
                source: source
            ),
            includeDiagnostics: includeDiagnostics
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if FeedbackEnvironment.isMock {
                    Section { Label("Mock data", systemImage: "testtube.2") }
                }
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(FeedbackCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    TextField("What happened, or what would you like to see?", text: $message, axis: .vertical)
                        .lineLimit(5...12)
                        .focused($isEditingMessage)
                        .accessibilityLabel("Your feedback")
                        .accessibilityIdentifier("feedback-message")
                } footer: {
                    Text("Tell us what you tried and what happened. For a scheduling problem, describe the expected availability or practice time and your time zone. Avoid sharing other members’ personal details.")
                }

                Section("Include in your email") {
                    if let context {
                        Toggle("Include context: \(context)", isOn: $includeContext)
                    }
                    Toggle("Include app and permission details", isOn: $includeDiagnostics)
                }

                Section("Email preview") {
                    Text(draft.body)
                        .accessibilityIdentifier("feedback-preview")
                        .font(.callout)
                        .textSelection(.enabled)
                }

                Section {
                    if !FeedbackEnvironment.canSendMail {
                        Text("Mail isn’t configured on this device. Copy your feedback and send it with your preferred email app.")
                            .foregroundStyle(.secondary)
                    }
                    Text(Self.supportEmail)
                        .textSelection(.enabled)
                    Button("Copy Email Address") {
                        UIPasteboard.general.string = Self.supportEmail
                        presentStatus("Email address copied.")
                    }
                    Button("Copy Feedback") {
                        copyFeedback()
                    }
                    .disabled(!hasMessage)
                } footer: {
                    Text("Nothing is sent automatically. Your email includes your sender address and the details shown above. Calendar contents, member details, and your band’s schedule aren’t attached.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasMessage { confirmDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit", action: submit)
                        .fontWeight(.semibold)
                        .disabled(!hasMessage)
                        .accessibilityHint(FeedbackEnvironment.canSendMail ? "Opens email for review before sending" : "Shows options to copy and email your feedback")
                }
            }
            .interactiveDismissDisabled(hasMessage)
            .confirmationDialog("Discard this feedback?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    message = ""
                    dismiss()
                }
            }
            .sheet(isPresented: $showMail, onDismiss: handleMailDismissal) {
                FeedbackMailComposer(
                    subject: draft.subject,
                    messageBody: draft.body
                ) { result in
                    mailOutcome = result
                    showMail = false
                }
            }
            .confirmationDialog("Submit Feedback", isPresented: $showSubmissionOptions, titleVisibility: .visible) {
                Button("Copy Feedback") { copyFeedback() }
                Button("Copy Email Address") {
                    UIPasteboard.general.string = Self.supportEmail
                    presentStatus("Email address copied.")
                }
            } message: {
                Text("Mail isn’t configured on this device. Copy your feedback and email it to \(Self.supportEmail) using your preferred email app. Nothing is sent until you send that email.")
            }
            .alert("Feedback", isPresented: $showStatus) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(status ?? "")
            }
            .task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                switch settings.authorizationStatus {
                case .notDetermined: notificationPermission = "Not requested"
                case .denied: notificationPermission = "Denied"
                case .authorized: notificationPermission = "Allowed"
                case .provisional: notificationPermission = "Provisional"
                case .ephemeral: notificationPermission = "Ephemeral"
                @unknown default: notificationPermission = "Other"
                }
            }
        }
    }

    private func submit() {
        isEditingMessage = false
        if FeedbackEnvironment.canSendMail {
            showMail = true
        } else {
            showSubmissionOptions = true
        }
    }

    private func copyFeedback() {
        UIPasteboard.general.string = draft.body
        presentStatus("Feedback copied, not sent. Paste it into an email to \(Self.supportEmail).")
    }

    private func presentStatus(_ text: String) {
        status = text
        showStatus = true
    }

    private func handleMailDismissal() {
        defer { mailOutcome = nil }
        switch mailOutcome {
        case .sent:
            message = ""
            presentStatus("Your email was queued in Mail. Thank you for your feedback.")
        case .saved:
            presentStatus("Your email was saved in Mail drafts.")
        case .failed:
            presentStatus("Mail couldn’t queue your email. Your feedback is still here; try again or copy it into another email app.")
        default:
            break
        }
    }
}

struct FeedbackMailComposer: UIViewControllerRepresentable {
    let subject: String
    let messageBody: String
    let onFinish: (MFMailComposeResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.setToRecipients([FeedbackView.supportEmail])
        controller.setSubject(subject)
        controller.setMessageBody(messageBody, isHTML: false)
        controller.mailComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) { }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult) -> Void

        init(onFinish: @escaping (MFMailComposeResult) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish(error == nil ? result : .failed)
        }
    }
}
