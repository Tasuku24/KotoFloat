import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    let controller: PopupController

    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder(for: .showSamplePopup) {
                    Text(L10n.text("settings.shortcut"))
                }
                Text(L10n.text("settings.shortcutHint"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L10n.text("settings.popup")) {
                Toggle(L10n.text("settings.topmost"), isOn: Binding(
                    get: { controller.preferences.alwaysOnTop },
                    set: { controller.setAlwaysOnTop($0) }))
                Picker(L10n.text("settings.position"), selection: Binding(
                    get: { controller.preferences.placement },
                    set: { controller.preferences.placement = $0 })) {
                    Text(L10n.text("settings.previous")).tag(PopupPlacement.previousPosition)
                    Text(L10n.text("settings.pointer")).tag(PopupPlacement.nearPointer)
                }
                Text(L10n.text("settings.positionHint"))
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(L10n.text("menu.showSample")) { controller.showSample() }
                    Button(L10n.text("settings.resetPosition")) { controller.resetPosition() }
                }
            }
            Section(L10n.text("settings.focus")) {
                Picker(L10n.text("settings.focusMode"), selection: Binding(
                    get: { controller.preferences.focusMode },
                    set: { controller.setFocusMode($0) })) {
                    Text(L10n.text("settings.standard")).tag(PopupFocusMode.standard)
                    Text(L10n.text("settings.autoRaise")).tag(PopupFocusMode.autoRaiseCompatible)
                }
                Text(L10n.text("settings.compatibilityHint"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text(L10n.text("settings.focusHint"))
                Text(L10n.text("sample.notice"))
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 540)
    }
}

extension KeyboardShortcuts.Name {
    static let showSamplePopup = Self("showSamplePopup", default: .init(.t, modifiers: [.control, .option, .command]))
}
