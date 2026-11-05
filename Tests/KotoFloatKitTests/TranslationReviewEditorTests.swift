import AppKit
import Testing
@testable import KotoFloatKit

extension PopupControllerTests {
    @Test func reviewKeepsClickedViewportStableWhenMatchedPassageIsLong() async throws {
        try await withTranslationContext { preferences, credentials in
            _ = NSApplication.shared
            preferences.targetLanguage = .english
            let translation = (0..<8).map { "Passage \($0) " + String(repeating: "useful words ", count: 200) + "." }.joined(separator: "\n")
            let service = ReviewService(translation: translation)
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            model.start(text: CapturedText(text: String(repeating: "便利な道具です。\n", count: 8), source: nil, bounds: nil, method: .manual))
            await waitFor { model.state == .completed }
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1040, height: 620), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let host = TranslationEditorView(model: model, openSettings: {}, openGlossaries: {}).makeHostingView()
            window.contentView = host
            defer { window.close(); model.cancel(); Task { await service.finishAll() } }
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
            let target = try #require(reviewEditorDescendants(host).compactMap { $0 as? DocumentTextView }
                .first { $0.accessibilityLabel() == L10n.text("editor.translation") })
            let location = (translation as NSString).range(of: "Passage 7").location
            target.layoutManager?.ensureLayout(for: try #require(target.textContainer))
            target.setSelectedRange(NSRange(location: location, length: 0))
            target.scrollRangeToVisible(NSRange(location: location, length: 1))
            let scroll = try #require(target.enclosingScrollView)
            let origin = scroll.contentView.bounds.origin
            #expect(origin.y > 0)
            #expect(target.reviewSelection(nil))
            await waitFor { await service.reviewCount == 1 }
            await service.answerReview(0, source: Array(0..<8), target: Array(0..<8))
            await waitFor { model.review.phase == .ready }
            try await Task.sleep(for: .milliseconds(50))
            host.layoutSubtreeIfNeeded()
            #expect(scroll.contentView.bounds.origin == origin)
            #expect(target.selectedRange() == NSRange(location: location, length: 0))
            #expect(target.layoutManager?.temporaryAttribute(.backgroundColor, atCharacterIndex: 0, effectiveRange: nil) != nil)
            #expect(!window.isVisible)
            #expect(!window.isKeyWindow)
        }
    }

    @Test func reviewActionHighlightsBothNativeEditorsWithoutChangingTextOrSelection() async throws {
        try await withTranslationContext { preferences, credentials in
            _ = NSApplication.shared
            preferences.targetLanguage = .english
            let service = ReviewService()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            model.start(text: CapturedText(text: "便利な道具です。\n\nこの文は変更しません。", source: nil, bounds: nil, method: .manual))
            await waitFor { model.state == .completed }
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1040, height: 620), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let host = TranslationEditorView(model: model, openSettings: {}, openGlossaries: {}).makeHostingView()
            window.contentView = host
            defer { window.close(); model.cancel(); Task { await service.finishAll() } }
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
            let editors = reviewEditorDescendants(host).compactMap { $0 as? NSTextView }
            let source = try #require(editors.first { $0.accessibilityLabel() == L10n.text("editor.source") })
            let target = try #require(editors.first { $0.accessibilityLabel() == L10n.text("editor.translation") })
            let location = (target.string as NSString).range(of: "useful").location
            target.setSelectedRange(NSRange(location: location, length: 0))
            #expect(NSApp.sendAction(#selector(DocumentTextView.reviewSelection(_:)), to: target, from: nil))
            await waitFor { await service.reviewCount == 1 }
            await service.answerReview(0)
            await waitFor { model.review.phase == .ready }
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
            host.layoutSubtreeIfNeeded()
            #expect(source.layoutManager?.temporaryAttribute(.backgroundColor, atCharacterIndex: 0, effectiveRange: nil) != nil)
            #expect(target.layoutManager?.temporaryAttribute(.backgroundColor, atCharacterIndex: 0, effectiveRange: nil) != nil)
            #expect(target.textStorage?.attribute(.backgroundColor, at: 0, effectiveRange: nil) == nil)
            #expect(target.selectedRange() == NSRange(location: location, length: 0))
            #expect(target.string == "This is a useful tool.\n\nKeep this sentence.")
            #expect(!model.canUndo)
            #expect(!window.isVisible)
            #expect(!window.isKeyWindow)
            model.review.inspect(side: .source, at: 0)
            await waitFor { await service.reviewCount == 2 }
            let popover = TranslationAlternativesPopover()
            popover.update(in: target, review: model.review)
            popover.popoverDidClose(Notification(name: NSPopover.didCloseNotification))
            #expect(model.review.phase == .loading)
            await service.answerReview(1)
            await waitFor { model.review.phase == .ready }
            model.editSource("Changed source")
            try await Task.sleep(for: .milliseconds(50))
            host.layoutSubtreeIfNeeded()
            #expect(source.layoutManager?.temporaryAttribute(.backgroundColor, atCharacterIndex: 0, effectiveRange: nil) == nil)
            #expect(target.layoutManager?.temporaryAttribute(.backgroundColor, atCharacterIndex: 0, effectiveRange: nil) == nil)
        }
    }

    private func reviewEditorDescendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(reviewEditorDescendants)
    }
}
