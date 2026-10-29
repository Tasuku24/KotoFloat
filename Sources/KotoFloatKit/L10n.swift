import Foundation

@MainActor enum L10n {
    static func text(_ key: String) -> String {
        AppLocalization.shared.text(key)
    }
}
