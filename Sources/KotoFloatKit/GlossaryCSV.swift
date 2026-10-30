import Foundation

enum GlossaryDuplicatePolicy: String, CaseIterable { case skip, replace, keepBoth }

struct GlossaryImportPreview {
    struct Row: Identifiable {
        let number: Int
        let fields: [String]
        var action: String
        var id: Int { number }
    }
    struct Issue: Error, Identifiable {
        let row: Int
        let failure: GlossaryFailure
        var id: Int { row }
    }
    var rows: [Row] = []
    var issues: [Issue] = []
    var duplicateCount = 0
    var entries: [GlossaryEntry] = []
    var canImport: Bool { !rows.isEmpty && issues.isEmpty }
}

enum GlossaryCSV {
    static let columns = ["source", "target", "source_language", "target_language", "context", "case_sensitive", "enabled"]

    static func preview(data: Data, existing: [GlossaryEntry], policy: GlossaryDuplicatePolicy) -> GlossaryImportPreview {
        var preview = GlossaryImportPreview()
        do {
            let records = try parse(data)
            guard records.first == columns, records.count > 1 else {
                throw GlossaryImportPreview.Issue(row: 1, failure: .invalidCSV)
            }
            var result = existing.map(Optional.some)
            var positions: [GlossaryEntry.MatchKey: [Int]] = [:]
            for (index, entry) in existing.enumerated() { positions[entry.matchKey, default: []].append(index) }
            for (index, fields) in records.dropFirst().enumerated() {
                let row = index + 2
                var action = "add"
                do {
                    var entry = try decode(fields)
                    let indices = positions[entry.matchKey] ?? []
                    if !indices.isEmpty {
                        preview.duplicateCount += 1
                        switch policy {
                        case .skip: action = "skip"
                        case .replace:
                            let first = indices[0]
                            entry.id = result[first]!.id
                            result[first] = entry
                            for duplicate in indices.dropFirst() { result[duplicate] = nil }
                            positions[entry.matchKey] = [first]
                            action = "replace"
                        case .keepBoth:
                            if indices.contains(where: { result[$0]?.duplicates(entry) == true }) { action = "skip" }
                        }
                    }
                    if action == "add" {
                        positions[entry.matchKey, default: []].append(result.count)
                        result.append(entry)
                    }
                } catch {
                    action = "invalid"
                    preview.issues.append(.init(row: row, failure: error as? GlossaryFailure ?? .invalidCSV))
                }
                preview.rows.append(.init(number: row, fields: fields, action: action))
            }
            preview.entries = result.compactMap { $0 }
            if preview.entries.count > 10_000 { preview.issues.append(.init(row: 1, failure: .limitExceeded)) }
        } catch {
            preview.issues.append(error as? GlossaryImportPreview.Issue ?? .init(row: 1, failure: .invalidCSV))
        }
        return preview
    }

    static func export(_ entries: [GlossaryEntry]) -> Data {
        let records = [columns] + entries.map {
            [$0.sourceTerm, $0.preferredTranslation, $0.sourceLanguage.rawValue, $0.targetLanguage.rawValue,
             $0.context, String($0.caseSensitive), String($0.enabled)]
        }
        let csv = records.map { $0.map(quote).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
        return Data(csv.utf8)
    }

    private static func quote(_ field: String) -> String {
        guard field.contains(where: { [",", "\"", "\n", "\r", "\r\n"].contains(String($0)) }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func decode(_ fields: [String]) throws -> GlossaryEntry {
        guard fields.count == columns.count,
              let from = TranslationLanguage(rawValue: fields[2]), let to = TranslationLanguage(rawValue: fields[3]),
              ["true", "false"].contains(fields[5]), ["true", "false"].contains(fields[6]) else { throw GlossaryFailure.invalidEntry }
        return try GlossaryEntry(sourceTerm: fields[0], preferredTranslation: fields[1], sourceLanguage: from, targetLanguage: to,
                                 context: fields[4], caseSensitive: fields[5] == "true", enabled: fields[6] == "true").validated()
    }

    private static func parse(_ data: Data) throws -> [[String]] {
        guard data.count <= GlossaryLibrary.maximumFileBytes else { throw GlossaryImportPreview.Issue(row: 1, failure: .limitExceeded) }
        guard var text = String(data: data, encoding: .utf8), !text.contains("\0") else { throw GlossaryFailure.invalidCSV }
        if text.hasPrefix("\u{feff}") { text.removeFirst() }
        let bytes = Array(text.utf8)
        enum State { case start, unquoted, quoted, closed }
        var state = State.start
        var records: [[String]] = []
        var fields: [String] = []
        var field: [UInt8] = []
        var index = 0
        var recordStarted = false
        func invalid() -> GlossaryImportPreview.Issue { .init(row: records.count + 1, failure: .invalidCSV) }
        func endField() throws {
            fields.append(String(decoding: field, as: UTF8.self))
            field.removeAll(keepingCapacity: true)
            state = .start
            guard fields.count <= columns.count else { throw invalid() }
        }
        func endRecord() throws {
            try endField()
            records.append(fields)
            fields.removeAll(keepingCapacity: true)
            recordStarted = false
            guard records.count <= 10_001 else { throw GlossaryImportPreview.Issue(row: records.count, failure: .limitExceeded) }
        }
        while index < bytes.count {
            let byte = bytes[index]
            recordStarted = true
            if state == .quoted {
                if byte == 34 { state = .closed } else { field.append(byte) }
            } else if state == .closed && byte == 34 {
                field.append(34)
                state = .quoted
            } else if byte == 44 {
                try endField()
            } else if byte == 10 || byte == 13 {
                try endRecord()
                if byte == 13, index + 1 < bytes.count, bytes[index + 1] == 10 { index += 1 }
            } else if byte == 34, state == .start {
                state = .quoted
            } else {
                guard state != .closed, byte != 34 else { throw invalid() }
                field.append(byte)
                state = .unquoted
            }
            index += 1
        }
        guard state != .quoted else { throw invalid() }
        if recordStarted { try endRecord() }
        return records
    }
}

extension GlossaryStore {
    func importCSV(_ preview: GlossaryImportPreview, in glossaryID: UUID, expectedRevision: Int) throws {
        guard preview.canImport else { throw GlossaryFailure.invalidCSV }
        try replaceEntries(preview.entries, in: glossaryID, expectedRevision: expectedRevision)
    }
}
