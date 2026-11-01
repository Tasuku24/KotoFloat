import SwiftUI

struct TranslationEditorView: View {
    let model: TranslationModel
    let openSettings: () -> Void
    let openGlossaries: () -> Void
    @State private var showsSource = true
    @State private var showsDetails = false
    @State private var copied = false
    @State private var glossaryFailure: GlossaryFailure?

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
            if !showsSource {
                Button { showsSource = true } label: {
                    Image(systemName: "sidebar.left").frame(width: 26, height: 28)
                }
                .help(L10n.text("popup.showSource"))
                .accessibilityLabel(L10n.text("popup.showSource"))
            }
            LanguagePicker(label: L10n.text("translation.to"), selection: model.preferences.targetLanguage,
                favoriteLanguages: model.preferences.favoriteLanguages) { model.preferences.targetLanguage = $0 }
                .frame(minWidth: 80, idealWidth: 120, maxWidth: 160).frame(height: 26)
            Button { copied = model.copyResult(to: .general) } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc").frame(width: 26, height: 28)
            }
            .disabled(!model.canCopy)
            .help(L10n.text(copied ? "translation.copied" : "translation.copy"))
            .accessibilityLabel(L10n.text(copied ? "translation.copied" : "translation.copy"))
            TranslationEditorMenu(model: model, showsSource: $showsSource, showsDetails: $showsDetails,
                glossaryFailure: $glossaryFailure, openSettings: openSettings, openGlossaries: openGlossaries)
        }
    }

    private var sourcePane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(L10n.text("editor.source")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                LanguagePicker(label: L10n.text("translation.from"), selection: model.preferences.sourceLanguage,
                    includeAutomatic: true) { model.preferences.sourceLanguage = $0 }
                    .frame(minWidth: 60, maxWidth: 150).frame(height: 26)
                Spacer(minLength: 0)
                Button { showsSource = false } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                    .help(L10n.text("editor.collapseSource"))
                    .accessibilityLabel(L10n.text("editor.collapseSource"))
            }.padding(.horizontal, 20).frame(height: 48)
            editor(text: model.sourceText, editable: true, label: "editor.source", isSource: true,
                onChange: model.editSource)
        }
        .frame(minWidth: 260, idealWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
        .background(TranslationEditorSplitPosition().frame(width: 0, height: 0))
    }

    private var resultPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.text(model.hasEdits ? "editor.edited" : "editor.translation"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }.padding(.horizontal, 24).frame(height: 48)
            editor(text: model.resultText, editable: model.state == .completed,
                label: "editor.translation", isSource: false, onChange: model.editTranslation)
        }.frame(minWidth: 360, idealWidth: 640, maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let glossaryFailure { GlossaryErrorView(failure: glossaryFailure) }
            HStack(spacing: 12) {
                let status = PopupTranslationStatusView(model: model, openSettings: openSettings,
                    showDetails: { showsDetails = true })
                if model.state == .running { ProgressView().controlSize(.small) }
                Text(status.notice ?? L10n.text("translation.completed"))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(3)
                    .help(status.notice ?? L10n.text("translation.completed"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if model.state == .needsConfiguration {
                    Button(L10n.text("menu.settings"), action: openSettings)
                }
                if model.input != nil || !model.sourceText.isEmpty {
                    Button { showsDetails.toggle() } label: { Image(systemName: "info.circle") }
                        .help(L10n.text("popup.showDetails"))
                        .accessibilityLabel(L10n.text("popup.showDetails"))
                }
                Button { model.undoManager.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!model.canUndo)
                    .help(L10n.text("menu.undo"))
                    .accessibilityLabel(L10n.text("menu.undo"))
                Button { model.undoManager.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    .disabled(!model.canRedo)
                    .help(L10n.text("menu.redo"))
                    .accessibilityLabel(L10n.text("menu.redo"))
                Divider().frame(height: 20)
                if model.state == .running {
                    Button(L10n.text("translation.cancel")) { model.cancel() }
                } else {
                    Button(L10n.text(model.input == nil ? "editor.translate" : "translation.retranslate")) {
                        model.translateSource()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canTranslate)
                    .help(L10n.text("editor.hint"))
                }
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
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
                        onChange: @escaping (String) -> Void) -> some View {
        TranslationTextEditor(text: text, editable: editable, label: L10n.text(label),
            documentID: model.documentID, undoManager: model.undoManager,
            backgroundColor: isSource ? .underPageBackgroundColor : .textBackgroundColor,
            fontSize: isSource ? 16 : 17, onChange: onChange)
    }
}
