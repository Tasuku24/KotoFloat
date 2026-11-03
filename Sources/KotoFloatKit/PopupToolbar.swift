import SwiftUI

struct PopupToolbar<Controls: View>: View {
    @ViewBuilder var controls: Controls
    @State private var leadingInset = PopupGeometry.toolbarLeadingInset(for: [])

    var body: some View {
        HStack(spacing: 8) {
            Text("KotoFloat")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1).truncationMode(.tail).layoutPriority(-1)
            Spacer(minLength: 4)
            controls
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.leading, leadingInset).padding(.trailing, 12)
        .frame(height: 48)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("popup.toolbar"))
        .background {
            WindowButtonClearanceReader { leadingInset = $0 }.frame(width: 0, height: 0)
        }
        .reportPopupHeight()
    }
}

private struct WindowButtonClearanceReader: NSViewRepresentable {
    let onChange: @MainActor (CGFloat) -> Void

    func makeNSView(context: Context) -> WindowButtonClearanceView {
        WindowButtonClearanceView(onChange: onChange)
    }

    func updateNSView(_ view: WindowButtonClearanceView, context: Context) {
        view.onChange = onChange
        view.scheduleUpdate()
    }
}

private final class WindowButtonClearanceView: NSView {
    var onChange: @MainActor (CGFloat) -> Void
    private var lastInset: CGFloat?
    private var updateScheduled = false

    init(onChange: @escaping @MainActor (CGFloat) -> Void) {
        self.onChange = onChange
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        if let window {
            // AppKit can reset native button positions after content layout without resizing.
            // AppKitは本文のリサイズを伴わない描画更新でも標準ボタンの位置を戻すことがある。
            for name in [NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification,
                         NSWindow.didExitFullScreenNotification, NSWindow.didUpdateNotification,
                         NSWindow.didBecomeKeyNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(windowLayoutChanged), name: name, object: window)
            }
        }
        scheduleUpdate()
    }

    override func layout() {
        super.layout()
        scheduleUpdate()
    }

    @objc private func windowLayoutChanged(_ notification: Notification) { scheduleUpdate() }

    func scheduleUpdate() {
        guard window != nil, !updateScheduled else { return }
        updateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            updateScheduled = false
            updateClearance()
        }
    }

    private func updateClearance() {
        guard let window, let contentView = window.contentView else { return }
        let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = types.compactMap { window.standardWindowButton($0) }.filter { !$0.isHidden }
        if window.styleMask.contains(.fullSizeContentView), !window.styleMask.contains(.fullScreen) {
            // Center native controls on the toolbar with a 16-point leading margin.
            // Move the group together to preserve native spacing and actions.
            // 標準ボタンを上部バーの中心線と左余白16ポイントに揃える。
            // 全体を同じ量だけ移動し、標準の間隔と操作を維持する。
            let centerY = convert(bounds, to: contentView).midY
            let leftEdge = buttons.map { $0.convert($0.bounds, to: contentView).minX }.min() ?? 16
            let offsetX = 16 - leftEdge
            for button in buttons {
                guard let parent = button.superview else { continue }
                let current = button.convert(button.bounds, to: contentView)
                let center = parent.convert(NSPoint(x: current.midX + offsetX, y: centerY), from: contentView)
                let origin = NSPoint(x: center.x - button.bounds.midX, y: center.y - button.bounds.midY)
                if abs(button.frame.minX - origin.x) > 0.5 || abs(button.frame.minY - origin.y) > 0.5 {
                    button.setFrameOrigin(origin)
                }
            }
        }
        let frames = buttons.map { $0.convert($0.bounds, to: contentView) }
        let inset = PopupGeometry.toolbarLeadingInset(for: frames)
        guard inset != lastInset else { return }
        lastInset = inset
        DispatchQueue.main.async { [weak self] in self?.onChange(inset) }
    }
}

struct TranslationPopupToolbar: View {
    let capture: CaptureModel
    let preferences: PopupPreferences
    let translation: TranslationModel?
    @Binding var showsSource: Bool
    @Binding var showsDetails: Bool
    let toggleTopmost: () -> Void
    let openSettings: () -> Void
    let openGlossaries: () -> Void
    let openEditor: () -> Void
    @State private var copied = false

    private var hasCapturedText: Bool {
        if case .captured = capture.state { return true }
        return false
    }

    var body: some View {
        PopupToolbar {
            if let translation {
                LanguagePicker(label: L10n.text("translation.to"), selection: translation.preferences.targetLanguage,
                    favoriteLanguages: translation.preferences.favoriteLanguages) { translation.preferences.targetLanguage = $0 }
                    .frame(minWidth: 70, idealWidth: 110, maxWidth: 160)
                    .frame(height: 26)
                if translation.state == .running {
                    Button { translation.cancel() } label: {
                        Image(systemName: "stop.circle").frame(width: 26, height: 28)
                    }
                    .help(L10n.text("translation.cancel"))
                    .accessibilityLabel(L10n.text("translation.cancel"))
                } else {
                    Button { copied = translation.copyResult(to: .general) } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc").frame(width: 26, height: 28)
                    }
                    .disabled(!translation.canCopy || !hasCapturedText)
                    .help(L10n.text(copied ? "translation.copied" : "translation.copy"))
                    .accessibilityLabel(L10n.text(copied ? "translation.copied" : "translation.copy"))
                }
                Button(action: openEditor) {
                    Image(systemName: "arrow.up.right.square").frame(width: 26, height: 28)
                }
                .help(L10n.text("menu.editor"))
                .accessibilityLabel(L10n.text("menu.editor"))
            }
            PopupMoreMenu(capture: capture, preferences: preferences, translation: translation,
                showsSource: $showsSource, showsDetails: $showsDetails,
                toggleTopmost: toggleTopmost, openSettings: openSettings, openGlossaries: openGlossaries)
        }
        .background {
            if let translation {
                FavoriteShortcutView(preferences: translation.preferences).frame(width: 0, height: 0)
            }
        }
        .onChange(of: translation?.state) { copied = false }
        .onChange(of: translation?.revision) { copied = false }
    }
}

private struct PopupMoreMenu: View {
    let capture: CaptureModel
    let preferences: PopupPreferences
    let translation: TranslationModel?
    @Binding var showsSource: Bool
    @Binding var showsDetails: Bool
    let toggleTopmost: () -> Void
    let openSettings: () -> Void
    let openGlossaries: () -> Void
    @State private var glossaryFailure: GlossaryFailure?

    var body: some View {
        Menu {
            if let translation {
                Button(L10n.text("translation.retranslate")) { translation.retranslate() }
                    .disabled(!translation.canTranslate || translation.state == .running)
                Toggle(L10n.text("popup.showSource"), isOn: $showsSource)
                    .disabled(translation.sourceText.isEmpty)
                Toggle(L10n.text("popup.showDetails"), isOn: $showsDetails)
                    .disabled(translation.input == nil)
                Menu(L10n.text("translation.from")) {
                    Picker(L10n.text("translation.from"), selection: Binding(
                        get: { translation.preferences.sourceLanguage },
                        set: { translation.preferences.sourceLanguage = $0 })) {
                        ForEach(TranslationLanguage.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
                if let store = translation.glossaries {
                    Menu(L10n.text("glossary.title")) {
                        Picker(L10n.text("glossary.active"), selection: Binding<UUID?>(
                            get: { store.library.activeGlossaryID },
                            set: { id in
                                do { try store.select(id) }
                                catch { glossaryFailure = error as? GlossaryFailure ?? .saveFailed }
                            })) {
                            Text(L10n.text("glossary.none")).tag(nil as UUID?)
                            ForEach(store.library.glossaries) { Text($0.name).tag(Optional($0.id)) }
                        }.disabled(store.failure != nil)
                        Divider()
                        Button(L10n.text("menu.glossaries"), action: openGlossaries)
                    }
                }
                Divider()
            }
            Button(L10n.text("capture.manual")) { capture.beginManualEntry() }
            Toggle(L10n.text("settings.topmost"), isOn: Binding(
                get: { preferences.alwaysOnTop },
                set: { if $0 != preferences.alwaysOnTop { toggleTopmost() } }))
            Button(L10n.text("menu.settings"), action: openSettings)
        } label: {
            Image(systemName: "ellipsis").frame(width: 26, height: 28)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help(L10n.text("popup.more"))
        .accessibilityLabel(L10n.text("popup.more"))
        .alert(L10n.text("glossary.title"), isPresented: Binding(
            get: { glossaryFailure != nil }, set: { if !$0 { glossaryFailure = nil } })) {
            Button(L10n.text("glossary.cancel"), role: .cancel) { glossaryFailure = nil }
        } message: {
            if let glossaryFailure { Text(L10n.text("glossary.error.\(glossaryFailure.rawValue)")) }
        }
    }
}
