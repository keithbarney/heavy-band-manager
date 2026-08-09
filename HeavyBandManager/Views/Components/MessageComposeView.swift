import MessageUI
import SwiftUI

struct InviteMembersButton: View {
    let invitation: BandInvitation

    @State private var isPresentingMessages = false

    var body: some View {
        Group {
            if MFMessageComposeViewController.canSendText() {
                Button {
                    isPresentingMessages = true
                } label: {
                    Label("Invite Members", systemImage: "message.fill")
                        .foregroundStyle(.blue)
                }
                .accessibilityHint("Creates an editable invitation. You choose who receives it.")
            } else {
                ShareLink(
                    item: invitation.messageBody,
                    subject: Text(invitation.subject)
                ) {
                    Label("Share Invitation", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.blue)
                }
                .accessibilityHint("Opens sharing options for the band invitation.")
            }
        }
        .sheet(isPresented: $isPresentingMessages) {
            MessageComposeView(
                messageBody: invitation.messageBody,
                isPresented: $isPresentingMessages
            )
            .ignoresSafeArea()
        }
    }

}

private struct MessageComposeView: UIViewControllerRepresentable {
    let messageBody: String
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = nil
        controller.body = messageBody
        return controller
    }

    func updateUIViewController(
        _ uiViewController: MFMessageComposeViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        @Binding private var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            isPresented = false
        }
    }
}
