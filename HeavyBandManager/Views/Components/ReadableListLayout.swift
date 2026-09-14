import SwiftUI

/// Keep lists readable in a wide iPad window while retaining system phone insets.
struct ReadableListLayout: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var availableWidth: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.horizontal,
                             sizeClass == .regular ? max(0, (availableWidth - 920) / 2) : 0)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.width - geometry.safeAreaInsets.leading - geometry.safeAreaInsets.trailing
            } action: { width in
                availableWidth = width
            }
    }
}
