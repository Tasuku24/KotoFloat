import SwiftUI

struct PopupContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

extension View {
    func reportPopupHeight() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: PopupContentHeightKey.self, value: proxy.size.height)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
