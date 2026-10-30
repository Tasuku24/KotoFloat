import SwiftUI

struct TranslationEditorView: View {
    let model: TranslationModel
    let openSettings: () -> Void
    let openGlossaries: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(L10n.text("editor.title"), systemImage: "character.bubble")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(L10n.text("editor.clear")) { model.clearDocument() }
                    .disabled(model.sourceText.isEmpty && model.output.isEmpty)
                Button(action: openSettings) { Image(systemName: "gearshape") }
                    .accessibilityLabel(L10n.text("menu.settings"))
                    .help(L10n.text("menu.settings"))
            }.padding(16)
            Divider()
            direction.padding(.horizontal, 16).padding(.vertical, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    TranslationGlossaryView(model: model, openGlossaries: openGlossaries)
                    TranslationStatusView(model: model, openSettings: openSettings)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.bottom, 8)
            }.frame(maxHeight: 150)
            TranslationConfirmationView(model: model).padding(.horizontal, 16)
            Divider()
            HSplitView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.text("editor.source")).font(.headline)
                        Spacer()
                        Text(String(format: L10n.text("editor.characters"), model.sourceText.count))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.horizontal, 12).padding(.top, 12)
                    editor(text: model.sourceText, editable: true, label: "editor.source", onChange: model.editSource)
                }.frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.text(model.hasEdits ? "editor.edited" : "editor.translation")).font(.headline)
                        Spacer()
                        Text(String(format: L10n.text("editor.characters"), model.resultText.count))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.horizontal, 12).padding(.top, 12)
                    editor(text: model.resultText, editable: model.state == .completed,
                           label: "editor.translation", onChange: model.editTranslation)
                    if model.hasEdits {
                        DisclosureGroup(L10n.text("editor.generated")) {
                            ScrollView {
                                Text(model.output).textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }.frame(maxHeight: 100)
                        }.padding(.horizontal, 12).padding(.bottom, 8)
                    }
                }.frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            }.frame(minHeight: 180)
            Divider()
            HStack(spacing: 12) {
                TranslationActionsView(model: model)
                Button(L10n.text("menu.undo")) { model.undoManager.undo() }.disabled(!model.canUndo)
                Button(L10n.text("menu.redo")) { model.undoManager.redo() }.disabled(!model.canRedo)
            }.padding(16)
            Text(L10n.text("editor.hint"))
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.bottom, 12)
        }
        .background(.background)
        .environment(\.locale, AppLocalization.shared.locale)
    }

    private var direction: some View {
        @Bindable var preferences = model.preferences
        return HStack(spacing: 16) {
            Picker(L10n.text("translation.from"), selection: $preferences.sourceLanguage) {
                ForEach(TranslationLanguage.allCases, id: \.self) { language in
                    Text(L10n.text("translation.language.\(language.rawValue)")).tag(language)
                }
            }.frame(maxWidth: .infinity)
            Button { model.swapLanguages() } label: { Image(systemName: "arrow.left.arrow.right") }
                .disabled(!model.canSwapLanguages)
                .accessibilityLabel(L10n.text("editor.swap"))
                .help(L10n.text("editor.swapHint"))
            Picker(L10n.text("translation.to"), selection: $preferences.targetLanguage) {
                ForEach([TranslationLanguage.english, .japanese], id: \.self) { language in
                    Text(L10n.text("translation.language.\(language.rawValue)")).tag(language)
                }
            }.frame(maxWidth: .infinity)
        }
    }

    private func editor(text: String, editable: Bool, label: String, onChange: @escaping (String) -> Void) -> some View {
        TranslationTextEditor(text: text, editable: editable, label: L10n.text(label),
            documentID: model.documentID, undoManager: model.undoManager, onChange: onChange)
    }
}
