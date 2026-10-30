import AppKit
import Testing
@testable import KotoFloatKit

@MainActor struct TranslationEditorTests {
    @Test func editingKeepsGeneratedTextAndUndoRedoUsesTheSameDocument() async throws {
        try await withEditor { model, service in
            await complete(model, service)
            let id = model.documentID
            let revision = model.revision
            model.editTranslation("Edited result")
            #expect(model.output == "Generated result")
            #expect(model.resultText == "Edited result")
            #expect(model.hasEdits)
            #expect(model.revision > revision)
            #expect(model.documentID == id)
            model.undoManager.undo()
            #expect(model.resultText == "Generated result")
            #expect(!model.hasEdits)
            model.undoManager.redo()
            #expect(model.resultText == "Edited result")
            #expect(await service.count == 1)
        }
    }

    @Test func retranslationRequiresConfirmationAndResetsUndoForNewGeneration() async throws {
        try await withEditor { model, service in
            await complete(model, service)
            model.editTranslation("Keep this")
            model.retranslate()
            #expect(model.pendingAction != nil)
            #expect(model.resultText == "Keep this")
            #expect(await service.count == 1)
            model.keepEditing()
            #expect(model.pendingAction == nil)
            model.retranslate()
            model.confirmPendingAction()
            await waitFor { await service.count == 2 }
            #expect(!model.undoManager.canUndo)
            await service.emit("Second generation", at: 1)
            await service.finish(at: 1)
            await waitFor { model.state == .completed }
            model.undoManager.undo()
            #expect(model.resultText == "Second generation")
            #expect(!model.hasEdits)
        }
    }

    @Test func captureCannotOverwriteEditedOrUntranslatedDrafts() async throws {
        try await withEditor { model, service in
            await complete(model, service)
            model.editTranslation("My wording")
            model.start(text: captured("New selection"))
            #expect(model.sourceText == "Source")
            #expect(model.resultText == "My wording")
            #expect(await service.count == 1)
            model.editTranslation("Newer wording")
            model.confirmPendingAction()
            #expect(model.resultText == "Newer wording")
            #expect(await service.count == 1)
            model.start(text: captured("New selection"))
            model.confirmPendingAction()
            await waitFor { await service.count == 2 }
            #expect(model.sourceText == "New selection")
            model.editSource("Untranslated draft")
            model.start(text: captured("Another selection"))
            #expect(model.sourceText == "Untranslated draft")
            #expect(model.pendingAction != nil)
        }
    }

    @Test func sourceEditsCancelStreamsAndLateResponsesCannotChangeDraft() async throws {
        try await withEditor { model, service in
            model.start(text: captured("Source"))
            await waitFor { await service.count == 1 }
            await service.emit("Partial", at: 0)
            model.editTranslation("Not accepted while streaming")
            #expect(model.resultText == "Partial")
            model.editSource("Changed source")
            #expect(model.state == .cancelled)
            #expect(model.sourceChanged)
            let revision = model.revision
            await service.emit(" obsolete", at: 0)
            await service.finish(at: 0)
            await Task.yield()
            #expect(model.sourceText == "Changed source")
            #expect(model.output == "Partial")
            #expect(model.revision == revision)
            model.translateSource()
            await waitFor { await service.count == 2 }
            #expect(await service.inputs.last?.text == "Changed source")
        }
    }

    @Test func clearRequiresConfirmationAndStaleSettingsCannotApproveDiscard() async throws {
        try await withEditor { model, service in
            model.editSource("Draft")
            model.clearDocument()
            #expect(model.sourceText == "Draft")
            model.preferences.targetLanguage = .english
            model.confirmPendingAction()
            #expect(model.sourceText == "Draft")
            model.clearDocument()
            model.confirmPendingAction()
            #expect(model.sourceText.isEmpty)
            #expect(model.output.isEmpty)
            #expect(model.state == .idle)
            #expect(!model.undoManager.canUndo)
            #expect(await service.count == 0)
        }
    }

    @Test func swapRequiresExplicitCurrentDirectionAndUsesEditedResultWithoutSending() async throws {
        try await withEditor { model, service in
            await complete(model, service)
            #expect(!model.canSwapLanguages)
            model.preferences.sourceLanguage = .english
            #expect(model.directionChanged)
            #expect(!model.canSwapLanguages)
            model.retranslate()
            await waitFor { await service.count == 2 }
            await service.emit("日本語の訳", at: 1)
            await service.finish(at: 1)
            await waitFor { model.state == .completed }
            model.editTranslation("編集した訳")
            #expect(model.canSwapLanguages)
            model.swapLanguages()
            #expect(model.sourceText == "Source")
            model.confirmPendingAction()
            #expect(model.sourceText == "編集した訳")
            #expect(model.preferences.sourceLanguage == .japanese)
            #expect(model.preferences.targetLanguage == .english)
            #expect(model.output.isEmpty)
            #expect(await service.count == 2)
            model.translateSource()
            await waitFor { await service.count == 3 }
            #expect(await service.inputs.last?.text == "編集した訳")
            #expect(await service.inputs.last?.target == .english)
        }
    }

    @Test func sourceUndoAndBlankOrOversizedInputNeverSendInvalidRequests() async throws {
        try await withEditor { model, service in
            model.editSource("First draft")
            model.editSource("Second draft")
            model.undoManager.undo()
            #expect(model.sourceText == "First draft")
            model.undoManager.redo()
            #expect(model.sourceText == "Second draft")
            model.editSource(" \n ")
            model.translateSource()
            #expect(!model.canTranslate)
            model.editSource(String(repeating: "あ", count: 43_691))
            model.translateSource()
            #expect(!model.canTranslate)
            #expect(await service.count == 0)
            #expect(!model.sourceText.isEmpty)
        }
    }

    @Test func manualAndUnconfirmedCapturePreserveExistingEdits() async throws {
        try await withEditor { model, service in
            await complete(model, service)
            model.editTranslation("Keep me")
            let capture = CaptureModel()
            model.bind(to: capture)
            capture.beginManualEntry()
            #expect(model.resultText == "Keep me")
            let environment = CaptureEnvironmentStub()
            environment.selection = .unavailable
            capture.start(using: SelectionCapture(environment: environment), completion: {})
            await waitFor { if case .needsConfirmation = capture.state { return true }; return false }
            #expect(model.resultText == "Keep me")
            #expect(model.pendingAction == nil)
            #expect(await service.count == 1)
            capture.confirmCopy()
            #expect(model.pendingAction != nil)
            #expect(await service.count == 1)
        }
    }

    @Test func copyUsesEditedCompletedTextAndNeverClearsClipboardForPartialOrEmptyResults() async throws {
        try await withEditor { model, service in
            let pasteboard = NSPasteboard(name: .init("KotoFloatEditorTests.\(UUID())"))
            defer { pasteboard.releaseGlobally() }
            pasteboard.setString("Existing", forType: .string)
            #expect(!model.copyResult(to: pasteboard))
            #expect(pasteboard.string(forType: .string) == "Existing")
            await complete(model, service)
            model.editTranslation("Edited copy")
            #expect(model.copyResult(to: pasteboard))
            #expect(pasteboard.string(forType: .string) == "Edited copy")
            model.editTranslation("")
            #expect(!model.copyResult(to: pasteboard))
            #expect(pasteboard.string(forType: .string) == "Edited copy")
        }
    }

    private func captured(_ text: String) -> CapturedText {
        CapturedText(text: text, source: nil, bounds: nil, method: .manual)
    }
    private func complete(_ model: TranslationModel, _ service: ControlledTranslator) async {
        model.start(text: captured("Source"))
        await waitFor { await service.count == 1 }
        await service.emit("Generated result", at: 0)
        await service.finish(at: 0)
        await waitFor { model.state == .completed }
    }
    private func withEditor(_ body: (TranslationModel, ControlledTranslator) async throws -> Void) async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            try await body(model, service)
            model.cancel()
            await service.finishAll()
        }
    }
}
