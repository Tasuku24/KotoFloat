import AppKit
import SwiftUI
import Testing
@testable import KotoFloatKit

extension PopupControllerTests {
    @Test(arguments: ["translator", "popup", "autoRaise"])
    func nativeWindowButtonsStayAlignedAfterAppKitUpdates(_ kind: String) async throws {
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
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        let host = NSHostingView(rootView: VStack(spacing: 0) {
            PopupToolbar {
                LanguagePicker(label: "Target", selection: .japanese) { _ in }.frame(width: 120, height: 26)
            }
            Color.white
        }.ignoresSafeArea(.container, edges: .top))
        host.sizingOptions = []
        window.contentView = host
        defer { window.close() }
        let offscreenX = (NSScreen.screens.map(\.frame.minX).min() ?? 0) - 2000
        for shown in [false, true] {
            window.setFrameOrigin(NSPoint(x: offscreenX, y: -10000))
            if shown { window.orderBack(nil) }
            for size in [CGSize(width: 840, height: 400), CGSize(width: 900, height: 600)] {
                window.setContentSize(size)
                window.setFrameOrigin(NSPoint(x: offscreenX, y: -10000))
                host.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(100))
                host.layoutSubtreeIfNeeded()
                let picker = try #require(toolbarDescendants(host).compactMap { $0 as? NSButton }.first {
                    $0.toolTip == "Target: \(TranslationLanguage.japanese.title)"
                })
                let targetY = picker.convert(picker.bounds, to: host).midY
                let chrome = try #require(host.superview)
                let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
                for nativeUpdate in [false, true] {
                    if nativeUpdate {
                        // Replay the 8-point reset measured after a real AppKit window update.
                        // 実アプリのAppKit更新後に測定した、8ポイントの位置の巻き戻りを再現する。
                        for type in types {
                            let button = try #require(window.standardWindowButton(type))
                            let parent = try #require(button.superview)
                            let frame = button.convert(button.bounds, to: host)
                            let center = parent.convert(NSPoint(x: frame.midX, y: targetY - 8), from: host)
                            button.setFrameOrigin(NSPoint(x: button.frame.minX, y: center.y - button.bounds.midY))
                        }
                        window.update()
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    for type in types {
                        let button = try #require(window.standardWindowButton(type))
                        let frame = button.convert(button.bounds, to: host)
                        #expect(abs(frame.midY - targetY) <= 0.5)
                        let center = NSPoint(x: button.bounds.midX, y: button.bounds.midY)
                        let hit = chrome.hitTest(button.convert(center, to: chrome.superview))
                        #expect(hit === button || hit?.isDescendant(of: button) == true)
                    }
                    let pickerCenter = NSPoint(x: picker.bounds.midX, y: picker.bounds.midY)
                    let pickerHit = chrome.hitTest(picker.convert(pickerCenter, to: chrome.superview))
                    #expect(pickerHit === picker || pickerHit?.isDescendant(of: picker) == true)
                }
                #expect(window.isVisible == shown)
                #expect(!window.isKeyWindow)
            }
        }
    }

    private func toolbarDescendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(toolbarDescendants)
    }
}
