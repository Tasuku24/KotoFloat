import Foundation
import Testing
@testable import KotoFloatKit

@MainActor struct ConnectionModelTests {
    @Test func connectionCheckDoesNotTranslateOrSaveDrafts() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let model = ConnectionModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            model.endpoint = "https://new.test"
            model.checkConnection()
            await waitFor { model.status == .connected(1) }
            #expect(model.availableModels == ["fixture-model"])
            #expect(await service.count == 0)
            #expect(preferences.server?.baseURL.host == "fixture.invalid")
        }
    }

    @Test func savingReportsKeychainFailureAndRetainsOldSettings() throws {
        try withTranslationDefaults { defaults in
            let preferences = TranslationPreferences(defaults: defaults)
            let credentials = MemoryCredentials()
            let model = ConnectionModel(preferences: preferences, credentials: credentials)
            model.endpoint = "https://example.test"
            model.modelName = "test-model"
            model.tokenInput = "fixture-token"
            credentials.shouldFail = true
            model.save()
            #expect(model.status == .failed(.credentialsUnavailable))
            #expect(preferences.server == nil)
            credentials.shouldFail = false
            model.save()
            #expect(model.status == .saved)
            #expect(preferences.server?.model == "test-model")
            #expect(model.tokenInput.isEmpty)
        }
    }

    @Test func editingDraftDiscardsLateModelList() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = DelayedModelList()
            let model = ConnectionModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            model.checkConnection()
            await waitFor { await service.isWaiting }
            model.endpoint = "https://other.test"
            await service.finish()
            await Task.yield()
            #expect(model.status == .idle)
            #expect(model.availableModels.isEmpty)
        }
    }

    @Test func trialUsesDisclosedFixtureAndDoesNotUseClipboard() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let model = ConnectionModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            model.tryTranslation()
            await waitFor { await service.count == 1 }
            #expect(await service.inputs.first?.text == "This is a translation connection test.")
            await service.emit("試し訳", at: 0)
            await service.finish(at: 0)
            await waitFor { model.status == .trialComplete }
            #expect(model.trialOutput == "試し訳")
        }
    }
}

actor DelayedModelList: TranslationServing {
    private var continuation: CheckedContinuation<[String], Error>?
    var isWaiting: Bool { continuation != nil }
    func models() async throws -> [String] { try await withCheckedThrowingContinuation { continuation = $0 } }
    func translate(_ input: TranslationInput, onText: @escaping @Sendable (String) async -> Void) async throws {}
    func finish() { continuation?.resume(returning: ["old-model"]); continuation = nil }
}
