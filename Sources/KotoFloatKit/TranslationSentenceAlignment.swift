import Foundation
import NaturalLanguage

// Compare English projections locally. The translation model never chooses sentence IDs.
// 英語へ変換した文章を端末内で比較し、翻訳モデルに文IDの選択を任せない。
enum TranslationSentenceAlignment {
    private static let maximumDistance = 0.75
    private static let minimumSeparation = 0.15
    private static let equivalentDistance = 0.05
    private struct Candidate {
        let ids: [Int]
        let score: Double
        let compatible: Bool
        func contains(_ other: Candidate) -> Bool { ids.first! <= other.ids.first! && ids.last! >= other.ids.last! }
    }

    static func match(_ request: TranslationReviewRequest, translated: [String: String]) throws -> TranslationReviewReply {
        try Task.checkCancellation()
        let expected = try request.pivotInput()
        guard Set(translated.keys) == Set(expected.keys),
              translated.values.reduce(0, { $0 + $1.utf8.count }) <= 131_072,
              translated.values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 131_072 }) else {
            throw TranslationFailure.malformedResponse
        }
        let selected = request.selectedLanguage == .english ? request.selectedSentences[request.query.sentenceID].text : translated["selection"]!
        let texts = request.counterpartSentences.map { request.counterpartLanguage == .english ? $0.text : translated[TranslationReviewRequest.candidateKey($0.id)]! }
        let query = Features(selected)
        let features = try texts.map { text in try Task.checkCancellation(); return Features(text) }
        let embedding = NLEmbedding.sentenceEmbedding(for: .english)
        var candidates: [Candidate] = []
        func score(_ ids: [Int]) throws -> Candidate? {
            try Task.checkCancellation()
            let combined = Features.combine(ids.map { features[$0] })
            let compatible = query.numbers == combined.numbers && query.negative == combined.negative && query.names == combined.names
            let text = canonical(ids.map { texts[$0] }.joined(separator: " "))
            let distance: Double
            if text == canonical(selected) { distance = 0 }
            else {
                guard let embedding else { throw TranslationFailure.sentenceComparisonUnavailable }
                distance = embedding.distance(between: canonical(selected), and: text)
            }
            guard distance.isFinite else { return nil }
            return Candidate(ids: ids, score: distance, compatible: compatible)
        }
        var singles: [Candidate] = []
        for id in texts.indices { if let candidate = try score([id]) { singles.append(candidate) } }
        candidates = singles.filter(\.compatible)
        // Expand around the strongest individual sentences instead of scoring every possible long span.
        // 長い範囲の全組合せを計算せず、類似度の高い単文の周辺で結合範囲を調べる。
        let anchors = singles.sorted { $0.score < $1.score }.prefix(4).map { $0.ids[0] }
        var spans = Set<[Int]>()
        for anchor in anchors {
            for length in 2...8 where length <= texts.count {
                let first = max(0, anchor - length + 1)
                let last = min(anchor, texts.count - length)
                for start in first...last {
                    let ids = Array(start..<(start + length))
                    if spans.insert(ids).inserted, let candidate = try score(ids), candidate.compatible { candidates.append(candidate) }
                }
            }
        }
        guard let minimum = candidates.map(\.score).min(), minimum <= maximumDistance else { return unmatched }
        let close = candidates.filter { $0.score <= minimum + equivalentDistance }
        let best = close.sorted { $0.ids.count != $1.ids.count ? $0.ids.count < $1.ids.count : $0.score < $1.score }[0]
        let competing = candidates.filter { !best.contains($0) && !$0.contains(best) }.map(\.score).min()
        guard competing.map({ $0 - best.score >= minimumSeparation }) ?? true else { return unmatched }
        return TranslationReviewReply(source_sentence_ids: request.query.side == .source ? [request.query.sentenceID] : best.ids,
            target_sentence_ids: request.query.side == .target ? [request.query.sentenceID] : best.ids, alternatives: [])
    }

    private static var unmatched: TranslationReviewReply { TranslationReviewReply(source_sentence_ids: [], target_sentence_ids: [], alternatives: []) }

    private static func canonical(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .replacingOccurrences(of: "^please\\s+", with: "", options: .regularExpression)
    }

    private struct Features {
        var numbers: [Double: Int] = [:]
        var names: Set<String> = []
        var negative = false

        private init() {}

        init(_ original: String) {
            let text = original.folding(options: .widthInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            negative = text.range(of: "\\b(not|no|never|without|neither|nor|cannot|nobody|nothing|none|nowhere)\\b|n['’]t\\b", options: [.regularExpression, .caseInsensitive]) != nil
            let literal = try! NSRegularExpression(pattern: "[-+]?[0-9]+(?:[,.][0-9]+)*(?:[eE][-+]?[0-9]+)?")
            for match in literal.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) {
                if let range = Range(match.range, in: text), let number = Double(text[range].replacingOccurrences(of: ",", with: "")), number.isFinite {
                    numbers[number, default: 0] += 1
                }
            }
            let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
            tagger.string = text
            tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
            var words: [(word: String, tag: NLTag?, range: Range<String.Index>)] = []
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
                                 options: [.omitWhitespace, .omitPunctuation]) { tag, range in
                words.append((String(text[range]).lowercased(), tag, range))
                return true
            }
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.numberStyle = .spellOut
            var phrase: [(word: String, range: Range<String.Index>)] = []
            func flush() {
                guard !phrase.isEmpty else { return }
                if phrase.last?.word == "and" { phrase.removeLast() }
                guard let first = phrase.first, let last = phrase.last else { return }
                let spelling = String(text[first.range.lowerBound..<last.range.upperBound]).lowercased()
                    .replacingOccurrences(of: "^negative\\b", with: "minus", options: .regularExpression)
                    .replacingOccurrences(of: "\\b(twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)\\s+(one|two|three|four|five|six|seven|eight|nine)\\b", with: "$1-$2", options: .regularExpression)
                if let number = formatter.number(from: spelling)?.doubleValue, number.isFinite {
                    numbers[number, default: 0] += 1
                }
                phrase.removeAll()
            }
            for (index, token) in words.enumerated() {
                let (word, tag, range) = token
                let next = index + 1 < words.count ? words[index + 1].tag : nil
                if tag == .number && word.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) {
                    if word == "one", next == .verb, phrase.isEmpty { flush(); continue }
                    phrase.append((word, range))
                } else if word == "and", !phrase.isEmpty { phrase.append((word, range)) }
                else if ["minus", "negative", "plus"].contains(word), next == .number { phrase.append((word, range)) }
                else { flush() }
            }
            flush()
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType,
                                 options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
                if [.personalName, .placeName, .organizationName].contains(tag) { names.insert(canonical(String(text[range]))) }
                return true
            }
        }

        static func combine(_ features: [Features]) -> Features {
            var value = Features()
            for feature in features {
                for (number, count) in feature.numbers { value.numbers[number, default: 0] += count }
                value.names.formUnion(feature.names)
                value.negative = value.negative || feature.negative
            }
            return value
        }
    }
}
