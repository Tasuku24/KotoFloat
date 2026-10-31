import Foundation

enum TranslationLanguage: String, CaseIterable, Codable, Sendable {
    case automatic
    case english = "en", japanese = "ja"
    case chineseSimplified = "zh-Hans", chineseTraditional = "zh-Hant", korean = "ko"
    case french = "fr", german = "de", spanish = "es"
    case portugueseBrazil = "pt-BR", portuguesePortugal = "pt-PT"
    case italian = "it", dutch = "nl", russian = "ru", ukrainian = "uk", polish = "pl"
    case czech = "cs", swedish = "sv", danish = "da", norwegian = "nb", finnish = "fi"
    case greek = "el", turkish = "tr", arabic = "ar", indonesian = "id", vietnamese = "vi"

    static var targets: [Self] { allCases.filter { $0 != .automatic } }

    var promptName: String {
        switch self {
        case .automatic: "the detected source language"
        case .english: "English"
        case .japanese: "Japanese"
        case .chineseSimplified: "Simplified Chinese"
        case .chineseTraditional: "Traditional Chinese"
        case .korean: "Korean"
        case .french: "French"
        case .german: "German"
        case .spanish: "Spanish"
        case .portugueseBrazil: "Portuguese (Brazil)"
        case .portuguesePortugal: "Portuguese (Portugal)"
        case .italian: "Italian"
        case .dutch: "Dutch"
        case .russian: "Russian"
        case .ukrainian: "Ukrainian"
        case .polish: "Polish"
        case .czech: "Czech"
        case .swedish: "Swedish"
        case .danish: "Danish"
        case .norwegian: "Norwegian Bokmål"
        case .finnish: "Finnish"
        case .greek: "Greek"
        case .turkish: "Turkish"
        case .arabic: "Arabic"
        case .indonesian: "Indonesian"
        case .vietnamese: "Vietnamese"
        }
    }

    func displayName(locale: Locale) -> String {
        if self == .automatic { return locale.language.languageCode?.identifier == "ja" ? "自動" : "Automatic" }
        return locale.localizedString(forIdentifier: rawValue) ?? promptName
    }

    var nativeName: String { displayName(locale: Locale(identifier: rawValue)) }

    @MainActor var title: String { displayName(locale: AppLocalization.shared.locale) }

    static func search(_ query: String, includeAutomatic: Bool) -> [Self] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return (includeAutomatic ? allCases : targets).filter { language in
            query.isEmpty || [language.rawValue, language.promptName, language.nativeName,
                language.displayName(locale: Locale(identifier: "en")), language.displayName(locale: Locale(identifier: "ja"))]
                .contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) != nil }
        }
    }
}
