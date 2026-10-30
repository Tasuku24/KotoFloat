import AppKit
import Testing
@testable import KotoFloatKit

// Opt in with an already loaded model on the local server; output quality is not asserted.
// ローカルサーバーの読み込み済みモデルを明示した場合だけ実行し、訳文の品質は判定しない。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["KOTOFLOAT_LOCAL_MODEL"] != nil))
struct LocalModelIntegrationTests {
    private func configuration() throws -> ServerConfiguration {
        try ServerConfiguration(endpoint: "http://127.0.0.1:1234/v1",
                                model: #require(ProcessInfo.processInfo.environment["KOTOFLOAT_LOCAL_MODEL"]))
    }

    @Test @MainActor func actualGenerationPreservesEditorContracts() async throws {
        let server = try configuration()
        let client = OpenAITranslationClient(server: server, token: nil)
        #expect(try await client.models().contains(server.model))
        try await withTranslationContext { preferences, credentials in
            try preferences.save(server, tokenUpdate: .keep, credentials: credentials)
            preferences.sourceLanguage = .english
            preferences.targetLanguage = .japanese
            let model = TranslationModel(preferences: preferences, credentials: credentials)
            defer { model.cancel() }
            let capture = CaptureModel()
            model.bind(to: capture)
            capture.beginManualEntry()
            capture.manualText = "The voltage across the resistor is five volts."
            capture.acceptManualText()
            try await waitUntilFinished(model)
            try #require(model.state == .completed)
            #expect(!model.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(model.input?.source == .english)
            #expect(model.input?.target == .japanese)
            let generated = model.output
            let document = model.documentID
            let edited = "Edited acceptance result. 編集の確認。"
            model.editTranslation(edited)
            #expect(model.output == generated)
            #expect(model.documentID == document)
            model.undoManager.undo()
            #expect(model.resultText == generated)
            model.undoManager.redo()
            #expect(model.resultText == edited)
            let pasteboard = NSPasteboard(name: .init("KotoFloatLocalModel.\(UUID())"))
            defer { pasteboard.releaseGlobally() }
            #expect(model.copyResult(to: pasteboard))
            #expect(pasteboard.string(forType: .string) == edited)
            model.retranslate()
            #expect(model.pendingAction != nil)
            #expect(model.resultText == edited)
            model.keepEditing()
            #expect(model.resultText == edited)
            model.retranslate()
            model.confirmPendingAction()
            try await waitUntilFinished(model)
            try #require(model.state == .completed)
            #expect(model.documentID != document)
            #expect(!model.canUndo)
            model.editTranslation(edited)
            #expect(model.canSwapLanguages)
            model.swapLanguages()
            model.confirmPendingAction()
            #expect(model.sourceText == edited)
            #expect(preferences.sourceLanguage == .japanese)
            #expect(preferences.targetLanguage == .english)
            #expect(model.output.isEmpty)
            #expect(model.state == .idle)
            #expect(!model.canCopy)
            model.clearDocument()
            #expect(model.pendingAction != nil)
            model.confirmPendingAction()
            #expect(model.sourceText.isEmpty)
        }
    }

    @Test func actualStreamCanBeCancelledAfterReceivingText() async throws {
        let client = OpenAITranslationClient(server: try configuration(), token: nil)
        let received = TextCollector()
        let input = TranslationInput(text: "The voltage across the resistor is five volts. The current is two amperes.",
                                     source: .english, target: .japanese)
        let request = Task {
            try await client.translate(input) { part in
                await received.append(part)
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        defer { request.cancel() }
        await #expect(throws: CancellationError.self) { try await request.value }
        #expect(!(await received.text).isEmpty)
    }

    @MainActor private func waitUntilFinished(_ model: TranslationModel) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while model.state == .running, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.state != .running)
    }
}
