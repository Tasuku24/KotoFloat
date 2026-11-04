import AppKit
import SwiftUI
import Testing
@testable import KotoFloatKit

extension PopupControllerTests {
    @Test(arguments: [CGFloat(360), 480])
    func popupLoadingCompletionKeepsBodyAndLanguageControlInPlace(_ width: CGFloat) async throws {
        try await withTranslationContext { preferences, credentials in
            _ = NSApplication.shared
            let name = "KotoFloatLoadingLayoutTests.\(UUID())"
            let defaults = try #require(UserDefaults(suiteName: name))
            defer { defaults.removePersistentDomain(forName: name) }
            let capture = CaptureModel()
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            model.bind(to: capture)
            let window = PopupWindowFactory.make(mode: .standard)
            let host = NSHostingView(rootView: CaptureContentView(model: capture,
                preferences: PopupPreferences(defaults: defaults), translation: model,
                toggleTopmost: {}, openSettings: {}))
            host.sizingOptions = []
            window.contentView = host
            window.setContentSize(CGSize(width: width, height: 400))
            defer { window.close(); model.cancel() }
            capture.beginManualEntry()
            capture.manualText = "Synthetic source"
            capture.acceptManualText()
            await waitFor { await service.count == 1 }
            await service.emit("A short translated result.", at: 0)
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            let scroll = try #require(loadingDescendants(host).compactMap { $0 as? NSScrollView }.first)
            let picker = try #require(loadingDescendants(host).compactMap { $0 as? NSButton }.first {
                $0.accessibilityLabel() == L10n.text("translation.to")
            })
            let bodyFrame = scroll.convert(scroll.bounds, to: host)
            let pickerFrame = picker.convert(picker.bounds, to: host)
            await service.finish(at: 0)
            await waitFor { model.state == .completed }
            try await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            #expect(scroll.convert(scroll.bounds, to: host) == bodyFrame)
            #expect(picker.convert(picker.bounds, to: host) == pickerFrame)
            #expect(host.bounds.contains(pickerFrame))
            #expect(!window.isVisible)
        }
    }

    private func loadingDescendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(loadingDescendants)
    }
}
