import SwiftUI

struct PopupContentView: View {
    let preferences: PopupPreferences
    let sample: SampleContent
    let toggleTopmost: () -> Void
    let openSettings: () -> Void
    @State private var showsSource = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            PopupToolbar {
                Text(TranslationLanguage.japanese.title).foregroundStyle(.secondary)
                Button {
                    NSPasteboard.general.clearContents()
                    copied = NSPasteboard.general.setString(sample.translation, forType: .string)
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc").frame(width: 26, height: 28)
                }
                .help(L10n.text(copied ? "translation.copied" : "translation.copy"))
                .accessibilityLabel(L10n.text(copied ? "translation.copied" : "translation.copy"))
                Menu {
                    Button(L10n.text(sample.isLong ? "sample.short" : "sample.long")) { sample.isLong.toggle() }
                    Toggle(L10n.text("popup.showSource"), isOn: $showsSource)
                    Toggle(L10n.text("settings.topmost"), isOn: Binding(
                        get: { preferences.alwaysOnTop },
                        set: { if $0 != preferences.alwaysOnTop { toggleTopmost() } }))
                    Button(L10n.text("menu.settings"), action: openSettings)
                } label: {
                    Image(systemName: "ellipsis").frame(width: 26, height: 28)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help(L10n.text("popup.more"))
                .accessibilityLabel(L10n.text("popup.more"))
            }

            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(sample.translation).font(.system(size: 17)).lineSpacing(6)
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    if showsSource {
                        Divider()
                        textSection(title: "sample.source", text: sample.source, isTranslation: false)
                    }
                    Text(L10n.text("sample.notice"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("sampleScrollView")

        }
        .background(.background)
        .ignoresSafeArea(.container, edges: .top)
        .onChange(of: sample.isLong) { copied = false }
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
