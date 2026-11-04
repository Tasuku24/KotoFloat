import AppKit
import Testing
@testable import KotoFloatKit

@MainActor struct PopupCloseShortcutTests {
    @Test func onlyCommandWIsRecognizedAsTheCloseShortcut() throws {
        for modifiers: NSEvent.ModifierFlags in [.command, [.command, .shift], [.command, .option], [.command, .control], [], .option] {
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                timestamp: 0, windowNumber: 0, context: nil, characters: "w", charactersIgnoringModifiers: "w",
                isARepeat: false, keyCode: 13))
            #expect(PopupWindowFactory.isCloseShortcut(event) == (modifiers == .command))
        }
        let other = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: 0, windowNumber: 0, context: nil, characters: "q", charactersIgnoringModifiers: "q",
            isARepeat: false, keyCode: 12))
        #expect(!PopupWindowFactory.isCloseShortcut(other))
    }
}
