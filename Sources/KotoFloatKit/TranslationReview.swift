import Foundation
import NaturalLanguage

private func encodeReviewPayload(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
}

enum TranslationSide: String, Codable, Sendable { case source, target }

struct TranslationSentence: Equatable, Sendable {
    let id: Int
    let text: String
    let range: NSRange
}

struct TranslationWordContext: Encodable, Equatable, Sendable {
    let prefix: String
    let word: String
    let suffix: String
}

struct TranslationReviewDocument: Equatable, Sendable {
    let source: String
    let target: String
    let sourceLanguage: TranslationLanguage
    let targetLanguage: TranslationLanguage
    let glossary: GlossaryContext
    let sourceSentences: [TranslationSentence]
    let targetSentences: [TranslationSentence]

    init(source: String, target: String, sourceLanguage: TranslationLanguage,
         targetLanguage: TranslationLanguage, glossary: GlossaryContext = GlossaryContext()) {
        self.source = source
        self.target = target
        self.sourceLanguage = sourceLanguage == .automatic ? TranslationLanguage.detect(in: source) ?? .automatic : sourceLanguage
        self.targetLanguage = targetLanguage
        self.glossary = glossary
        sourceSentences = Self.sentences(in: source, language: self.sourceLanguage)
        targetSentences = Self.sentences(in: target, language: targetLanguage)
    }

    static func sentences(in text: String, language: TranslationLanguage) -> [TranslationSentence] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        if language != .automatic { tokenizer.setLanguage(NLLanguage(rawValue: language.rawValue)) }
        var result: [TranslationSentence] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = text[range]
            if let first = token.firstIndex(where: { !$0.isWhitespace }),
               let last = token.lastIndex(where: { !$0.isWhitespace }) {
                let trimmed = first..<text.index(after: last)
                result.append(TranslationSentence(id: result.count, text: String(text[trimmed]), range: NSRange(trimmed, in: text)))
            }
            return true
        }
        return result
    }

    func query(side: TranslationSide, at location: Int) -> TranslationReviewQuery? {
        let sentences = side == .source ? sourceSentences : targetSentences
        guard let sentence = sentences.first(where: { NSLocationInRange(location, $0.range) }) else { return nil }
        let word = side == .target ? Self.word(in: target, at: location, language: targetLanguage) : nil
        return TranslationReviewQuery(side: side, sentenceID: sentence.id, wordRange: word)
    }

    static func word(in text: String, at location: Int, language: TranslationLanguage) -> NSRange? {
        guard location >= 0, location < (text as NSString).length,
              let index = Range(NSRange(location: location, length: 0), in: text)?.lowerBound else { return nil }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        if language != .automatic { tokenizer.setLanguage(NLLanguage(rawValue: language.rawValue)) }
        let range = tokenizer.tokenRange(at: index)
        guard range.contains(index), text[range].unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) else { return nil }
        return NSRange(range, in: text)
    }

    func text(in range: NSRange, side: TranslationSide) -> String? {
        let text = side == .source ? source : target
        guard let range = Range(range, in: text) else { return nil }
        return String(text[range])
    }

    func wordContext(_ word: NSRange, within passage: NSRange) -> TranslationWordContext? {
        guard word.length > 0, word.location >= passage.location, NSMaxRange(word) <= NSMaxRange(passage),
              let selected = text(in: word, side: .target),
              let prefix = text(in: NSRange(location: passage.location, length: word.location - passage.location), side: .target),
              let suffix = text(in: NSRange(location: NSMaxRange(word), length: NSMaxRange(passage) - NSMaxRange(word)), side: .target) else { return nil }
        return TranslationWordContext(prefix: prefix, word: selected, suffix: suffix)
    }


}

struct TranslationReviewQuery: Equatable, Hashable, Sendable {
    let side: TranslationSide
    let sentenceID: Int
    let wordRange: NSRange?
}

struct TranslationReviewRequest: Sendable {
    let document: TranslationReviewDocument
    let query: TranslationReviewQuery

    var selectedSentences: [TranslationSentence] { query.side == .source ? document.sourceSentences : document.targetSentences }
    var counterpartSentences: [TranslationSentence] { query.side == .source ? document.targetSentences : document.sourceSentences }
    var selectedLanguage: TranslationLanguage { query.side == .source ? document.sourceLanguage : document.targetLanguage }
    var counterpartLanguage: TranslationLanguage { query.side == .source ? document.targetLanguage : document.sourceLanguage }

    func pivotInput() throws -> [String: String] {
        guard document.source.utf8.count <= 131_072, document.target.utf8.count <= 131_072,
              !document.sourceSentences.isEmpty, !document.targetSentences.isEmpty,
              selectedSentences.indices.contains(query.sentenceID) else { throw TranslationFailure.requestRejected }
        let selection = query.wordRange.flatMap { document.wordContext($0, within: selectedSentences[query.sentenceID].range) }
        guard query.wordRange == nil || (query.side == .target && selection != nil) else { throw TranslationFailure.requestRejected }
        var values: [String: String] = [:]
        if selectedLanguage != .english { values["selection"] = selectedSentences[query.sentenceID].text }
        if counterpartLanguage != .english {
            for sentence in counterpartSentences { values[Self.candidateKey(sentence.id)] = sentence.text }
        }
        return values
    }

    static func candidateKey(_ id: Int) -> String { String(format: "candidate_%06d", id) }

    func payload() throws -> String { try encodeReviewPayload(pivotInput()) }

    func alternativesPayload(for match: TranslationSentenceMatch) throws -> String {
        struct Payload: Encodable {
            let source_language: String
            let target_language: String
            let source_passage: String
            let target_passage: String
            let selected_word_context: TranslationWordContext
            let glossary: String
        }
        guard let word = query.wordRange, let selection = document.wordContext(word, within: match.targetRange),
              let source = document.text(in: match.sourceRange, side: .source),
              let target = document.text(in: match.targetRange, side: .target) else { throw TranslationFailure.requestRejected }
        let payload = Payload(source_language: document.sourceLanguage.promptName, target_language: document.targetLanguage.promptName,
            source_passage: source, target_passage: target, selected_word_context: selection,
            glossary: String(decoding: try document.glossary.referenceData(), as: UTF8.self))
        return try encodeReviewPayload(payload)
    }

    func validatedAlternatives(_ values: [String]) throws -> [String] {
        guard values.count <= 8 else { throw TranslationFailure.malformedResponse }
        guard let word = query.wordRange, let original = document.text(in: word, side: .target) else { return [] }
        var seen = Set<String>()
        return Array(values.compactMap { candidate -> String? in
            let text = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = text.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            let unchanged = document.text(in: NSRange(location: word.location, length: (text as NSString).length), side: .target)
            guard !text.isEmpty, text.count <= 100, !text.contains(where: \.isNewline),
                  text.caseInsensitiveCompare(original) != .orderedSame,
                  unchanged?.caseInsensitiveCompare(text) != .orderedSame, seen.insert(key).inserted else { return nil }
            return text
        }.prefix(5))
    }
}

struct TranslationSentenceMatch: Equatable, Sendable {
    let sourceRange: NSRange
    let targetRange: NSRange
    let alternatives: [String]
}

struct TranslationReviewReply: Sendable {
    let source_sentence_ids: [Int]
    let target_sentence_ids: [Int]
    let alternatives: [String]
    var alternativesFailure: TranslationFailure?

    func validated(for request: TranslationReviewRequest) throws -> TranslationSentenceMatch {
        func span(_ ids: [Int], in sentences: [TranslationSentence]) throws -> NSRange {
            guard !ids.isEmpty, ids.count <= 8, ids == Array(Set(ids)).sorted(),
                  ids.allSatisfy({ sentences.indices.contains($0) }),
                  ids.last! - ids.first! + 1 == ids.count else { throw TranslationFailure.malformedResponse }
            let first = sentences[ids.first!].range
            let last = sentences[ids.last!].range
            return NSRange(location: first.location, length: NSMaxRange(last) - first.location)
        }
        let anchoredIDs = request.query.side == .source ? source_sentence_ids : target_sentence_ids
        guard anchoredIDs.contains(request.query.sentenceID) else { throw TranslationFailure.malformedResponse }
        let source = try span(source_sentence_ids, in: request.document.sourceSentences)
        let target = try span(target_sentence_ids, in: request.document.targetSentences)
        return TranslationSentenceMatch(sourceRange: source, targetRange: target,
            alternatives: try request.validatedAlternatives(alternatives))
    }
}

struct TranslationRewriteRequest: Sendable {
    let document: TranslationReviewDocument
    let match: TranslationSentenceMatch
    let originalWord: String
    let wordRange: NSRange
    let preferred: String

    func payload() throws -> String {
        struct Payload: Encodable {
            let source_language: String
            let target_language: String
            let source_passage: String
            let target_passage: String
            let original_word: String
            let selected_word_context: TranslationWordContext
            let preferred_word: String
            let glossary: String
        }
        guard let source = document.text(in: match.sourceRange, side: .source),
              let target = document.text(in: match.targetRange, side: .target),
              let selection = document.wordContext(wordRange, within: match.targetRange), selection.word == originalWord,
              match.alternatives.contains(preferred), !preferred.isEmpty else { throw TranslationFailure.requestRejected }
        let payload = Payload(source_language: document.sourceLanguage.promptName, target_language: document.targetLanguage.promptName,
            source_passage: source, target_passage: target, original_word: originalWord, selected_word_context: selection, preferred_word: preferred,
            glossary: String(decoding: try document.glossary.referenceData(), as: UTF8.self))
        return try encodeReviewPayload(payload)
    }

    func validate(_ replacement: String) throws -> String {
        let text = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.utf8.count <= 16_384,
              text.range(of: preferred, options: [.caseInsensitive, .diacriticInsensitive]) != nil,
              let original = document.text(in: match.targetRange, side: .target), text != original,
              text.filter(\.isNewline).count == original.filter(\.isNewline).count else { throw TranslationFailure.malformedResponse }
        // A replacement must not import sentences that belong to the untouched document.
        // 置換範囲外にある文を、書き直し結果へ取り込ませない。
        func normalized(_ value: String) -> String {
            value.precomposedStringWithCanonicalMapping.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
        }
        let replacementText = normalized(text)
        let originalText = normalized(original)
        for sentence in document.targetSentences where NSIntersectionRange(sentence.range, match.targetRange).length == 0 {
            let outsideText = normalized(sentence.text)
            if replacementText.contains(outsideText), !originalText.contains(outsideText) { throw TranslationFailure.malformedResponse }
        }
        return text
    }
}
