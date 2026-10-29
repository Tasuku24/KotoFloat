import Foundation

struct SSEDecoder {
    enum Event: Equatable { case text(String), completed }
    private var line = Data()
    private var payload = ""
    private var receivedBytes = 0
    private var outputBytes = 0
    private var stopped = false
    private var done = false
    private var hasText = false
    private var isError = false

    mutating func feed(_ byte: UInt8) throws -> [Event] {
        guard !done else { return [] }
        receivedBytes += 1
        guard receivedBytes <= 4_194_304, line.count < 262_144 else { throw TranslationFailure.outputTooLarge }
        guard byte == 10 else { line.append(byte); return [] }
        guard var text = String(data: line, encoding: .utf8) else { throw TranslationFailure.malformedResponse }
        line.removeAll(keepingCapacity: true)
        if text.hasPrefix("\u{feff}") { text.removeFirst() }
        if text.hasSuffix("\r") { text.removeLast() }
        if text.isEmpty {
            defer { payload = ""; isError = false }
            if isError { throw TranslationFailure.requestRejected }
            guard !payload.isEmpty else { return [] }
            return try decodeEvent()
        }
        if text.hasPrefix("data:") {
            var value = String(text.dropFirst(5))
            if value.hasPrefix(" ") { value.removeFirst() }
            if !payload.isEmpty { payload += "\n" }
            payload += value
            guard payload.utf8.count <= 262_144 else { throw TranslationFailure.outputTooLarge }
        } else if text == "event: error" || text == "event:error" { isError = true }
        return []
    }

    func finish() throws {
        guard done else { throw TranslationFailure.interrupted }
    }

    private mutating func decodeEvent() throws -> [Event] {
        if payload == "[DONE]" {
            guard stopped else { throw TranslationFailure.interrupted }
            guard hasText else { throw TranslationFailure.emptyResponse }
            done = true
            return [.completed]
        }
        let chunk: Chunk
        do { chunk = try JSONDecoder().decode(Chunk.self, from: Data(payload.utf8)) }
        catch { throw TranslationFailure.malformedResponse }
        if chunk.error != nil { throw TranslationFailure.requestRejected }
        guard let choices = chunk.choices else { throw TranslationFailure.malformedResponse }
        if choices.isEmpty { return [] }
        guard let choice = choices.first(where: { $0.index == 0 }), !stopped else { throw TranslationFailure.malformedResponse }
        if choice.delta?.tool_calls != nil || choice.delta?.refusal != nil { throw TranslationFailure.requestRejected }
        var events: [Event] = []
        if let content = choice.delta?.content, !content.isEmpty {
            outputBytes += content.utf8.count
            guard outputBytes <= 1_048_576 else { throw TranslationFailure.outputTooLarge }
            hasText = hasText || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            events.append(.text(content))
        }
        if let reason = choice.finish_reason {
            guard reason == "stop" else { throw TranslationFailure.truncated }
            stopped = true
        }
        return events
    }

    private struct Chunk: Decodable {
        let choices: [Choice]?
        let error: IgnoredObject?
    }
    private struct Choice: Decodable {
        let index: Int
        let delta: Delta?
        let finish_reason: String?
    }
    private struct Delta: Decodable {
        let content: String?
        let refusal: String?
        let tool_calls: [IgnoredObject]?
    }
    private struct IgnoredObject: Decodable {}
}
