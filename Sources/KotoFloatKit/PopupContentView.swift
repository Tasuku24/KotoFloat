import SwiftUI

struct PopupContentView: View {
    let preferences: PopupPreferences
    let sample: SampleContent
    let toggleTopmost: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label(L10n.text("sample.badge"), systemImage: "text.bubble")
                    .font(.subheadline.weight(.semibold))
                Text(L10n.text("sample.languages"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button {
                    toggleTopmost()
                } label: {
                    Image(systemName: preferences.alwaysOnTop ? "pin.fill" : "pin")
                        .foregroundStyle(preferences.alwaysOnTop ? Color.accentColor : .secondary)
                }
                .help(L10n.text("settings.topmost"))
                .accessibilityLabel(L10n.text("settings.topmost"))
                .accessibilityValue(L10n.text(preferences.alwaysOnTop ? "state.on" : "state.off"))
                Button { openSettings() } label: {
                    Image(systemName: "gearshape")
                }
                .help(L10n.text("menu.settings"))
                .accessibilityLabel(L10n.text("menu.settings"))
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 18).padding(.vertical, 12)

            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    textSection(title: "sample.source", text: sample.source, isTranslation: false)
                    Divider()
                    textSection(title: "sample.translation", text: sample.translation, isTranslation: true)
                    Text(L10n.text("sample.notice"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("sampleScrollView")

            Divider()
            HStack {
                Button(L10n.text(sample.isLong ? "sample.short" : "sample.long")) {
                    sample.isLong.toggle()
                }
                .controlSize(.small)
                Spacer()
                Text(L10n.text("sample.escapeHint"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
        }
        .background(.background)
    }

    private func textSection(title: String, text: String, isTranslation: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text(title)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: isTranslation ? 17 : 14))
                .lineSpacing(isTranslation ? 6 : 4)
                .foregroundStyle(isTranslation ? .primary : .secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
