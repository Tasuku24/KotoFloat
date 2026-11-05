import SwiftUI

struct TranslationEditorMenu: View {
    let model: TranslationModel
    @Binding var showsSource: Bool
    @Binding var showsDetails: Bool
    @Binding var glossaryFailure: GlossaryFailure?
    let openSettings: () -> Void
    let openGlossaries: () -> Void

    var body: some View {
        Menu {
            Toggle(L10n.text("popup.showSource"), isOn: $showsSource)
            Button(L10n.text("popup.showDetails")) { showsDetails = true }
                .disabled(model.input == nil && model.sourceText.isEmpty)
            Menu(L10n.text("translation.from")) {
                Picker(L10n.text("translation.from"), selection: Binding(
                    get: { model.preferences.sourceLanguage },
                    set: { model.preferences.sourceLanguage = $0 })) {
                    ForEach(TranslationLanguage.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
            Button(L10n.text("editor.swap")) { model.swapLanguages() }
                .disabled(!model.canSwapLanguages)
            Divider()
            if let store = model.glossaries {
                Menu(L10n.text("glossary.title")) {
                    Picker(L10n.text("glossary.active"), selection: Binding<UUID?>(
                        get: { store.library.activeGlossaryID },
                        set: { id in
                            do { try store.select(id); glossaryFailure = nil }
                            catch { glossaryFailure = error as? GlossaryFailure ?? .saveFailed }
                        })) {
                        Text(L10n.text("glossary.none")).tag(nil as UUID?)
                        ForEach(store.library.glossaries) { Text($0.name).tag(Optional($0.id)) }
                    }.disabled(store.failure != nil)
                    Divider()
                    Button(L10n.text("menu.glossaries"), action: openGlossaries)
                }
            }
            Button(L10n.text("editor.clear")) { model.clearDocument() }
                .disabled(model.sourceText.isEmpty && model.output.isEmpty)
            Divider()
            Button(L10n.text("menu.settings"), action: openSettings)
                .keyboardShortcut(",", modifiers: .command)
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 16)).frame(width: 36, height: 36)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help(L10n.text("popup.more"))
        .accessibilityLabel(L10n.text("popup.more"))
    }
}
