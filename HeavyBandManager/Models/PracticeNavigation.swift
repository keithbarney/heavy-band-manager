import SwiftUI

@MainActor
final class PracticeNavigation: ObservableObject {
    @Published var pending: PracticeRoute?
    @Published var requestID = UUID()
    @Published var day: String?
    @Published var showAllBands = false

    func open(_ url: URL) {
        if let route = PracticeRoute(url: url) {
            showAllBands = false
            pending = route
        } else if url.scheme == PracticeRoute.scheme, url.host == "practices", url.path.isEmpty || url.path == "/" {
            pending = nil
            showAllBands = true
        } else if url.scheme == PracticeRoute.scheme, url.host == "calendar" {
            showAllBands = false
            pending = nil
        } else { return }
        day = nil
        requestID = UUID()
    }
}
