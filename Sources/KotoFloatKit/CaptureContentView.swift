import SwiftUI

struct PopupRootView: View {
    let preferences: PopupPreferences
    let sample: SampleContent
    let capture: CaptureModel
    let translation: TranslationModel?
    let toggleTopmost: () -> Void
    let openSettings: () -> Void
    var openGlossaries: () -> Void = {}
    var openEditor: () -> Void = {}

    var body: some View {
        Group {
            if capture.showsSample {
                PopupContentView(preferences: preferences, sample: sample,
                    toggleTopmost: toggleTopmost, openSettings: openSettings)
            } else {
                CaptureContentView(model: capture, preferences: preferences, translation: translation,
                    toggleTopmost: toggleTopmost, openSettings: openSettings, openGlossaries: openGlossaries, openEditor: openEditor)
            }
        }
        .environment(\.locale, AppLocalization.shared.locale)
    }
}

struct CaptureContentView: View {
    @Bindable var model: CaptureModel
    let preferences: PopupPreferences
    let translation: TranslationModel?
    let toggleTopmost: () -> Void
    let openSettings: () -> Void
    var openGlossaries: () -> Void = {}
    var openEditor: () -> Void = {}
    @State private var showsSource = false
    @State private var showsDetails = false
    @FocusState private var manualFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TranslationPopupToolbar(capture: model, preferences: preferences, translation: translation,
                showsSource: $showsSource, showsDetails: $showsDetails, toggleTopmost: toggleTopmost,
                openSettings: openSettings, openGlossaries: openGlossaries, openEditor: openEditor)
            Divider()
            if case .captured = model.state, let translation {
                PopupTranslationStatusView(model: translation, openSettings: openSettings) { showsDetails = true }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("captureScrollView")
            .id(translation?.documentID)
            if let translation, translation.pendingAction != nil {
                Divider()
                TranslationConfirmationView(model: translation)
                    .padding(12)
            }
        }
        .background(.background)
        .ignoresSafeArea(.container, edges: .top)
        .onChange(of: translation?.documentID) { resetDisclosure() }
        .onChange(of: model.state) {
            if model.state == .capturing || model.state == .manual { resetDisclosure() }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle:
            Text(L10n.text("capture.idle"))
        case .capturing:
            ProgressView(L10n.text("capture.working"))
        case .captured(let text):
            if let translation {
                if !translation.resultText.isEmpty {
                    Text(translation.resultText)
                        .font(.system(size: 17)).lineSpacing(6)
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("translationOutput")
                }
                if showsSource {
                    Divider()
                    Text(L10n.text("editor.source")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(translation.sourceText).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                }
                if showsDetails {
                    Divider()
                    TranslationStatusView(model: translation, openSettings: openSettings)
                    TranslationGlossaryDetailsView(model: translation)
                }
            } else { sourceText(text) }
        case .needsConfirmation(let text):
            sourceText(text)
            Text(L10n.text("capture.confirmHint")).font(.callout)
            Button(L10n.text("capture.confirm")) { model.confirmCopy() }
                .buttonStyle(.borderedProminent)
        case .failed(let failure):
            Label(L10n.text("capture.failed"), systemImage: "exclamationmark.circle")
                .font(.headline)
            Text(L10n.text("capture.error.\(failure.rawValue)"))
            if failure == .permissionRequired { AccessibilityPermissionView() }
            Button(L10n.text("capture.manual")) { model.beginManualEntry() }
        case .manual:
            Text(L10n.text("capture.manualHint")).font(.callout)
            TextEditor(text: $model.manualText)
                .font(.system(size: 15))
                .frame(minHeight: 140)
                .focused($manualFocused)
                .accessibilityLabel(L10n.text("capture.manual"))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(.separator))
                .onAppear { manualFocused = true }
            Button(L10n.text("capture.useManual")) { model.acceptManualText() }
                .buttonStyle(.borderedProminent)
                .disabled(model.manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func resetDisclosure() {
        showsSource = false
        showsDetails = false
    }

    private func sourceText(_ text: CapturedText) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text.source?.name ?? L10n.text("capture.manualSource"))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(text.text).font(.system(size: 16)).lineSpacing(5)
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }
}
