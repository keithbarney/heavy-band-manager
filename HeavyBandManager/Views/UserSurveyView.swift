import SwiftUI
import MessageUI

struct UserSurveyView: View {
    @EnvironmentObject private var userSurvey: UserSurveyStore
    @Environment(\.dismiss) private var dismiss
    @State private var showMail = false
    @State private var showSubmissionOptions = false
    @State private var mailOutcome: MFMailComposeResult?
    @State private var showStatus = false
    @State private var status = ""
    @State private var confirmClearDraft = false
    private enum Field: Hashable { case frustrations, usefulChange, replyAddress }
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                if FeedbackEnvironment.isMock {
                    Section { Label("Mock data", systemImage: "testtube.2") }
                }
                Section {
                    Text("Help us understand what works and what needs improving, including when setup hasn’t worked. Choose how you usually use the app to prepare an email. The written answers are optional.")
                        .listRowBackground(Color.clear)
                } footer: {
                    Text("Your draft stays on this device until you choose to send or copy it. Closing this screen keeps your draft for later.")
                }

                usageStyleSection

                Section("2. What has been frustrating or missing?") {
                    TextField("Optional", text: $userSurvey.draft.frustrations, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focusedField, equals: .frustrations)
                        .accessibilityLabel("What has been frustrating or missing? Optional")
                        .accessibilityIdentifier("survey-frustrations")
                }

                Section("3. What one change would make the app more useful?") {
                    TextField("Optional", text: $userSurvey.draft.usefulChange, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focusedField, equals: .usefulChange)
                        .accessibilityLabel("One change that would make the app more useful. Optional")
                }

                Section {
                    Toggle("I’m interested in a 15-minute conversation", isOn: Binding(
                        get: { userSurvey.draft.interviewOptIn },
                        set: { userSurvey.draft.setInterviewOptIn($0) }
                    ))
                    if userSurvey.draft.interviewOptIn {
                        TextField("Reply email (optional)", text: $userSurvey.draft.replyAddress)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .replyAddress)
                    }
                } header: {
                    Text("Optional conversation")
                } footer: {
                    Text(userSurvey.draft.interviewOptIn
                         ? "Keith may reply to arrange a time. Leave the reply email blank to use the address you send from. Turning this off removes your reply email from the draft."
                         : "You can share feedback without volunteering for an interview.")
                }

                Section("Email preview") {
                    Text(userSurvey.draft.body)
                        .accessibilityIdentifier("survey-preview")
                        .font(.callout)
                        .textSelection(.enabled)
                }

                Section {
                    if !FeedbackEnvironment.canSendMail {
                        Text("Mail isn’t configured on this device. Copy your answers and send them with your preferred email app.")
                            .foregroundStyle(.secondary)
                    }
                    Text(FeedbackView.supportEmail)
                        .textSelection(.enabled)
                    Button("Copy Email Address") {
                        UIPasteboard.general.string = FeedbackView.supportEmail
                        presentStatus("Email address copied.")
                    }
                    Button("Copy Survey Answers") {
                        copyFeedback()
                    }
                    .disabled(!userSurvey.draft.canSubmit)
                } footer: {
                    Text("Nothing is sent automatically. Email includes your sender address and the answers shown above. No calendar contents, band or member details, or usage analytics are attached.")
                }

                Section {
                    Toggle("Show survey invitations", isOn: Binding(
                        get: { !userSurvey.invitationsDisabled },
                        set: { userSurvey.invitationsDisabled = !$0 }
                    ))
                    if userSurvey.draft.hasContent {
                        Button("Delete Saved Survey Draft", role: .destructive) { confirmClearDraft = true }
                    }
                } footer: {
                    Text("You can always reopen this survey in Settings. Not Now or closing the survey pauses invitations for at least 30 days.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Three-Question Survey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit", action: submit)
                        .fontWeight(.semibold)
                        .disabled(!userSurvey.draft.canSubmit)
                        .accessibilityHint(FeedbackEnvironment.canSendMail ? "Opens email for review before sending" : "Shows options to copy and email your feedback")
                }
            }
            .onDisappear { userSurvey.deferInvitation() }
            .sheet(isPresented: $showMail, onDismiss: handleMailDismissal) {
                FeedbackMailComposer(subject: userSurvey.draft.subject, messageBody: userSurvey.draft.body) { result in
                    mailOutcome = result
                    showMail = false
                }
            }
            .confirmationDialog("Submit Survey", isPresented: $showSubmissionOptions, titleVisibility: .visible) {
                Button("Copy Survey Answers") { copyFeedback() }
                Button("Copy Email Address") {
                    UIPasteboard.general.string = FeedbackView.supportEmail
                    presentStatus("Email address copied.")
                }
            } message: {
                Text("Mail isn’t configured on this device. Copy your answers and email them to \(FeedbackView.supportEmail) using your preferred email app. Nothing is sent until you send that email.")
            }
            .alert("Survey", isPresented: $showStatus) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(status)
            }
            .confirmationDialog("Delete the saved survey draft from this device?", isPresented: $confirmClearDraft, titleVisibility: .visible) {
                Button("Delete Draft", role: .destructive) { userSurvey.clearDraft() }
            }
        }
    }

    private var usageStyleSection: some View {
        Section("1. How do you usually use Band Practice?") {
            ForEach(AppUsageStyle.allCases) { location in
                usageStyleRow(location)
            }
        }
    }

    private func usageStyleRow(_ location: AppUsageStyle) -> some View {
        let selected = userSurvey.draft.usageStyle == location
        return Button {
            userSurvey.draft.usageStyle = location
        } label: {
            HStack {
                Text(location.label)
                    .foregroundStyle(Color.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func submit() {
        focusedField = nil
        if FeedbackEnvironment.canSendMail {
            showMail = true
        } else {
            showSubmissionOptions = true
        }
    }

    private func copyFeedback() {
        UIPasteboard.general.string = userSurvey.draft.body
        userSurvey.deferInvitation()
        presentStatus("Answers copied, not sent. Paste them into an email to \(FeedbackView.supportEmail). Your draft is still saved here.")
    }

    private func presentStatus(_ message: String) {
        status = message
        showStatus = true
    }

    private func handleMailDismissal() {
        defer { mailOutcome = nil }
        switch mailOutcome {
        case .sent:
            userSurvey.handleEmailOutcome(.queued)
            presentStatus("Your email was queued in Mail. Thank you. Automatic survey invitations are now off, and your local draft has been cleared.")
        case .saved:
            userSurvey.handleEmailOutcome(.saved)
            presentStatus("Saved in Mail drafts, not sent. Your answers are also still here.")
        case .failed:
            userSurvey.handleEmailOutcome(.failed)
            presentStatus("Mail couldn’t queue your email. Your answers are still here; try again or copy them into another email app.")
        case .cancelled:
            userSurvey.handleEmailOutcome(.cancelled)
        default:
            break
        }
    }
}
