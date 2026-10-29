import AppKit
import SwiftUI

@MainActor
final class PopupController: NSObject, NSWindowDelegate {
    private(set) var panel: NSWindow
    let preferences: PopupPreferences
    let sample = SampleContent()
    var openSettings: (() -> Void)?

    init(preferences: PopupPreferences) {
        self.preferences = preferences
        panel = PopupWindowFactory.make(mode: preferences.focusMode)
        super.init()
        configurePanel()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private func configurePanel() {
        panel.delegate = self
        let hostingView = NSHostingView(rootView: PopupContentView(preferences: preferences, sample: sample,
            toggleTopmost: { [weak self] in
                guard let self else { return }
                setAlwaysOnTop(!preferences.alwaysOnTop)
            }, openSettings: { [weak self] in self?.openSettings?() }))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        applyWindowLevel()
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

    func setFocusMode(_ mode: PopupFocusMode) {
        guard mode != preferences.focusMode else { return }
        let wasVisible = panel.isVisible
        let frame = wasVisible ? panel.frame : preferences.savedFrame ?? panel.frame
        preferences.focusMode = mode
        // Recreate the native window; changing nonactivatingPanel on a live panel is unreliable.
        // nonactivatingPanelを実行中に変更すると不整合が生じるため、ウィンドウを作り直す。
        panel.delegate = nil
        panel.close()
        panel = PopupWindowFactory.make(mode: mode)
        configurePanel()
        panel.setFrame(frame, display: false)
        if wasVisible {
            panel.orderFrontRegardless()
            preferences.savedFrame = panel.frame
        }
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
