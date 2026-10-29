import Foundation
import Testing
@testable import KotoFloatKit

@Suite(.enabled(if: ProcessInfo.processInfo.environment["KOTOFLOAT_TEST_BASE_URL"] != nil))
struct TranslationIntegrationTests {
    private let input = TranslationInput(text: "Synthetic integration input.", source: .english, target: .japanese)

    @Test func listsModelsAndStreamsOverRealLoopbackHTTP() async throws {
        let client = try client()
        #expect(try await client.models() == ["kotofloat-fixture"])
        let result = TextCollector()
        try await client.translate(input) { await result.append($0) }
        #expect(await result.text == "テスト応答です。実際の翻訳ではありません。")
    }

    @Test(arguments: [("redirect", TranslationFailure.requestRejected), ("broken", .interrupted),
        ("malformed", .malformedResponse), ("missing", .modelUnavailable)])
    func realFailuresDoNotBecomeCompletedTranslations(_ fixture: String, _ expected: TranslationFailure) async throws {
        let client = try client(scenario: fixture)
        await #expect(throws: expected) { try await client.translate(input, onText: { _ in }) }
    }

    @Test func authenticationFailureIsNotAConnectionSuccess() async throws {
        await #expect(throws: TranslationFailure.authentication) { try await client(scenario: "unauthorized").models() }
    }

    @Test @MainActor func confirmedManualInputReachesTheActualClient() async throws {
        try await withTranslationContext { preferences, credentials in
            try preferences.save(try configuration(), tokenUpdate: .keep, credentials: credentials)
            let translation = TranslationModel(preferences: preferences, credentials: credentials)
            let capture = CaptureModel()
            translation.bind(to: capture)
            capture.beginManualEntry()
            capture.manualText = "Synthetic integration input."
            capture.acceptManualText()
            await waitFor { translation.state == .completed }
            #expect(translation.state == .completed)
            #expect(translation.output == "テスト応答です。実際の翻訳ではありません。")
            translation.cancel()
        }
    }

    private func configuration(scenario: String = "") throws -> ServerConfiguration {
        let endpoint = try #require(ProcessInfo.processInfo.environment["KOTOFLOAT_TEST_BASE_URL"])
        var parts = try #require(URLComponents(string: endpoint))
        #expect(parts.host == "127.0.0.1")
        guard parts.host == "127.0.0.1", parts.scheme == "http" else { throw TranslationFailure.invalidEndpoint }
        parts.path = scenario.isEmpty ? "/v1" : "/\(scenario)/v1"
        return try ServerConfiguration(endpoint: #require(parts.string), model: "kotofloat-fixture")
    }
    private func client(scenario: String = "") throws -> OpenAITranslationClient {
        OpenAITranslationClient(server: try configuration(scenario: scenario), token: "fixture-token")
    }
}
