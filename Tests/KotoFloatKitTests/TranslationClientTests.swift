import Foundation
import Testing
@testable import KotoFloatKit

struct TranslationClientTests {
    private let source = TranslationInput(text: "Please translate this fixture.", source: .automatic, target: .japanese)

    @Test func translationRequestUsesOnlySelectedServerAndSeparatesInstructions() throws {
        let client = OpenAITranslationClient(server: try ServerConfiguration(endpoint: "https://example.test", model: "test-model"), token: "fixture-token")
        let request = try client.request(for: source)
        #expect(request.url?.absoluteString == "https://example.test/v1/chat/completions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-token")
        #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
        let body = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["model"] as? String == "test-model")
        #expect(object["stream"] as? Bool == true)
        let messages = try #require(object["messages"] as? [[String: String]])
        #expect(messages.count == 2)
        #expect(messages[0]["role"] == "system")
        #expect(messages[1] == ["role": "user", "content": source.text])
    }

    @Test func rejectsMissingModelAndHeaderInjectionBeforeSending() throws {
        let missing = OpenAITranslationClient(server: try ServerConfiguration(endpoint: "https://example.test", model: ""), token: nil)
        #expect(throws: TranslationFailure.modelRequired) { try missing.request(for: source) }
        let invalid = OpenAITranslationClient(server: try ServerConfiguration(endpoint: "https://example.test", model: "test-model"), token: "bad\r\nHeader: injected")
        #expect(throws: TranslationFailure.invalidToken) { try invalid.request(for: source) }
    }

    @Test func parsesModelsAndMapsFailuresWithoutExposingServerBody() throws {
        #expect(try OpenAITranslationClient.decodeModels(Data(#"{"object":"list","data":[{"id":"model-b"},{"id":"model-a"},{"id":"model-a"}]}"#.utf8)) == ["model-a", "model-b"])
        #expect(throws: TranslationFailure.malformedResponse) { try OpenAITranslationClient.decodeModels(Data(#"{"data":[{}]}"#.utf8)) }
        #expect(throws: TranslationFailure.authentication) { try OpenAITranslationClient.validate(status: 401, isTranslation: false) }
        #expect(throws: TranslationFailure.modelUnavailable) { try OpenAITranslationClient.validate(status: 404, isTranslation: true) }
        #expect(throws: TranslationFailure.rateLimited) { try OpenAITranslationClient.validate(status: 429, isTranslation: true) }
        #expect(throws: TranslationFailure.requestRejected) { try OpenAITranslationClient.validate(status: 302, isTranslation: true) }
    }

    @Test func fragmentedUTF8AndCRLFBecomeTextOnlyAfterWholeEvents() throws {
        var decoder = SSEDecoder()
        var events: [SSEDecoder.Event] = []
        let wire = ": keepalive\r\n\r\ndata: {\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\",\"reasoning_content\":\"hidden\"},\"finish_reason\":null}]}\r\n\r\n"
            + "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"日本語 🌸\"},\"finish_reason\":null}]}\r\n\r\n"
            + "data: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}\r\n\r\ndata: [DONE]\r\n\r\n"
        for byte in wire.utf8 { events += try decoder.feed(byte) }
        try decoder.finish()
        #expect(events == [.text("日本語 🌸"), .completed])
    }

    @Test(arguments: [
        "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"partial\"}}]}\n\n",
        "data: [DONE]\n\n",
        "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"partial\"},\"finish_reason\":\"stop\"}]}\n\n"
    ])
    func eofAndDoneWithoutStopNeverComplete(_ wire: String) throws {
        var decoder = SSEDecoder()
        #expect(throws: TranslationFailure.interrupted) {
            for byte in wire.utf8 { _ = try decoder.feed(byte) }
            try decoder.finish()
        }
    }

    @Test func malformedAndLengthLimitedOutputAreNotComplete() {
        for (wire, failure) in [
            ("data: invalid-json\n\n", TranslationFailure.malformedResponse),
            ("data: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"length\"}]}\n\n", .truncated)
        ] {
            var decoder = SSEDecoder()
            #expect(throws: failure) { for byte in wire.utf8 { _ = try decoder.feed(byte) } }
        }
    }

    @Test func urlSessionFetchesModelsAndStreamsFixture() async throws {
        let client = fixtureClient()
        #expect(try await client.models() == ["fixture-model"])
        let output = TextCollector()
        try await client.translate(source) { await output.append($0) }
        #expect(await output.text == "テスト訳")
    }

    @Test func urlSessionTimeoutIsExplained() async {
        await #expect(throws: TranslationFailure.timedOut) { try await fixtureClient(path: "/timeout").models() }
    }

    private func fixtureClient(path: String = "") -> OpenAITranslationClient {
        OpenAITranslationClient(server: try! ServerConfiguration(endpoint: "https://fixture.invalid\(path)", model: "fixture-model"), token: nil,
            sessionFactory: {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [TranslationFixtureProtocol.self]
                return URLSession(configuration: configuration)
            })
    }
}

actor TextCollector {
    var text = ""
    func append(_ part: String) { text += part }
}

final class TranslationFixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        if url.path.hasPrefix("/timeout") {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut)); return
        }
        let models = url.path.hasSuffix("/models")
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": models ? "application/json" : "text/event-stream"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let body = models ? #"{"data":[{"id":"fixture-model"}]}"# :
            "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"テスト訳\"},\"finish_reason\":null}]}\n\ndata: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n"
        for byte in body.utf8 { client?.urlProtocol(self, didLoad: Data([byte])) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
