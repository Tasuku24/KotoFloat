import SwiftUI

struct PopupRootView: View {
    let preferences: PopupPreferences
    let sample: SampleContent
    let capture: CaptureModel
    let translation: TranslationModel?
    let toggleTopmost: () -> Void
    let openSettings: () -> Void
    var openGlossaries: () -> Void = {}

    var body: some View {
        Group {
            if capture.showsSample {
                PopupContentView(preferences: preferences, sample: sample,
                    toggleTopmost: toggleTopmost, openSettings: openSettings)
            } else {
                CaptureContentView(model: capture, preferences: preferences, translation: translation,
                    toggleTopmost: toggleTopmost, openSettings: openSettings, openGlossaries: openGlossaries)
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
    @FocusState private var manualFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label(L10n.text("capture.title"), systemImage: "text.viewfinder")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Button(action: toggleTopmost) {
                    Image(systemName: preferences.alwaysOnTop ? "pin.fill" : "pin")
                }
                .accessibilityLabel(L10n.text("settings.topmost"))
                .accessibilityValue(L10n.text(preferences.alwaysOnTop ? "state.on" : "state.off"))
                .help(L10n.text("settings.topmost"))
                Button(action: openSettings) { Image(systemName: "gearshape") }
                    .accessibilityLabel(L10n.text("menu.settings"))
                    .help(L10n.text("menu.settings"))
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 18).padding(.vertical, 12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("captureScrollView")
            Divider()
            VStack(spacing: 10) {
                if case .captured = model.state, let translation {
                    TranslationActionsView(model: translation)
                }
                HStack {
                    if model.state != .manual {
                        Button(L10n.text("capture.manual")) { model.beginManualEntry() }
                            .controlSize(.small)
                    }
                    Spacer()
                    Text(L10n.text("sample.escapeHint")).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
        }
        .background(.background)
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle:
            Text(L10n.text("capture.idle"))
        case .capturing:
            ProgressView(L10n.text("capture.working"))
        case .captured(let text):
            sourceText(text)
            Divider()
            if let translation { TranslationContentView(model: translation, openSettings: openSettings, openGlossaries: openGlossaries) }
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

    private func sourceText(_ text: CapturedText) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text.source?.name ?? L10n.text("capture.manualSource"))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(text.text).font(.system(size: 16)).lineSpacing(5)
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }
}
