import Foundation
import AppKit
import SwiftUI
import Testing
@testable import KotoFloatKit

@MainActor struct BackTranslationTests {
    @Test func translatesTheDisplayedEditedResultWithoutReplacingTheDocument() async throws {
        try await withDocument { model, service in
            model.editTranslation("This tool is helpful.")
            let revision = model.revision
            model.backTranslation.start()
            await waitFor { await service.count == 1 }
            let input = try #require(await service.input(at: 0))
            #expect(input.text == "This tool is helpful.")
            #expect(input.source == .english)
            #expect(input.target == .japanese)
            #expect(input.glossary.entries.isEmpty)
            await service.emit("この道具は", at: 0)
            #expect(model.backTranslation.resultText == "この道具は")
            await service.emit("役立ちます。", at: 0)
            await service.finish(0)
            await waitFor { model.backTranslation.state == .completed }
            #expect(model.backTranslation.resultText == "この道具は役立ちます。")
            #expect(model.sourceText == "便利な道具です。")
            #expect(model.resultText == "This tool is helpful.")
            #expect(model.revision == revision)
            model.undoManager.undo()
            #expect(model.resultText == "This is a useful tool.")
            #expect(model.backTranslation.resultText.isEmpty)
        }
    }

    @Test func automaticSourceLanguageIsDetectedFromTheOriginalRatherThanTheTranslation() async throws {
        try await withDocument(sourceLanguage: .automatic) { model, service in
            model.backTranslation.start()
            await waitFor { await service.count == 1 }
            #expect(await service.input(at: 0)?.target == .japanese)
            #expect(model.backTranslation.targetLanguage == .japanese)
            await service.emit("便利な道具です。", at: 0)
            await service.finish(0)
            await waitFor { model.backTranslation.state == .completed }
        }
    }

    @Test(arguments: ["source", "translation", "language", "server", "newDocument", "dismiss"])
    func lateBackTranslationCannotAppearForChangedOrDismissedWork(_ change: String) async throws {
        try await withDocument { model, service in
            model.backTranslation.start()
            await waitFor { await service.count == 1 }
            await service.emit("Partial", at: 0)
            switch change {
            case "source": model.editSource("Changed source", isComposing: true)
            case "translation": model.editTranslation("Keep this edit.")
            case "language": model.preferences.targetLanguage = .french
            case "server":
                try model.preferences.save(try ServerConfiguration(endpoint: "https://other.fixture.invalid", model: "other"),
                    tokenUpdate: .keep, credentials: MemoryCredentials())
            case "newDocument": model.cancel(clear: true)
            default: model.backTranslation.invalidate()
            }
            let source = model.sourceText
            let translation = model.resultText
            await service.emit("Obsolete reply", at: 0)
            await service.finish(0)
            for _ in 0..<10 { await Task.yield() }
            #expect(model.backTranslation.resultText.isEmpty)
            #expect(model.sourceText == source)
            #expect(model.resultText == translation)
        }
    }

    @Test func unknownSourceLanguageRequiresAnExplicitChoice() async throws {
        try await withDocument(source: "😀", sourceLanguage: .automatic) { model, service in
            model.backTranslation.start()
            #expect(model.backTranslation.needsLanguage)
            #expect(await service.count == 0)
            model.backTranslation.start(language: .japanese)
            await waitFor { await service.count == 1 }
            #expect(await service.input(at: 0)?.target == .japanese)
            await service.finish(0)
            await waitFor { model.backTranslation.state == .failed(.emptyResponse) }
        }
    }

    @Test func failureAndOversizedRepliesLeaveTheDocumentIntact() async throws {
        try await withDocument { model, service in
            model.backTranslation.start()
            await waitFor { await service.count == 1 }
            await service.finish(0, error: TranslationFailure.network)
            await waitFor { model.backTranslation.state == .failed(.network) }
            model.backTranslation.start()
            await waitFor { await service.count == 2 }
            await service.emit(String(repeating: "x", count: 131_073), at: 1)
            await service.finish(1)
            await waitFor { model.backTranslation.state == .failed(.outputTooLarge) }
            #expect(model.backTranslation.resultText.isEmpty)
            #expect(model.sourceText == "便利な道具です。")
            #expect(model.resultText == "This is a useful tool.")
            #expect(!model.canUndo)
        }
    }

    private func withDocument(source: String = "便利な道具です。", sourceLanguage: TranslationLanguage = .japanese,
                              _ body: (TranslationModel, BackTranslationService) async throws -> Void) async throws {
        try await withTranslationContext { preferences, credentials in
            let service = BackTranslationService()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            model.restoreHistory(TranslationHistoryEntry(id: UUID(), source: source, translation: "This is a useful tool.",
                sourceLanguage: sourceLanguage, targetLanguage: .english, createdAt: Date(), updatedAt: Date()))
            do { try await body(model, service) }
            catch { model.cancel(); await service.finishAll(); throw error }
            model.cancel()
            await service.finishAll()
        }
    }
}

extension PopupControllerTests {
    @Test func backTranslationKeepsBothEditorsVisibleAtMinimumWindowSize() async throws {
        try await withTranslationContext { preferences, credentials in
            _ = NSApplication.shared
            let service = BackTranslationService()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            model.restoreHistory(TranslationHistoryEntry(id: UUID(), source: "便利な道具です。", translation: "This is a useful tool.",
                sourceLanguage: .japanese, targetLanguage: .english, createdAt: Date(), updatedAt: Date()))
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 840, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let host = TranslationEditorView(model: model, openSettings: {}, openGlossaries: {}).makeHostingView()
            window.contentView = host
            defer { window.close(); model.cancel(); Task { await service.finishAll() } }
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            let collapse = try #require(backTranslationToolbarButtons(in: host).first)
            collapse.performClick(nil)
            try await Task.sleep(for: .milliseconds(50))
            #expect(backTranslationViews(host).compactMap { $0 as? DocumentTextView }.count == 1)
            let buttons = backTranslationToolbarButtons(in: host)
            try #require(buttons.count >= 2)
            buttons[1].performClick(nil)
            await waitFor { await service.count == 1 }
            try #require(await service.count == 1)
            await service.emit("これは便利な道具です。", at: 0)
            await service.finish(0)
            await waitFor { model.backTranslation.state == .completed }
            try await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            let backResult = try #require(backTranslationViews(host).compactMap { $0 as? NSTextView }
                .first { $0.accessibilityLabel() == L10n.text("backTranslation.result") })
            #expect(backResult.string == "これは便利な道具です。")
            #expect(!backResult.isEditable)
            #expect(backResult.accessibilityValue() == "これは便利な道具です。")
            let editors = backTranslationViews(host).compactMap { $0 as? DocumentTextView }
                .filter { $0.accessibilityLabel() != L10n.text("backTranslation.result") }
            #expect(editors.count == 2)
            for editor in editors {
                let scroll = try #require(editor.enclosingScrollView)
                #expect(scroll.frame.height >= 70)
                #expect(host.bounds.contains(scroll.convert(scroll.bounds, to: host)))
            }
            #expect(!window.isVisible)
            #expect(!window.isKeyWindow)
            #expect(window.contentView?.frame.size == CGSize(width: 840, height: 400))
            if let directory = ProcessInfo.processInfo.environment["KOTOFLOAT_EDITOR_PREVIEW_DIR"] {
                let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let data = try #require(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("06-back-translation-minimum.png"))
            }
        }
    }

    private func backTranslationViews(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(backTranslationViews)
    }

    private func backTranslationToolbarButtons(in host: NSView) -> [NSButton] {
        backTranslationViews(host).compactMap { $0 as? NSButton }.filter { button in
            let frame = button.convert(button.bounds, to: host)
            return host.isFlipped ? frame.midY < 48 : frame.midY > host.bounds.height - 48
        }.sorted { $0.convert($0.bounds, to: host).minX < $1.convert($1.bounds, to: host).minX }
    }

}

private actor BackTranslationService: TranslationServing {
    private var inputs: [TranslationInput] = []
    private var callbacks: [@Sendable (String) async -> Void] = []
    private var pending: [CheckedContinuation<Void, any Error>?] = []
    var count: Int { inputs.count }
    func models() async throws -> [String] { ["fixture-model"] }
    func translate(_ input: TranslationInput, onText: @escaping @Sendable (String) async -> Void) async throws {
        inputs.append(input)
        callbacks.append(onText)
        try await withCheckedThrowingContinuation { pending.append($0) }
    }
    func input(at index: Int) -> TranslationInput? { inputs.indices.contains(index) ? inputs[index] : nil }
    func emit(_ text: String, at index: Int) async { await callbacks[index](text) }
    func finish(_ index: Int, error: (any Error)? = nil) {
        guard pending.indices.contains(index), let continuation = pending[index] else { return }
        pending[index] = nil
        if let error { continuation.resume(throwing: error) }
        else { continuation.resume() }
    }
    func finishAll() { for index in pending.indices { finish(index, error: CancellationError()) } }
}
