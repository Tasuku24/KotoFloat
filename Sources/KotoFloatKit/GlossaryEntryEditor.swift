import SwiftUI

struct GlossaryEntryEditor: View {
    let store: GlossaryStore
    let glossaryID: UUID
    @State var entry: GlossaryEntry
    @State private var failure: GlossaryFailure?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("glossary.editEntry")).font(.title2)
            Form {
                TextField(L10n.text("glossary.source"), text: $entry.sourceTerm)
                TextField(L10n.text("glossary.target"), text: $entry.preferredTranslation)
                LabeledContent(L10n.text("translation.from")) {
                    LanguagePicker(label: L10n.text("translation.from"), selection: entry.sourceLanguage) {
                        entry.sourceLanguage = $0
                    }.frame(height: 26)
                }
                LabeledContent(L10n.text("translation.to")) {
                    LanguagePicker(label: L10n.text("translation.to"), selection: entry.targetLanguage) {
                        entry.targetLanguage = $0
                    }.frame(height: 26)
                }
                Toggle(L10n.text("glossary.caseSensitive"), isOn: $entry.caseSensitive)
                Toggle(L10n.text("glossary.enabled"), isOn: $entry.enabled)
            }
            Text(L10n.text("glossary.context")).font(.headline)
            TextEditor(text: $entry.context)
                .font(.body).frame(height: 100)
                .accessibilityLabel(L10n.text("glossary.context"))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
            Text(L10n.text("glossary.entryHint")).font(.caption).foregroundStyle(.secondary)
            if let failure { GlossaryErrorView(failure: failure) }
            HStack {
                Button(L10n.text("glossary.cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.text("connection.save")) {
                    do { try store.saveEntry(entry, in: glossaryID); dismiss() }
                    catch { failure = error as? GlossaryFailure ?? .saveFailed }
                }
                .keyboardShortcut(.defaultAction)
                .disabled((try? entry.validated()) == nil)
            }
        }
        .padding(24).frame(width: 520)
        .environment(\.locale, AppLocalization.shared.locale)
    }
}

struct GlossaryErrorView: View {
    let failure: GlossaryFailure
    var body: some View {
        Label(L10n.text("glossary.error.\(failure.rawValue)"), systemImage: "exclamationmark.triangle")
            .font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
    }
}

struct GlossarySelectionView: View {
    let store: GlossaryStore
    @State private var failure: GlossaryFailure?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(L10n.text("glossary.active"), selection: Binding<UUID?>(
                get: { store.library.activeGlossaryID },
                set: { id in
                    do { try store.select(id); failure = nil }
                    catch { failure = error as? GlossaryFailure ?? .saveFailed }
                })) {
                Text(L10n.text("glossary.none")).tag(nil as UUID?)
                ForEach(store.library.glossaries) { glossary in
                    Text(glossary.name).tag(Optional(glossary.id))
                }
            }.disabled(store.failure != nil)
            if let failure { GlossaryErrorView(failure: failure) }
        }
    }
}
