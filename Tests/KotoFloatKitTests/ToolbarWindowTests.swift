import AppKit
import SwiftUI
import Testing
@testable import KotoFloatKit

extension PopupControllerTests {
    @Test(arguments: ["translator", "popup", "autoRaise"])
    func nativeWindowButtonsAlignWithToolbarAndRemainHittable(_ kind: String) async throws {
        _ = NSApplication.shared
        let window: NSWindow
        if kind == "translator" {
            window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 840, height: 400),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
        } else {
            window = PopupWindowFactory.make(mode: kind == "popup" ? .standard : .autoRaiseCompatible)
        }
        let host = NSHostingView(rootView: VStack(spacing: 0) {
            PopupToolbar {
                LanguagePicker(label: "Target", selection: .japanese) { _ in }.frame(width: 120, height: 26)
            }
            Color.white
        }.ignoresSafeArea(.container, edges: .top))
        host.sizingOptions = []
        window.contentView = host
        defer { window.close() }
        for size in [CGSize(width: 840, height: 400), CGSize(width: 900, height: 600)] {
            window.setContentSize(size)
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            let picker = try #require(toolbarDescendants(host).compactMap { $0 as? NSButton }.first { $0.toolTip == "Target: \(TranslationLanguage.japanese.title)" })
            let targetY = picker.convert(picker.bounds, to: host).midY
            let chrome = try #require(host.superview)
            for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                let button = try #require(window.standardWindowButton(type))
                let frame = button.convert(button.bounds, to: host)
                #expect(abs(frame.midY - targetY) <= 0.5)
                let center = NSPoint(x: button.bounds.midX, y: button.bounds.midY)
                let hit = chrome.hitTest(button.convert(center, to: chrome.superview))
                #expect(hit === button || hit?.isDescendant(of: button) == true)
            }
            #expect(!window.isVisible)
        }
    }

    private func toolbarDescendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(toolbarDescendants)
    }
}
