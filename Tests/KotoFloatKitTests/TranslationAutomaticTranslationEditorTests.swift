import AppKit
import Testing
@testable import KotoFloatKit

extension PopupControllerTests {
    @Test func translatorCommandReturnRunsImmediatelyAndCompositionDefersAutomaticTranslation() async throws {
        try await withTranslationContext { preferences, credentials in
            _ = NSApplication.shared
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1040, height: 620), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let host = TranslationEditorView(model: model, openSettings: {}, openGlossaries: {}).makeHostingView()
            window.contentView = host
            defer { window.close(); model.cancel(); Task { await service.finishAll() } }
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
            let source = try #require(automaticEditorDescendants(host).compactMap { $0 as? DocumentTextView }
                .first { $0.accessibilityLabel() == L10n.text("editor.source") })
            source.insertText("First source", replacementRange: NSRange(location: 0, length: 0))
            #expect(model.sourceText == "First source")
            try await Task.sleep(for: .milliseconds(50))
            host.layoutSubtreeIfNeeded()
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "\r",
                charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
            #expect(host.performKeyEquivalent(with: event))
            await waitFor { await service.count == 1 }
            await service.emit("First result", at: 0)
            await service.finish(at: 0)
            await waitFor { model.state == .completed }
            try await Task.sleep(for: .milliseconds(50))
            host.layoutSubtreeIfNeeded()
            source.setMarkedText("にほん", selectedRange: NSRange(location: 3, length: 0),
                replacementRange: NSRange(location: 0, length: (source.string as NSString).length))
            #expect(source.hasMarkedText())
            try await Task.sleep(for: .milliseconds(1150))
            #expect(await service.count == 1)
            source.insertText("日本", replacementRange: NSRange(location: NSNotFound, length: 0))
            #expect(!source.hasMarkedText())
            #expect(model.sourceText == "日本")
            try await Task.sleep(for: .milliseconds(1100))
            await waitFor { await service.count == 2 }
            #expect(await service.inputs.last?.text == "日本")
            await service.emit("Japan", at: 1)
            await service.finish(at: 1)
            await waitFor { model.state == .completed }
            try await Task.sleep(for: .milliseconds(50))
            host.layoutSubtreeIfNeeded()
            #expect(host.performKeyEquivalent(with: event))
            await waitFor { await service.count == 3 }
            #expect(!window.isVisible)
            #expect(!window.isKeyWindow)
        }
    }

    private func automaticEditorDescendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(automaticEditorDescendants)
    }
}
