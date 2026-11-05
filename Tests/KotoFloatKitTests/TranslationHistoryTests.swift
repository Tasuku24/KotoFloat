import Foundation
import SQLite3
import Testing
@testable import KotoFloatKit

@MainActor struct TranslationHistoryTests {
    @Test func completedEntriesSurviveReopeningWithExactUnicodeAndLineBreaks() async throws {
        try await withDatabase { url in
            let entry = sample(source: "見出し\n\n😀 日本語\n  • 項目", translation: "Heading\n\n😀 English\n  • Item")
            try await TranslationHistoryDatabase(url: url).save(entry, create: true)
            let reopened = TranslationHistoryDatabase(url: url)
            #expect(try await reopened.entry(id: entry.id) == entry)
            #expect(try await reopened.search(query: "日本語", offset: 0, limit: 50).map(\.id) == [entry.id])
        }
    }

    @Test func literalSearchAndPaginationDoNotInterpretSQLOrWildcardCharacters() async throws {
        try await withDatabase { url in
            let database = TranslationHistoryDatabase(url: url)
            let first = sample(source: "100% _ ' OR 1=1 --", translation: "Literal punctuation", time: 1)
            let second = sample(source: "Ordinary text", translation: "Needle in translation", time: 2)
            try await database.save(first, create: true)
            try await database.save(second, create: true)
            #expect(try await database.search(query: "% _ '", offset: 0, limit: 50).map(\.id) == [first.id])
            #expect(try await database.search(query: "NEEDLE", offset: 0, limit: 50).map(\.id) == [second.id])
            #expect(try await database.search(query: "", offset: 0, limit: 1).map(\.id) == [second.id])
            #expect(try await database.search(query: "", offset: 1, limit: 1).map(\.id) == [first.id])
        }
    }

    @Test func updatingADeletedEntryNeverRecreatesIt() async throws {
        try await withDatabase { url in
            let database = TranslationHistoryDatabase(url: url)
            let entry = sample()
            try await database.save(entry, create: true)
            var edited = entry
            edited.translation = "Edited result"
            edited.updatedAt = Date(timeIntervalSince1970: 2)
            try await database.save(edited, create: false)
            #expect(try await database.entry(id: entry.id)?.translation == "Edited result")
            try await database.delete(id: entry.id)
            try await database.save(edited, create: false)
            #expect(try await database.entry(id: entry.id) == nil)
            try await database.save(sample(), create: true)
            try await database.clear()
            #expect(try await database.search(query: "", offset: 0, limit: 50).isEmpty)
        }
    }

    @Test func corruptAndUnsupportedFilesArePreserved() async throws {
        for unsupported in [false, true] {
            try await withDatabase { url in
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                if unsupported {
                    var handle: OpaquePointer?
                    #expect(sqlite3_open(url.path, &handle) == SQLITE_OK)
                    #expect(sqlite3_exec(handle, "PRAGMA user_version=99;", nil, nil, nil) == SQLITE_OK)
                    sqlite3_close(handle)
                } else { try Data("Keep this damaged file".utf8).write(to: url) }
                let original = try Data(contentsOf: url)
                await #expect(throws: TranslationHistoryFailure.self) {
                    try await TranslationHistoryDatabase(url: url).save(sample(), create: true)
                }
                #expect(try Data(contentsOf: url) == original)
            }
        }
    }

    @Test func queuedWritesAndDeletesAreOrderedAndStorageErrorsAreVisible() async throws {
        try await withDatabase { url in
            let store = TranslationHistoryStore(url: url)
            let entry = sample()
            store.save(entry, create: true)
            await store.delete(id: entry.id)
            store.save(entry, create: false)
            await store.flush()
            await store.search("")
            #expect(store.entries.isEmpty)
            #expect(store.failure == nil)
            let blocked = url.deletingLastPathComponent().appendingPathComponent("blocked")
            try Data().write(to: blocked)
            let unavailable = TranslationHistoryStore(url: blocked.appendingPathComponent("history.sqlite"))
            unavailable.save(entry, create: true)
            await unavailable.flush()
            #expect(unavailable.failure != nil)
            #expect(unavailable.hasUnsavedEntries)
            await unavailable.search("")
            #expect(unavailable.failure != nil)
            try FileManager.default.removeItem(at: blocked)
            await unavailable.retry()
            #expect(unavailable.failure == nil)
            #expect(!unavailable.hasUnsavedEntries)
            #expect(await unavailable.entry(id: entry.id) == entry)
        }
    }

    private func sample(source: String = "Source", translation: String = "Result", time: TimeInterval = 1) -> TranslationHistoryEntry {
        TranslationHistoryEntry(id: UUID(), source: source, translation: translation, sourceLanguage: .japanese,
            targetLanguage: .english, createdAt: Date(timeIntervalSince1970: time), updatedAt: Date(timeIntervalSince1970: time))
    }

    private func withDatabase(_ body: (URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("KotoFloatHistoryTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try await body(directory.appendingPathComponent("History/history.sqlite"))
    }
}
