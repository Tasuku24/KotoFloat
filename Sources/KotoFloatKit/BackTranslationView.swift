import SwiftUI

struct BackTranslationView: View {
    let model: BackTranslationModel
    let documentID: UUID
    let canTranslate: Bool
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(L10n.text("backTranslation.title")).font(.system(size: 14, weight: .semibold))
                LanguagePicker(label: L10n.text("backTranslation.language"), selection: model.targetLanguage ?? .automatic,
                    buttonTitle: model.targetLanguage?.title ?? L10n.text("backTranslation.chooseLanguage")) { model.start(language: $0) }
                    .frame(minWidth: 90, maxWidth: 180).frame(height: 28)
                    .disabled(!canTranslate)
                Spacer(minLength: 0)
                if model.isCurrent, model.state == .running { ProgressView().controlSize(.small) }
                Button { model.start(language: model.targetLanguage) } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!canTranslate || model.isCurrent && model.state == .running)
                .help(L10n.text("backTranslation.refresh"))
                .accessibilityLabel(L10n.text("backTranslation.refresh"))
                Button(action: close) { Image(systemName: "xmark") }
                    .help(L10n.text("backTranslation.close"))
                    .accessibilityLabel(L10n.text("backTranslation.close"))
            }.padding(.horizontal, 24)
            TranslationTextEditor(text: model.resultText.isEmpty ? status : model.resultText, editable: false,
                label: L10n.text("backTranslation.result"), documentID: documentID, undoManager: nil,
                backgroundColor: .underPageBackgroundColor, fontSize: 17, onChange: { _, _ in })
        }
        .padding(.vertical, 14)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var status: String {
        if !model.isCurrent { return L10n.text("backTranslation.stale") }
        if model.needsLanguage { return L10n.text("backTranslation.unknownLanguage") }
        if case .failed(let failure) = model.state {
            return L10n.text("translation.error.\(failure.rawValue)")
        }
        return L10n.text(model.state == .running ? "backTranslation.loading" : "backTranslation.stale")
    }
}
