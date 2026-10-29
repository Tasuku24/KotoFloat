import AppKit

struct ClipboardSnapshot {
    let generation: Int
    let items: [[NSPasteboard.PasteboardType: Data]]
}

@MainActor
protocol ClipboardAccess: AnyObject {
    var generation: Int { get }
    func snapshot() throws -> ClipboardSnapshot
    func text() -> String?
    func restore(_ snapshot: ClipboardSnapshot, ifUnchangedSince generation: Int)
}

@MainActor
protocol CopySession: AnyObject {
    var sourceIsCurrent: Bool { get }
    var interrupted: Bool { get }
    var modifiersReleased: Bool { get }
    func sendCopy() -> Bool
    func finish()
}

@MainActor
struct ClipboardCapture {
    let clipboard: any ClipboardAccess
    var wait: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }

    func capture(session: any CopySession) async throws -> String {
        defer { session.finish() }
        try check(session)
        let original = try clipboard.snapshot()
        for _ in 0..<25 {
            if session.modifiersReleased { break }
            try await wait(.milliseconds(20))
            try check(session)
        }
        guard session.modifiersReleased else { throw CaptureFailure.inputChanged }
        try check(session)
        guard clipboard.generation == original.generation else { throw CaptureFailure.clipboardChanged }
        guard session.sendCopy() else { throw CaptureFailure.copyFailed }
        for _ in 0..<40 {
            try check(session)
            let copiedGeneration = clipboard.generation
            if copiedGeneration != original.generation {
                guard copiedGeneration == original.generation + 1 else { throw CaptureFailure.clipboardChanged }
                let text = clipboard.text()
                try await wait(.milliseconds(100))
                try check(session)
                guard clipboard.generation == copiedGeneration else { throw CaptureFailure.clipboardChanged }
                clipboard.restore(original, ifUnchangedSince: copiedGeneration)
                guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw CaptureFailure.copyFailed
                }
                return text
            }
            try await wait(.milliseconds(20))
        }
        throw CaptureFailure.timedOut
    }

    private func check(_ session: any CopySession) throws {
        try Task.checkCancellation()
        guard session.sourceIsCurrent else { throw CaptureFailure.sourceChanged }
        guard !session.interrupted else { throw CaptureFailure.inputChanged }
    }
}

@MainActor
final class SystemClipboard: ClipboardAccess {
    private let pasteboard: NSPasteboard
    init(_ pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }
    var generation: Int { pasteboard.changeCount }
    func snapshot() throws -> ClipboardSnapshot {
        let before = generation
        var totalBytes = 0
        let items = try (pasteboard.pasteboardItems ?? []).map { item in
            var representations: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                guard let data = item.data(forType: type) else { throw CaptureFailure.clipboardUnavailable }
                totalBytes += data.count
                guard totalBytes <= 8 * 1024 * 1024 else { throw CaptureFailure.clipboardUnavailable }
                representations[type] = data
            }
            return representations
        }
        guard generation == before else { throw CaptureFailure.clipboardChanged }
        return ClipboardSnapshot(generation: before, items: items)
    }
    func text() -> String? { pasteboard.string(forType: .string) }
    func restore(_ snapshot: ClipboardSnapshot, ifUnchangedSince generation: Int) {
        let items = snapshot.items.map { representations in
            let item = NSPasteboardItem()
            for (type, data) in representations { item.setData(data, forType: type) }
            return item
        }
        // NSPasteboard has no cross-process compare-and-swap; keep the final check next to the write.
        // NSPasteboardにはプロセス間の原子的な比較・更新がないため、書き込み直前に再確認する。
        guard self.generation == generation else { return }
        pasteboard.clearContents()
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }
}
