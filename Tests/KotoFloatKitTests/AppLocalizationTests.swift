import Foundation
import Observation
import Testing
@testable import KotoFloatKit

@MainActor struct AppLocalizationTests {
    @Test func freshAndInvalidPreferencesFollowSystem() throws {
        try withDefaults { defaults in
            #expect(AppLocalization(defaults: defaults).language == .system)
            defaults.set("unknown", forKey: "app.language")
            #expect(AppLocalization(defaults: defaults).language == .system)
        }
    }

    @Test func explicitChoicePersistsAndSystemCanBeRestored() throws {
        try withDefaults { defaults in
            let localization = AppLocalization(defaults: defaults)
            localization.language = .japanese
            #expect(AppLocalization(defaults: defaults).language == .japanese)
            localization.language = .english
            #expect(AppLocalization(defaults: defaults).language == .english)
            localization.language = .system
            #expect(AppLocalization(defaults: defaults).language == .system)
        }
    }

    @Test func systemMatchesSupportedLanguagesAndFallsBackToEnglish() {
        #expect(AppLanguage.system.resolvedLanguage(preferredLanguages: ["ja-JP", "en-HK"]) == "ja")
        #expect(AppLanguage.system.resolvedLanguage(preferredLanguages: ["en-GB", "ja"]) == "en")
        #expect(AppLanguage.system.resolvedLanguage(preferredLanguages: ["fr-FR", "ja-JP"]) == "ja")
        #expect(AppLanguage.system.resolvedLanguage(preferredLanguages: ["fr-FR"]) == "en")
        #expect(AppLanguage.english.resolvedLanguage(preferredLanguages: ["ja-JP"]) == "en")
        #expect(AppLanguage.japanese.resolvedLanguage(preferredLanguages: ["en-HK"]) == "ja")
    }

    @Test func switchingUsesActualLocalizedResourcesImmediately() throws {
        try withDefaults { defaults in
            let localization = AppLocalization(defaults: defaults)
            localization.language = .english
            #expect(localization.text("settings.tab.general") == "General")
            #expect(localization.text("menu.settings") == "Settings…")
            localization.language = .japanese
            #expect(localization.text("settings.tab.general") == "一般")
            #expect(localization.text("menu.settings") == "設定…")
        }
    }

    @Test func changedLanguageNotifiesNativeMenusButSameChoiceDoesNot() throws {
        try withDefaults { defaults in
            let localization = AppLocalization(defaults: defaults)
            let counter = NotificationCounter()
            let observer = NotificationCenter.default.addObserver(forName: AppLocalization.didChange,
                object: localization, queue: nil) { _ in counter.increment() }
            defer { NotificationCenter.default.removeObserver(observer) }
            localization.language = .japanese
            localization.language = .japanese
            localization.language = .english
            #expect(counter.value == 2)
        }
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "KotoFloatLanguageTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }
}

private final class NotificationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.lock(); defer { lock.unlock() }; count += 1 }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}
