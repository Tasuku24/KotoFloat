import AppKit
import SwiftUI
import Testing
@testable import KotoFloatKit

@Suite(.serialized) @MainActor
struct PopupControllerTests {
    @Test func compatibilityModeExposesStandardMainCapableWindow() throws {
        try withController { controller in
            controller.setFocusMode(.autoRaiseCompatible)
            controller.showSample()
            #expect(controller.panel.canBecomeMain)
            #expect(controller.panel.accessibilitySubrole() == .standardWindow)
        }
    }

    @Test func standardModeDoesNotBecomeMainWhenFocused() throws {
        try withController { controller in
            controller.showSample()
            try focus(controller.panel)
            #expect(!controller.panel.isMainWindow)
        }
    }

    @Test func switchingModePreservesVisibleFrameAndSampleContent() throws {
        try withController { controller in
            controller.showSample()
            controller.sample.isLong = true
            let originalWindow = controller.panel
            let frame = originalWindow.frame
            controller.setFocusMode(.autoRaiseCompatible)
            #expect(controller.panel !== originalWindow)
            #expect(!originalWindow.isVisible)
            #expect(controller.panel.isVisible)
            #expect(controller.panel.frame == frame)
            #expect(controller.sample.isLong)
            controller.setFocusMode(.standard)
            #expect(controller.panel.isVisible)
            #expect(controller.panel.frame == frame)
            #expect(controller.sample.isLong)
        }
    }

    @Test func switchingModeDoesNotOpenHiddenPopupOrLoseSavedFrame() throws {
        try withController { controller in
            let frame = CGRect(x: 100, y: 100, width: 500, height: 400)
            controller.preferences.savedFrame = frame
            controller.setFocusMode(.autoRaiseCompatible)
            #expect(!controller.panel.isVisible)
            #expect(controller.preferences.savedFrame == frame)
        }
    }

    @Test func closingAndReleasingControllerReleasesItsPanel() async throws {
        _ = NSApplication.shared
        let suite = "KotoFloatLifetimeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var controller: PopupController? = PopupController(preferences: PopupPreferences(defaults: defaults))
        weak var releasedController = controller
        weak var panel = controller?.panel
        controller?.showSample()
        controller?.panel.close()
        controller = nil
        try await Task.sleep(for: .milliseconds(150))
        #expect(releasedController == nil)
        #expect(panel == nil)
        releasedController = nil
        panel = nil
    }

    @Test func longTextDoesNotResizeOrMovePopup() async throws {
        let suite = "KotoFloatLongTextTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let controller = PopupController(preferences: PopupPreferences(defaults: defaults))
        defer {
            controller.panel.close()
            defaults.removePersistentDomain(forName: suite)
        }
        controller.showSample()
        let initialFrame = controller.panel.frame
        controller.sample.isLong = true
        try await Task.sleep(for: .milliseconds(150))
        controller.panel.contentView?.layoutSubtreeIfNeeded()
        #expect(controller.panel.frame == initialFrame)
        let content = try #require(controller.panel.contentView)
        let scrollView = try #require(findScrollView(in: content))
        #expect(try #require(scrollView.documentView).frame.height > scrollView.contentView.bounds.height)
    }

    @Test func escapeKeyEventClosesFocusedPanel() throws {
        try withController { controller in
            controller.showSample()
            try focus(controller.panel)
            #expect(controller.panel.isKeyWindow)
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: [], timestamp: 0, windowNumber: controller.panel.windowNumber,
                context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                isARepeat: false, keyCode: 53))
            controller.panel.sendEvent(event)
            #expect(!controller.panel.isVisible)
        }
    }

    @Test func showingPreservesSourceFocusAndRepeatedShowUsesSameWindow() throws {
        try withController { controller in
            let source = NSPanel(contentRect: CGRect(x: 100, y: 100, width: 300, height: 200),
                                 styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
            source.isReleasedWhenClosed = false
            defer { source.close() }
            source.makeKeyAndOrderFront(nil)
            #expect(source.isKeyWindow)
            let activePID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            controller.showSample()
            #expect(controller.panel.isVisible)
            #expect(!controller.panel.isKeyWindow)
            #expect(source.isKeyWindow)
            #expect(NSWorkspace.shared.frontmostApplication?.processIdentifier == activePID)
            let number = controller.panel.windowNumber
            let frame = controller.panel.frame
            controller.showSample()
            #expect(controller.panel.windowNumber == number)
            #expect(controller.panel.frame == frame)
        }
    }

    @Test func focusLossKeepsPopupVisibleAndEscapeOnlyClosesKeyPopup() throws {
        try withController { controller in
            controller.showSample()
            try focus(controller.panel)
            #expect(controller.panel.isKeyWindow)
            let other = NSPanel(contentRect: CGRect(x: 100, y: 100, width: 300, height: 200),
                                styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
            other.isReleasedWhenClosed = false
            defer { other.close() }
            other.makeKeyAndOrderFront(nil)
            #expect(other.isKeyWindow)
            #expect(!controller.panel.isKeyWindow)
            #expect(controller.panel.isVisible)
            controller.panel.cancelOperation(nil)
            #expect(controller.panel.isVisible)
            try focus(controller.panel)
            #expect(controller.panel.isKeyWindow)
            controller.panel.cancelOperation(nil)
            #expect(!controller.panel.isVisible)
        }
    }

    @Test func closeButtonAndReopenPreserveUserFrame() throws {
        try withController { controller in
            controller.showSample()
            let usable = try #require(NSScreen.main?.visibleFrame)
            let target = CGRect(x: usable.minX + 30, y: usable.minY + 30, width: 520, height: 360)
            controller.panel.setFrame(target, display: true)
            controller.panel.standardWindowButton(.closeButton)?.performClick(nil)
            #expect(!controller.panel.isVisible)
            #expect(controller.preferences.savedFrame == target)
            controller.showSample()
            #expect(controller.panel.frame == target)
        }
    }

    @Test func changingTopmostUpdatesVisiblePanelWithoutHidingOrMovingIt() throws {
        try withController { controller in
            controller.showSample()
            let frame = controller.panel.frame
            #expect(controller.panel.level == .floating)
            controller.setAlwaysOnTop(false)
            #expect(controller.panel.level == .normal)
            #expect(controller.panel.isVisible)
            #expect(controller.panel.frame == frame)
            controller.setAlwaysOnTop(true)
            #expect(controller.panel.level == .floating)
        }
    }

    @Test func recoversOffscreenVisibleWindowWithoutReopeningHiddenWindow() throws {
        try withController { controller in
            controller.showSample()
            controller.panel.setFrameOrigin(CGPoint(x: 50000, y: 50000))
            controller.recoverVisibleFrame()
            #expect(NSScreen.screens.contains { $0.visibleFrame.contains(controller.panel.frame) })
            controller.panel.close()
            controller.recoverVisibleFrame()
            #expect(!controller.panel.isVisible)
        }
    }

    @Test func capturedSelectionReusesPopupAndPreservesFrameAndFocus() async throws {
        try await withCaptureController { controller, env in
            controller.showSample()
            let frame = controller.panel.frame
            let number = controller.panel.windowNumber
            let source = NSWorkspace.shared.frontmostApplication?.processIdentifier
            controller.captureSelectedText()
            try await Task.sleep(for: .milliseconds(50))
            #expect(controller.capture.state == .captured(CapturedText(text: "  selected\ntext  ", source: env.source, bounds: nil, method: .accessibility)))
            #expect(!controller.capture.showsSample)
            #expect(controller.panel.isVisible)
            #expect(controller.panel.frame == frame)
            #expect(controller.panel.windowNumber == number)
            #expect(NSWorkspace.shared.frontmostApplication?.processIdentifier == source)
            controller.setFocusMode(.autoRaiseCompatible)
            #expect(controller.capture.state == .captured(CapturedText(text: "  selected\ntext  ", source: env.source, bounds: nil, method: .accessibility)))
        }
    }

    @Test func permissionFailureOpensExplainedFallback() async throws {
        try await withCaptureController { controller, env in
            env.isTrusted = false
            controller.captureSelectedText()
            try await Task.sleep(for: .milliseconds(50))
            #expect(controller.capture.state == .failed(.permissionRequired))
            #expect(controller.panel.isVisible)
            controller.showManualEntry()
            #expect(controller.capture.state == .manual)
            #expect(!controller.capture.showsSample)
        }
    }

    @Test func closingPopupCancelsPendingCaptureWithoutReopening() async throws {
        try await withCaptureController { controller, env in
            controller.showSample()
            env.selection = .unavailable
            var resume: CheckedContinuation<String, Never>?
            env.copyAction = { await withCheckedContinuation { resume = $0 } }
            controller.captureSelectedText()
            try await Task.sleep(for: .milliseconds(20))
            #expect(controller.capture.state == .capturing)
            let finish = try #require(resume)
            controller.panel.close()
            finish.resume(returning: "late copy")
            try await Task.sleep(for: .milliseconds(20))
            #expect(!controller.panel.isVisible)
            #expect(controller.capture.state == .idle)
        }
    }

    @Test func editorNativeInsertionUpdatesTheSharedModel() async throws {
        try await withTranslationContext { preferences, credentials in
            _ = NSApplication.shared
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            let window = NSWindow(contentRect: CGRect(x: 50, y: 50, width: 900, height: 650),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let host = TranslationEditorView(model: model, openSettings: {}, openGlossaries: {}).makeHostingView()
            window.contentView = host
            defer { window.close() }
            window.makeKeyAndOrderFront(nil)
            try await Task.sleep(for: .milliseconds(80))
            host.layoutSubtreeIfNeeded()
            let initialFrame = window.frame
            let source = try #require(textViews(in: host).first)
            #expect(source.isEditable)
            #expect(source.delegate != nil)
            window.makeFirstResponder(source)
            source.insertText("Native source text", replacementRange: NSRange(location: NSNotFound, length: 0))
            #expect(source.string == "Native source text")
            #expect(model.sourceText == "Native source text")
            #expect(model.canTranslate)
            try await Task.sleep(for: .milliseconds(40))
            #expect(window.frame == initialFrame)
            #expect(NSApp.sendAction(NSSelectorFromString("undo:"), to: source, from: nil))
            try await Task.sleep(for: .milliseconds(30))
            #expect(model.sourceText.isEmpty)
            #expect(source.string.isEmpty)
            #expect(NSApp.sendAction(NSSelectorFromString("redo:"), to: source, from: nil))
            try await Task.sleep(for: .milliseconds(30))
            #expect(model.sourceText == "Native source text")
            #expect(source.string == "Native source text")
            #expect(window.frame == initialFrame)
            model.translateSource()
            await waitFor { await service.count == 1 }
            await service.emit("Generated native result", at: 0)
            await service.finish(at: 0)
            await waitFor { model.state == .completed }
            model.editTranslation("Edited native result")
            try await Task.sleep(for: .milliseconds(80))
            #expect(window.frame == initialFrame)
            model.retranslate()
            try await Task.sleep(for: .milliseconds(80))
            #expect(window.frame == initialFrame)
            model.keepEditing()
            model.cancel()
            await service.finishAll()
        }
    }

    @Test func editorPreservesMarkedTextAndScrollsAtMinimumSize() async throws {
        try await withTranslationContext { preferences, credentials in
            _ = NSApplication.shared
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            let window = NSWindow(contentRect: CGRect(x: 50, y: 50, width: 840, height: 600),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let host = TranslationEditorView(model: model, openSettings: {}, openGlossaries: {}).makeHostingView()
            window.contentView = host
            defer { window.close() }
            window.makeKeyAndOrderFront(nil)
            try await Task.sleep(for: .milliseconds(80))
            let source = try #require(textViews(in: host).first)
            window.makeFirstResponder(source)
            source.setMarkedText("にほん", selectedRange: NSRange(location: 3, length: 0),
                                 replacementRange: NSRange(location: NSNotFound, length: 0))
            try await Task.sleep(for: .milliseconds(80))
            #expect(source.hasMarkedText())
            #expect(source.string == "にほん")
            source.setMarkedText("日本", selectedRange: NSRange(location: 2, length: 0),
                                 replacementRange: NSRange(location: NSNotFound, length: 0))
            source.insertText("日本語", replacementRange: NSRange(location: NSNotFound, length: 0))
            try await Task.sleep(for: .milliseconds(80))
            #expect(!source.hasMarkedText())
            #expect(source.string == "日本語")
            #expect(model.sourceText == "日本語")
            let frame = window.frame
            let longText = String(repeating: "A long source line for scrolling. 長文スクロールの確認。\n", count: 200)
            model.editSource(longText)
            model.translateSource()
            await waitFor { await service.count == 1 }
            await service.emit(longText, at: 0)
            await service.finish(at: 0)
            await waitFor { model.state == .completed }
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                window.appearance = NSAppearance(named: appearance)
                try await Task.sleep(for: .milliseconds(80))
                host.layoutSubtreeIfNeeded()
                let editors = textViews(in: host)
                #expect(editors.count == 2)
                for editor in editors {
                    let scroll = try #require(editor.enclosingScrollView)
                    #expect(editor.string == longText)
                    #expect(editor.frame.height > scroll.contentView.bounds.height)
                    #expect(scroll.frame.height > 0)
                    #expect(scroll.frame.width >= 300)
                    editor.scrollRangeToVisible(NSRange(location: (longText as NSString).length, length: 0))
                    #expect(scroll.contentView.bounds.minY > 0)
                }
                #expect(window.frame == frame)
            }
            model.cancel()
            await service.finishAll()
        }
    }

    private func textViews(in view: NSView) -> [NSTextView] {
        if let text = view as? NSTextView { return [text] }
        return view.subviews.flatMap { textViews(in: $0) }
    }

    private func withCaptureController(_ body: (PopupController, CaptureEnvironmentStub) async throws -> Void) async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let suite = "KotoFloatCapturePopupTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let env = CaptureEnvironmentStub()
        let controller = PopupController(preferences: PopupPreferences(defaults: defaults), captureEnvironment: env)
        defer { controller.panel.close(); defaults.removePersistentDomain(forName: suite) }
        try await body(controller, env)
    }

    private func withController(_ body: (PopupController) throws -> Void) throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let suite = "KotoFloatPanelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let controller = PopupController(preferences: PopupPreferences(defaults: defaults))
        defer {
            controller.panel.close()
            defaults.removePersistentDomain(forName: suite)
        }
        try body(controller)
    }

    private func focus(_ window: NSWindow) throws {
        window.makeKeyAndOrderFront(nil)
        try #require(window.isKeyWindow)
    }

    private func findScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView { return scrollView }
        return view.subviews.lazy.compactMap { findScrollView(in: $0) }.first
    }
}
