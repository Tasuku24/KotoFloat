import Foundation

enum TranslationHistoryFailure: String, Error, Equatable {
    case unavailable, unsupportedVersion, invalidEntry
}

struct TranslationHistoryEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    var source: String
    var translation: String
    let sourceLanguage: TranslationLanguage
    let targetLanguage: TranslationLanguage
    let createdAt: Date
    var updatedAt: Date

    func validated() throws -> Self {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              source.utf8.count <= 131_072, translation.utf8.count <= 1_048_576,
              targetLanguage != .automatic, createdAt.timeIntervalSince1970.isFinite,
              updatedAt.timeIntervalSince1970.isFinite else { throw TranslationHistoryFailure.invalidEntry }
        return self
    }
}

struct TranslationHistorySummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourcePreview: String
    let translationPreview: String
    let sourceLanguage: TranslationLanguage
    let targetLanguage: TranslationLanguage
    let updatedAt: Date
}
