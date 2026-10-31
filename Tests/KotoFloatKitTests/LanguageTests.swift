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
    @Test func everySelectableLanguageBuildsAnExplicitPromptAndGlossaryRoundTrips() throws {
        let client = OpenAITranslationClient(server: try ServerConfiguration(endpoint: "https://fixture.invalid", model: "fixture"), token: nil)
        for language in TranslationLanguage.targets {
            let request = try client.request(for: TranslationInput(text: "Synthetic text", source: .automatic, target: language))
            let body = try #require(request.httpBody)
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let messages = try #require(json["messages"] as? [[String: String]])
            #expect(messages[0]["content"]?.contains("into \(language.promptName).") == true)
            let entry = GlossaryEntry(sourceTerm: "term", preferredTranslation: "preferred", sourceLanguage: language == .english ? .japanese : .english, targetLanguage: language)
            let library = try GlossaryLibrary(glossaries: [Glossary(name: "Fixture", entries: [entry])]).validated()
            #expect(try JSONDecoder().decode(GlossaryLibrary.self, from: JSONEncoder().encode(library)) == library)
            let preview = GlossaryCSV.preview(data: GlossaryCSV.export([entry]), existing: [], policy: .keepBoth)
            #expect(preview.canImport)
            #expect(preview.entries.first?.targetLanguage == language)
        }
        let entry = GlossaryEntry(sourceTerm: "voltage", preferredTranslation: "電壓", sourceLanguage: .english, targetLanguage: .chineseTraditional)
        let glossary = Glossary(name: "Fixture", entries: [entry])
        #expect(GlossaryMatcher.context(for: "voltage", source: .english, target: .chineseTraditional, glossary: glossary).entries == [entry])
        #expect(GlossaryMatcher.context(for: "voltage", source: .english, target: .chineseSimplified, glossary: glossary).entries.isEmpty)
    }

    @Test func languageSwitchKeepsActiveRequestAndEditedDraftUntilExplicitRetranslation() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            defer { model.cancel() }
            model.start(text: CapturedText(text: "Synthetic", source: nil, bounds: nil, method: .manual))
            await waitFor { await service.count == 1 }
            preferences.targetLanguage = .chineseTraditional
            #expect(model.input?.target == .japanese)
            #expect(model.directionChanged)
            await service.emit("Generated", at: 0)
            await service.finish(at: 0)
            await waitFor { model.state == .completed }
            model.editTranslation("Keep my edit")
            let document = model.documentID
            preferences.targetLanguage = .portugueseBrazil
            #expect(model.resultText == "Keep my edit")
            #expect(model.documentID == document)
            #expect(model.canUndo)
            #expect(await service.count == 1)
            model.retranslate()
            preferences.targetLanguage = .french
            model.confirmPendingAction()
            #expect(await service.count == 1)
            #expect(model.resultText == "Keep my edit")
            model.retranslate()
            preferences.favoriteLanguages = [.french, .german]
            model.confirmPendingAction()
            await waitFor { await service.count == 2 }
            #expect(await service.inputs.last?.target == .french)
            await service.emit("New generation", at: 1)
            await service.finish(at: 1)
            await waitFor { model.state == .completed }
            #expect(model.output == "New generation")
            await service.emit(" stale", at: 0)
            #expect(model.output == "New generation")
        }
    }

}
