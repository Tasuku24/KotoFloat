import AppKit
import SwiftUI
import KeyboardShortcuts

@MainActor
public final class KotoFloatDelegate: NSObject, NSApplicationDelegate {
    private var popupController: PopupController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = PopupController(preferences: PopupPreferences())
        controller.openSettings = { [weak self] in self?.showSettings() }
        popupController = controller
        configureMenuBar()
        configureAppMenu()
        KeyboardShortcuts.onKeyUp(for: .showSamplePopup) { [weak controller] in
            controller?.captureSelectedText()
        }
        if !UserDefaults.standard.bool(forKey: "hasShownWelcome") {
            UserDefaults.standard.set(true, forKey: "hasShownWelcome")
            showSettings()
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    @objc private func showManualEntry() { popupController?.showManualEntry() }

    @objc private func showSample() { popupController?.showSample() }

    @objc private func showSettings() {
        guard let popupController else { return }
        if settingsWindow == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 540, height: 720),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = L10n.text("settings.title")
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(controller: popupController))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func configureMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "KotoFloat")
        item.button?.toolTip = "KotoFloat"
        let menu = NSMenu()
        menu.addItem(actionItem("capture.manual", action: #selector(showManualEntry)))
        menu.addItem(actionItem("menu.showSample", action: #selector(showSample)))
        menu.addItem(actionItem("menu.settings", action: #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.text("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func configureAppMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "KotoFloat")
        appMenu.addItem(actionItem("menu.settings", action: #selector(showSettings), key: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: L10n.text("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: L10n.text("menu.edit"))
        editMenu.addItem(NSMenuItem(title: L10n.text("menu.undo"), action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: L10n.text("menu.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: L10n.text("menu.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: L10n.text("menu.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: L10n.text("menu.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    private func actionItem(_ key: String, action: Selector, key equivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: L10n.text(key), action: action, keyEquivalent: equivalent)
        item.target = self
        return item
    }
}
