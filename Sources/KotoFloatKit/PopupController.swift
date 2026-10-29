import AppKit
import SwiftUI

@MainActor
final class PopupController: NSObject, NSWindowDelegate {
    let panel = PopupPanel()
    let preferences: PopupPreferences
    let sample = SampleContent()
    var openSettings: (() -> Void)?

    init(preferences: PopupPreferences) {
        self.preferences = preferences
        super.init()
        panel.delegate = self
        let hostingView = NSHostingView(rootView: PopupContentView(preferences: preferences, sample: sample,
            toggleTopmost: { [weak self] in
                guard let self else { return }
                setAlwaysOnTop(!preferences.alwaysOnTop)
            }, openSettings: { [weak self] in self?.openSettings?() }))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        applyWindowLevel()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func showSample() {
        let screens = NSScreen.screens.map(\.visibleFrame)
        let pointer = NSEvent.mouseLocation
        let frame: CGRect
        switch preferences.placement {
        case .previousPosition:
            frame = PopupGeometry.restore(preferences.savedFrame, screens: screens, pointer: pointer)
        case .nearPointer:
            frame = PopupGeometry.nearPointer(size: preferences.savedFrame?.size ?? PopupGeometry.defaultSize,
                                             screens: screens, pointer: pointer)
        }
        panel.setFrame(frame, display: panel.isVisible)
        applyWindowLevel()
        // Keep the source application's keyboard focus until the user clicks the panel.
        // 利用者がパネルをクリックするまで、元アプリのキーボードフォーカスを維持する。
        panel.orderFrontRegardless()
        preferences.savedFrame = panel.frame
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        preferences.alwaysOnTop = enabled
        applyWindowLevel()
    }

    func resetPosition() {
        preferences.savedFrame = nil
        showSample()
    }

    func recoverVisibleFrame() {
        guard panel.isVisible else { return }
        let frame = PopupGeometry.restore(panel.frame, screens: NSScreen.screens.map(\.visibleFrame),
                                          pointer: NSEvent.mouseLocation)
        if frame != panel.frame { panel.setFrame(frame, display: true) }
        preferences.savedFrame = panel.frame
    }

    func windowDidMove(_ notification: Notification) { saveFrameIfVisible() }
    func windowDidResize(_ notification: Notification) { saveFrameIfVisible() }
    func windowWillClose(_ notification: Notification) { preferences.savedFrame = panel.frame }

    @objc private func screensChanged(_ notification: Notification) { recoverVisibleFrame() }

    private func saveFrameIfVisible() {
        if panel.isVisible { preferences.savedFrame = panel.frame }
    }

    private func applyWindowLevel() {
        panel.level = preferences.alwaysOnTop ? .floating : .normal
    }
}
