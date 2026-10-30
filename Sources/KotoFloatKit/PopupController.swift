import AppKit
import SwiftUI

@MainActor
final class PopupController: NSObject, NSWindowDelegate {
    private(set) var panel: NSWindow
    let preferences: PopupPreferences
    let sample = SampleContent()
    let capture = CaptureModel()
    let translation: TranslationModel?
    private let captureEnvironment: any CaptureEnvironment
    var openSettings: (() -> Void)?
    var openGlossaries: (() -> Void)?

    init(preferences: PopupPreferences, captureEnvironment: any CaptureEnvironment = SystemCaptureEnvironment(), translation: TranslationModel? = nil) {
        self.preferences = preferences
        self.captureEnvironment = captureEnvironment
        self.translation = translation
        panel = PopupWindowFactory.make(mode: preferences.focusMode)
        super.init()
        translation?.bind(to: capture)
        configurePanel()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private func configurePanel() {
        panel.delegate = self
        let hostingView = NSHostingView(rootView: PopupRootView(preferences: preferences, sample: sample, capture: capture, translation: translation,
            toggleTopmost: { [weak self] in
                guard let self else { return }
                setAlwaysOnTop(!preferences.alwaysOnTop)
            }, openSettings: { [weak self] in self?.openSettings?() }, openGlossaries: { [weak self] in self?.openGlossaries?() }))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        applyWindowLevel()
    }

    func showSample() {
        capture.cancel()
        translation?.cancel(clear: true)
        capture.showsSample = true
        showPopup()
    }

    private func showPopup(selectionBounds: CGRect? = nil) {
        let screens = NSScreen.screens.map(\.visibleFrame)
        let pointer = NSEvent.mouseLocation
        let frame: CGRect
        switch preferences.placement {
        case .previousPosition:
            frame = PopupGeometry.restore(preferences.savedFrame, screens: screens, pointer: pointer)
        case .nearPointer:
            frame = PopupGeometry.nearPointer(size: preferences.savedFrame?.size ?? PopupGeometry.defaultSize,
                                             screens: screens, pointer: pointer)
        case .nearSelection:
            frame = PopupGeometry.nearSelection(selectionBounds,
                size: preferences.savedFrame?.size ?? PopupGeometry.defaultSize, screens: screens, pointer: pointer)
        }
        panel.setFrame(frame, display: panel.isVisible)
        applyWindowLevel()
        // Keep the source application's keyboard focus until the user clicks the panel.
        // 利用者がパネルをクリックするまで、元アプリのキーボードフォーカスを維持する。
        panel.orderFrontRegardless()
        preferences.savedFrame = panel.frame
    }

    func captureSelectedText() {
        guard capture.state != .capturing else { return }
        capture.start(using: SelectionCapture(environment: captureEnvironment)) { [weak self] in
            guard let self else { return }
            let bounds: CGRect?
            if case .captured(let text) = capture.state { bounds = text.bounds } else { bounds = nil }
            showPopup(selectionBounds: bounds)
        }
    }

    func showManualEntry() {
        capture.beginManualEntry()
        showPopup()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
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
        showPopup()
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
    func windowWillClose(_ notification: Notification) {
        preferences.savedFrame = panel.frame
        capture.cancel()
        translation?.cancel()
    }

    @objc private func screensChanged(_ notification: Notification) { recoverVisibleFrame() }

    private func saveFrameIfVisible() {
        if panel.isVisible { preferences.savedFrame = panel.frame }
    }

    private func applyWindowLevel() {
        panel.level = preferences.alwaysOnTop ? .floating : .normal
    }
}
