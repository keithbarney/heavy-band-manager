import SwiftUI

struct FeedbackButton: View {
    var label = "Send Feedback"
    var category: FeedbackCategory = .general
    var source = "Settings"
    var context: String? = nil

    @EnvironmentObject private var presentation: FeedbackPresentation

    var body: some View {
        Button {
            presentation.route = .feedback(category, source: source, context: context)
        } label: {
            Label(label, systemImage: "bubble.left.and.text.bubble.right")
        }
    }
}
