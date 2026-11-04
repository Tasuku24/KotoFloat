import SwiftUI

struct PopupTranslationStatusView: View {
    let model: TranslationModel
    let openSettings: () -> Void
    let showDetails: () -> Void

    private var needsRetranslation: Bool {
        model.sourceChanged || model.directionChanged || model.glossaryChanged
    }

    private var changedInputNotice: String? {
        if model.sourceChanged, model.input != nil { return L10n.text("editor.sourceChanged") }
        if model.directionChanged { return L10n.text("editor.directionChanged") }
        if model.glossaryChanged { return L10n.text("glossary.changed") }
        return nil
    }

    var notice: String? {
        if model.sourceText.utf8.count > 131_072 { return L10n.text("editor.sourceTooLarge") }
        switch model.state {
        case .running: return changedInputNotice
        case .needsConfiguration: return L10n.text("translation.configure")
        case .cancelled: return changedInputNotice ?? L10n.text("translation.cancelled")
        case .failed(let error):
            return L10n.text("translation.incomplete") + " " + L10n.text("translation.error.\(error.rawValue)")
        case .idle, .completed: break
        }
        if let changedInputNotice { return changedInputNotice }
        if model.input?.glossary.conflicts.isEmpty == false { return L10n.text("glossary.conflicts") }
        if !model.missingGlossaryTerms.isEmpty { return L10n.text("glossary.missing") }
        if model.hasEdits { return L10n.text("editor.edited") }
        if model.state == .idle { return L10n.text("translation.ready") }
        return nil
    }

    var body: some View {
        if let notice {
            HStack(spacing: 10) {
                if model.state == .running {
                    Text(notice).font(.caption).foregroundStyle(.secondary).lineLimit(2).help(notice)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(notice).font(.caption).lineLimit(2).help(notice)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if model.state == .needsConfiguration {
                    Button(L10n.text("menu.settings"), action: openSettings)
                }
                if model.state != .running, model.state != .completed || needsRetranslation {
                    Button { model.retranslate() } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(!model.canTranslate)
                        .help(L10n.text("translation.retranslate"))
                        .accessibilityLabel(L10n.text("translation.retranslate"))
                }
                if model.input != nil, model.state != .running || needsRetranslation {
                    Button(action: showDetails) { Image(systemName: "info.circle") }
                        .help(L10n.text("popup.showDetails"))
                        .accessibilityLabel(L10n.text("popup.showDetails"))
                }
            }
            .controlSize(.small)
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider()
        }
    }
}
