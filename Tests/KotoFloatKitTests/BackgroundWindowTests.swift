import AppKit
import Testing
@testable import KotoFloatKit

extension PopupControllerTests {
    @Test func backgroundActionHidesWindowsWithoutClosingAndAllowsReopening() throws {
        _ = NSApplication.shared
        let delegate = KotoFloatDelegate()
        let tracker = BackgroundCloseTracker()
        let windows = (0..<2).map { _ in
            let window = NSPanel(contentRect: CGRect(x: -10000, y: -10000, width: 400, height: 300),
                styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.alphaValue = 0
            window.ignoresMouseEvents = true
            window.delegate = tracker
            let draft = NSTextView()
            draft.string = "Unsent draft"
            window.contentView = draft
            window.orderBack(nil)
            return window
        }
        defer { for window in windows { window.close() } }
        #expect(windows.allSatisfy { $0.isVisible })
        delegate.moveToBackground()
        #expect(windows.allSatisfy { !$0.isVisible && !$0.isKeyWindow })
        #expect(tracker.closeCount == 0)
        for window in windows {
            #expect(try #require(window.contentView as? NSTextView).string == "Unsent draft")
            window.orderBack(nil)
            #expect(window.isVisible)
            #expect(!window.isKeyWindow)
        }
    }
}

@MainActor private final class BackgroundCloseTracker: NSObject, NSWindowDelegate {
    var closeCount = 0
    func windowWillClose(_ notification: Notification) { closeCount += 1 }
}
