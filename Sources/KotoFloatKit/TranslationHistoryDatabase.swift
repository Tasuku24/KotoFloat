import Foundation
import SQLite3

actor TranslationHistoryDatabase {
    private let url: URL
    private var connection: HistorySQLiteConnection?
    init(url: URL) { self.url = url }

    private func database() throws -> HistorySQLiteConnection {
        if let connection { return connection }
        let opened = try HistorySQLiteConnection(url: url)
        connection = opened
        return opened
    }

    func save(_ entry: TranslationHistoryEntry, create: Bool) throws {
        let entry = try entry.validated()
        let database = try database()
        let sql = create ? """
            INSERT INTO history (source, translation, source_language, target_language, created_at, updated_at, id)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """ : """
            UPDATE history SET source=?, translation=?, source_language=?, target_language=?, created_at=?, updated_at=? WHERE id=?
            """
        try database.statement(sql) { statement in
            try database.bind(entry.source, at: 1, to: statement)
            try database.bind(entry.translation, at: 2, to: statement)
            try database.bind(entry.sourceLanguage.rawValue, at: 3, to: statement)
            try database.bind(entry.targetLanguage.rawValue, at: 4, to: statement)
            guard sqlite3_bind_double(statement, 5, entry.createdAt.timeIntervalSince1970) == SQLITE_OK,
                  sqlite3_bind_double(statement, 6, entry.updatedAt.timeIntervalSince1970) == SQLITE_OK else {
                throw TranslationHistoryFailure.unavailable
            }
            try database.bind(entry.id.uuidString, at: 7, to: statement)
            try database.finish(statement)
        }
    }

    func search(query: String, offset: Int, limit: Int) throws -> [TranslationHistorySummary] {
        guard offset >= 0, (1...51).contains(limit) else { throw TranslationHistoryFailure.invalidEntry }
        let database = try database()
        return try database.statement("""
            SELECT id, substr(source,1,180), substr(translation,1,180), source_language, target_language, updated_at
            FROM history WHERE ?='' OR instr(lower(source), lower(?))>0 OR instr(lower(translation), lower(?))>0
            ORDER BY updated_at DESC, id DESC LIMIT ? OFFSET ?
            """) { statement in
            for index: Int32 in 1...3 { try database.bind(query, at: index, to: statement) }
            guard sqlite3_bind_int64(statement, 4, Int64(limit)) == SQLITE_OK,
                  sqlite3_bind_int64(statement, 5, Int64(offset)) == SQLITE_OK else { throw TranslationHistoryFailure.unavailable }
            var entries: [TranslationHistorySummary] = []
            while try database.next(statement) {
                guard let id = UUID(uuidString: try database.text(0, from: statement)),
                      let source = TranslationLanguage(rawValue: try database.text(3, from: statement)),
                      let target = TranslationLanguage(rawValue: try database.text(4, from: statement)), target != .automatic else {
                    throw TranslationHistoryFailure.invalidEntry
                }
                entries.append(TranslationHistorySummary(id: id, sourcePreview: try database.text(1, from: statement),
                    translationPreview: try database.text(2, from: statement), sourceLanguage: source, targetLanguage: target,
                    updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))))
            }
            return entries
        }
    }

    func entry(id: UUID) throws -> TranslationHistoryEntry? {
        let database = try database()
        return try database.statement("""
            SELECT source, translation, source_language, target_language, created_at, updated_at FROM history WHERE id=?
            """) { statement in
            try database.bind(id.uuidString, at: 1, to: statement)
            guard try database.next(statement) else { return nil }
            guard let source = TranslationLanguage(rawValue: try database.text(2, from: statement)),
                  let target = TranslationLanguage(rawValue: try database.text(3, from: statement)) else {
                throw TranslationHistoryFailure.invalidEntry
            }
            return try TranslationHistoryEntry(id: id, source: database.text(0, from: statement), translation: database.text(1, from: statement),
                sourceLanguage: source, targetLanguage: target,
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))).validated()
        }
    }

    func delete(id: UUID) throws {
        let database = try database()
        try database.statement("DELETE FROM history WHERE id=?") { statement in
            try database.bind(id.uuidString, at: 1, to: statement)
            try database.finish(statement)
        }
    }

    func clear() throws { try database().execute("DELETE FROM history") }
}

private final class HistorySQLiteConnection {
    private var handle: OpaquePointer?
    private let applicationID = 0x4B4F544F

    init(url: URL) throws {
        do {
            let existed = FileManager.default.fileExists(atPath: url.path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
                throw TranslationHistoryFailure.unavailable
            }
            if !existed { try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path) }
            sqlite3_busy_timeout(handle, 1000)
            let version = try integer("PRAGMA user_version")
            if version == 0 {
                guard try integer("SELECT count(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'") == 0 else {
                    throw TranslationHistoryFailure.unsupportedVersion
                }
                try execute("""
                    BEGIN IMMEDIATE;
                    CREATE TABLE history (id TEXT PRIMARY KEY NOT NULL, source TEXT NOT NULL, translation TEXT NOT NULL,
                        source_language TEXT NOT NULL, target_language TEXT NOT NULL,
                        created_at REAL NOT NULL, updated_at REAL NOT NULL);
                    CREATE INDEX history_updated ON history(updated_at DESC, id DESC);
                    PRAGMA application_id=\(applicationID);
                    PRAGMA user_version=1;
                    COMMIT;
                    """)
            } else {
                guard version == 1, try integer("PRAGMA application_id") == applicationID else {
                    throw TranslationHistoryFailure.unsupportedVersion
                }
            }
            try execute("PRAGMA journal_mode=WAL; PRAGMA secure_delete=ON;")
        } catch {
            sqlite3_close(handle)
            handle = nil
            throw error as? TranslationHistoryFailure ?? .unavailable
        }
    }

    deinit { sqlite3_close(handle) }

    func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw TranslationHistoryFailure.unavailable }
    }

    private func integer(_ sql: String) throws -> Int {
        try statement(sql) { statement in
            guard try next(statement) else { throw TranslationHistoryFailure.unavailable }
            return Int(sqlite3_column_int64(statement, 0))
        }
    }

    func statement<T>(_ sql: String, _ body: (OpaquePointer) throws -> T) throws -> T {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw TranslationHistoryFailure.unavailable
        }
        defer { sqlite3_finalize(statement) }
        return try body(statement)
    }

    func bind(_ value: String, at index: Int32, to statement: OpaquePointer) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_bind_text(statement, index, value, Int32(value.utf8.count), transient) == SQLITE_OK else {
            throw TranslationHistoryFailure.unavailable
        }
    }

    func text(_ column: Int32, from statement: OpaquePointer) throws -> String {
        guard let bytes = sqlite3_column_text(statement, column),
              let value = String(bytes: UnsafeBufferPointer(start: bytes, count: Int(sqlite3_column_bytes(statement, column))), encoding: .utf8) else {
            throw TranslationHistoryFailure.invalidEntry
        }
        return value
    }

    func next(_ statement: OpaquePointer) throws -> Bool {
        switch sqlite3_step(statement) {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw TranslationHistoryFailure.unavailable
        }
    }

    func finish(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else { throw TranslationHistoryFailure.unavailable }
    }
}
