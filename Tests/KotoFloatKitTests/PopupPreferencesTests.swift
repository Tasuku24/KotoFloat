import Foundation
import CoreGraphics
import Testing
@testable import KotoFloatKit

@MainActor
struct PopupPreferencesTests {
    @Test func restoresPreferencesAcrossInstances() throws {
        let suite = "KotoFloatTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PopupPreferences(defaults: defaults)
        preferences.alwaysOnTop = false
        preferences.placement = .nearPointer
        preferences.focusMode = .autoRaiseCompatible
        preferences.savedFrame = CGRect(x: -700, y: 200, width: 500, height: 350)
        let restored = PopupPreferences(defaults: defaults)
        #expect(!restored.alwaysOnTop)
        #expect(restored.placement == .nearPointer)
        #expect(restored.focusMode == .autoRaiseCompatible)
        #expect(restored.savedFrame == CGRect(x: -700, y: 200, width: 500, height: 350))
    }

    @Test func rejectsCorruptOrInvalidFrames() throws {
        let suite = "KotoFloatTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("corrupt", forKey: "popup.frame.v1")
        defaults.set("unknown-placement", forKey: "popup.placement")
        let preferences = PopupPreferences(defaults: defaults)
        #expect(preferences.savedFrame == nil)
        #expect(preferences.placement == .previousPosition)
        preferences.savedFrame = CGRect(x: 0, y: 0, width: 500, height: 400)
        preferences.savedFrame = CGRect(x: CGFloat.infinity, y: 0, width: 500, height: 400)
        #expect(preferences.savedFrame == nil)
        #expect(PopupPreferences(defaults: defaults).savedFrame == nil)
    }

    @Test func resetFrameDoesNotResetOtherPreferences() throws {
        let suite = "KotoFloatTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PopupPreferences(defaults: defaults)
        preferences.alwaysOnTop = false
        preferences.savedFrame = CGRect(x: 10, y: 50, width: 500, height: 400)
        preferences.savedFrame = nil
        let restored = PopupPreferences(defaults: defaults)
        #expect(restored.savedFrame == nil)
        #expect(!restored.alwaysOnTop)
    }
}
