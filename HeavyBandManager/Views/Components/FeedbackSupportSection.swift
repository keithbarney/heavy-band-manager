import SwiftUI

struct FeedbackSupportSection: View {
    @EnvironmentObject private var userSurvey: UserSurveyStore
    @EnvironmentObject private var presentation: FeedbackPresentation

    var body: some View {
        Section("Feedback & Support") {
            FeedbackButton()
            Button {
                userSurvey.deferInvitation()
                presentation.route = .survey
            } label: {
                Label(userSurvey.draft.hasContent ? "Continue Three-Question Survey" : "Take Three-Question Survey", systemImage: "text.bubble")
            }
            Toggle("Show survey invitations", isOn: Binding(
                get: { !userSurvey.invitationsDisabled },
                set: { userSurvey.invitationsDisabled = !$0 }
            ))
        }
    }
}

struct UserSurveyInvitationCard: View {
    @EnvironmentObject private var userSurvey: UserSurveyStore
    @EnvironmentObject private var presentation: FeedbackPresentation

    var body: some View {
        Group {
            if userSurvey.shouldInvite {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Help Improve the App").font(.headline)
                    Text("Optional. Tell us what works and what could be better.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        Button("Take a Three-Question Survey") { presentation.route = .survey }
                        Spacer()
                        Menu("Survey Options", systemImage: "ellipsis") {
                            Button("Not Now") { userSurvey.deferInvitation() }
                            Button("Don’t Ask Again") { userSurvey.invitationsDisabled = true }
                        }
                        .labelStyle(.iconOnly)
                    }
                }
                .padding()
            }
        }
    }
}
