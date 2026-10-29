import AppKit

final class PopupWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        guard isKeyWindow else { return }
        performClose(sender)
    }

    override func sendEvent(_ event: NSEvent) {
        if PopupWindowFactory.isDismissal(event, in: self) {
            cancelOperation(nil)
            return
        }
        super.sendEvent(event)
    }
}

final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        guard isKeyWindow else { return }
        performClose(sender)
    }

    override func sendEvent(_ event: NSEvent) {
        if PopupWindowFactory.isDismissal(event, in: self) {
            cancelOperation(nil)
            return
        }
        super.sendEvent(event)
    }
}

@MainActor
enum PopupWindowFactory {
    static func make(mode: PopupFocusMode) -> NSWindow {
        let frame = CGRect(origin: .zero, size: PopupGeometry.defaultSize)
        let style: NSWindow.StyleMask = [.titled, .closable, .resizable]
        let window: NSWindow
        switch mode {
        case .standard:
            let panel = PopupPanel(contentRect: frame, styleMask: style.union(.nonactivatingPanel),
                                   backing: .buffered, defer: false)
            panel.becomesKeyOnlyIfNeeded = false
            window = panel
        case .autoRaiseCompatible:
            // AutoRaise's focus-first mode requires a main, standard window after interaction.
            // AutoRaiseのフォーカス優先モードは、操作中の画面が通常のメインウィンドウであることを要求する。
            window = PopupWindow(contentRect: frame, styleMask: style, backing: .buffered, defer: false)
        }
        window.title = "KotoFloat"
        window.identifier = NSUserInterfaceItemIdentifier("translationPopup")
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.minSize = PopupGeometry.minimumSize
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.animationBehavior = .none
        return window
    }

    static func isDismissal(_ event: NSEvent, in window: NSWindow) -> Bool {
        // Handle Escape only inside the key popup, never in a global event monitor.
        // Escはキー状態のポップアップ内でのみ扱い、グローバル監視はしない。
        event.type == .keyDown && event.keyCode == 53 && window.isKeyWindow &&
            event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
    }
}
