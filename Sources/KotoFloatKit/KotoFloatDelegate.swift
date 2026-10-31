import AppKit
import SwiftUI
import KeyboardShortcuts

@MainActor
public final class KotoFloatDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var popupController: PopupController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var connectionModel: ConnectionModel?
    private var glossaryStore: GlossaryStore?
    private var glossaryWindow: NSWindow?
    private var editorWindow: NSWindow?

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let translationPreferences = TranslationPreferences()
        let credentials = KeychainCredentialStore()
        let glossaries = GlossaryStore()
        glossaryStore = glossaries
        let translation = TranslationModel(preferences: translationPreferences, credentials: credentials, glossaries: glossaries)
        connectionModel = ConnectionModel(preferences: translationPreferences, credentials: credentials)
        let controller = PopupController(preferences: PopupPreferences(), translation: translation)
        controller.openSettings = { [weak self] in self?.showSettings() }
        controller.openGlossaries = { [weak self] in self?.showGlossaries() }
        controller.openEditor = { [weak self] in self?.showEditor() }
        controller.isEditorVisible = { [weak self] in self?.editorWindow?.isVisible == true }
        popupController = controller
        configureMenuBar()
        configureAppMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged),
            name: AppLocalization.didChange, object: AppLocalization.shared)
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
        showEditor()
        return false
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard popupController?.translation?.hasUnsentWork == true || popupController?.capture.hasUnsentWork == true else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = L10n.text("editor.quitTitle")
        alert.informativeText = L10n.text("editor.quitMessage")
        alert.addButton(withTitle: L10n.text("editor.keepEditing"))
        alert.addButton(withTitle: L10n.text("menu.quit"))
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }

    @objc private func showEditor() {
        guard let model = popupController?.translation else { return }
        if editorWindow == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1040, height: 720),
                                  styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = L10n.text("editor.title")
            window.isReleasedWhenClosed = false
            window.contentMinSize = CGSize(width: 840, height: 600)
            window.delegate = self
            window.contentView = TranslationEditorView(model: model,
                openSettings: { [weak self] in self?.showSettings() },
                openGlossaries: { [weak self] in self?.showGlossaries() }).makeHostingView()
            window.setFrameAutosaveName("TranslationEditor")
            if !window.setFrameUsingName("TranslationEditor") { window.center() }
            editorWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        editorWindow?.makeKeyAndOrderFront(nil)
    }

    public func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        window === editorWindow ? popupController?.translation?.undoManager : nil
    }

    public func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === editorWindow, popupController?.panel.isVisible != true {
            popupController?.translation?.cancel()
        }
    }

    @objc private func showManualEntry() { popupController?.showManualEntry() }

    @objc private func showSample() { popupController?.showSample() }

    @objc private func showGlossaries() {
        guard let glossaryStore else { return }
        if glossaryWindow == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 960, height: 640),
                                  styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = L10n.text("glossary.title")
            window.isReleasedWhenClosed = false
            window.contentMinSize = CGSize(width: 800, height: 560)
            window.contentView = NSHostingView(rootView: GlossaryView(store: glossaryStore))
            window.center()
            glossaryWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        glossaryWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func showSettings() {
        guard let popupController, let connectionModel else { return }
        if settingsWindow == nil {
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: SettingsView.contentSize),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = L10n.text("settings.title")
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(controller: popupController, connection: connectionModel))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func configureMenuBar() {
        let item = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "pdf")
            .flatMap { NSImage(contentsOf: $0) }
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = true
        image?.accessibilityDescription = "KotoFloat"
        item.button?.image = image ?? NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "KotoFloat")
        item.button?.toolTip = "KotoFloat"
        let menu = NSMenu()
        menu.addItem(actionItem("menu.editor", action: #selector(showEditor)))
        menu.addItem(actionItem("capture.manual", action: #selector(showManualEntry)))
        menu.addItem(actionItem("menu.glossaries", action: #selector(showGlossaries)))
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
        appMenu.addItem(actionItem("menu.editor", action: #selector(showEditor)))
        appMenu.addItem(actionItem("menu.glossaries", action: #selector(showGlossaries)))
        appMenu.addItem(actionItem("menu.settings", action: #selector(showSettings), key: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: L10n.text("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: L10n.text("menu.edit"))
        editMenu.addItem(NSMenuItem(title: L10n.text("menu.undo"), action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: L10n.text("menu.redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(NSMenuItem(title: L10n.text("menu.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: L10n.text("menu.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: L10n.text("menu.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: L10n.text("menu.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func languageChanged() {
        settingsWindow?.title = L10n.text("settings.title")
        glossaryWindow?.title = L10n.text("glossary.title")
        editorWindow?.title = L10n.text("editor.title")
        configureMenuBar()
        configureAppMenu()
    }

    private func actionItem(_ key: String, action: Selector, key equivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: L10n.text(key), action: action, keyEquivalent: equivalent)
        item.target = self
        return item
    }
}
