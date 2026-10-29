import Foundation
import Testing
@testable import KotoFloatKit

@MainActor struct GlossaryStoreTests {
    @Test func editsSelectionAndDeletionSurviveReload() throws {
        try withGlossaryStore { store, url in
            let id = try store.create(name: "  Engineering  ")
            try store.select(id)
            var entry = glossaryEntry(" voltage ", " 電圧 ")
            entry.context = "circuit, DC\nlow voltage"
            try store.saveEntry(entry, in: id)
            let reopened = GlossaryStore(url: url)
            #expect(reopened.failure == nil)
            #expect(reopened.activeGlossary?.name == "Engineering")
            #expect(reopened.activeGlossary?.entries.first?.sourceTerm == "voltage")
            #expect(reopened.activeGlossary?.entries.first?.preferredTranslation == "電圧")
            #expect(reopened.activeGlossary?.entries.first?.context == entry.context)
            entry.preferredTranslation = "電位差"
            try reopened.saveEntry(entry, in: id)
            try reopened.rename(id: id, name: "Physics")
            #expect(GlossaryStore(url: url).activeGlossary?.entries.count == 1)
            #expect(GlossaryStore(url: url).activeGlossary?.name == "Physics")
            try reopened.deleteEntry(id: entry.id, in: id)
            #expect(GlossaryStore(url: url).activeGlossary?.entries.isEmpty == true)
            try reopened.delete(id: id)
            #expect(GlossaryStore(url: url).library.glossaries.isEmpty)
            #expect(GlossaryStore(url: url).library.activeGlossaryID == nil)
        }
    }

    @Test func invalidAndExactDuplicateEntriesDoNotChangeSavedLibrary() throws {
        try withGlossaryStore { store, url in
            let id = try store.create(name: "Test")
            try store.saveEntry(glossaryEntry("Cat", "猫"), in: id)
            let saved = try Data(contentsOf: url)
            #expect(throws: GlossaryFailure.duplicateEntry) { try store.saveEntry(glossaryEntry("cat", "猫"), in: id) }
            #expect(throws: GlossaryFailure.invalidEntry) { try store.saveEntry(glossaryEntry(" ", "猫"), in: id) }
            var invalid = glossaryEntry("a", "b")
            invalid.sourceLanguage = .automatic
            #expect(throws: GlossaryFailure.invalidEntry) { try store.saveEntry(invalid, in: id) }
            #expect(try Data(contentsOf: url) == saved)
            #expect(store.library.glossaries.first?.entries.count == 1)
            try store.saveEntry(glossaryEntry("Cat", "ネコ"), in: id)
            #expect(store.library.glossaries.first?.entries.count == 2)
        }
    }

    @Test func failedSaveDoesNotPublishChanges() throws {
        try withGlossaryStore { store, url in
            let id = try store.create(name: "Before")
            let before = store.library
            let revision = store.revision
            try FileManager.default.removeItem(at: url)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            #expect(throws: (any Error).self) { try store.rename(id: id, name: "After") }
            #expect(store.library == before)
            #expect(store.revision == revision)
            #expect((try url.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true)
        }
    }

    @Test func corruptAndUnknownSchemasAreNeverReplacedWithEmptyData() throws {
        try withGlossaryStore { _, url in
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            for raw in ["broken", #"{"version":99,"glossaries":[]}"#] {
                let data = Data(raw.utf8)
                try data.write(to: url)
                let store = GlossaryStore(url: url)
                #expect(store.failure != nil)
                #expect(throws: (any Error).self) { _ = try store.create(name: "Must not save") }
                #expect(try Data(contentsOf: url) == data)
            }
        }
    }

    @Test func concurrentStoresRejectStaleWritesAndCanReload() throws {
        try withGlossaryStore { first, url in
            let second = GlossaryStore(url: url)
            _ = try first.create(name: "First")
            #expect(throws: GlossaryFailure.changedOnDisk) { _ = try second.create(name: "Second") }
            #expect(second.library.glossaries.isEmpty)
            second.reload()
            _ = try second.create(name: "Second")
            #expect(GlossaryStore(url: url).library.glossaries.map(\.name) == ["First", "Second"])
        }
    }

    @Test func staleRevisionAndInvalidReplacementCannotPartiallyUpdate() throws {
        try withGlossaryStore { store, url in
            let id = try store.create(name: "Test")
            let revision = store.revision
            try store.saveEntry(glossaryEntry("old", "旧"), in: id)
            #expect(throws: GlossaryFailure.stalePreview) {
                try store.replaceEntries([glossaryEntry("new", "新")], in: id, expectedRevision: revision)
            }
            let data = try Data(contentsOf: url)
            #expect(throws: GlossaryFailure.invalidEntry) {
                try store.replaceEntries([glossaryEntry("valid", "有効"), glossaryEntry("", "invalid")], in: id, expectedRevision: store.revision)
            }
            #expect(try Data(contentsOf: url) == data)
            #expect(store.library.glossaries.first?.entries.map(\.sourceTerm) == ["old"])
        }
    }
}

func glossaryEntry(_ source: String, _ target: String) -> GlossaryEntry {
    GlossaryEntry(sourceTerm: source, preferredTranslation: target, sourceLanguage: .english, targetLanguage: .japanese)
}

@MainActor func withGlossaryStore(_ body: (GlossaryStore, URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("KotoFloatGlossaryTests-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("glossaries.json")
    try body(GlossaryStore(url: url), url)
}
