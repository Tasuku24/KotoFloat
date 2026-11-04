import AppKit
import Testing
@testable import KotoFloatKit

extension PopupControllerTests {
    @Test(arguments: [PopupFocusMode.standard, .autoRaiseCompatible])
    func manualHeightSurvivesReleaseStreamingAndScreenRecovery(_ mode: PopupFocusMode) async throws {
        try await withTranslationContext { preferences, credentials in
            _ = NSApplication.shared
            let name = "KotoFloatManualHeightTests.\(UUID())"
            let defaults = try #require(UserDefaults(suiteName: name))
            let popupPreferences = PopupPreferences(defaults: defaults)
            popupPreferences.focusMode = mode
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            let controller = PopupController(preferences: popupPreferences,
                captureEnvironment: CaptureEnvironmentStub(), translation: model)
            // Ordered test windows stay transparent, ignore input, and never become key.
            // 表示状態の検証ウィンドウは透明にし、入力を受けず、キー状態にしない。
            controller.panel.alphaValue = 0
            controller.panel.ignoresMouseEvents = true
            defer {
                controller.panel.close()
                model.cancel()
                defaults.removePersistentDomain(forName: name)
            }
            controller.captureSelectedText()
            await waitFor { await service.count == 1 && controller.panel.isVisible }
            let screen = try #require(controller.panel.screen?.visibleFrame)
            let cap = PopupGeometry.maximumHeight(on: screen)
            let longText = String(repeating: "A long translated paragraph. 長い訳文です。\n\n", count: 100)
            await service.emit(longText, at: 0)
            await waitFor { abs(controller.panel.frame.height - cap) < 1 }
            let start = controller.panel.frame
            let height = min(240, cap - 40)
            let smaller = CGRect(x: start.minX, y: start.maxY - height, width: start.width, height: height)
            controller.windowWillStartLiveResize(Notification(name: NSWindow.willStartLiveResizeNotification, object: controller.panel))
            controller.panel.setFrame(smaller, display: false)
            controller.panel.contentView?.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            #expect(abs(controller.panel.frame.height - height) < 1)
            controller.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification, object: controller.panel))
            try await Task.sleep(for: .milliseconds(100))
            #expect(abs(controller.panel.frame.height - height) < 1)
            await service.emit(longText, at: 0)
            await service.finish(at: 0)
            await waitFor { model.state == .completed }
            controller.panel.contentView?.layoutSubtreeIfNeeded()
            controller.recoverVisibleFrame()
            try await Task.sleep(for: .milliseconds(100))
            #expect(abs(controller.panel.frame.height - height) < 1)
            #expect(controller.preferences.savedFrame == controller.panel.frame)
            let host = try #require(controller.panel.contentView)
            let scroll = try #require(manualResizeScrollView(in: host))
            #expect(try #require(scroll.documentView).frame.height > scroll.contentView.bounds.height)
            #expect(!controller.panel.isKeyWindow)

            controller.captureSelectedText()
            await waitFor { await service.count == 2 && controller.panel.frame.height < cap }
            let reopened = controller.panel.frame
            controller.windowWillStartLiveResize(Notification(name: NSWindow.willStartLiveResizeNotification, object: controller.panel))
            controller.panel.setFrame(CGRect(x: reopened.minX, y: reopened.minY,
                width: reopened.width + 40, height: reopened.height), display: false)
            controller.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification, object: controller.panel))
            await service.emit(longText, at: 1)
            await service.finish(at: 1)
            await waitFor { model.state == .completed && abs(controller.panel.frame.height - cap) < 1 }
            #expect(controller.panel.frame.width == reopened.width + 40)
        }
    }

    private func manualResizeScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { manualResizeScrollView(in: $0) }.first
    }
}
