import Foundation
import Testing
@testable import KotoFloatKit

@MainActor struct PopupPresentationTests {
    @Test(arguments: [true, false])
    func normalLoadingHasNoBannerButChangedLanguageRemainsVisible(changeSource: Bool) async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            defer { model.cancel() }
            model.start(text: CapturedText(text: "Synthetic", source: nil, bounds: nil, method: .manual))
            await waitFor { await service.count == 1 }
            let view = PopupTranslationStatusView(model: model, openSettings: {}, showDetails: {})
            #expect(view.notice == nil)
            if changeSource { preferences.sourceLanguage = .english }
            else { preferences.targetLanguage = .french }
            #expect(model.state == .running)
            #expect(view.notice == L10n.text("editor.directionChanged"))
            #expect(await service.count == 1)
            await service.finishAll()
        }
    }

    @Test func changedGlossaryRemainsVisibleWhileOldRequestStreams() async throws {
        try await withTranslationContext { preferences, credentials in
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = GlossaryStore(url: directory.appendingPathComponent("glossaries.json"))
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, glossaries: store,
                clientFactory: { _, _ in service })
            defer { model.cancel() }
            model.start(text: CapturedText(text: "Synthetic", source: nil, bounds: nil, method: .manual))
            await waitFor { await service.count == 1 }
            try store.create(name: "Changed")
            let view = PopupTranslationStatusView(model: model, openSettings: {}, showDetails: {})
            #expect(model.state == .running)
            #expect(view.notice == L10n.text("glossary.changed"))
            #expect(await service.count == 1)
            await service.finishAll()
        }
    }
}
