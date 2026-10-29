import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    static let contentSize = CGSize(width: 600, height: 520)

    private enum Tab: String, CaseIterable {
        case general, popup, capture, connection, translation
        @MainActor var title: String { L10n.text("settings.tab.\(rawValue)") }
    }

    let controller: PopupController
    let connection: ConnectionModel
    @State private var selectedTab = Tab.general

    var body: some View {
        VStack(spacing: 18) {
            Picker(L10n.text("settings.tabs"), selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("settingsTabs")

            VStack(alignment: .leading, spacing: 16) {
                switch selectedTab {
                case .general: generalSettings
                case .popup: popupSettings
                case .capture: captureSettings
                case .connection: ConnectionSettingsView(model: connection)
                case .translation:
                    settingsGroup("translation.direction") {
                        TranslationDirectionView(preferences: connection.preferences)
                    }
                    note("translation.privacy")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .frame(width: Self.contentSize.width, height: Self.contentSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, AppLocalization.shared.locale)
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsGroup("settings.languageGroup") {
                Picker(L10n.text("settings.language"), selection: Binding(
                    get: { AppLocalization.shared.language },
                    set: { AppLocalization.shared.language = $0 })) {
                    Text(L10n.text("settings.language.system")).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.english)
                    Text("日本語").tag(AppLanguage.japanese)
                }
                note("settings.languageHint")
            }
            settingsGroup("settings.shortcutGroup") {
                HStack {
                    Text(L10n.text("settings.shortcut"))
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .showSamplePopup)
                }
                note("settings.shortcutHint")
            }
            settingsGroup("settings.actions") {
                HStack {
                    Button(L10n.text("menu.showSample")) { controller.showSample() }
                    Button(L10n.text("capture.manual")) { controller.showManualEntry() }
                }
                note("translation.privacy")
            }
        }
    }

    private var popupSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsGroup("settings.popup") {
                Toggle(L10n.text("settings.topmost"), isOn: Binding(
                    get: { controller.preferences.alwaysOnTop },
                    set: { controller.setAlwaysOnTop($0) }))
                Picker(L10n.text("settings.position"), selection: Binding(
                    get: { controller.preferences.placement },
                    set: { controller.preferences.placement = $0 })) {
                    Text(L10n.text("settings.previous")).tag(PopupPlacement.previousPosition)
                    Text(L10n.text("settings.pointer")).tag(PopupPlacement.nearPointer)
                    Text(L10n.text("settings.selection")).tag(PopupPlacement.nearSelection)
                }
                note("settings.positionHint")
                Button(L10n.text("settings.resetPosition")) { controller.resetPosition() }
            }
            settingsGroup("settings.focus") {
                Picker(L10n.text("settings.focusMode"), selection: Binding(
                    get: { controller.preferences.focusMode },
                    set: { controller.setFocusMode($0) })) {
                    Text(L10n.text("settings.standard")).tag(PopupFocusMode.standard)
                    Text(L10n.text("settings.autoRaise")).tag(PopupFocusMode.autoRaiseCompatible)
                }
                note("settings.compatibilityHint")
            }
            note("settings.focusHint")
        }
    }

    private var captureSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsGroup("permission.title") {
                AccessibilityPermissionView()
                Divider()
                Button(L10n.text("capture.manual")) { controller.showManualEntry() }
            }
            note("translation.privacy")
        }
    }

    private func settingsGroup<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        } label: {
            Text(L10n.text(key)).font(.headline)
        }
    }

    private func note(_ key: String) -> some View {
        Text(L10n.text(key)).font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension KeyboardShortcuts.Name {
    static let showSamplePopup = Self("showSamplePopup", default: .init(.t, modifiers: [.control, .option, .command]))
}
