import AppKit
import Testing
@testable import KotoFloatKit

// Opt in with a loaded local model or the app's saved server; output quality is reviewed separately.
// 読み込み済みのローカルモデルまたはアプリの保存済みサーバーを明示した場合だけ実行し、訳文の品質は別途評価する。
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["KOTOFLOAT_LOCAL_MODEL"] != nil ||
                            ProcessInfo.processInfo.environment["KOTOFLOAT_USE_SAVED_SERVER"] == "1"))
struct LocalModelIntegrationTests {
    @MainActor private func configuration() throws -> (server: ServerConfiguration, token: String?) {
        if ProcessInfo.processInfo.environment["KOTOFLOAT_USE_SAVED_SERVER"] == "1" {
            let defaults = try #require(UserDefaults(suiteName: "com.tasuku24.KotoFloat"))
            let server = try #require(TranslationPreferences(defaults: defaults).server)
            return (server, try KeychainCredentialStore().token(for: server.baseURL.absoluteString))
        }
        return (try ServerConfiguration(endpoint: "http://127.0.0.1:1234/v1",
                                       model: #require(ProcessInfo.processInfo.environment["KOTOFLOAT_LOCAL_MODEL"])), nil)
    }

    @Test @MainActor func actualConnectionCheckAndTrialTranslation() async throws {
        let (server, token) = try configuration()
        try await withTranslationContext { preferences, credentials in
            try preferences.save(server, tokenUpdate: token.map(TokenUpdate.replace) ?? .keep, credentials: credentials)
            preferences.targetLanguage = .japanese
            let connection = ConnectionModel(preferences: preferences, credentials: credentials)
            defer { connection.cancel() }
            connection.checkConnection()
            let deadline = ContinuousClock.now.advanced(by: .seconds(310))
            while connection.isBusy, ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            try #require(connection.status == .connected(connection.availableModels.count))
            #expect(connection.availableModels.contains(server.model))
            connection.tryTranslation()
            let trialDeadline = ContinuousClock.now.advanced(by: .seconds(310))
            while connection.isBusy, ContinuousClock.now < trialDeadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(connection.status == .trialComplete)
            #expect(!connection.trialOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["KOTOFLOAT_USE_SAVED_SERVER"] == "1"))
    @MainActor func actualAuthenticatedServerRejectsMissingAndInvalidTokens() async throws {
        let (server, token) = try configuration()
        try #require(token != nil)
        for rejectedToken: String? in [nil, "kotofloat-deliberately-invalid-acceptance-token"] {
            let client = OpenAITranslationClient(server: server, token: rejectedToken)
            await #expect(throws: TranslationFailure.authentication) { try await client.models() }
        }
    }

    @Test @MainActor func actualGenerationPreservesEditorContracts() async throws {
        let (server, token) = try configuration()
        let client = OpenAITranslationClient(server: server, token: token)
        #expect(try await client.models().contains(server.model))
        try await withTranslationContext { preferences, credentials in
            try preferences.save(server, tokenUpdate: token.map(TokenUpdate.replace) ?? .keep, credentials: credentials)
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

    @Test @MainActor func actualStreamCanBeCancelledAfterReceivingText() async throws {
        let (server, token) = try configuration()
        let client = OpenAITranslationClient(server: server, token: token)
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

    // Capture real outputs for human review; a successful request does not prove translation quality.
    // 実際の出力を目視評価用に保存する。通信の成功は翻訳品質の成功を意味しない。
    @Test(.enabled(if: ProcessInfo.processInfo.environment["KOTOFLOAT_EVALUATION_REPORT"] != nil))
    @MainActor func recordsBilingualAndGlossarySamplesForReview() async throws {
        struct Sample: Encodable {
            let id: String
            let text: String
            let source: TranslationLanguage
            let target: TranslationLanguage
            var glossary: [GlossaryEntry] = []
        }
        struct Result: Encodable {
            let sample: Sample
            let state: String
            let output: String
            let missingPreferredTranslations: [String]
        }
        let english = "The voltage across the resistor is five volts."
        let japanese = "抵抗器の両端の電位差は5 Vです。"
        let samples = [
            Sample(id: "en-ja-basic", text: english, source: .english, target: .japanese),
            Sample(id: "ja-en-basic", text: japanese, source: .japanese, target: .english),
            Sample(id: "auto-ja", text: english, source: .automatic, target: .japanese),
            Sample(id: "auto-en", text: japanese, source: .automatic, target: .english),
            Sample(id: "en-ja-paragraphs", text: "Disconnect the power before replacing the resistor.\n\nAfter reconnecting the power, the voltage is 5 V and the current is 0.2 A.", source: .english, target: .japanese),
            Sample(id: "ja-en-paragraphs", text: "抵抗器を交換する前に、電源を切ってください。\n\n電源を再接続した後、電圧は5 V、電流は0.2 Aです。", source: .japanese, target: .english),
            Sample(id: "en-ja-glossary", text: english, source: .english, target: .japanese, glossary: [
                GlossaryEntry(sourceTerm: "voltage", preferredTranslation: "電位差", sourceLanguage: .english, targetLanguage: .japanese, context: "Electrical potential difference across a component."),
                GlossaryEntry(sourceTerm: "resistor", preferredTranslation: "抵抗器", sourceLanguage: .english, targetLanguage: .japanese)
            ]),
            Sample(id: "ja-en-glossary", text: japanese, source: .japanese, target: .english, glossary: [
                GlossaryEntry(sourceTerm: "電位差", preferredTranslation: "potential difference", sourceLanguage: .japanese, targetLanguage: .english, context: "Electrical potential difference across a component."),
                GlossaryEntry(sourceTerm: "抵抗器", preferredTranslation: "resistor", sourceLanguage: .japanese, targetLanguage: .english)
            ])
        ]
        let (server, token) = try configuration()
        var results: [Result] = []
        for sample in samples {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("KotoFloatEvaluation-\(UUID())")
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = GlossaryStore(url: directory.appendingPathComponent("glossaries.json"))
            if !sample.glossary.isEmpty {
                let id = try store.create(name: "Acceptance glossary")
                for entry in sample.glossary { try store.saveEntry(entry, in: id) }
                try store.select(id)
            }
            try await withTranslationContext { preferences, credentials in
                try preferences.save(server, tokenUpdate: token.map(TokenUpdate.replace) ?? .keep, credentials: credentials)
                preferences.sourceLanguage = sample.source
                preferences.targetLanguage = sample.target
                let model = TranslationModel(preferences: preferences, credentials: credentials, glossaries: store)
                defer { model.cancel() }
                model.editSource(sample.text)
                model.translateSource()
                try await waitUntilFinished(model)
                #expect(model.state == .completed)
                #expect(model.input?.glossary.entries == sample.glossary)
                results.append(Result(sample: sample, state: String(describing: model.state), output: model.output,
                                      missingPreferredTranslations: model.missingGlossaryTerms.map(\.preferredTranslation)))
            }
        }
        let path = try #require(ProcessInfo.processInfo.environment["KOTOFLOAT_EVALUATION_REPORT"])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(results).write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    @MainActor private func waitUntilFinished(_ model: TranslationModel) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(310))
        while model.state == .running, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.state != .running)
    }
}
