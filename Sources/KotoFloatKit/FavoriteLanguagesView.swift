import AppKit
import SwiftUI

struct FavoriteLanguageBar: View {
    let preferences: TranslationPreferences
    var body: some View {
        if !preferences.favoriteLanguages.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(preferences.favoriteLanguages.enumerated()), id: \.element) { index, language in
                        Button {
                            preferences.targetLanguage = language
                        } label: {
                            HStack(spacing: 4) {
                                if preferences.targetLanguage == language { Image(systemName: "checkmark") }
                                Text(language.title)
                                Text("⌘\(index + 1)").foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel(String(format: L10n.text("language.favoriteSelect"), language.title, index + 1))
                        .accessibilityValue(preferences.targetLanguage == language ? L10n.text("language.selected") : "")
                    }
                }.padding(.vertical, 2)
            }
            .controlSize(.small)
            .background(FavoriteShortcutView(preferences: preferences).frame(width: 0, height: 0))
        }
    }
}

struct FavoriteLanguagesSettings: View {
    let preferences: TranslationPreferences
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("language.favorites")).font(.headline)
            ForEach(Array(preferences.favoriteLanguages.enumerated()), id: \.element) { index, language in
                HStack {
                    Text("⌘\(index + 1)  \(language.title)")
                    Spacer()
                    Button { move(index, by: -1) } label: { Image(systemName: "arrow.up") }
                        .disabled(index == 0)
                        .accessibilityLabel(String(format: L10n.text("language.moveUp"), language.title))
                    Button { move(index, by: 1) } label: { Image(systemName: "arrow.down") }
                        .disabled(index == preferences.favoriteLanguages.count - 1)
                        .accessibilityLabel(String(format: L10n.text("language.moveDown"), language.title))
                    Button { preferences.favoriteLanguages.remove(at: index) } label: { Image(systemName: "minus.circle") }
                        .accessibilityLabel(String(format: L10n.text("language.remove"), language.title))
                }
            }
            if preferences.favoriteLanguages.count < 5 {
                LanguagePicker(label: L10n.text("language.add"), selection: preferences.targetLanguage,
                    excluded: Set(preferences.favoriteLanguages), buttonTitle: L10n.text("language.add")) {
                        preferences.favoriteLanguages.append($0)
                    }.frame(height: 26)
            }
            Text(L10n.text("language.favoritesHint")).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }.controlSize(.small)
    }

    private func move(_ index: Int, by offset: Int) {
        preferences.favoriteLanguages.swapAt(index, index + offset)
    }
}

struct FavoriteShortcutView: NSViewRepresentable {
    let preferences: TranslationPreferences
    func makeNSView(context: Context) -> FavoriteShortcutControl { FavoriteShortcutControl(preferences: preferences) }
    func updateNSView(_ view: FavoriteShortcutControl, context: Context) { view.preferences = preferences }
    static func dismantleNSView(_ view: FavoriteShortcutControl, coordinator: ()) { view.stopMonitoring() }
}

@MainActor final class FavoriteShortcutControl: NSView {
    var preferences: TranslationPreferences
    private var monitor: Any?
    init(preferences: TranslationPreferences) {
        self.preferences = preferences
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handle(event) == true }
            return handled ? nil : event
        }
    }
    func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    @discardableResult func handle(_ event: NSEvent) -> Bool {
        // Local events must belong to this key window; another app or a picker never qualifies.
        // このキーウィンドウ宛てのローカル入力だけを扱い、他アプリや言語選択画面では動作しない。
        guard let window, window.isKeyWindow, event.window === window,
              event.type == .keyDown,
              event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command,
              let characters = event.charactersIgnoringModifiers, let number = Int(characters),
              (1...5).contains(number), preferences.favoriteLanguages.indices.contains(number - 1) else { return false }
        if !event.isARepeat { preferences.targetLanguage = preferences.favoriteLanguages[number - 1] }
        return true
    }
}
