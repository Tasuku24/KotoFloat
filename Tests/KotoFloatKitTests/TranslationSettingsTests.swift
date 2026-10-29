import Foundation
import Testing
@testable import KotoFloatKit

@MainActor struct TranslationSettingsTests {
    @Test func normalizesBaseURLWithoutDuplicatingVersionOrProxyPath() throws {
        let server = try ServerConfiguration(endpoint: " https://example.test/proxy/v1/ ", model: " model-a ")
        #expect(server.baseURL.absoluteString == "https://example.test/proxy/v1")
        #expect(server.modelsURL.absoluteString == "https://example.test/proxy/v1/models")
        #expect(server.chatURL.absoluteString == "https://example.test/proxy/v1/chat/completions")
        #expect(server.model == "model-a")
        #expect(try ServerConfiguration(endpoint: "https://example.test", model: "").baseURL.absoluteString == "https://example.test/v1")
    }

    @Test(arguments: ["ftp://example.test", "https://user:secret@example.test", "https://example.test?token=secret",
        "https://example.test/#fragment", "example.test", "http://example.test:70000"])
    func rejectsAmbiguousOrCredentialBearingURLs(_ endpoint: String) {
        #expect(throws: TranslationFailure.invalidEndpoint) { try ServerConfiguration(endpoint: endpoint, model: "model", allowHTTP: true) }
    }

    @Test func httpRequiresOptInExceptLoopback() throws {
        #expect(throws: TranslationFailure.insecureConnection) {
            try ServerConfiguration(endpoint: "http://192.168.1.2:1234", model: "model")
        }
        #expect(try ServerConfiguration(endpoint: "http://127.0.0.1:1234", model: "model").modelsURL.absoluteString == "http://127.0.0.1:1234/v1/models")
        #expect(try ServerConfiguration(endpoint: "http://[::1]:1234/v1", model: "model").baseURL.scheme == "http")
        #expect(try ServerConfiguration(endpoint: "http://192.168.1.2:1234", model: "model", allowHTTP: true).allowHTTP)
    }

    @Test func savesOnlyNonSecretsAndKeepsCredentialsScopedToEndpoint() throws {
        try withTranslationDefaults { defaults in
            let preferences = TranslationPreferences(defaults: defaults)
            let credentials = MemoryCredentials()
            let a = try ServerConfiguration(endpoint: "https://a.test", model: "alpha")
            let b = try ServerConfiguration(endpoint: "https://b.test", model: "beta")
            try preferences.save(a, tokenUpdate: .replace("fixture-token"), credentials: credentials)
            try preferences.save(b, tokenUpdate: .keep, credentials: credentials)
            #expect(try credentials.token(for: b.baseURL.absoluteString) == nil)
            #expect(try credentials.token(for: a.baseURL.absoluteString) == "fixture-token")
            #expect(TranslationPreferences(defaults: defaults).server == b)
            #expect(!defaults.dictionaryRepresentation().description.contains("fixture-token"))
            preferences.sourceLanguage = .japanese
            preferences.targetLanguage = .english
            let restored = TranslationPreferences(defaults: defaults)
            #expect(restored.sourceLanguage == .japanese)
            #expect(restored.targetLanguage == .english)
        }
    }

    @Test func failedCredentialSaveDoesNotChangeWorkingConfiguration() throws {
        try withTranslationDefaults { defaults in
            let preferences = TranslationPreferences(defaults: defaults)
            let credentials = MemoryCredentials()
            let a = try ServerConfiguration(endpoint: "https://a.test", model: "a")
            try preferences.save(a, tokenUpdate: .keep, credentials: credentials)
            credentials.shouldFail = true
            #expect(throws: TranslationFailure.credentialsUnavailable) {
                try preferences.save(try ServerConfiguration(endpoint: "https://b.test", model: "b"),
                    tokenUpdate: .replace("fixture-token"), credentials: credentials)
            }
            #expect(TranslationPreferences(defaults: defaults).server == a)
        }
    }
}

@MainActor final class MemoryCredentials: CredentialStore {
    var values: [String: String] = [:]
    var shouldFail = false
    func token(for endpoint: String) throws -> String? {
        if shouldFail { throw TranslationFailure.credentialsUnavailable }
        return values[endpoint]
    }
    func setToken(_ token: String?, for endpoint: String) throws {
        if shouldFail { throw TranslationFailure.credentialsUnavailable }
        values[endpoint] = token
    }
}

@MainActor func withTranslationDefaults(_ body: (UserDefaults) throws -> Void) throws {
    let name = "KotoFloatTranslationTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    try body(defaults)
}
