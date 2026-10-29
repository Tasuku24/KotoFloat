import AppKit

final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: CGRect(origin: .zero, size: PopupGeometry.defaultSize),
                   styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        title = "KotoFloat"
        identifier = NSUserInterfaceItemIdentifier("translationPopup")
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        minSize = PopupGeometry.minimumSize
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .none
    }

    override func cancelOperation(_ sender: Any?) {
        guard isKeyWindow else { return }
        performClose(sender)
    }

    override func sendEvent(_ event: NSEvent) {
        // Handle Escape only inside this key panel, never in a global event monitor.
        // Escはキー状態のこのパネル内でのみ扱い、グローバル監視はしない。
        if event.type == .keyDown, event.keyCode == 53, isKeyWindow,
           event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            cancelOperation(nil)
            return
        }
        super.sendEvent(event)
    }
}
