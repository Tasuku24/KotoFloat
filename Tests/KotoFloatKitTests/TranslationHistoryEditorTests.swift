import AppKit
import SwiftUI
import Testing
@testable import KotoFloatKit

extension PopupControllerTests {
    @Test func savedHistoryReopensInNativeEditorsWithoutSendingOrResizing() async throws {
        try await withTranslationContext { preferences, credentials in
            _ = NSApplication.shared
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("KotoFloatHistoryEditor-\(UUID())")
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = TranslationHistoryStore(url: directory.appendingPathComponent("history.sqlite"))
            let entry = TranslationHistoryEntry(id: UUID(), source: "これは保存済みの翻訳です。\n\n次の段落です。",
                translation: "This translation is saved locally.\n\nThis is the next paragraph.",
                sourceLanguage: .japanese, targetLanguage: .english, createdAt: Date(), updatedAt: Date())
            store.save(entry, create: true)
            await store.search("")
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, history: store, clientFactory: { _, _ in service })
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 840, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let host = TranslationEditorView(model: model, openSettings: {}, openGlossaries: {}).makeHostingView()
            window.contentView = host
            defer { window.close(); model.cancel(); Task { await service.finishAll() } }
            host.layoutSubtreeIfNeeded()
            let frame = window.frame
            let saved = try #require(await store.entry(id: entry.id))
            model.restoreHistory(saved)
            try await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            let editors = historyDescendants(host).compactMap { $0 as? NSTextView }
            #expect(editors.first { $0.accessibilityLabel() == L10n.text("editor.source") }?.string == entry.source)
            #expect(editors.first { $0.accessibilityLabel() == L10n.text("editor.translation") }?.string == entry.translation)
            #expect(window.frame == frame)
            #expect(await service.count == 0)
            #expect(!window.isVisible)
            #expect(!window.isKeyWindow)
            let historyHost = NSHostingView(rootView: TranslationHistoryView(store: store, open: model.restoreHistory, close: {}))
            window.contentView = historyHost
            window.setContentSize(CGSize(width: 440, height: 480))
            historyHost.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(250))
            historyHost.layoutSubtreeIfNeeded()
            if let path = ProcessInfo.processInfo.environment["KOTOFLOAT_HISTORY_PREVIEW"] {
                let bitmap = try #require(historyHost.bitmapImageRepForCachingDisplay(in: historyHost.bounds))
                historyHost.cacheDisplay(in: historyHost.bounds, to: bitmap)
                let data = try #require(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: path))
            }
            await store.flush()
        }
    }

    private func historyDescendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(historyDescendants)
    }
}
