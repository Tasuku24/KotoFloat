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
    var clipboardText: String?
    var clipboardAge: TimeInterval?
    var clipboardReads = 0
    var clipboardAction: (() throws -> String?)?
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
    func readClipboardText() throws -> ClipboardText? {
        clipboardReads += 1
        let text = try clipboardAction?() ?? clipboardText
        return text.map { ClipboardText(text: $0, age: clipboardAge) }
    }
}

@Suite @MainActor
struct SelectionCaptureTests {
    @Test func directSelectionPreservesWhitespaceAndSource() async throws {
        let env = CaptureEnvironmentStub()
        env.clipboardText = "Other clipboard text"
        let result = try await SelectionCapture(environment: env).capture()
        #expect(result.text == "  selected\ntext  ")
        #expect(result.source == env.source)
        #expect(result.method == .accessibility)
        #expect(env.copies == 0)
        #expect(env.clipboardReads == 0)
    }

    @Test func permissionFailureDoesNotReadOrCopy() async {
        let env = CaptureEnvironmentStub()
        env.isTrusted = false
        env.clipboardText = "Other clipboard text"
        await #expect(throws: CaptureFailure.permissionRequired) {
            try await SelectionCapture(environment: env).capture()
        }
        #expect(env.copies == 0)
        #expect(env.clipboardReads == 0)
    }

    @Test func directSelectionTranslatesWithoutReadingClipboard() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let translation = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            defer { translation.cancel() }
            let capture = CaptureModel()
            translation.bind(to: capture)
            let env = CaptureEnvironmentStub()
            let original = "Heading\n\n• First item\n• Second item\n\nClosing paragraph."
            let bounds = CGRect(x: 20, y: 40, width: 120, height: 60)
            env.selection = .selected(original, bounds)
            env.copyText = "A whole document instead of the selected words"
            env.clipboardText = "Earlier clipboard text"
            capture.start(using: SelectionCapture(environment: env), completion: {})
            await waitFor { await service.count == 1 }
            #expect(capture.state == .captured(CapturedText(text: original, source: env.source, bounds: bounds, method: .accessibility)))
            #expect(env.copies == 0)
            #expect(env.clipboardReads == 0)
            #expect(translation.sourceText == original)
            #expect(await service.inputs.last?.text == original)
            await service.emit("見出し\n\n• 最初の項目\n• 次の項目\n\n最後の段落。", at: 0)
            await service.finish(at: 0)
            await waitFor { translation.state == .completed }
            #expect(translation.output.contains("\n\n"))
        }
    }

    @Test(arguments: [SelectionRead.empty, .unavailable])
    func blockedClipboardFallsBackToManualInput(_ selection: SelectionRead) async {
        let env = CaptureEnvironmentStub()
        env.selection = selection
        env.clipboardAction = { throw CaptureFailure.clipboardReadNotAllowed }
        env.copyAction = { throw CaptureFailure.clipboardReadNotAllowed }
        let model = CaptureModel()
        model.start(using: SelectionCapture(environment: env), completion: {})
        await waitFor { model.state != .capturing }
        #expect(model.state == .failed(.clipboardReadNotAllowed))
        model.beginManualEntry()
        model.manualText = "Pasted text"
        model.acceptManualText()
        #expect(model.state == .captured(CapturedText(text: "Pasted text", source: nil, bounds: nil, method: .manual)))
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
        #expect(env.clipboardReads == 0)
    }

    @Test(arguments: [SelectionRead.empty, .selected(" \n", nil)])
    func noSelectionUsesClipboardWithoutCopyingOrClaimingTheFrontmostApp(_ selection: SelectionRead) async throws {
        let env = CaptureEnvironmentStub()
        env.selection = selection
        env.clipboardText = "  Clipboard\nparagraphs  "
        let result = try await SelectionCapture(environment: env).capture()
        #expect(result.text == env.clipboardText)
        #expect(result.method == .clipboard)
        #expect(result.source == nil)
        #expect(result.bounds == nil)
        #expect(env.copies == 0)
        #expect(env.clipboardReads == 1)
    }

    @Test func unavailableSelectionFallsBackOnlyWhenCopyDoesNotProduceText() async throws {
        let env = CaptureEnvironmentStub()
        env.selection = .unavailable
        env.copyAction = { throw CaptureFailure.timedOut }
        env.clipboardText = "Existing clipboard"
        let result = try await SelectionCapture(environment: env).capture()
        #expect(result.method == .clipboard)
        #expect(result.text == "Existing clipboard")
        #expect(env.copies == 1)
        #expect(env.clipboardReads == 1)
    }

    @Test(arguments: [CaptureFailure.sourceChanged, .inputChanged, .clipboardChanged, .copyFailed])
    func interruptedCopyNeverFallsBackToClipboard(_ failure: CaptureFailure) async {
        let env = CaptureEnvironmentStub()
        env.selection = .unavailable
        env.copyAction = { throw failure }
        env.clipboardText = "Other clipboard text"
        await #expect(throws: failure) { try await SelectionCapture(environment: env).capture() }
        #expect(env.clipboardReads == 0)
    }

    @Test func protectedFieldsDoNotReadExistingClipboard() async {
        let env = CaptureEnvironmentStub()
        env.selection = .protectedField
        env.clipboardText = "Other clipboard text"
        await #expect(throws: CaptureFailure.protectedField) { try await SelectionCapture(environment: env).capture() }
        #expect(env.clipboardReads == 0)
    }

    @Test func emptyClipboardAndSourceChangesCannotBecomeCapturedText() async {
        let env = CaptureEnvironmentStub()
        env.selection = .empty
        env.clipboardText = " \n "
        await #expect(throws: CaptureFailure.noSelection) { try await SelectionCapture(environment: env).capture() }
        env.clipboardAction = { env.source = nil; return "Late text" }
        await #expect(throws: CaptureFailure.sourceChanged) { try await SelectionCapture(environment: env).capture() }
    }

    @Test func clipboardWithUnknownCopyTimeWaitsForConfirmationBeforeTranslation() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let translation = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            defer { translation.cancel() }
            let capture = CaptureModel()
            translation.bind(to: capture)
            let env = CaptureEnvironmentStub()
            env.selection = .empty
            env.clipboardText = "Clipboard with unknown age"
            capture.start(using: SelectionCapture(environment: env), completion: {})
            await waitFor { capture.state != .capturing }
            #expect(capture.state == .needsConfirmation(CapturedText(text: "Clipboard with unknown age", source: nil,
                                                                   bounds: nil, method: .clipboard)))
            #expect(translation.state != .running)
            #expect(await service.count == 0)
            capture.confirmCopy()
            await waitFor { await service.count == 1 }
            #expect(translation.sourceText == "Clipboard with unknown age")
        }
    }

    @Test(arguments: [0.0, 299.0, 300.0])
    func recentClipboardFallbackAutomaticallyStartsTranslation(_ age: TimeInterval) async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let translation = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            defer { translation.cancel() }
            let capture = CaptureModel()
            translation.bind(to: capture)
            let env = CaptureEnvironmentStub()
            env.selection = .empty
            env.clipboardText = "Translate this clipboard text"
            env.clipboardAge = age
            capture.start(using: SelectionCapture(environment: env), completion: {})
            await waitFor { await service.count == 1 }
            #expect(capture.state == .captured(CapturedText(text: "Translate this clipboard text", source: nil,
                                                          bounds: nil, method: .clipboard, clipboardAge: age)))
            #expect(await service.inputs.last?.text == env.clipboardText)
            await service.emit("Translated clipboard", at: 0)
            await service.finish(at: 0)
            await waitFor { translation.state == .completed }
            #expect(translation.resultText == "Translated clipboard")
        }
    }

    @Test(arguments: [300.001, 600.0, -1.0])
    func olderOrInvalidClipboardAgeWaitsBeforeSendingText(_ age: TimeInterval) async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let translation = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            defer { translation.cancel() }
            let capture = CaptureModel()
            translation.bind(to: capture)
            let env = CaptureEnvironmentStub()
            env.selection = .unavailable
            env.copyAction = { throw CaptureFailure.timedOut }
            env.clipboardText = "Older clipboard text"
            env.clipboardAge = age
            capture.start(using: SelectionCapture(environment: env), completion: {})
            await waitFor { capture.state != .capturing }
            #expect(capture.state == .needsConfirmation(CapturedText(text: "Older clipboard text", source: nil,
                                                                   bounds: nil, method: .clipboard, clipboardAge: age)))
            #expect(await service.count == 0)
            capture.confirmCopy()
            await waitFor { await service.count == 1 }
            #expect(translation.sourceText == "Older clipboard text")
        }
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

    @Test func unavailableSelectionCopyStartsTranslationWithoutConfirmation() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let translation = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            defer { translation.cancel() }
            let capture = CaptureModel()
            translation.bind(to: capture)
            let env = CaptureEnvironmentStub()
            env.selection = .unavailable
            capture.start(using: SelectionCapture(environment: env), completion: {})
            await waitFor { capture.state != .capturing }
            #expect(capture.state == .captured(CapturedText(text: "copied selection", source: env.source,
                                                          bounds: nil, method: .copy)))
            #expect(translation.state == .running)
            if case .captured = capture.state {
                await waitFor { await service.count == 1 }
                #expect(await service.inputs.last?.text == "copied selection")
            }
        }
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
