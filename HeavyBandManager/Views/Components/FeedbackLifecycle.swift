import SwiftUI

@MainActor
final class FeedbackPresentation: ObservableObject {
    enum Route: Identifiable {
        case feedback(FeedbackCategory, source: String, context: String?)
        case survey

        var id: String {
            switch self {
            case .feedback: return "feedback"
            case .survey: return "survey"
            }
        }
    }

    @Published var route: Route?
}

/// Present from the stable app root, not a lazily recycled List row.
struct FeedbackLifecycle: ViewModifier {
    @Environment(\.scenePhase) private var phase
    @StateObject private var survey = UserSurveyStore()
    func body(content: Content) -> some View {
        content
            .modifier(FeedbackPresenter())
            .environmentObject(survey)
            .onChange(of: phase, initial: true) { _, phase in
                if phase == .active { survey.recordForeground() }
                if phase == .background { survey.recordBackground() }
            }
    }
}

/// A screen already presented modally needs its own host for nested feedback.
/// Reuse the inherited survey store so presentation never resets survey progress.
struct FeedbackPresenter: ViewModifier {
    @EnvironmentObject private var survey: UserSurveyStore
    @StateObject private var presentation = FeedbackPresentation()

    func body(content: Content) -> some View {
        content
            .environmentObject(presentation)
            .sheet(item: $presentation.route) { route in
                Group {
                    switch route {
                    case let .feedback(category, source, context):
                        FeedbackView(category: category, source: source, context: context)
                    case .survey:
                        UserSurveyView()
                    }
                }
                .environmentObject(survey)
            }
    }
}
