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
            TranslationGlossaryView(model: model, openGlossaries: openGlossaries)
            TranslationStatusView(model: model, openSettings: openSettings)
            if model.hasEdits {
                Label(L10n.text("editor.edited"), systemImage: "pencil").font(.caption).foregroundStyle(.secondary)
            }
            if !model.resultText.isEmpty {
                Text(model.resultText).font(.system(size: 17)).lineSpacing(6)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("translationOutput")
            }
        }
    }
}

struct TranslationGlossaryView: View {
    let model: TranslationModel
    var openGlossaries: () -> Void = {}
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

}

struct TranslationStatusView: View {
    let model: TranslationModel
    let openSettings: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.state == .running {
                ProgressView(L10n.text("translation.working")).controlSize(.small)
            } else {
                Text(statusText).font(.callout).foregroundStyle(.secondary)
            }
            if model.state == .needsConfiguration {
                Button(L10n.text("menu.settings"), action: openSettings)
            }
            if model.sourceChanged, model.input != nil {
                Text(L10n.text("editor.sourceChanged")).font(.caption).foregroundStyle(.orange)
                DisclosureGroup(L10n.text("editor.requestSource")) {
                    Text(model.input?.text ?? "").textSelection(.enabled)
                }.font(.caption)
            }
            if model.directionChanged {
                Text(L10n.text("editor.directionChanged")).font(.caption).foregroundStyle(.orange)
            }
            if let input = model.input {
                Text(String(format: L10n.text("editor.requestDirection"),
                    L10n.text("translation.language.\(input.source.rawValue)"),
                    L10n.text("translation.language.\(input.target.rawValue)")))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if model.sourceText.utf8.count > 131_072 {
                Text(L10n.text("editor.sourceTooLarge")).font(.caption).foregroundStyle(.red)
            }
        }
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
                Button(L10n.text(model.input == nil ? "editor.translate" : "translation.retranslate")) { model.translateSource() }
                    .disabled(!model.canTranslate)
            }
            Button(L10n.text(copied ? "translation.copied" : "translation.copy")) {
                copied = model.copyResult(to: .general)
            }.disabled(!model.canCopy)
            Spacer()
        }
        .controlSize(.small)
        .onChange(of: model.state) { copied = false }
        .onChange(of: model.revision) { copied = false }
    }
}

struct TranslationConfirmationView: View {
    let model: TranslationModel
    var body: some View {
        if let action = model.pendingAction {
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.text(action.messageKey), systemImage: "exclamationmark.triangle")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                if case .translate(let text) = action {
                    Text(String(text.text.prefix(160))).font(.caption).lineLimit(3).textSelection(.enabled)
                }
                HStack {
                    Button(L10n.text("editor.keepEditing")) { model.keepEditing() }
                    Button(L10n.text("editor.discardContinue"), role: .destructive) { model.confirmPendingAction() }
                }.controlSize(.small)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
