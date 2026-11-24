import AppKit
import Testing
@testable import KotoFloatKit

@MainActor
final class CopySessionStub: CopySession {
    var sourceIsCurrent = true
    var interrupted = false
    var modifiersReleased = true
    var sends = 0
    var finished = false
    var onSend: () -> Bool = { true }
    func sendCopy() -> Bool { sends += 1; return onSend() }
    func finish() { finished = true }
}

@Suite @MainActor
struct ClipboardCaptureTests {
    private func board() -> NSPasteboard { NSPasteboard.withUniqueName() }
    private func write(_ text: String, to board: NSPasteboard) {
        board.clearContents()
        board.setString(text, forType: .string)
    }

    @Test func successfulCopyRestoresEveryFormatAndItem() async throws {
        let board = board()
        defer { board.releaseGlobally() }
        let first = NSPasteboardItem()
        first.setString("original", forType: .string)
        first.setData(Data("{\\rtf1\\ansi original}".utf8), forType: .rtf)
        let second = NSPasteboardItem()
        second.setString("file:///fixture", forType: .fileURL)
        board.writeObjects([first, second])
        let session = CopySessionStub()
        session.onSend = { write("selected", to: board); return true }
        let capture = ClipboardCapture(clipboard: SystemClipboard(board), wait: { _ in })
        #expect(try await capture.capture(session: session) == "selected")
        #expect(board.pasteboardItems?.count == 2)
        #expect(board.pasteboardItems?.first?.string(forType: .string) == "original")
        #expect(board.pasteboardItems?.first?.data(forType: .rtf) == Data("{\\rtf1\\ansi original}".utf8))
        #expect(board.pasteboardItems?.last?.string(forType: .fileURL) == "file:///fixture")
        #expect(session.finished)
    }

    @Test func clipboardFallbackReadsTextWithoutChangingContentsOrGeneration() throws {
        let board = board()
        defer { board.releaseGlobally() }
        write("  Existing\nclipboard  ", to: board)
        let clipboard = SystemClipboard(board)
        let original = try clipboard.snapshot()
        #expect(try clipboard.readStableText()?.text == "  Existing\nclipboard  ")
        #expect(clipboard.generation == original.generation)
        #expect(try clipboard.snapshot().items == original.items)
        board.clearContents()
        board.setData(Data([1]), forType: .png)
        let generation = clipboard.generation
        #expect(try clipboard.readStableText() == nil)
        #expect(clipboard.generation == generation)
    }

    @Test func clipboardFallbackRejectsAConcurrentClipboardWrite() {
        let clipboard = ChangingClipboard()
        #expect(throws: CaptureFailure.clipboardChanged) { try clipboard.readStableText() }
    }

    @Test func blockedAccessSkipsReadingExistingClipboardAndSendingCopy() async {
        let clipboard = ChangingClipboard()
        clipboard.canReadWithoutPrompt = false
        let session = CopySessionStub()
        let capture = ClipboardCapture(clipboard: clipboard, wait: { _ in })

        #expect(throws: CaptureFailure.clipboardReadNotAllowed) { try clipboard.readStableText() }
        await #expect(throws: CaptureFailure.clipboardReadNotAllowed) { try await capture.capture(session: session) }
        #expect(clipboard.snapshots == 0)
        #expect(clipboard.reads == 0)
        #expect(session.sends == 0)
        #expect(session.finished)
    }

    @Test func accessRevokedWhileWaitingForModifiersStopsCopy() async {
        let clipboard = ChangingClipboard()
        let session = CopySessionStub()
        session.modifiersReleased = false
        let capture = ClipboardCapture(clipboard: clipboard, wait: { _ in
            clipboard.canReadWithoutPrompt = false
            session.modifiersReleased = true
        })

        await #expect(throws: CaptureFailure.clipboardReadNotAllowed) { try await capture.capture(session: session) }
        #expect(clipboard.reads == 0)
        #expect(session.sends == 0)
    }

    @Test func accessRevokedAfterCopySkipsReadingAndRestoresOriginalSnapshot() async {
        let clipboard = ChangingClipboard()
        let session = CopySessionStub()
        session.onSend = {
            clipboard.generation += 1
            clipboard.canReadWithoutPrompt = false
            return true
        }
        let capture = ClipboardCapture(clipboard: clipboard, wait: { _ in })

        await #expect(throws: CaptureFailure.clipboardReadNotAllowed) { try await capture.capture(session: session) }
        #expect(clipboard.reads == 0)
        #expect(clipboard.restoredSnapshot?.generation == 0)
    }

    @Test func existingTextHasUnknownAgeAndObservedCopiesExpireWithoutBeingRead() throws {
        let board = board()
        defer { board.releaseGlobally() }
        write("Before launch", to: board)
        var now = Date(timeIntervalSince1970: 1_000)
        let clipboard = SystemClipboard(board, now: { now })
        #expect(try clipboard.readStableText()?.age == nil)
        now = Date(timeIntervalSince1970: 1_010)
        _ = clipboard.generation
        write("New copy", to: board)
        now = Date(timeIntervalSince1970: 1_010.5)
        _ = clipboard.generation
        now = Date(timeIntervalSince1970: 1_310)
        let recentValue = try clipboard.readStableText()
        let recent = try #require(recentValue)
        #expect(recent.text == "New copy")
        #expect(recent.age == 300)
        now = Date(timeIntervalSince1970: 1_311)
        #expect(try clipboard.readStableText()?.age == 301)
        write("New copy", to: board)
        #expect(try clipboard.readStableText()?.age == 0)
    }

    @Test func delayedObservationDoesNotTreatAnOldCopyAsNew() throws {
        let board = board()
        defer { board.releaseGlobally() }
        var now = Date(timeIntervalSince1970: 1_000)
        let clipboard = SystemClipboard(board, now: { now })
        write("Copied while observation was suspended", to: board)
        now = Date(timeIntervalSince1970: 1_601)
        #expect(try clipboard.readStableText()?.age == 601)
    }

    @Test func clockMovingBackwardsCannotMakeAnOldClipboardRecent() throws {
        let board = board()
        defer { board.releaseGlobally() }
        var now = Date(timeIntervalSince1970: 1_000)
        let clipboard = SystemClipboard(board, now: { now })
        write("Old copy", to: board)
        _ = clipboard.generation
        now = Date(timeIntervalSince1970: 1_400)
        #expect(try clipboard.readStableText()?.age == 400)
        now = Date(timeIntervalSince1970: 1_200)
        #expect(try clipboard.readStableText()?.age == nil)
    }

    @Test(arguments: [false, true])
    func selectionCopyRestorationPreservesOriginalClipboardAge(_ knownAge: Bool) async throws {
        let board = board()
        defer { board.releaseGlobally() }
        write("Original clipboard", to: board)
        var now = Date(timeIntervalSince1970: 1_000)
        let clipboard = SystemClipboard(board, now: { now })
        if knownAge {
            write("Original clipboard", to: board)
            _ = clipboard.generation
        }
        now = Date(timeIntervalSince1970: 1_601)
        let session = CopySessionStub()
        session.onSend = { write("Selected text", to: board); return true }
        let capture = ClipboardCapture(clipboard: clipboard, wait: { _ in })
        #expect(try await capture.capture(session: session) == "Selected text")
        let restoredValue = try clipboard.readStableText()
        let restored = try #require(restoredValue)
        #expect(restored.text == "Original clipboard")
        #expect(restored.age == (knownAge ? 601 : nil))
    }

    @Test func unchangedClipboardIsNeverUsedAsSelection() async {
        let board = board()
        defer { board.releaseGlobally() }
        write("old unrelated clipboard", to: board)
        let session = CopySessionStub()
        let capture = ClipboardCapture(clipboard: SystemClipboard(board), wait: { _ in })
        await #expect(throws: CaptureFailure.timedOut) { try await capture.capture(session: session) }
        #expect(board.string(forType: .string) == "old unrelated clipboard")
        #expect(session.finished)
    }

    @Test func twoWritesBeforeFirstObservationPreserveNewerClipboard() async {
        let board = board()
        defer { board.releaseGlobally() }
        write("original", to: board)
        let session = CopySessionStub()
        session.onSend = {
            write("selection", to: board)
            write("newer copy before first poll", to: board)
            return true
        }
        let capture = ClipboardCapture(clipboard: SystemClipboard(board), wait: { _ in })
        await #expect(throws: CaptureFailure.clipboardChanged) { try await capture.capture(session: session) }
        #expect(board.string(forType: .string) == "newer copy before first poll")
    }

    @Test func newerCopyDuringSettlingIsPreserved() async {
        let board = board()
        defer { board.releaseGlobally() }
        write("original", to: board)
        let session = CopySessionStub()
        session.onSend = { write("selection", to: board); return true }
        let capture = ClipboardCapture(clipboard: SystemClipboard(board), wait: { _ in
            write("newer user copy", to: board)
        })
        await #expect(throws: CaptureFailure.clipboardChanged) { try await capture.capture(session: session) }
        #expect(board.string(forType: .string) == "newer user copy")
    }

    @Test func snapshotRestorationCannotOverwriteNewGeneration() throws {
        let board = board()
        defer { board.releaseGlobally() }
        write("original", to: board)
        let clipboard = SystemClipboard(board)
        let snapshot = try clipboard.snapshot()
        write("selection", to: board)
        let observed = clipboard.generation
        write("new copy", to: board)
        clipboard.restore(snapshot, ifUnchangedSince: observed)
        #expect(board.string(forType: .string) == "new copy")
    }

    @Test func nonTextCopyFailsAndRestoresOriginal() async {
        let board = board()
        defer { board.releaseGlobally() }
        write("original", to: board)
        let session = CopySessionStub()
        session.onSend = {
            board.clearContents()
            board.setData(Data([1]), forType: .png)
            return true
        }
        let capture = ClipboardCapture(clipboard: SystemClipboard(board), wait: { _ in })
        await #expect(throws: CaptureFailure.copyFailed) { try await capture.capture(session: session) }
        #expect(board.string(forType: .string) == "original")
    }

    @Test func appSwitchAfterCopyDoesNotRestoreAmbiguousClipboard() async {
        let board = board()
        defer { board.releaseGlobally() }
        write("original", to: board)
        let session = CopySessionStub()
        session.onSend = { write("new value", to: board); return true }
        let capture = ClipboardCapture(clipboard: SystemClipboard(board), wait: { _ in session.sourceIsCurrent = false })
        await #expect(throws: CaptureFailure.sourceChanged) { try await capture.capture(session: session) }
        #expect(board.string(forType: .string) == "new value")
    }

    @Test func unrelatedInputCancelsWithoutOverwritingClipboard() async {
        let board = board()
        defer { board.releaseGlobally() }
        write("original", to: board)
        let session = CopySessionStub()
        session.onSend = { write("new value", to: board); return true }
        let capture = ClipboardCapture(clipboard: SystemClipboard(board), wait: { _ in session.interrupted = true })
        await #expect(throws: CaptureFailure.inputChanged) { try await capture.capture(session: session) }
        #expect(board.string(forType: .string) == "new value")
    }

    @Test func heldModifiersTimeoutBeforeCopy() async {
        let board = board()
        defer { board.releaseGlobally() }
        write("original", to: board)
        let session = CopySessionStub()
        session.modifiersReleased = false
        let capture = ClipboardCapture(clipboard: SystemClipboard(board), wait: { _ in })
        await #expect(throws: CaptureFailure.inputChanged) { try await capture.capture(session: session) }
        #expect(session.sends == 0)
        #expect(board.string(forType: .string) == "original")
    }

    @Test func clipboardChangeWhileWaitingForModifiersPreventsCopy() async {
        let board = board()
        defer { board.releaseGlobally() }
        write("original", to: board)
        let session = CopySessionStub()
        session.modifiersReleased = false
        let capture = ClipboardCapture(clipboard: SystemClipboard(board), wait: { _ in
            write("new copy", to: board)
            session.modifiersReleased = true
        })
        await #expect(throws: CaptureFailure.clipboardChanged) { try await capture.capture(session: session) }
        #expect(session.sends == 0)
        #expect(board.string(forType: .string) == "new copy")
    }

    @Test func cancelledWaitDoesNotRestoreClipboard() async {
        let board = board()
        defer { board.releaseGlobally() }
        write("original", to: board)
        let session = CopySessionStub()
        session.onSend = { write("new copy", to: board); return true }
        let capture = ClipboardCapture(clipboard: SystemClipboard(board), wait: { _ in throw CancellationError() })
        await #expect(throws: CancellationError.self) { try await capture.capture(session: session) }
        #expect(board.string(forType: .string) == "new copy")
        #expect(session.finished)
    }
}

@MainActor private final class ChangingClipboard: ClipboardAccess {
    var canReadWithoutPrompt = true
    var generation = 0
    var snapshots = 0
    var reads = 0
    var restoredSnapshot: ClipboardSnapshot?
    func snapshot() throws -> ClipboardSnapshot {
        snapshots += 1
        return ClipboardSnapshot(generation: generation, items: [])
    }
    func text() -> String? {
        reads += 1
        generation += 1
        return "Text from an obsolete generation"
    }
    func restore(_ snapshot: ClipboardSnapshot, ifUnchangedSince generation: Int) {
        guard self.generation == generation else { return }
        restoredSnapshot = snapshot
    }
}
