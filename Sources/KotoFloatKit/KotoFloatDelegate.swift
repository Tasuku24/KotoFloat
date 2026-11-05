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
    private var editorContentView: NSHostingView<TranslationEditorView>?

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let translationPreferences = TranslationPreferences()
        let credentials = KeychainCredentialStore()
        let glossaries = GlossaryStore()
        glossaryStore = glossaries
        let translation = TranslationModel(preferences: translationPreferences, credentials: credentials, glossaries: glossaries,
            history: TranslationHistoryStore())
        connectionModel = ConnectionModel(preferences: translationPreferences, credentials: credentials)
        let controller = PopupController(preferences: PopupPreferences(), translation: translation)
        controller.openSettings = { [weak self] in self?.showSettings() }
        controller.openGlossaries = { [weak self] in self?.showGlossaries() }
        controller.openEditor = { [weak self] in self?.showEditor() }
        controller.isEditorVisible = { [weak self] in self?.editorWindow?.isVisible == true }
        popupController = controller
        configureMenuBar()
        NSApp.mainMenu = makeAppMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged),
            name: AppLocalization.didChange, object: AppLocalization.shared)
        KeyboardShortcuts.onKeyUp(for: .showSamplePopup) { [weak controller] in
            controller?.captureSelectedText()
        }
        showEditor()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showEditor()
        return false
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if popupController?.translation?.hasUnsentWork == true || popupController?.capture.hasUnsentWork == true {
            let alert = NSAlert()
            alert.messageText = L10n.text("editor.quitTitle")
            alert.informativeText = L10n.text("editor.quitMessage")
            alert.addButton(withTitle: L10n.text("editor.keepEditing"))
            alert.addButton(withTitle: L10n.text("menu.quit"))
            guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        }
        popupController?.translation?.cancel()
        guard let history = popupController?.translation?.history else { return .terminateNow }
        Task {
            await history.flush()
            var shouldQuit = true
            if history.hasUnsavedEntries {
                let alert = NSAlert()
                alert.messageText = L10n.text("history.quitTitle")
                alert.informativeText = L10n.text("history.quitMessage")
                alert.addButton(withTitle: L10n.text("history.retry"))
                alert.addButton(withTitle: L10n.text("editor.keepEditing"))
                alert.addButton(withTitle: L10n.text("history.quitWithoutSaving"))
                switch alert.runModal() {
                case .alertFirstButtonReturn:
                    await history.retry()
                    shouldQuit = !history.hasUnsavedEntries
                case .alertThirdButtonReturn: break
                default: shouldQuit = false
                }
            }
            sender.reply(toApplicationShouldTerminate: shouldQuit)
        }
        return .terminateLater
    }

    @objc func moveToBackground() {
        // Hide application UI while retaining drafts and active translations.
        // A pending capture must not reopen the popup after the user hides it.
        // アプリの画面を非表示にし、下書きと実行中の翻訳を保持する。
        // 取得処理が後からポップアップを再表示しないよう、進行中の取得だけを取り消す。
        popupController?.capture.cancel()
        releaseEditorWindow()
        for window in NSApp.windows where window !== statusItem?.button?.window {
            window.orderOut(nil)
        }
    }

    @objc private func showEditor() {
        guard let model = popupController?.translation else { return }
        let window = prepareEditorWindow(model: model)
        if window.frameAutosaveName.isEmpty {
            window.setFrameAutosaveName("TranslationEditor")
            if !window.setFrameUsingName("TranslationEditor") { window.center() }
        }
        // Order the new native window on the current Space before requesting app activation.
        // 新しい標準ウィンドウを現在のスペースに表示してから、アプリのアクティブ化を要求する。
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func prepareEditorWindow(model: TranslationModel) -> NSWindow {
        if let editorWindow, editorWindow.isVisible, !editorWindow.isMiniaturized { return editorWindow }
        releaseEditorWindow()
        if editorContentView == nil {
            editorContentView = TranslationEditorView(model: model,
                openSettings: { [weak self] in self?.showSettings() },
                openGlossaries: { [weak self] in self?.showGlossaries() }).makeHostingView()
        }
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1040, height: 620),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = L10n.text("editor.title")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentMinSize = CGSize(width: 840, height: 400)
        window.delegate = self
        window.contentView = editorContentView
        editorWindow = window
        return window
    }

    private func releaseEditorWindow() {
        // Retain the hosted editor and shared model while discarding the old native Space association.
        // Do not trigger the user-close cancellation path when moving to the background.
        // 編集ビューと共有モデルを保持し、古い標準ウィンドウのスペースへの所属だけを破棄する。
        // バックグラウンドへの移行時には、利用者が閉じた場合の翻訳取消処理を呼ばない。
        editorWindow?.delegate = nil
        editorWindow?.close()
        editorWindow = nil
    }

    public func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        window === editorWindow ? popupController?.translation?.undoManager : nil
    }

    public func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === editorWindow {
            if popupController?.panel.isVisible != true { popupController?.translation?.cancel() }
            editorWindow = nil
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
        image?.size = NSSize(width: 16, height: 16)
        image?.isTemplate = true
        image?.accessibilityDescription = "KotoFloat"
        item.button?.image = image ?? NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "KotoFloat")
        item.button?.toolTip = "KotoFloat"
        item.menu = makeStatusMenu()
        statusItem = item
    }

    func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(actionItem("menu.editor", action: #selector(showEditor)))
        menu.addItem(actionItem("capture.manual", action: #selector(showManualEntry)))
        menu.addItem(actionItem("menu.glossaries", action: #selector(showGlossaries)))
        menu.addItem(actionItem("menu.showSample", action: #selector(showSample)))
        menu.addItem(actionItem("menu.settings", action: #selector(showSettings), key: ","))
        menu.addItem(.separator())
        addLifecycleActions(to: menu)
        return menu
    }

    func makeAppMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "KotoFloat")
        appMenu.addItem(actionItem("menu.editor", action: #selector(showEditor)))
        appMenu.addItem(actionItem("menu.glossaries", action: #selector(showGlossaries)))
        appMenu.addItem(actionItem("menu.settings", action: #selector(showSettings), key: ","))
        appMenu.addItem(.separator())
        addLifecycleActions(to: appMenu)
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: L10n.text("menu.file"))
        fileMenu.addItem(NSMenuItem(title: L10n.text("menu.close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

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
        editMenu.addItem(.separator())
        let reviewItem = NSMenuItem(title: L10n.text("review.action"), action: #selector(DocumentTextView.reviewSelection(_:)), keyEquivalent: "\r")
        reviewItem.keyEquivalentModifierMask = [.command, .option]
        editMenu.addItem(reviewItem)
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        return mainMenu
    }

    @objc private func languageChanged() {
        settingsWindow?.title = L10n.text("settings.title")
        glossaryWindow?.title = L10n.text("glossary.title")
        editorWindow?.title = L10n.text("editor.title")
        configureMenuBar()
        NSApp.mainMenu = makeAppMenu()
    }

    private func actionItem(_ key: String, action: Selector, key equivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: L10n.text(key), action: action, keyEquivalent: equivalent)
        item.target = self
        return item
    }

    private func addLifecycleActions(to menu: NSMenu) {
        menu.addItem(actionItem("menu.background", action: #selector(moveToBackground), key: "q"))
        let quit = NSMenuItem(title: L10n.text("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(quit)
    }
}
