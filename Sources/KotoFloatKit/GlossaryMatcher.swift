import Foundation

struct GlossaryContext: Equatable, Sendable {
    var name: String?
    var entries: [GlossaryEntry] = []
    var conflicts: [GlossaryEntry] = []
    var exceedsLimit = false

    func missingTerms(in output: String) -> [GlossaryEntry] {
        entries.filter { !GlossaryMatcher.contains($0.preferredTranslation, in: output, caseSensitive: false) }
    }

    func referenceData() throws -> Data {
        guard !exceedsLimit, entries.count + conflicts.count <= 100 else { throw TranslationFailure.glossaryTooLarge }
        struct Reference: Encodable {
            let source: String
            let preferred_translation: String
            let source_language: String
            let target_language: String
            let context: String
            let case_sensitive: Bool
        }
        let references = try entries.map { entry -> Reference in
            let entry = try entry.validated()
            return Reference(source: entry.sourceTerm, preferred_translation: entry.preferredTranslation,
                             source_language: entry.sourceLanguage.rawValue, target_language: entry.targetLanguage.rawValue,
                             context: entry.context, case_sensitive: entry.caseSensitive)
        }
        let data = try JSONEncoder().encode(references)
        guard data.count <= 65_536 else { throw TranslationFailure.glossaryTooLarge }
        return data
    }
}

enum GlossaryMatcher {
    static func context(for text: String, source: TranslationLanguage, target: TranslationLanguage, glossary: Glossary?) -> GlossaryContext {
        guard let glossary else { return GlossaryContext() }
        var matched: [GlossaryEntry] = []
        for entry in glossary.entries {
            if Task.isCancelled { return GlossaryContext(name: glossary.name) }
            guard entry.enabled, entry.targetLanguage == target, source == .automatic || entry.sourceLanguage == source,
                  contains(entry.sourceTerm, in: text, caseSensitive: entry.caseSensitive) else { continue }
            matched.append(entry)
            if matched.count > 100 { return GlossaryContext(name: glossary.name, exceedsLimit: true) }
        }
        var conflicts = Set<UUID>()
        let groups = Dictionary(grouping: matched) {
            $0.sourceTerm.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        }
        for entries in groups.values {
            for (index, first) in entries.enumerated() {
                for second in entries.dropFirst(index + 1) where first.preferredTranslation != second.preferredTranslation {
                    if !first.caseSensitive || !second.caseSensitive || first.sourceTerm == second.sourceTerm {
                        conflicts.insert(first.id)
                        conflicts.insert(second.id)
                    }
                }
            }
        }
        return GlossaryContext(name: glossary.name, entries: matched.filter { !conflicts.contains($0.id) },
                               conflicts: matched.filter { conflicts.contains($0.id) })
    }

    static func contains(_ term: String, in text: String, caseSensitive: Bool) -> Bool {
        guard !term.isEmpty else { return false }
        let term = term.precomposedStringWithCanonicalMapping
        let text = text.precomposedStringWithCanonicalMapping
        var start = text.startIndex
        while start < text.endIndex,
              let range = text.range(of: term, options: caseSensitive ? [] : [.caseInsensitive],
                                     range: start..<text.endIndex, locale: Locale(identifier: "en_US_POSIX")) {
            let left = isJapanese(term.first!) || range.lowerBound == text.startIndex || !isWord(text[text.index(before: range.lowerBound)])
            let right = isJapanese(term.last!) || range.upperBound == text.endIndex || !isWord(text[range.upperBound])
            if left && right { return true }
            if Task.isCancelled { return false }
            start = text.index(after: range.lowerBound)
        }
        return false
    }

    private static func isWord(_ character: Character) -> Bool {
        !isJapanese(character) && (character.isLetter || character.isNumber || character == "_" || character.unicodeScalars.contains { CharacterSet.nonBaseCharacters.contains($0) })
    }

    private static func isJapanese(_ character: Character) -> Bool {
        character.unicodeScalars.contains {
            (0x2E80...0x9FFF).contains($0.value) || (0xF900...0xFAFF).contains($0.value)
                || (0xFF66...0xFF9F).contains($0.value) || (0x20000...0x323AF).contains($0.value)
        }
    }
}
