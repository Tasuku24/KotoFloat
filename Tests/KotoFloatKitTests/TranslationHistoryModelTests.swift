import AppKit
import Testing
@testable import KotoFloatKit

@MainActor struct TranslationHistoryModelTests {
    @Test func completedRetranslationsAndEditsUpdateOneHistoryUntilANewCapture() async throws {
        try await withHistory { model, service, history in
            model.start(text: capture("Source"))
            await finish(model, service, at: 0, text: "First result")
            await history.search("")
            let id = try #require(history.entries.first?.id)
            model.editTranslation("My wording\n\nNext paragraph")
            await history.flush()
            #expect(await history.entry(id: id)?.translation == "My wording\n\nNext paragraph")
            model.undoManager.undo()
            await history.flush()
            #expect(await history.entry(id: id)?.translation == "First result")
            model.editSource("Revised source")
            model.translateSource()
            await finish(model, service, at: 1, text: "Revised result")
            await history.search("")
            #expect(history.entries.map(\.id) == [id])
            #expect(await history.entry(id: id)?.source == "Revised source")
            model.start(text: capture("New selection"))
            await finish(model, service, at: 2, text: "New result")
            await history.search("")
            #expect(history.entries.count == 2)
        }
    }

    @Test func incompleteRetranslationDoesNotReplaceTheCompletedHistory() async throws {
        try await withHistory { model, service, history in
            model.start(text: capture("Source"))
            await finish(model, service, at: 0, text: "Completed")
            await history.search("")
            let id = try #require(history.entries.first?.id)
            model.editSource("New source")
            model.translateSource()
            await waitFor { await service.count == 2 }
            await service.emit("Incomplete", at: 1)
            await service.finish(at: 1, error: TranslationFailure.interrupted)
            await waitFor { model.state == .failed(.interrupted) }
            await history.flush()
            #expect(await history.entry(id: id)?.source == "Source")
            #expect(await history.entry(id: id)?.translation == "Completed")
        }
    }

    @Test(arguments: [false, true])
    func reopeningImmediatelyReplacesTheCurrentDocumentWithoutSending(wasTranslating: Bool) async throws {
        try await withHistory { model, service, history in
            model.start(text: capture("Saved source"))
            await finish(model, service, at: 0, text: "Saved result")
            await history.search("")
            let id = try #require(history.entries.first?.id)
            let entry = try #require(await history.entry(id: id))
            if wasTranslating {
                model.start(text: capture("In-flight source"))
                await waitFor { await service.count == 2 }
            } else {
                model.editSource("Pending draft")
            }
            model.restoreHistory(entry)
            #expect(model.sourceText == "Saved source")
            #expect(model.resultText == "Saved result")
            #expect(model.state == .completed)
            #expect(!model.hasEdits)
            #expect(!model.canUndo)
            if wasTranslating {
                await service.emit("Obsolete result", at: 1)
                await service.finish(at: 1)
            }
            try await Task.sleep(for: .milliseconds(1100))
            #expect(model.resultText == "Saved result")
            #expect(await service.count == (wasTranslating ? 2 : 1))
        }
    }

    @Test func deletedActiveHistoryDoesNotReturnAfterEditingOrRetranslating() async throws {
        try await withHistory { model, service, history in
            model.start(text: capture("Source"))
            await finish(model, service, at: 0, text: "Completed")
            await history.search("")
            let id = try #require(history.entries.first?.id)
            await history.delete(id: id)
            model.editTranslation("Edited after deletion")
            await history.flush()
            model.translateSource()
            await finish(model, service, at: 1, text: "Retranslated after deletion")
            await history.search("")
            #expect(history.entries.isEmpty)
        }
    }

    private func capture(_ text: String) -> CapturedText { CapturedText(text: text, source: nil, bounds: nil, method: .manual) }

    private func finish(_ model: TranslationModel, _ service: ControlledTranslator, at index: Int, text: String) async {
        await waitFor { await service.count == index + 1 }
        await service.emit(text, at: index)
        await service.finish(at: index)
        await waitFor { model.state == .completed }
    }

    private func withHistory(_ body: (TranslationModel, ControlledTranslator, TranslationHistoryStore) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("KotoFloatHistoryModelTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try await withTranslationContext { preferences, credentials in
            let history = TranslationHistoryStore(url: directory.appendingPathComponent("history.sqlite"))
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, history: history, clientFactory: { _, _ in service })
            do { try await body(model, service, history) }
            catch { model.cancel(); await service.finishAll(); await history.flush(); throw error }
            model.cancel()
            await service.finishAll()
            await history.flush()
        }
    }
}
