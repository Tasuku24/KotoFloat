import AppKit

struct ClipboardSnapshot {
    let generation: Int
    let items: [[NSPasteboard.PasteboardType: Data]]
    let copiedAt: Date?

    init(generation: Int, items: [[NSPasteboard.PasteboardType: Data]], copiedAt: Date? = nil) {
        self.generation = generation
        self.items = items
        self.copiedAt = copiedAt
    }
}

struct ClipboardText {
    let text: String
    let age: TimeInterval?
}

@MainActor
protocol ClipboardAccess: AnyObject {
    var canReadWithoutPrompt: Bool { get }
    var generation: Int { get }
    var age: TimeInterval? { get }
    func snapshot() throws -> ClipboardSnapshot
    func text() -> String?
    func restore(_ snapshot: ClipboardSnapshot, ifUnchangedSince generation: Int)
}

extension ClipboardAccess {
    var age: TimeInterval? { nil }

    func requireReadWithoutPrompt() throws {
        guard canReadWithoutPrompt else { throw CaptureFailure.clipboardReadNotAllowed }
    }

    func readTextWithoutPrompt() throws -> String? {
        try requireReadWithoutPrompt()
        return text()
    }

    func readStableText() throws -> ClipboardText? {
        let before = generation
        let value = try readTextWithoutPrompt()
        let age = age
        guard generation == before else { throw CaptureFailure.clipboardChanged }
        return value.map { ClipboardText(text: $0, age: age) }
    }
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
        try clipboard.requireReadWithoutPrompt()
        let original = try clipboard.snapshot()
        for _ in 0..<25 {
            if session.modifiersReleased { break }
            try await wait(.milliseconds(20))
            try check(session)
        }
        guard session.modifiersReleased else { throw CaptureFailure.inputChanged }
        try check(session)
        guard clipboard.generation == original.generation else { throw CaptureFailure.clipboardChanged }
        try clipboard.requireReadWithoutPrompt()
        guard session.sendCopy() else { throw CaptureFailure.copyFailed }
        for _ in 0..<40 {
            try check(session)
            let copiedGeneration = clipboard.generation
            if copiedGeneration != original.generation {
                guard copiedGeneration == original.generation + 1 else { throw CaptureFailure.clipboardChanged }
                let read = Result { try clipboard.readTextWithoutPrompt() }
                try await wait(.milliseconds(100))
                try check(session)
                guard clipboard.generation == copiedGeneration else { throw CaptureFailure.clipboardChanged }
                clipboard.restore(original, ifUnchangedSince: copiedGeneration)
                guard let text = try read.get(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
    private let now: () -> Date
    private var observedGeneration: Int
    private var lastObservedAt: Date
    private var copiedAt: Date?
    private var observationTask: Task<Void, Never>?

    init(_ pasteboard: NSPasteboard = .general, observeChanges: Bool = false, now: @escaping () -> Date = Date.init) {
        self.pasteboard = pasteboard
        self.now = now
        observedGeneration = pasteboard.changeCount
        lastObservedAt = now()
        if observeChanges {
            observationTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(500)) }
                    catch { return }
                    guard let self else { return }
                    observeChangesIfNeeded()
                }
            }
        }
    }

    deinit { observationTask?.cancel() }

    var canReadWithoutPrompt: Bool {
        if #available(macOS 15.4, *) {
            return pasteboard.accessBehavior == .alwaysAllow
        }
        return true
    }

    var generation: Int {
        observeChangesIfNeeded()
        return observedGeneration
    }

    var age: TimeInterval? {
        observeChangesIfNeeded()
        guard let copiedAt else { return nil }
        let elapsed = lastObservedAt.timeIntervalSince(copiedAt)
        return elapsed >= 0 ? elapsed : nil
    }

    private func observeChangesIfNeeded() {
        let current = pasteboard.changeCount
        let observedAt = now()
        if observedAt < lastObservedAt {
            copiedAt = nil
        } else if current != observedGeneration {
            // Use the earliest possible copy time, including across sleep or a delayed poll.
            // スリープや監視の遅延も含め、コピーされた可能性がある最も早い時刻を使う。
            copiedAt = lastObservedAt
        }
        observedGeneration = current
        lastObservedAt = observedAt
    }
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
        return ClipboardSnapshot(generation: before, items: items, copiedAt: copiedAt)
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
        // Restoring a selection-copy transaction must not make old clipboard text recent.
        // 選択文のコピー後に元の内容を復元しても、古い文章のコピー時刻は更新しない。
        observedGeneration = pasteboard.changeCount
        copiedAt = snapshot.copiedAt
        lastObservedAt = now()
    }
}
