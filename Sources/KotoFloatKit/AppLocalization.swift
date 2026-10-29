import Foundation
import Observation

enum AppLanguage: String, CaseIterable {
    case system, english = "en", japanese = "ja"

    func resolvedLanguage(preferredLanguages: [String]) -> String {
        switch self {
        case .english, .japanese: return rawValue
        case .system:
            return Bundle.preferredLocalizations(from: ["en", "ja"], forPreferences: preferredLanguages).first ?? "en"
        }
    }
}

@MainActor @Observable
final class AppLocalization {
    static let shared = AppLocalization()
    static let didChange = Notification.Name("KotoFloat.languageDidChange")
    @ObservationIgnored private let defaults: UserDefaults
    var language: AppLanguage {
        didSet {
            guard oldValue != language else { return }
            defaults.set(language.rawValue, forKey: "app.language")
            NotificationCenter.default.post(name: Self.didChange, object: self)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = defaults.string(forKey: "app.language").flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    var locale: Locale { Locale(identifier: language.resolvedLanguage(preferredLanguages: Locale.preferredLanguages)) }

    func text(_ key: String) -> String {
        let identifier = language.resolvedLanguage(preferredLanguages: Locale.preferredLanguages)
        guard let path = Bundle.module.path(forResource: identifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.module.localizedString(forKey: key, value: nil, table: nil)
        }
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
