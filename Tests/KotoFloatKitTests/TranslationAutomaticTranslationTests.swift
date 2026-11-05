import AppKit
import Testing
@testable import KotoFloatKit

@MainActor struct TranslationAutomaticTranslationTests {
    @Test func compositionWaitsUntilTheSameTextIsCommitted() async throws {
        try await withEditor { model, service in
            model.editSource("日本語", isComposing: true)
            try await Task.sleep(for: .milliseconds(1150))
            #expect(await service.count == 0)
            #expect(model.sourceText == "日本語")
            model.editSource("日本語", isComposing: false)
            try await Task.sleep(for: .milliseconds(1100))
            await waitFor { await service.count == 1 }
            #expect(await service.inputs.map(\.text) == ["日本語"])
        }
    }

    @Test func typingWaitsForOneIdleSecondAndTranslatesOnlyTheLatestDraft() async throws {
        try await withEditor { model, service in
            model.editSource("First draft")
            try await Task.sleep(for: .milliseconds(600))
            #expect(await service.count == 0)
            model.editSource("Latest draft")
            try await Task.sleep(for: .milliseconds(600))
            #expect(await service.count == 0)
            try await Task.sleep(for: .milliseconds(500))
            await waitFor { await service.count == 1 }
            #expect(await service.inputs.map(\.text) == ["Latest draft"])
            await service.emit("Latest translation", at: 0)
            await service.finish(at: 0)
            await waitFor { model.state == .completed }
            #expect(model.resultText == "Latest translation")
        }
    }

    @Test func explicitTranslationConsumesThePendingAutomaticRequest() async throws {
        try await withEditor { model, service in
            model.editSource("Translate now")
            model.translateSource()
            await waitFor { await service.count == 1 }
            await service.emit("Immediate result", at: 0)
            await service.finish(at: 0)
            await waitFor { model.state == .completed }
            let document = model.documentID
            try await Task.sleep(for: .milliseconds(1150))
            #expect(await service.count == 1)
            #expect(model.documentID == document)
            #expect(model.resultText == "Immediate result")
        }
    }

    @Test(arguments: ["cancel", "clear", "blank", "oversized", "settings", "language", "confirmation", "edited", "restored"])
    func obsoleteOrUnsafeDraftsDoNotTranslateAutomatically(_ change: String) async throws {
        try await withEditor { model, service in
            model.start(text: CapturedText(text: "Original source", source: nil, bounds: nil, method: .manual))
            await waitFor { await service.count == 1 }
            await service.emit("Original result", at: 0)
            await service.finish(at: 0)
            await waitFor { model.state == .completed }
            model.editSource("New source")
            switch change {
            case "cancel": model.cancel()
            case "clear": model.cancel(clear: true)
            case "blank": model.editSource(" \n ")
            case "oversized": model.editSource(String(repeating: "x", count: 131_073))
            case "settings":
                try model.preferences.save(try ServerConfiguration(endpoint: "https://other.fixture.invalid", model: "other"),
                    tokenUpdate: .keep, credentials: MemoryCredentials())
            case "language": model.preferences.targetLanguage = .french
            case "confirmation": model.clearDocument()
            case "edited": model.editTranslation("Keep my wording")
            default: model.editSource("Original source")
            }
            let result = model.resultText
            try await Task.sleep(for: .milliseconds(1150))
            #expect(await service.count == 1)
            #expect(model.resultText == result)
        }
    }

    @Test func automaticRetranslationRejectsLateOutputFromThePreviousSource() async throws {
        try await withEditor { model, service in
            model.start(text: CapturedText(text: "Old source", source: nil, bounds: nil, method: .manual))
            await waitFor { await service.count == 1 }
            model.editSource("New source")
            try await Task.sleep(for: .milliseconds(1100))
            await waitFor { await service.count == 2 }
            await service.emit("Obsolete output", at: 0)
            await service.finish(at: 0)
            await service.emit("Current output", at: 1)
            await service.finish(at: 1)
            await waitFor { model.state == .completed }
            #expect(model.sourceText == "New source")
            #expect(model.resultText == "Current output")
        }
    }

    private func withEditor(_ body: (TranslationModel, ControlledTranslator) async throws -> Void) async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            do { try await body(model, service) }
            catch { model.cancel(); await service.finishAll(); throw error }
            model.cancel()
            await service.finishAll()
        }
    }
}
