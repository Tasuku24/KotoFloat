import SwiftUI

struct TranslationDirectionView: View {
    @Bindable var preferences: TranslationPreferences
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(L10n.text("translation.from"), selection: $preferences.sourceLanguage) {
                ForEach(TranslationLanguage.allCases, id: \.self) { language in
                    Text(L10n.text("translation.language.\(language.rawValue)")).tag(language)
                }
            }
            Picker(L10n.text("translation.to"), selection: $preferences.targetLanguage) {
                ForEach([TranslationLanguage.english, .japanese], id: \.self) { language in
                    Text(L10n.text("translation.language.\(language.rawValue)")).tag(language)
                }
            }
            Text(L10n.text("translation.directionHint"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TranslationContentView: View {
    let model: TranslationModel
    let openSettings: () -> Void
    var openGlossaries: () -> Void = {}
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TranslationDirectionView(preferences: model.preferences).controlSize(.small)
            if let store = model.glossaries {
                GlossarySelectionView(store: store).controlSize(.small)
                Button(L10n.text("menu.glossaries"), action: openGlossaries).controlSize(.small)
                if model.glossaryChanged {
                    Text(L10n.text("glossary.changed")).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let context = model.input?.glossary, let name = context.name {
                Text(String(format: L10n.text("glossary.used"), name, context.entries.count))
                    .font(.caption).foregroundStyle(.secondary)
                if !context.entries.isEmpty {
                    DisclosureGroup(L10n.text("glossary.matched")) { termList(context.entries) }
                }
                if !context.conflicts.isEmpty {
                    DisclosureGroup(L10n.text("glossary.conflicts")) { termList(context.conflicts) }
                        .foregroundStyle(.orange)
                }
            }
            if !model.missingGlossaryTerms.isEmpty {
                DisclosureGroup(L10n.text("glossary.missing")) { termList(model.missingGlossaryTerms) }
                    .foregroundStyle(.orange)
            }
            if model.state == .running {
                ProgressView(L10n.text("translation.working")).controlSize(.small)
            } else {
                Text(statusText).font(.callout).foregroundStyle(.secondary)
            }
            if model.state == .needsConfiguration {
                Button(L10n.text("menu.settings"), action: openSettings)
            }
            if !model.output.isEmpty {
                Text(model.output).font(.system(size: 17)).lineSpacing(6)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("translationOutput")
            }
        }
    }

    private func termList(_ entries: [GlossaryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entries) { entry in
                Text("\(entry.sourceTerm) → \(entry.preferredTranslation)").textSelection(.enabled)
                if !entry.context.isEmpty { Text(entry.context).foregroundStyle(.secondary) }
            }
        }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusText: String {
        switch model.state {
        case .idle: L10n.text("translation.ready")
        case .needsConfiguration: L10n.text("translation.configure")
        case .running: L10n.text("translation.working")
        case .completed: L10n.text("translation.completed")
        case .cancelled: L10n.text("translation.cancelled")
        case .failed(let error): L10n.text("translation.incomplete") + " " + L10n.text("translation.error.\(error.rawValue)")
        }
    }
}

struct TranslationActionsView: View {
    let model: TranslationModel
    @State private var copied = false

    var body: some View {
        HStack {
            if model.state == .running {
                Button(L10n.text("translation.cancel")) { model.cancel() }
            } else {
                Button(L10n.text("translation.retranslate")) { model.retranslate() }
            }
            Button(L10n.text(copied ? "translation.copied" : "translation.copy")) {
                guard model.state == .completed else { return }
                let clipboard = NSPasteboard.general
                clipboard.clearContents()
                copied = clipboard.setString(model.output, forType: .string)
            }.disabled(model.state != .completed)
            Spacer()
        }
        .controlSize(.small)
        .onChange(of: model.state) { copied = false }
    }
}
