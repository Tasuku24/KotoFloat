import Darwin
import Foundation
import Observation

@MainActor @Observable final class GlossaryStore {
    private(set) var library = GlossaryLibrary()
    private(set) var failure: GlossaryFailure?
    private(set) var revision = 0
    @ObservationIgnored private let url: URL
    @ObservationIgnored private var loadedData: Data?

    static var defaultURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("KotoFloat", isDirectory: true).appendingPathComponent("glossaries.json")
    }

    init(url: URL = GlossaryStore.defaultURL) {
        self.url = url
        reload()
    }

    var activeGlossary: Glossary? { library.glossaries.first { $0.id == library.activeGlossaryID } }

    func reload() {
        do {
            let data = try Self.read(url)
            let next: GlossaryLibrary
            if let data {
                struct Header: Decodable { let version: Int }
                guard try JSONDecoder().decode(Header.self, from: data).version == 1 else { throw GlossaryFailure.unsupportedVersion }
                next = try JSONDecoder().decode(GlossaryLibrary.self, from: data).validated()
            } else { next = GlossaryLibrary() }
            library = next
            loadedData = data
            failure = nil
            revision += 1
        } catch { failure = error as? GlossaryFailure ?? .unreadable }
    }

    @discardableResult func create(name: String) throws -> UUID {
        let glossary = Glossary(name: try GlossaryLibrary.validatedName(name))
        try update { $0.glossaries.append(glossary) }
        return glossary.id
    }

    func rename(id: UUID, name: String) throws {
        let name = try GlossaryLibrary.validatedName(name)
        try edit(id: id) { $0.name = name }
    }

    func delete(id: UUID) throws {
        try update { library in
            guard library.glossaries.contains(where: { $0.id == id }) else { throw GlossaryFailure.missingGlossary }
            library.glossaries.removeAll { $0.id == id }
            if library.activeGlossaryID == id { library.activeGlossaryID = nil }
        }
    }

    func select(_ id: UUID?) throws { try update { $0.activeGlossaryID = id } }

    func saveEntry(_ entry: GlossaryEntry, in glossaryID: UUID) throws {
        let entry = try entry.validated()
        try edit(id: glossaryID) { glossary in
            guard !glossary.entries.contains(where: { $0.id != entry.id && $0.duplicates(entry) }) else { throw GlossaryFailure.duplicateEntry }
            if let index = glossary.entries.firstIndex(where: { $0.id == entry.id }) { glossary.entries[index] = entry }
            else { glossary.entries.append(entry) }
        }
    }

    func deleteEntry(id: UUID, in glossaryID: UUID) throws {
        try edit(id: glossaryID) { $0.entries.removeAll { $0.id == id } }
    }

    func replaceEntries(_ entries: [GlossaryEntry], in glossaryID: UUID, expectedRevision: Int) throws {
        guard revision == expectedRevision else { throw GlossaryFailure.stalePreview }
        try edit(id: glossaryID) { $0.entries = entries }
    }

    private func edit(id: UUID, change: (inout Glossary) throws -> Void) throws {
        try update { library in
            guard let index = library.glossaries.firstIndex(where: { $0.id == id }) else { throw GlossaryFailure.missingGlossary }
            try change(&library.glossaries[index])
        }
    }

    private func update(_ change: (inout GlossaryLibrary) throws -> Void) throws {
        if let failure { throw failure }
        var next = library
        try change(&next)
        next = try next.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(next)
        guard data.count <= GlossaryLibrary.maximumFileBytes else { throw GlossaryFailure.limitExceeded }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                   attributes: [.posixPermissions: 0o700])
            let lock = open(url.appendingPathExtension("lock").path, O_CREAT | O_RDWR, 0o600)
            guard lock >= 0 else { throw GlossaryFailure.saveFailed }
            defer { close(lock) }
            guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw GlossaryFailure.changedOnDisk }
            defer { flock(lock, LOCK_UN) }
            guard try Self.read(url) == loadedData else { throw GlossaryFailure.changedOnDisk }
            try data.write(to: url, options: .atomic)
        } catch { throw error as? GlossaryFailure ?? .saveFailed }
        loadedData = data
        library = next
        revision += 1
    }

    static func read(_ url: URL) throws -> Data? {
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: url) }
        catch {
            let error = error as NSError
            if error.domain == NSCocoaErrorDomain && [NSFileReadNoSuchFileError, NSFileNoSuchFileError].contains(error.code) { return nil }
            throw GlossaryFailure.unreadable
        }
        defer { try? handle.close() }
        let data = try handle.read(upToCount: GlossaryLibrary.maximumFileBytes + 1) ?? Data()
        guard data.count <= GlossaryLibrary.maximumFileBytes else { throw GlossaryFailure.limitExceeded }
        return data
    }
}
