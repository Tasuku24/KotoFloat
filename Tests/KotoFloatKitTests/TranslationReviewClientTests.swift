import Foundation
import Testing
@testable import KotoFloatKit

struct TranslationReviewClientTests {
    private func review() throws -> TranslationReviewRequest {
        let document = TranslationReviewDocument(source: "便利な道具です。", target: "This is a useful tool.", sourceLanguage: .japanese, targetLanguage: .english)
        return TranslationReviewRequest(document: document, query: try #require(document.query(side: .target, at: 10)))
    }

    private func rewrite() throws -> TranslationRewriteRequest {
        let request = try review()
        let match = try TranslationReviewReply(source_sentence_ids: [0], target_sentence_ids: [0], alternatives: ["helpful"]).validated(for: request)
        return TranslationRewriteRequest(document: request.document, match: match, originalWord: "useful", wordRange: try #require(request.query.wordRange), preferred: "helpful")
    }

    @Test func reviewRequestsUseTheSavedEndpointAndKeepDocumentDataOutOfSystemInstructions() throws {
        let client = fixtureClient("review")
        let input = try review()
        let request = try client.request(for: input)
        #expect(request.url?.absoluteString == "https://review.fixture.invalid/review/v1/chat/completions")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-review-token")
        let body = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try #require(object["messages"] as? [[String: String]])
        #expect(messages.map { $0["role"] } == ["system", "user"])
        let payload = try #require(messages.last?["content"])
        let separator = try #require(payload.range(of: "\n\n"))
        let data = try #require(JSONSerialization.jsonObject(with: Data(payload[separator.upperBound...].utf8)) as? [String: String])
        #expect(data == ["candidate_000000": "便利な道具です。"])
        #expect(messages.first?["content"]?.contains(input.document.source) == false)
        #expect(object["stream"] as? Bool == true)
        #expect(object["model"] as? String == "fixture-model")
    }

    @Test func reviewAndRewriteDecodeCompletedStreams() async throws {
        let request = try review()
        let reply = try await fixtureClient("review").review(request)
        #expect(try reply.validated(for: request).alternatives == ["helpful", "handy"])
        #expect(try await fixtureClient("rewrite").rewrite(rewrite()) == "This tool is helpful.")
    }

    @Test func malformedUnboundedAndMissingChosenWordRepliesFailClosed() async throws {
        let request = try review()
        await #expect(throws: TranslationFailure.malformedResponse) { try await fixtureClient("malformed").review(request) }
        await #expect(throws: TranslationFailure.outputTooLarge) { try await fixtureClient("large").review(request) }
        await #expect(throws: TranslationFailure.malformedResponse) { try await fixtureClient("missing-word").rewrite(rewrite()) }
    }

    @Test func invalidCredentialsAndOversizedReviewAreRejectedBeforeSending() throws {
        let server = try ServerConfiguration(endpoint: "https://review.fixture.invalid", model: "fixture-model")
        let client = OpenAITranslationClient(server: server, token: "bad\nInjected: value")
        #expect(throws: TranslationFailure.invalidToken) { try client.request(for: review()) }
        let document = TranslationReviewDocument(source: String(repeating: "x", count: 131_073), target: "Short.", sourceLanguage: .english, targetLanguage: .french)
        let query = TranslationReviewQuery(side: .target, sentenceID: 0, wordRange: nil)
        #expect(throws: TranslationFailure.requestRejected) { try TranslationReviewRequest(document: document, query: query).payload() }
    }

    @Test func aCandidateFailureStillReturnsTheValidatedCorrespondence() async throws {
        let request = try review()
        let reply = try await fixtureClient("bad-alternatives").review(request)
        #expect(reply.alternativesFailure == .malformedResponse)
        #expect(try reply.validated(for: request).sourceRange == request.document.sourceSentences[0].range)
        #expect(reply.alternatives.isEmpty)
    }

    @Test func unchangedCandidatesTriggerOnePhraseAlternativeAttempt() async throws {
        let request = try review()
        let reply = try await fixtureClient("empty-first").review(request)
        #expect(try reply.validated(for: request).alternatives == ["practical", "of real use"])
    }

    @Test func twoEmptyAttemptsRemainAnHonestEmptyResult() async throws {
        let request = try review()
        let reply = try await fixtureClient("always-empty").review(request)
        #expect(try reply.validated(for: request).alternatives.isEmpty)
        #expect(reply.alternativesFailure == nil)
    }

    @Test func projectedCounterpartsKeepTheClickedSentenceAnchoredAcrossReordering() async throws {
        let document = TranslationReviewDocument(source: "便利な道具です。別の文です。", target: "Another sentence. This is a useful tool.",
            sourceLanguage: .japanese, targetLanguage: .english)
        let query = try #require(document.query(side: .target, at: (document.target as NSString).range(of: "useful").location))
        let request = TranslationReviewRequest(document: document, query: query)
        let reply = try await fixtureClient("counterpart").review(request)
        #expect(reply.source_sentence_ids == [0])
        #expect(reply.target_sentence_ids == [1])
        #expect(try reply.validated(for: request).alternatives == ["helpful"])
    }

    @Test func translatedSelectionIsMatchedLocallyInsteadOfTrustingAModelChosenSentence() async throws {
        let document = TranslationReviewDocument(source: "This is a useful tool. It saves time.",
            target: "これはとても便利なツールです。時間を節約できます。", sourceLanguage: .automatic, targetLanguage: .japanese)
        let query = try #require(document.query(side: .target, at: 6))
        let request = TranslationReviewRequest(document: document, query: query)
        let reply = try await fixtureClient("pivot").review(request)
        #expect(reply.source_sentence_ids == [0])
        #expect(reply.target_sentence_ids == [0])
        #expect(try reply.validated(for: request).alternatives == ["役立つ", "有用"])
    }

    private func fixtureClient(_ path: String) -> OpenAITranslationClient {
        OpenAITranslationClient(server: try! ServerConfiguration(endpoint: "https://review.fixture.invalid/\(path)", model: "fixture-model"),
            token: "fixture-review-token", sessionFactory: {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [ReviewFixtureProtocol.self]
                return URLSession(configuration: configuration)
            })
    }
}

private final class ReviewFixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "review.fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                body.append(contentsOf: buffer.prefix(count))
            }
        }
        let retry = String(decoding: body, as: UTF8.self).contains("second attempt")
        let wireObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        let messages = wireObject?["messages"] as? [[String: String]]
        let isPivot = messages?.last?["content"]?.contains("\"selection\"") == true || messages?.last?["content"]?.contains("\"candidate_") == true
        let output: String
        if path.hasPrefix("/large") { output = String(repeating: "x", count: 131_073) }
        else if path.hasPrefix("/malformed") { output = "Not a JSON response" }
        else if path.hasPrefix("/missing-word") { output = "The original text should remain unchanged." }
        else if path.hasPrefix("/bad-alternatives") {
            output = isPivot ? #"{"candidate_000000":"This is a useful tool."}"# : #"{"alternatives":"invalid array"}"#
        }
        else if path.hasPrefix("/rewrite") { output = "This tool is helpful." }
        else if path.hasPrefix("/counterpart") {
            output = isPivot ? #"{"candidate_000000":"This is a useful tool.","candidate_000001":"Another sentence."}"# : #"{"alternatives":["helpful"]}"#
        }
        else if path.hasPrefix("/pivot") {
            output = isPivot ? #"{"selection":"This is a very useful tool."}"# : #"{"alternatives":["役立つ","有用"]}"#
        }
        else if path.hasPrefix("/empty-first") {
            output = isPivot ? #"{"candidate_000000":"This is a useful tool."}"# : retry
                ? #"{"alternatives":["practical","of real use"]}"#
                : #"{"source_passage":"便利な道具です。","target_passage":"This is a useful tool.","alternatives":["useful","USEFUL","useful tool"]}"#
        }
        else if path.hasPrefix("/always-empty") { output = isPivot ? #"{"candidate_000000":"This is a useful tool."}"# : #"{"alternatives":[]}"# }
        else { output = isPivot ? #"{"candidate_000000":"This is a useful tool."}"# : #"{"alternatives":["helpful","handy"]}"# }
        let data = try! JSONSerialization.data(withJSONObject: ["choices": [["index": 0, "delta": ["content": output]]]])
        let wire = "data: \(String(decoding: data, as: UTF8.self))\n\n"
            + "data: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n"
            + "data: [DONE]\n\n"
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/event-stream"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(wire.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
