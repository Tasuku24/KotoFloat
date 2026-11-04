import AppKit
import Testing
@testable import KotoFloatKit

@MainActor struct LanguagePickerTests {
    @Test(arguments: [false, true])
    func footerHasOnlyStandardInsetWithAndWithoutSearchResults(includeAutomatic: Bool) throws {
        let picker = LanguagePickerController(selection: .japanese, includeAutomatic: includeAutomatic, excluded: [],
            onSelect: { _ in }, onDismiss: {})
        picker.loadViewIfNeeded()
        let stack = try #require(picker.view as? NSStackView)
        let hint = try #require(stack.arrangedSubviews.last as? NSTextField)
        for query in ["", "not-a-language", "ja"] {
            picker.searchField.stringValue = query
            picker.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
            stack.setFrameSize(picker.preferredContentSize)
            stack.layoutSubtreeIfNeeded()
            let bottomInset = stack.isFlipped ? stack.bounds.maxY - hint.frame.maxY : hint.frame.minY - stack.bounds.minY
            #expect(abs(bottomInset - 12) <= 1, "query: \(query), preferred: \(picker.preferredContentSize), hint: \(hint.frame)")
            #expect(hint.frame.height >= hint.fittingSize.height)
        }
    }

    @Test func favoritesLeadUnfilteredListWithoutDuplicatesOrExcludedLanguages() {
        let picker = LanguagePickerController(selection: .japanese, includeAutomatic: false, excluded: [.english],
            favoriteLanguages: [.french, .japanese, .french, .automatic, .english],
            onSelect: { _ in }, onDismiss: {})
        picker.loadViewIfNeeded()
        #expect(Array(picker.results.prefix(2)) == [.french, .japanese])
        #expect(picker.results.count == 24)
        #expect(!picker.results.contains(.english))
        #expect(!picker.results.contains(.automatic))
        picker.searchField.stringValue = "pt"
        picker.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        #expect(picker.results == [.portugueseBrazil, .portuguesePortugal])
        picker.searchField.stringValue = "  "
        picker.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        #expect(Array(picker.results.prefix(2)) == [.french, .japanese])
    }

    @Test func searchNavigationAndSelectionNeverSubmitUntilReturn() {
        var selected: TranslationLanguage?
        let picker = LanguagePickerController(selection: .japanese, includeAutomatic: false, excluded: [],
            onSelect: { selected = $0 }, onDismiss: {})
        picker.loadViewIfNeeded()
        picker.searchField.stringValue = "pt"
        picker.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        #expect(picker.results == [.portugueseBrazil, .portuguesePortugal])
        #expect(selected == nil)
        picker.moveSelection(by: 1)
        picker.chooseSelection()
        #expect(selected == .portuguesePortugal)
        picker.searchField.stringValue = "not-a-language"
        picker.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        picker.moveSelection(by: 1)
        picker.chooseSelection()
        #expect(selected == .portuguesePortugal)
        picker.searchField.stringValue = "日本語"
        picker.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        #expect(picker.results == [.japanese])
        picker.chooseSelection()
        #expect(selected == .japanese)
    }

    @Test func escapeDismissesWithoutSelectingAndFavoriteAddExcludesExistingLanguages() {
        var dismissed = false
        var selected: TranslationLanguage?
        let picker = LanguagePickerController(selection: .japanese, includeAutomatic: false, excluded: [.japanese, .english],
            onSelect: { selected = $0 }, onDismiss: { dismissed = true })
        picker.loadViewIfNeeded()
        #expect(!picker.results.contains(.automatic))
        #expect(!picker.results.contains(.japanese))
        #expect(picker.control(picker.searchField, textView: NSTextView(), doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        #expect(dismissed)
        #expect(selected == nil)
    }
    @Test func markedTextKeepsCandidateCommandsWithTheNativeInputContext() {
        var dismissed = false
        let picker = LanguagePickerController(selection: .japanese, includeAutomatic: true, excluded: [],
            onSelect: { _ in }, onDismiss: { dismissed = true })
        picker.loadViewIfNeeded()
        let editor = NSTextView()
        editor.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(!picker.control(picker.searchField, textView: editor, doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        #expect(!dismissed)
    }

}
