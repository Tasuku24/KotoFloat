import Foundation
import Testing
@testable import KotoFloatKit

@MainActor struct TranslationModelTests {
    @Test func progressCompletesAndRepeatedActiveInputDoesNotSendTwice() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            model.start(text: fixture("source"))
            await waitFor { await service.count == 1 }
            model.start(text: fixture("source"))
            await service.emit("partial", at: 0)
            #expect(model.output == "partial")
            #expect(model.state == .running)
            #expect(await service.count == 1)
            await service.finish(at: 0)
            await waitFor { model.state == .completed }
            #expect(model.output == "partial")
            await service.finishAll()
        }
    }

    @Test func cancelledAndReplacedRequestsCannotReviveOldOutput() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            model.start(text: fixture("old"))
            await waitFor { await service.count == 1 }
            model.start(text: fixture("new"))
            await waitFor { await service.count == 2 }
            await service.emit("obsolete", at: 0)
            await service.finish(at: 0)
            await service.emit("current", at: 1)
            #expect(model.output == "current")
            model.cancel()
            await service.emit("late", at: 1)
            await service.finish(at: 1)
            await Task.yield()
            #expect(model.state == .cancelled)
            #expect(model.output == "current")
            await service.finishAll()
        }
    }

    @Test func changingDirectionAndRetranslatingSnapshotsNewSettings() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            model.start(text: fixture("source"))
            await waitFor { await service.count == 1 }
            preferences.targetLanguage = .english
            model.retranslate()
            await waitFor { await service.count == 2 }
            #expect(await service.inputs.map(\.target) == [.japanese, .english])
            await service.finishAll()
        }
    }

    @Test func failureRetainsPartialTextButDoesNotClaimCompletion() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            model.start(text: fixture("source"))
            await waitFor { await service.count == 1 }
            await service.emit("partial", at: 0)
            await service.finish(at: 0, error: TranslationFailure.interrupted)
            await waitFor { model.state == .failed(.interrupted) }
            #expect(model.output == "partial")
            #expect(model.state == .failed(.interrupted))
        }
    }

    @Test func copiedTextWaitsForConfirmationAndManualEntryInvalidatesTranslation() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            let capture = CaptureModel()
            model.bind(to: capture)
            let environment = CaptureEnvironmentStub()
            environment.selection = .unavailable
            capture.start(using: SelectionCapture(environment: environment), completion: {})
            await waitFor { if case .needsConfirmation = capture.state { return true }; return false }
            #expect(await service.count == 0)
            capture.confirmCopy()
            await waitFor { await service.count == 1 }
            capture.beginManualEntry()
            await service.emit("stale", at: 0)
            await service.finish(at: 0)
            #expect(model.output.isEmpty)
            #expect(model.state == .idle)
            capture.manualText = "manual source"
            capture.acceptManualText()
            await waitFor { await service.count == 2 }
            #expect(await service.inputs.last?.text == "manual source")
            await service.finishAll()
        }
    }

    private func fixture(_ text: String) -> CapturedText { CapturedText(text: text, source: nil, bounds: nil, method: .manual) }
}

actor ControlledTranslator: TranslationServing {
    var inputs: [TranslationInput] = []
    var count: Int { inputs.count }
    private var callbacks: [@Sendable (String) async -> Void] = []
    private var completions: [Int: CheckedContinuation<Void, Error>] = [:]
    func models() async throws -> [String] { ["fixture-model"] }
    func translate(_ input: TranslationInput, onText: @escaping @Sendable (String) async -> Void) async throws {
        let index = inputs.count
        inputs.append(input)
        callbacks.append(onText)
        try await withCheckedThrowingContinuation { completions[index] = $0 }
    }
    func emit(_ text: String, at index: Int) async {
        guard callbacks.indices.contains(index) else { return }
        await callbacks[index](text)
    }
    func finish(at index: Int, error: Error? = nil) {
        guard let continuation = completions.removeValue(forKey: index) else { return }
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
    }
    func finishAll() { for index in Array(completions.keys) { finish(at: index) } }
}

@MainActor func waitFor(_ condition: () async -> Bool) async {
    for _ in 0..<100 {
        if await condition() { return }
        try? await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Expected asynchronous state was not reached")
}

@MainActor func withTranslationContext(_ body: (TranslationPreferences, MemoryCredentials) async throws -> Void) async throws {
    let name = "KotoFloatTranslationTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let preferences = TranslationPreferences(defaults: defaults)
    let credentials = MemoryCredentials()
    try preferences.save(try ServerConfiguration(endpoint: "https://fixture.invalid", model: "fixture-model"), tokenUpdate: .keep, credentials: credentials)
    try await body(preferences, credentials)
}
