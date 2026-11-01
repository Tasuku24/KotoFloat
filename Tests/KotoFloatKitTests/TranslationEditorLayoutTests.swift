import AppKit
import Testing
@testable import KotoFloatKit

// Keep native-window checks in the suite excluded from routine background tests.
// 通常のバックグラウンド検証で除外するスイート内に、ネイティブウィンドウの確認を置く。
extension PopupControllerTests {
    @Test func editorSplitStartsWithWiderResultAndKeepsManualDividerPosition() async throws {
        try await withTranslationContext { preferences, credentials in
            _ = NSApplication.shared
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1040, height: 620),
                styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.contentMinSize = CGSize(width: 840, height: 400)
            let host = TranslationEditorView(model: model, openSettings: {}, openGlossaries: {}).makeHostingView()
            window.contentView = host
            defer { window.close() }
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            let split = try #require(editorDescendants(host).compactMap { $0 as? NSSplitView }.first)
            #expect(split.arrangedSubviews.count == 2)
            #expect(abs(split.arrangedSubviews[0].frame.width - 1040 * 0.36) < 2)
            #expect(split.arrangedSubviews[1].frame.width > split.arrangedSubviews[0].frame.width)
            split.setPosition(450, ofDividerAt: 0)
            let longText = String(repeating: "Long source text. 長い原文をスクロールして確認します。\n", count: 200)
            model.editSource(longText)
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            #expect(abs(split.arrangedSubviews[0].frame.width - 450) < 2)
            model.translateSource()
            await waitFor { await service.count == 1 }
            await service.emit(longText, at: 0)
            await service.finish(at: 0)
            await waitFor { model.state == .completed }
            window.setContentSize(CGSize(width: 840, height: 400))
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            let editors = editorDescendants(host).compactMap { $0 as? NSTextView }
            #expect(editors.count == 2)
            for editor in editors {
                let scroll = try #require(editor.enclosingScrollView)
                #expect(scroll.hasVerticalScroller)
                #expect(editor.frame.height > scroll.contentView.bounds.height)
                #expect(scroll.frame.width >= 260)
                #expect(scroll.frame.height > 150)
                #expect(editor.string == longText)
            }
            #expect(!window.isVisible)
            #expect(window.frame.size.width == 840)
            #expect(await service.count == 1)
            #expect(model.state == .completed)
            model.cancel()
        }
    }

    private func editorDescendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(editorDescendants)
    }
}
