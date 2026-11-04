import AppKit
import Testing
@testable import KotoFloatKit

@MainActor struct ApplicationMenuTests {
    @Test func commandWUsesTheNativeCloseAction() throws {
        let delegate = KotoFloatDelegate()
        let items = delegate.makeAppMenu().items.flatMap { $0.submenu?.items ?? [] }
        let close = try #require(items.first { $0.keyEquivalent == "w" })
        #expect(close.keyEquivalentModifierMask == .command)
        #expect(close.action == #selector(NSWindow.performClose(_:)))
        #expect(close.target == nil)
    }

    @Test func commandQBackgroundsAndOptionCommandQExplicitlyQuitsInBothMenus() throws {
        let delegate = KotoFloatDelegate()
        let appMenu = try #require(delegate.makeAppMenu().items.first?.submenu)
        for menu in [appMenu, delegate.makeStatusMenu()] {
            let background = try #require(menu.items.first {
                $0.keyEquivalent == "q" && $0.keyEquivalentModifierMask == .command
            })
            #expect(background.target === delegate)
            #expect(background.action == NSSelectorFromString("moveToBackground"))
            let quit = try #require(menu.items.first {
                $0.keyEquivalent == "q" && $0.keyEquivalentModifierMask == [.command, .option]
            })
            #expect(quit.action == #selector(NSApplication.terminate(_:)))
            #expect(quit.target == nil)
        }
        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
    }
}
