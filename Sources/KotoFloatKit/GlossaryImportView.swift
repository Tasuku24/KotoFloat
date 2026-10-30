import SwiftUI
import UniformTypeIdentifiers

struct GlossaryImportDraft: Identifiable {
    let id = UUID()
    let glossaryID: UUID
    let revision: Int
    let data: Data
    let existing: [GlossaryEntry]
}

struct GlossaryImportView: View {
    let store: GlossaryStore
    let draft: GlossaryImportDraft
    @State private var policy = GlossaryDuplicatePolicy.skip
    @State private var preview: GlossaryImportPreview
    @State private var failure: GlossaryFailure?
    @Environment(\.dismiss) private var dismiss

    init(store: GlossaryStore, draft: GlossaryImportDraft) {
        self.store = store
        self.draft = draft
        _preview = State(initialValue: GlossaryCSV.preview(data: draft.data, existing: draft.existing, policy: .skip))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("glossary.importPreview")).font(.title2)
            Text(L10n.text("glossary.csvHint")).font(.callout).foregroundStyle(.secondary)
            Picker(L10n.text("glossary.duplicates"), selection: $policy) {
                ForEach(GlossaryDuplicatePolicy.allCases, id: \.self) { value in
                    Text(L10n.text("glossary.policy.\(value.rawValue)")).tag(value)
                }
            }.pickerStyle(.segmented)
            Text(String(format: L10n.text("glossary.importSummary"), preview.rows.count, preview.duplicateCount, preview.entries.count))
                .font(.caption)
            Table(preview.rows) {
                TableColumn(L10n.text("glossary.row")) { Text(String($0.number)) }.width(35)
                TableColumn(L10n.text("glossary.source")) { Text(field($0, 0)) }.width(min: 80)
                TableColumn(L10n.text("glossary.target")) { Text(field($0, 1)) }.width(min: 80)
                TableColumn(L10n.text("glossary.direction")) { Text("\(field($0, 2)) → \(field($0, 3))") }.width(65)
                TableColumn(L10n.text("glossary.context")) { Text(field($0, 4)).lineLimit(3) }.width(min: 100)
                TableColumn(L10n.text("glossary.caseSensitive")) { Text(field($0, 5)) }.width(90)
                TableColumn(L10n.text("glossary.enabled")) { Text(field($0, 6)) }.width(55)
                TableColumn(L10n.text("glossary.action")) { Text(L10n.text("glossary.row.\($0.action)")) }.width(70)
            }
            .frame(minHeight: 220)
            if !preview.issues.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(preview.issues) { issue in
                            Text(String(format: L10n.text("glossary.rowError"), issue.row, L10n.text("glossary.error.\(issue.failure.rawValue)")))
                                .foregroundStyle(.red)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 90)
            }
            if let failure { GlossaryErrorView(failure: failure) }
            if store.revision != draft.revision { GlossaryErrorView(failure: .stalePreview) }
            HStack {
                Button(L10n.text("glossary.cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.text("glossary.importApply")) {
                    do { try store.importCSV(preview, in: draft.glossaryID, expectedRevision: draft.revision); dismiss() }
                    catch { failure = error as? GlossaryFailure ?? .saveFailed }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!preview.canImport || store.revision != draft.revision)
            }
        }
        .padding(24).frame(width: 900, height: 560)
        .environment(\.locale, AppLocalization.shared.locale)
        .onChange(of: policy) {
            preview = GlossaryCSV.preview(data: draft.data, existing: draft.existing, policy: policy)
            failure = nil
        }
    }

    private func field(_ row: GlossaryImportPreview.Row, _ index: Int) -> String {
        row.fields.indices.contains(index) ? row.fields[index] : ""
    }
}

struct GlossaryCSVDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText]
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw GlossaryFailure.unreadable }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
