import SwiftUI
import UniformTypeIdentifiers

struct GlossaryView: View {
    let store: GlossaryStore
    @State private var selectedID: UUID?
    @State private var selectedEntryID: UUID?
    @State private var search = ""
    @State private var entryDraft: GlossaryEntry?
    @State private var nameDraft: NameDraft?
    @State private var importDraft: GlossaryImportDraft?
    @State private var showsImporter = false
    @State private var showsExporter = false
    @State private var exportDocument = GlossaryCSVDocument(data: Data())
    @State private var deletion: Deletion?
    @State private var failure: GlossaryFailure?
    @State private var exported = false

    private struct NameDraft: Identifiable {
        let id = UUID()
        var glossaryID: UUID?
        var name = ""
    }
    private enum Deletion { case glossary(UUID), entry(UUID, UUID) }
    private var selected: Glossary? { store.library.glossaries.first { $0.id == selectedID } }
    private var filteredEntries: [GlossaryEntry] {
        (selected?.entries ?? []).filter { entry in
            search.isEmpty || [entry.sourceTerm, entry.preferredTranslation, entry.context].contains { $0.localizedCaseInsensitiveContains(search) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.text("glossary.title")).font(.title2)
                Spacer()
                Button(L10n.text("glossary.reload")) { store.reload(); failure = nil }
            }
            GlossarySelectionView(store: store)
            Text(L10n.text("glossary.nextRequest")).font(.caption).foregroundStyle(.secondary)
            if let error = store.failure ?? failure { GlossaryErrorView(failure: error) }
            HSplitView {
                VStack(alignment: .leading, spacing: 10) {
                    List(store.library.glossaries, selection: $selectedID) { glossary in
                        Text(glossary.name).tag(glossary.id)
                    }
                    .accessibilityLabel(L10n.text("glossary.title"))
                    Button(L10n.text("glossary.new")) { nameDraft = NameDraft() }
                    HStack {
                        Button(L10n.text("glossary.rename")) {
                            if let selected { nameDraft = NameDraft(glossaryID: selected.id, name: selected.name) }
                        }
                        Button(L10n.text("glossary.delete")) { if let selectedID { deletion = .glossary(selectedID) } }
                    }.disabled(selected == nil)
                }.frame(minWidth: 160, idealWidth: 190, maxWidth: 240)
                VStack(alignment: .leading, spacing: 10) {
                    if let selected {
                        Text(selected.name).font(.headline)
                        TextField(L10n.text("glossary.search"), text: $search)
                            .textFieldStyle(.roundedBorder)
                        Table(filteredEntries, selection: $selectedEntryID) {
                            TableColumn(L10n.text("glossary.source"), value: \.sourceTerm)
                            TableColumn(L10n.text("glossary.target"), value: \.preferredTranslation)
                            TableColumn(L10n.text("glossary.direction")) { Text("\($0.sourceLanguage.rawValue) → \($0.targetLanguage.rawValue)") }.width(min: 90, ideal: 140)
                            TableColumn(L10n.text("glossary.context"), value: \.context)
                            TableColumn(L10n.text("glossary.enabled")) { Text(L10n.text($0.enabled ? "state.on" : "state.off")) }.width(55)
                        }
                        .accessibilityLabel(L10n.text("glossary.entries"))
                        HStack {
                            Button(L10n.text("glossary.addEntry")) {
                                entryDraft = GlossaryEntry(sourceTerm: "", preferredTranslation: "", sourceLanguage: .english, targetLanguage: .japanese)
                            }
                            Button(L10n.text("glossary.editEntry")) { entryDraft = selected.entries.first { $0.id == selectedEntryID } }
                                .disabled(selectedEntryID == nil)
                            Button(L10n.text("glossary.delete")) {
                                if let selectedEntryID { deletion = .entry(selectedEntryID, selected.id) }
                            }.disabled(selectedEntryID == nil)
                            Spacer()
                        }
                        HStack {
                            Button(L10n.text("glossary.import")) { showsImporter = true }
                            Button(L10n.text("glossary.export")) {
                                exportDocument = GlossaryCSVDocument(data: GlossaryCSV.export(selected.entries))
                                exported = false
                                showsExporter = true
                            }
                            if exported { Text(L10n.text("glossary.exported")).font(.caption) }
                        }
                    } else {
                        ContentUnavailableView(L10n.text("glossary.empty"), systemImage: "books.vertical", description: Text(L10n.text("glossary.emptyHint")))
                    }
                }.padding(.leading, 14).frame(minWidth: 500)
            }
            .disabled(store.failure != nil)
            Text(L10n.text("glossary.privacy")).font(.caption).foregroundStyle(.secondary)
        }
        .padding(20).frame(minWidth: 800, minHeight: 560)
        .environment(\.locale, AppLocalization.shared.locale)
        .onAppear { selectedID = store.library.activeGlossaryID ?? store.library.glossaries.first?.id }
        .onChange(of: selectedID) { selectedEntryID = nil; search = ""; exported = false }
        .onChange(of: search) { selectedEntryID = nil }
        .onChange(of: store.library.glossaries.map(\.id)) {
            if !store.library.glossaries.contains(where: { $0.id == selectedID }) { selectedID = store.library.glossaries.first?.id }
        }
        .sheet(item: $nameDraft) { draft in
            GlossaryNameEditor(name: draft.name) { name in
                if let id = draft.glossaryID { try store.rename(id: id, name: name) }
                else { selectedID = try store.create(name: name) }
            }
        }
        .sheet(item: $entryDraft) { entry in
            if let selectedID { GlossaryEntryEditor(store: store, glossaryID: selectedID, entry: entry) }
        }
        .sheet(item: $importDraft) { draft in GlossaryImportView(store: store, draft: draft) }
        .alert(L10n.text("glossary.deleteConfirm"), isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }), presenting: deletion) { pending in
            Button(L10n.text("glossary.cancel"), role: .cancel) { deletion = nil }
            Button(L10n.text("glossary.delete"), role: .destructive) {
                do {
                    switch pending {
                    case .glossary(let id): try store.delete(id: id)
                    case .entry(let entry, let glossary): try store.deleteEntry(id: entry, in: glossary); selectedEntryID = nil
                    }
                    failure = nil
                } catch { failure = error as? GlossaryFailure ?? .saveFailed }
                deletion = nil
            }
        } message: { _ in Text(L10n.text("glossary.deleteHint")) }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard let selected, let data = try GlossaryStore.read(url) else { throw GlossaryFailure.unreadable }
                importDraft = GlossaryImportDraft(glossaryID: selected.id, revision: store.revision, data: data, existing: selected.entries)
                failure = nil
            } catch { failure = error as? GlossaryFailure ?? .unreadable }
        }
        .fileExporter(isPresented: $showsExporter, document: exportDocument, contentType: .commaSeparatedText, defaultFilename: "glossary") { result in
            switch result {
            case .success: exported = true; failure = nil
            case .failure: failure = .saveFailed
            }
        }
    }
}

private struct GlossaryNameEditor: View {
    @State var name: String
    let save: (String) throws -> Void
    @State private var failure: GlossaryFailure?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField(L10n.text("glossary.name"), text: $name).textFieldStyle(.roundedBorder)
            if let failure { GlossaryErrorView(failure: failure) }
            HStack {
                Button(L10n.text("glossary.cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.text("connection.save")) {
                    do { try save(name); dismiss() }
                    catch { failure = error as? GlossaryFailure ?? .saveFailed }
                }.keyboardShortcut(.defaultAction).disabled((try? GlossaryLibrary.validatedName(name)) == nil)
            }
        }.padding(24).frame(width: 380)
    }
}
