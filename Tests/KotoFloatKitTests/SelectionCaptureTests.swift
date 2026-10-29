import Testing
import Foundation
@testable import KotoFloatKit

@MainActor
final class CaptureEnvironmentStub: CaptureEnvironment {
    var isTrusted = true
    var source: SourceApplication? = SourceApplication(processIdentifier: 42, bundleIdentifier: "test.source", name: "Fixture")
    var selection: SelectionRead = .selected("  selected\ntext  ", nil)
    var copyText = "copied selection"
    var copies = 0
    var onRead: (() -> Void)?
    var copyAction: (() async throws -> String)?
    func currentSource() -> SourceApplication? { source }
    func readSelection(from source: SourceApplication) -> SelectionRead {
        let result = selection
        onRead?()
        return result
    }
    func copySelection(from source: SourceApplication) async throws -> String {
        copies += 1
        if let copyAction { return try await copyAction() }
        return copyText
    }
}

@Suite @MainActor
struct SelectionCaptureTests {
    @Test func directSelectionPreservesWhitespaceAndSource() async throws {
        let env = CaptureEnvironmentStub()
        let result = try await SelectionCapture(environment: env).capture()
        #expect(result.text == "  selected\ntext  ")
        #expect(result.source == env.source)
        #expect(result.method == .accessibility)
        #expect(env.copies == 0)
    }

    @Test func permissionFailureDoesNotReadOrCopy() async {
        let env = CaptureEnvironmentStub()
        env.isTrusted = false
        await #expect(throws: CaptureFailure.permissionRequired) {
            try await SelectionCapture(environment: env).capture()
        }
        #expect(env.copies == 0)
    }

    @Test func missingSourceIsExplained() async {
        let env = CaptureEnvironmentStub()
        env.source = nil
        await #expect(throws: CaptureFailure.noSource) { try await SelectionCapture(environment: env).capture() }
    }

    @Test(arguments: [SelectionRead.empty, .selected(" \n", nil), .protectedField])
    func emptyAndProtectedSelectionsNeverCopy(_ selection: SelectionRead) async {
        let env = CaptureEnvironmentStub()
        env.selection = selection
        let expected: CaptureFailure = selection == .protectedField ? .protectedField : .noSelection
        await #expect(throws: expected) { try await SelectionCapture(environment: env).capture() }
        #expect(env.copies == 0)
    }

    @Test func unsupportedSelectionUsesCopyButRetainsOrigin() async throws {
        let env = CaptureEnvironmentStub()
        env.selection = .unavailable
        let result = try await SelectionCapture(environment: env).capture()
        #expect(result.text == "copied selection")
        #expect(result.method == .copy)
        #expect(env.copies == 1)
    }

    @Test func appSwitchDuringDirectReadDiscardsText() async {
        let env = CaptureEnvironmentStub()
        env.onRead = { env.source = nil }
        await #expect(throws: CaptureFailure.sourceChanged) { try await SelectionCapture(environment: env).capture() }
    }

    @Test func appSwitchDuringCopyDiscardsText() async {
        let env = CaptureEnvironmentStub()
        env.selection = .unavailable
        env.copyAction = { env.source = nil; return "wrong app" }
        await #expect(throws: CaptureFailure.sourceChanged) { try await SelectionCapture(environment: env).capture() }
    }

    @Test func copiedTextNeedsExplicitConfirmation() async {
        let env = CaptureEnvironmentStub()
        env.selection = .unavailable
        let model = CaptureModel()
        model.start(using: SelectionCapture(environment: env), completion: {})
        for _ in 0..<10 { await Task.yield() }
        guard case .needsConfirmation(let text) = model.state else {
            Issue.record("Copied text must be unconfirmed"); return
        }
        model.confirmCopy()
        #expect(model.state == .captured(text))
    }

    @Test func manualInputCannotAcceptWhitespace() {
        let model = CaptureModel()
        model.beginManualEntry()
        model.manualText = " \n"
        model.acceptManualText()
        #expect(model.state == .manual)
        model.manualText = "manual input"
        model.acceptManualText()
        #expect(model.state == .captured(CapturedText(text: "manual input", source: nil, bounds: nil, method: .manual)))
    }

    @Test func delayedCopyCannotOverwriteNewerManualInputOrCallCompletion() async {
        let env = CaptureEnvironmentStub()
        env.selection = .unavailable
        var resume: CheckedContinuation<String, Never>?
        env.copyAction = { await withCheckedContinuation { resume = $0 } }
        let model = CaptureModel()
        var completions = 0
        model.start(using: SelectionCapture(environment: env), completion: { completions += 1 })
        for _ in 0..<10 { await Task.yield() }
        model.beginManualEntry()
        model.manualText = "new text"
        model.acceptManualText()
        resume?.resume(returning: "old text")
        for _ in 0..<10 { await Task.yield() }
        #expect(model.state == .captured(CapturedText(text: "new text", source: nil, bounds: nil, method: .manual)))
        #expect(completions == 0)
    }

    @Test func newerCaptureWinsEvenIfOlderOperationIgnoresCancellation() async {
        let slow = CaptureEnvironmentStub()
        slow.selection = .unavailable
        var resume: CheckedContinuation<String, Never>?
        slow.copyAction = { await withCheckedContinuation { resume = $0 } }
        let model = CaptureModel()
        var completions = 0
        model.start(using: SelectionCapture(environment: slow), completion: { completions += 1 })
        for _ in 0..<10 { await Task.yield() }
        let fast = CaptureEnvironmentStub()
        model.start(using: SelectionCapture(environment: fast), completion: { completions += 1 })
        for _ in 0..<10 { await Task.yield() }
        resume?.resume(returning: "old")
        for _ in 0..<10 { await Task.yield() }
        #expect(model.state == .captured(CapturedText(text: "  selected\ntext  ", source: fast.source, bounds: nil, method: .accessibility)))
        #expect(completions == 1)
    }
}
