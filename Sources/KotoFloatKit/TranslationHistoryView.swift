import SwiftUI

struct TranslationHistoryView: View {
    let store: TranslationHistoryStore
    let open: (TranslationHistoryEntry) -> Void
    let close: () -> Void
    @State private var query = ""
    @State private var confirmsClear = false
    @State private var isOpening = false
    @State private var openingTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    private struct Search: Equatable { let query: String; let revision: Int }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.text("history.title")).font(.headline)
                Spacer()
                Button { openingTask?.cancel(); close() } label: { Image(systemName: "xmark").frame(width: 24, height: 24) }
                    .buttonStyle(.borderless).keyboardShortcut(.cancelAction)
                    .help(L10n.text("history.close")).accessibilityLabel(L10n.text("history.close"))
            }.padding(.horizontal, 16).padding(.top, 14)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
                TextField(L10n.text("history.search"), text: $query)
                    .textFieldStyle(.plain).focused($searchFocused)
                    .accessibilityLabel(L10n.text("history.search"))
            }
            .padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 16).padding(.vertical, 12)
            if let failure = store.failure {
                HStack(alignment: .top) {
                    Text(L10n.text("history.error.\(failure.rawValue)")).font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(L10n.text("history.retry")) { Task { await store.retry() } }
                }.padding(.horizontal, 16).padding(.bottom, 10)
            }
            Divider()
            ZStack {
                List {
                    ForEach(store.entries) { entry in row(entry) }
                    if store.hasMore {
                        Button(L10n.text("history.loadMore")) { Task { await store.loadMore() } }
                            .disabled(store.isLoading)
                    }
                }.listStyle(.plain)
                if store.entries.isEmpty {
                    VStack(spacing: 10) {
                        if store.isLoading { ProgressView().controlSize(.small) }
                        Text(L10n.text(store.isLoading ? "history.loading" : query.isEmpty ? "history.empty" : "history.noResults"))
                            .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.padding(24).allowsHitTesting(false)
                }
            }
            Divider()
            HStack {
                Text(L10n.text("history.local")).font(.caption).foregroundStyle(.secondary)
                    .help(TranslationHistoryStore.defaultURL.path)
                Spacer()
                Button(L10n.text("history.deleteAll"), role: .destructive) { confirmsClear = true }
                    .disabled(store.entries.isEmpty && query.isEmpty)
            }.padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: 440, height: 480)
        .onAppear { searchFocused = true }
        .onDisappear { openingTask?.cancel(); openingTask = nil; isOpening = false }
        .task(id: Search(query: query, revision: store.revision)) {
            do { try await Task.sleep(for: .milliseconds(200)) }
            catch { return }
            await store.search(query)
        }
        .alert(L10n.text("history.deleteAll"), isPresented: $confirmsClear) {
            Button(L10n.text("history.cancel"), role: .cancel) {}
            Button(L10n.text("history.deleteAll"), role: .destructive) { Task { await store.clear() } }
        } message: { Text(L10n.text("history.confirmDeleteAll")) }
    }

    private func row(_ entry: TranslationHistorySummary) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                guard !isOpening else { return }
                isOpening = true
                openingTask = Task {
                    let saved = await store.entry(id: entry.id)
                    guard !Task.isCancelled else { return }
                    if let saved { open(saved) }
                    isOpening = false
                }
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(entry.sourceLanguage.title + " → " + entry.targetLanguage.title)
                        Spacer(minLength: 4)
                        Text(entry.updatedAt, format: .dateTime.month().day().hour().minute())
                    }.font(.caption).foregroundStyle(.secondary)
                    Text(entry.sourcePreview.split(whereSeparator: \.isWhitespace).joined(separator: " "))
                        .font(.system(size: 14)).lineLimit(2)
                    Text(entry.translationPreview.split(whereSeparator: \.isWhitespace).joined(separator: " "))
                        .font(.system(size: 14)).foregroundStyle(.secondary).lineLimit(2)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(isOpening)
            .help(L10n.text("history.open"))
            .accessibilityHint(L10n.text("history.open"))
            Button(role: .destructive) { Task { await store.delete(id: entry.id) } } label: {
                Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
            }
            .buttonStyle(.borderless).disabled(isOpening)
            .help(L10n.text("history.delete"))
            .accessibilityLabel(L10n.text("history.delete") + ": " + String(entry.sourcePreview.prefix(60)))
        }.padding(.vertical, 6)
    }
}
