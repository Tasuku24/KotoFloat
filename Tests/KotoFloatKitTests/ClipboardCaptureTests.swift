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
