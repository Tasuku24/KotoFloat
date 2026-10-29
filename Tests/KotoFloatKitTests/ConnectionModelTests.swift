import Foundation
import Testing
@testable import KotoFloatKit

@MainActor struct ConnectionModelTests {
    @Test func endpointChangeNeverSendsOrSavesPreviousDraftToken() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            try credentials.setToken("b-existing", for: "https://b.test/v1")
            var requestedToken: String?
            let model = ConnectionModel(preferences: preferences, credentials: credentials, clientFactory: { _, token in
                requestedToken = token
                return service
            })
            model.tokenInput = "a-unsaved"
            model.allowHTTP = true
            model.endpoint = "https://b.test"
            model.checkConnection()
            await waitFor { model.status == .connected(1) }
            #expect(requestedToken == "b-existing")
            #expect(model.tokenInput.isEmpty)
            #expect(!model.allowHTTP)
            model.save()
            #expect(try credentials.token(for: "https://b.test/v1") == "b-existing")
        }
    }

    @Test func endpointChangeRequiresFreshHTTPConsentAndCannotDeleteOtherToken() throws {
        try withTranslationDefaults { defaults in
            let preferences = TranslationPreferences(defaults: defaults)
            let credentials = MemoryCredentials()
            try credentials.setToken("b-existing", for: "http://b.test/v1")
            var requests = 0
            let service = ControlledTranslator()
            let model = ConnectionModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in
                requests += 1
                return service
            })
            model.endpoint = "http://a.test"
            model.allowHTTP = true
            model.removeSavedToken = true
            model.endpoint = "http://b.test"
            model.checkConnection()
            #expect(requests == 0)
            #expect(model.status == .failed(.insecureConnection))
            #expect(!model.removeSavedToken)
            model.allowHTTP = true
            model.save()
            #expect(try credentials.token(for: "http://b.test/v1") == "b-existing")
        }
    }

    @Test func equivalentEndpointFormattingPreservesDraftChoices() throws {
        try withTranslationDefaults { defaults in
            let model = ConnectionModel(preferences: TranslationPreferences(defaults: defaults), credentials: MemoryCredentials())
            model.endpoint = "http://localhost:1234/v1"
            model.tokenInput = "same-server-token"
            model.removeSavedToken = true
            model.allowHTTP = true
            model.endpoint = " http://LOCALHOST:1234/ "
            #expect(model.tokenInput == "same-server-token")
            #expect(model.removeSavedToken)
            #expect(model.allowHTTP)
        }
    }

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
