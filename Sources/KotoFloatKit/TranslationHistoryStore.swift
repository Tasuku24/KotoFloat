import Foundation
import Observation

@MainActor @Observable final class TranslationHistoryStore {
    static var defaultURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("KotoFloat/History", isDirectory: true)
            .appendingPathComponent("history.sqlite")
    }

    private(set) var entries: [TranslationHistorySummary] = []
    private(set) var failure: TranslationHistoryFailure?
    private(set) var isLoading = false
    private(set) var hasMore = false
    private(set) var revision = 0
    @ObservationIgnored private let database: TranslationHistoryDatabase
    @ObservationIgnored private var pendingOperation: Task<Void, Never>?
    @ObservationIgnored private var searchID = UUID()
    @ObservationIgnored private var failedSaves: [UUID: (entry: TranslationHistoryEntry, create: Bool)] = [:]
    private var query = ""

    init(url: URL = TranslationHistoryStore.defaultURL) { database = TranslationHistoryDatabase(url: url) }
    var hasUnsavedEntries: Bool { !failedSaves.isEmpty }

    func save(_ entry: TranslationHistoryEntry, create: Bool) {
        enqueue { [weak self] database in
            guard let self else { return }
            let create = create || failedSaves[entry.id]?.create == true
            do {
                try await database.save(entry, create: create)
                failedSaves.removeValue(forKey: entry.id)
            } catch {
                failedSaves[entry.id] = (entry, create)
                throw error
            }
        }
    }

    func delete(id: UUID) async {
        await enqueue { [weak self] database in
            try await database.delete(id: id)
            self?.failedSaves.removeValue(forKey: id)
        }.value
    }
    func clear() async {
        await enqueue { [weak self] database in
            try await database.clear()
            self?.failedSaves.removeAll()
        }.value
    }
    func flush() async { await pendingOperation?.value }

    func retry() async {
        await flush()
        for value in failedSaves.values { save(value.entry, create: value.create) }
        await flush()
        await search(query)
    }

    @discardableResult private func enqueue(_ action: @escaping @MainActor (TranslationHistoryDatabase) async throws -> Void) -> Task<Void, Never> {
        let previous = pendingOperation
        let database = database
        let operation = Task { [weak self] in
            await previous?.value
            do {
                try await action(database)
                if self?.failedSaves.isEmpty == true { self?.failure = nil }
                self?.revision += 1
            } catch { self?.failure = error as? TranslationHistoryFailure ?? .unavailable }
        }
        pendingOperation = operation
        return operation
    }

    func search(_ query: String) async {
        self.query = query
        searchID = UUID()
        let id = searchID
        isLoading = true
        await flush()
        do {
            let results = try await database.search(query: query, offset: 0, limit: 51)
            guard searchID == id, !Task.isCancelled else { if searchID == id { isLoading = false }; return }
            entries = Array(results.prefix(50))
            hasMore = results.count > 50
            if failedSaves.isEmpty { failure = nil }
        } catch {
            guard searchID == id else { return }
            failure = error as? TranslationHistoryFailure ?? .unavailable
        }
        if searchID == id { isLoading = false }
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        let id = searchID
        do {
            let results = try await database.search(query: query, offset: entries.count, limit: 51)
            guard searchID == id, !Task.isCancelled else { if searchID == id { isLoading = false }; return }
            entries.append(contentsOf: results.prefix(50))
            hasMore = results.count > 50
            if failedSaves.isEmpty { failure = nil }
        } catch {
            if searchID == id { failure = error as? TranslationHistoryFailure ?? .unavailable }
        }
        if searchID == id { isLoading = false }
    }

    func entry(id: UUID) async -> TranslationHistoryEntry? {
        await flush()
        do { return try await database.entry(id: id) }
        catch { failure = error as? TranslationHistoryFailure ?? .unavailable; return nil }
    }
}
