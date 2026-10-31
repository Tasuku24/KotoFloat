import Foundation
import Testing
@testable import KotoFloatKit

@MainActor struct LanguageTests {
    @Test func searchesNamesCodesAndVariants() {
        #expect(TranslationLanguage.search(" 日本語 ", includeAutomatic: false) == [.japanese])
        #expect(TranslationLanguage.search("deutsch", includeAutomatic: false) == [.german])
        #expect(TranslationLanguage.search("FR", includeAutomatic: false).contains(.french))
        #expect(TranslationLanguage.search("繁体", includeAutomatic: false) == [.chineseTraditional])
        #expect(TranslationLanguage.search("pt-BR", includeAutomatic: false) == [.portugueseBrazil])
        #expect(TranslationLanguage.search("nonsense", includeAutomatic: false).isEmpty)
        #expect(!TranslationLanguage.search("", includeAutomatic: false).contains(.automatic))
        #expect(TranslationLanguage.search("", includeAutomatic: true).first == .automatic)
    }

    @Test func preservesLegacyValuesAndRoundTripsEveryLanguage() throws {
        #expect(TranslationLanguage.english.rawValue == "en")
        #expect(TranslationLanguage.japanese.rawValue == "ja")
        for language in TranslationLanguage.allCases {
            #expect(try JSONDecoder().decode(TranslationLanguage.self, from: JSONEncoder().encode(language)) == language)
            #expect(!language.promptName.isEmpty)
            #expect(!language.displayName(locale: Locale(identifier: "ja")).isEmpty)
        }
        #expect(TranslationLanguage.chineseTraditional.promptName.contains("Traditional"))
        #expect(TranslationLanguage.portugueseBrazil.promptName.contains("Brazil"))
    }

    @Test func restoresAndNormalizesFavoritesWithoutChangingDirectionOrServerRevision() throws {
        try withTranslationDefaults { defaults in
            defaults.set("ja", forKey: "translation.sourceLanguage")
            defaults.set("en", forKey: "translation.targetLanguage")
            let preferences = TranslationPreferences(defaults: defaults)
            #expect(preferences.favoriteLanguages == [.japanese, .english])
            preferences.favoriteLanguages = [.automatic, .french, .french, .german, .english, .japanese, .korean, .italian]
            #expect(preferences.favoriteLanguages == [.french, .german, .english, .japanese, .korean])
            let restored = TranslationPreferences(defaults: defaults)
            #expect(restored.favoriteLanguages == preferences.favoriteLanguages)
            #expect(restored.sourceLanguage == .japanese)
            #expect(restored.targetLanguage == .english)
            #expect(preferences.revision == 0)
            preferences.favoriteLanguages = []
            #expect(TranslationPreferences(defaults: defaults).favoriteLanguages.isEmpty)
            preferences.targetLanguage = .french
            #expect(TranslationPreferences(defaults: defaults).targetLanguage == .french)
        }
    }

    @Test func handlesInvalidSavedValuesAndRejectsAutomaticTarget() throws {
        try withTranslationDefaults { defaults in
            defaults.set("automatic", forKey: "translation.targetLanguage")
            defaults.set(["bogus", "automatic", "en", "en", "ja"], forKey: "translation.favoriteLanguages")
            let preferences = TranslationPreferences(defaults: defaults)
            #expect(preferences.targetLanguage == .japanese)
            #expect(preferences.favoriteLanguages == [.english, .japanese])
            preferences.targetLanguage = .automatic
            #expect(preferences.targetLanguage == .japanese)
        }
    }
}
