import AppKit
import Testing
@testable import KotoFloatKit

@Suite(.serialized) @MainActor
struct PopupControllerTests {
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
            controller.panel.makeKey()
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
            controller.panel.makeKey()
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
            controller.panel.makeKey()
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

    private func findScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView { return scrollView }
        return view.subviews.lazy.compactMap { findScrollView(in: $0) }.first
    }
}
