import AppKit
import SwiftUI

struct LanguagePicker: NSViewRepresentable {
    let label: String
    let selection: TranslationLanguage
    var includeAutomatic = false
    var excluded: Set<TranslationLanguage> = []
    var buttonTitle: String?
    let onSelect: (TranslationLanguage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "", target: context.coordinator, action: #selector(Coordinator.open(_:)))
        button.bezelStyle = .rounded
        button.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)
        button.imagePosition = .imageTrailing
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.picker = self
        button.title = buttonTitle ?? selection.title
        button.setAccessibilityLabel(label)
        button.setAccessibilityValue(selection.title)
        button.toolTip = label + ": " + selection.title
    }

    static func dismantleNSView(_ button: NSButton, coordinator: Coordinator) { coordinator.popover.close() }

    @MainActor final class Coordinator: NSObject {
        var picker: LanguagePicker?
        let popover = NSPopover()

        @objc func open(_ button: NSButton) {
            guard let picker else { return }
            if popover.isShown { popover.performClose(nil); return }
            let controller = LanguagePickerController(selection: picker.selection, includeAutomatic: picker.includeAutomatic,
                excluded: picker.excluded, onSelect: { [weak self] language in
                    self?.picker?.onSelect(language)
                    self?.popover.performClose(nil)
                }, onDismiss: { [weak self] in self?.popover.performClose(nil) })
            popover.contentViewController = controller
            popover.behavior = .transient
            popover.animates = false
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            controller.view.window?.makeFirstResponder(controller.searchField)
        }
    }
}

@MainActor final class LanguagePickerController: NSViewController, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    let searchField = NSSearchField()
    private let table = LanguageTableView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private let selection: TranslationLanguage
    private let includeAutomatic: Bool
    private let excluded: Set<TranslationLanguage>
    private let onSelect: (TranslationLanguage) -> Void
    private let onDismiss: () -> Void
    private(set) var results: [TranslationLanguage] = []

    init(selection: TranslationLanguage, includeAutomatic: Bool, excluded: Set<TranslationLanguage>,
         onSelect: @escaping (TranslationLanguage) -> Void, onDismiss: @escaping () -> Void) {
        self.selection = selection
        self.includeAutomatic = includeAutomatic
        self.excluded = excluded
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        searchField.placeholderString = L10n.text("language.search")
        searchField.setAccessibilityLabel(L10n.text("language.search"))
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        table.addTableColumn(NSTableColumn(identifier: .init("language")))
        table.headerView = nil
        table.rowHeight = 42
        table.allowsEmptySelection = false
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(clickedRow)
        table.onChoose = { [weak self] in self?.chooseSelection() }
        table.onDismiss = { [weak self] in self?.onDismiss() }
        table.setAccessibilityLabel(L10n.text("language.results"))
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        emptyLabel.stringValue = L10n.text("language.noResults")
        let hint = NSTextField(wrappingLabelWithString: L10n.text("language.modelHint"))
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [searchField, scroll, emptyLabel, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        for child in [searchField, scroll, emptyLabel, hint] {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true
        }
        scroll.heightAnchor.constraint(equalToConstant: 280).isActive = true
        view = stack
        preferredContentSize = CGSize(width: 360, height: 400)
        refreshResults()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let language = results[row]
        let check = language == selection ? "✓ " : ""
        let field = NSTextField(wrappingLabelWithString: check + language.title + "\n" + language.nativeName + " · " + language.rawValue)
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.setAccessibilityLabel(field.stringValue)
        return field
    }

    func controlTextDidChange(_ obj: Notification) { refreshResults() }

    private func refreshResults() {
        results = TranslationLanguage.search(searchField.stringValue, includeAutomatic: includeAutomatic).filter { !excluded.contains($0) }
        table.reloadData()
        emptyLabel.isHidden = !results.isEmpty
        if let index = results.firstIndex(of: selection) ?? results.indices.first {
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            table.scrollRowToVisible(index)
        } else { table.deselectAll(nil) }
    }

    func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        let index = min(max(table.selectedRow + offset, 0), results.count - 1)
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        table.scrollRowToVisible(index)
    }

    func chooseSelection() {
        guard results.indices.contains(table.selectedRow) else { return }
        onSelect(results[table.selectedRow])
    }

    @objc private func clickedRow() {
        guard table.clickedRow >= 0 else { return }
        chooseSelection()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Let the native input context consume IME candidate navigation first.
        // IME候補の操作は先にネイティブの入力コンテキストで処理する。
        guard !textView.hasMarkedText() else { return false }
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)): moveSelection(by: 1)
        case #selector(NSResponder.moveUp(_:)): moveSelection(by: -1)
        case #selector(NSResponder.insertNewline(_:)): chooseSelection()
        case #selector(NSResponder.cancelOperation(_:)): onDismiss()
        default: return false
        }
        return true
    }
}

@MainActor private final class LanguageTableView: NSTableView {
    var onChoose: (() -> Void)?
    var onDismiss: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            if event.keyCode == 36 || event.keyCode == 76 { onChoose?(); return }
            if event.keyCode == 53 { onDismiss?(); return }
        }
        super.keyDown(with: event)
    }
}
