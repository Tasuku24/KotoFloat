import SwiftUI

struct TranslationEditorView: View {
    let model: TranslationModel
    let openSettings: () -> Void
    let openGlossaries: () -> Void
    @State private var showsSource = true
    @State private var showsDetails = false
    @State private var copied = false
    @State private var glossaryFailure: GlossaryFailure?
    @State private var showsHistory = false

    func makeHostingView() -> NSHostingView<TranslationEditorView> {
        let host = NSHostingView(rootView: self)
        // Keep the user's frame when result details or confirmation controls appear.
        // 結果の詳細や確認操作が現れても、利用者が決めたウィンドウ枠を維持する。
        host.sizingOptions = []
        return host
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if model.pendingAction != nil {
                TranslationConfirmationView(model: model).padding(12)
                Divider()
            }
            HSplitView {
                if showsSource { sourcePane }
                resultPane
            }.frame(minHeight: 180)
            Divider()
            footer
        }
        .background(Color(nsColor: .textBackgroundColor))
        .ignoresSafeArea(.container, edges: .top)
        .environment(\.locale, AppLocalization.shared.locale)
        .background(FavoriteShortcutView(preferences: model.preferences).frame(width: 0, height: 0))
        .onChange(of: model.state) { copied = false }
        .onChange(of: model.revision) { copied = false }
        .onChange(of: model.documentID) {
            if model.sourceText.isEmpty { showsSource = true }
        }
    }

    private var toolbar: some View {
        PopupToolbar {
            HStack(spacing: 20) {
                Button { showsSource.toggle() } label: {
                    Label(L10n.text("editor.source"), systemImage: "sidebar.left")
                        .font(.system(size: 14)).frame(minHeight: 36)
                        .contentShape(Rectangle())
                }
                .help(L10n.text(showsSource ? "editor.collapseSource" : "popup.showSource"))
                .accessibilityLabel(L10n.text(showsSource ? "editor.collapseSource" : "popup.showSource"))
                if let history = model.history {
                    Button { showsHistory.toggle() } label: {
                        Label(L10n.text("history.title"), systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 14)).frame(minHeight: 36).contentShape(Rectangle())
                    }
                    .help(L10n.text("history.title"))
                    .popover(isPresented: $showsHistory, arrowEdge: .bottom) {
                        TranslationHistoryView(store: history, open: { entry in
                            showsHistory = false
                            model.restoreHistory(entry)
                        }, close: { showsHistory = false })
                    }
                }
                TranslationEditorMenu(model: model, showsSource: $showsSource, showsDetails: $showsDetails,
                    glossaryFailure: $glossaryFailure, openSettings: openSettings, openGlossaries: openGlossaries)
            }
        }
    }

    private var sourcePane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(L10n.text("editor.source")).font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                LanguagePicker(label: L10n.text("translation.from"), selection: model.preferences.sourceLanguage,
                    includeAutomatic: true, controlSize: .large, fontSize: 16) { model.preferences.sourceLanguage = $0 }
                    .frame(minWidth: 90, maxWidth: 180).frame(height: 36)
                Spacer(minLength: 0)
            }.padding(.horizontal, 28).frame(height: 72)
            editor(text: model.sourceText, editable: true, label: "editor.source", isSource: true,
                onChange: { model.editSource($0, isComposing: $1) })
                .overlay(alignment: .topLeading) {
                    if model.sourceText.isEmpty {
                        Text(L10n.text("editor.sourcePlaceholder"))
                            .font(.system(size: 20)).foregroundStyle(.secondary)
                            .padding(.horizontal, 29).padding(.top, 18)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
        }
        .frame(minWidth: 260, idealWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
        .background(TranslationEditorSplitPosition().frame(width: 0, height: 0))
    }

    private var resultPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(L10n.text(model.hasEdits ? "editor.edited" : "editor.translation"))
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                LanguagePicker(label: L10n.text("translation.to"), selection: model.preferences.targetLanguage,
                    favoriteLanguages: model.preferences.favoriteLanguages, controlSize: .large, fontSize: 16) { model.preferences.targetLanguage = $0 }
                    .frame(minWidth: 90, idealWidth: 150, maxWidth: 180).frame(height: 36)
                ZStack {
                    if model.review.isBusy {
                        ProgressView().controlSize(.small)
                            .accessibilityLabel(L10n.text("review.loading"))
                    }
                }.frame(width: 16, height: 20)
                Spacer(minLength: 0)
                Button { copied = model.copyResult(to: .general) } label: {
                    Label(L10n.text(copied ? "editor.copyDone" : "editor.copy"),
                        systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 15)).frame(minWidth: 80, minHeight: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless).controlSize(.small)
                .disabled(!model.canCopy)
                .help(L10n.text(copied ? "translation.copied" : "translation.copy"))
                .accessibilityLabel(L10n.text(copied ? "translation.copied" : "translation.copy"))
            }.padding(.horizontal, 28).frame(height: 72)
            editor(text: model.resultText, editable: model.state == .completed,
                label: "editor.translation", isSource: false, onChange: { text, _ in model.editTranslation(text) })
                .overlay {
                    if model.resultText.isEmpty, model.state != .completed {
                        VStack(spacing: 8) {
                            Text(L10n.text("editor.resultPlaceholder"))
                                .font(.system(size: 20, weight: .medium))
                            Text(resultGuidance)
                                .font(.system(size: 15)).foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center).padding(32)
                        .allowsHitTesting(false)
                    }
                }
        }.frame(minWidth: 360, idealWidth: 640, maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultGuidance: String {
        if model.state == .running { return L10n.text("translation.working") }
        if model.state == .idle {
            return L10n.text("editor.resultGuidance")
        }
        return PopupTranslationStatusView(model: model, openSettings: openSettings,
            showDetails: { showsDetails = true }).notice ?? L10n.text("editor.resultGuidance")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let glossaryFailure { GlossaryErrorView(failure: glossaryFailure) }
            HStack(spacing: 12) {
                let status = PopupTranslationStatusView(model: model, openSettings: openSettings,
                    showDetails: { showsDetails = true })
                if model.state == .running { ProgressView().controlSize(.small) }
                let reviewNotice = model.review.failure.map { L10n.text("review.failed") + " " + L10n.text("translation.error.\($0.rawValue)") }
                    ?? (model.review.isCurrent && model.review.phase == .unmatched ? L10n.text("review.noMatch") : nil)
                let translationNotice = reviewNotice ?? status.notice ?? L10n.text(model.state == .running ? "translation.working" : "translation.completed")
                let historyNotice = model.history?.failure.map { L10n.text("history.error.\($0.rawValue)") }
                let statusText = [translationNotice, historyNotice].compactMap { $0 }.joined(separator: " ")
                Text(statusText)
                    .font(.system(size: 14)).foregroundStyle(.secondary).lineLimit(3)
                    .help(statusText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if model.state == .needsConfiguration {
                    Button(L10n.text("menu.settings"), action: openSettings)
                }
                if model.input != nil || !model.sourceText.isEmpty {
                    Button { showsDetails.toggle() } label: {
                        Image(systemName: "info.circle").font(.system(size: 16)).frame(width: 36, height: 36).contentShape(Rectangle())
                    }
                        .help(L10n.text("popup.showDetails"))
                        .accessibilityLabel(L10n.text("popup.showDetails"))
                }
                Button { model.undoManager.undo() } label: {
                    Image(systemName: "arrow.uturn.backward").font(.system(size: 16)).frame(width: 36, height: 36).contentShape(Rectangle())
                }
                    .disabled(!model.canUndo)
                    .help(L10n.text("menu.undo"))
                    .accessibilityLabel(L10n.text("menu.undo"))
                Button { model.undoManager.redo() } label: {
                    Image(systemName: "arrow.uturn.forward").font(.system(size: 16)).frame(width: 36, height: 36).contentShape(Rectangle())
                }
                    .disabled(!model.canRedo)
                    .help(L10n.text("menu.redo"))
                    .accessibilityLabel(L10n.text("menu.redo"))
                Divider().frame(height: 20)
                if model.state == .running {
                    Button { model.cancel() } label: {
                        Text(L10n.text("translation.cancel"))
                            .font(.system(size: 16, weight: .medium)).frame(minWidth: 96, minHeight: 32)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    .help(L10n.text("translation.stopHelp"))
                } else {
                    Button { model.translateSource() } label: {
                        Text(L10n.text(model.input == nil ? "editor.translate" : "translation.retranslate"))
                            .font(.system(size: 16, weight: .medium)).frame(minWidth: 96, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!model.canTranslate)
                    .help(L10n.text("editor.hint"))
                }
            }
            .controlSize(.regular)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
        .popover(isPresented: $showsDetails) { details }
    }

    private var details: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TranslationStatusView(model: model, openSettings: openSettings)
                TranslationGlossaryDetailsView(model: model)
                HStack {
                    Text(L10n.text("editor.source"))
                    Spacer()
                    Text(String(format: L10n.text("editor.characters"), model.sourceText.count))
                }.font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(L10n.text("editor.translation"))
                    Spacer()
                    Text(String(format: L10n.text("editor.characters"), model.resultText.count))
                }.font(.caption).foregroundStyle(.secondary)
                if model.hasEdits {
                    DisclosureGroup(L10n.text("editor.generated")) {
                        Text(model.output).textSelection(.enabled)
                    }
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(width: 440, height: 340)
    }

    private func editor(text: String, editable: Bool, label: String, isSource: Bool,
                        onChange: @escaping (String, Bool) -> Void) -> some View {
        TranslationTextEditor(text: text, editable: editable, label: L10n.text(label),
            documentID: model.documentID, undoManager: model.undoManager,
            backgroundColor: isSource ? .underPageBackgroundColor : .textBackgroundColor,
            fontSize: isSource ? 20 : 22,
            help: L10n.text(isSource ? "editor.hint" : "review.editorHint"),
            review: model.review, side: isSource ? .source : .target,
            highlightRange: isSource ? model.review.sourceHighlight : model.review.targetHighlight,
            highlightedWord: isSource ? nil : model.review.targetWordRange, onChange: onChange)
    }
}
