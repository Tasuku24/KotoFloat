import Foundation

enum GlossaryFailure: String, Error, Equatable {
    case invalidName, invalidEntry, duplicateEntry, missingGlossary, limitExceeded
    case unreadable, unsupportedVersion, saveFailed, changedOnDisk, stalePreview, invalidCSV
}

struct GlossaryEntry: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var sourceTerm: String
    var preferredTranslation: String
    var sourceLanguage: TranslationLanguage
    var targetLanguage: TranslationLanguage
    var context = ""
    var caseSensitive = false
    var enabled = true

    func validated() throws -> Self {
        var entry = self
        entry.sourceTerm = sourceTerm.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        entry.preferredTranslation = preferredTranslation.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        guard !entry.sourceTerm.isEmpty, entry.sourceTerm.count <= 256,
              !entry.preferredTranslation.isEmpty, entry.preferredTranslation.count <= 1_024,
              context.count <= 2_048, sourceLanguage != .automatic, targetLanguage != .automatic,
              sourceLanguage != targetLanguage,
              ![sourceTerm, preferredTranslation, context].contains(where: { $0.unicodeScalars.contains(where: { $0.value == 0 }) }) else {
            throw GlossaryFailure.invalidEntry
        }
        return entry
    }

    var matchKey: MatchKey {
        MatchKey(source: caseSensitive ? sourceTerm : sourceTerm.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX")),
                 from: sourceLanguage, to: targetLanguage, caseSensitive: caseSensitive)
    }

    func duplicates(_ other: Self) -> Bool {
        matchKey == other.matchKey && preferredTranslation == other.preferredTranslation && context == other.context && enabled == other.enabled
    }

    struct MatchKey: Hashable {
        let source: String
        let from: TranslationLanguage
        let to: TranslationLanguage
        let caseSensitive: Bool
    }
}

struct Glossary: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var entries: [GlossaryEntry] = []
}

struct GlossaryLibrary: Codable, Equatable, Sendable {
    var version = 1
    var glossaries: [Glossary] = []
    var activeGlossaryID: UUID?
    static let maximumFileBytes = 16 * 1_024 * 1_024

    func validated() throws -> Self {
        guard version == 1 else { throw GlossaryFailure.unsupportedVersion }
        guard glossaries.count <= 100, glossaries.reduce(0, { $0 + $1.entries.count }) <= 10_000 else {
            throw GlossaryFailure.limitExceeded
        }
        var result = self
        var ids = Set<UUID>()
        for index in result.glossaries.indices {
            guard ids.insert(result.glossaries[index].id).inserted else { throw GlossaryFailure.unreadable }
            result.glossaries[index].name = try Self.validatedName(result.glossaries[index].name)
            result.glossaries[index].entries = try result.glossaries[index].entries.map { entry in
                guard ids.insert(entry.id).inserted else { throw GlossaryFailure.invalidEntry }
                return try entry.validated()
            }
        }
        if let activeGlossaryID, !glossaries.contains(where: { $0.id == activeGlossaryID }) { throw GlossaryFailure.missingGlossary }
        return result
    }

    static func validatedName(_ name: String) throws -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 120, !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw GlossaryFailure.invalidName
        }
        return name
    }
}
