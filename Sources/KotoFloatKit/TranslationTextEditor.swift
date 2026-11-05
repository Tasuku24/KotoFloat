import AppKit
import SwiftUI

struct TranslationTextEditor: NSViewRepresentable {
    let text: String
    let editable: Bool
    let label: String
    let documentID: UUID
    let undoManager: UndoManager
    var backgroundColor: NSColor = .textBackgroundColor
    var fontSize: CGFloat = 17
    var help: String?
    var review: TranslationReviewModel?
    var side: TranslationSide = .source
    var highlightRange: NSRange?
    var highlightedWord: NSRange?
    let onChange: (String, Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        let view = DocumentTextView()
        view.isRichText = false
        view.importsGraphics = false
        view.allowsUndo = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.font = .systemFont(ofSize: fontSize)
        view.textColor = .textColor
        view.backgroundColor = backgroundColor
        view.textContainerInset = NSSize(width: 24, height: 18)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 8
        paragraph.paragraphSpacing = 16
        view.defaultParagraphStyle = paragraph
        view.typingAttributes[.paragraphStyle] = paragraph
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        view.delegate = context.coordinator
        scroll.documentView = view
        updateNSView(scroll, context: context)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? DocumentTextView else { return }
        scroll.backgroundColor = backgroundColor
        view.backgroundColor = backgroundColor
        view.documentUndoManager = undoManager
        view.isEditable = editable
        view.isSelectable = true
        view.canReview = review?.isAvailable == true
        view.onInspect = { [weak review] location in review?.inspect(side: side, at: location) }
        view.setAccessibilityLabel(label)
        view.setAccessibilityHelp(help)
        let newDocument = context.coordinator.documentID != documentID
        if newDocument || view.string != text {
            let selection = view.selectedRange()
            // A new document must also discard an in-progress input-method composition.
            // 新しい文書に切り替える場合は、入力メソッドの変換途中の文字列も破棄する。
            if newDocument { view.unmarkText() }
            view.string = text
            let length = (text as NSString).length
            let location = newDocument ? 0 : min(selection.location, length)
            view.setSelectedRange(NSRange(location: location, length: newDocument ? 0 : min(selection.length, length - location)))
        }
        context.coordinator.documentID = documentID
        view.showHighlight(highlightRange, word: highlightedWord, reveal: review?.selectedSide != side)
        view.setAccessibilityCustomActions(view.canReview ? [NSAccessibilityCustomAction(name: L10n.text("review.action"),
            target: view, selector: #selector(DocumentTextView.reviewSelection(_:)))] : [])
        if side == .target, let review { context.coordinator.popover.update(in: view, review: review) }
    }

    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) { coordinator.popover.close() }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TranslationTextEditor
        var documentID: UUID?
        let popover = TranslationAlternativesPopover()
        init(_ parent: TranslationTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.onChange(view.string, view.hasMarkedText())
        }
    }
}

final class DocumentTextView: NSTextView {
    weak var documentUndoManager: UndoManager?
    var canReview = false
    var onInspect: ((Int) -> Void)?
    private var highlightedSentence: NSRange?

    func showHighlight(_ range: NSRange?, word: NSRange?, reveal: Bool) {
        let full = NSRange(location: 0, length: (string as NSString).length)
        layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
        if let range, Range(range, in: string) != nil {
            layoutManager?.addTemporaryAttribute(.backgroundColor,
                value: NSColor.controlAccentColor.withAlphaComponent(0.14), forCharacterRange: range)
            if reveal, highlightedSentence != range { scrollRangeToVisible(range) }
        }
        if let word, Range(word, in: string) != nil {
            layoutManager?.addTemporaryAttribute(.backgroundColor,
                value: NSColor.controlAccentColor.withAlphaComponent(0.28), forCharacterRange: word)
        }
        highlightedSentence = range
    }

    override func mouseDown(with event: NSEvent) {
        let wasComposing = hasMarkedText()
        super.mouseDown(with: event)
        guard canReview, !wasComposing, !hasMarkedText(), event.clickCount == 1, selectedRange().length == 0,
              event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
              let layout = layoutManager, let container = textContainer else { return }
        let point = convert(event.locationInWindow, from: nil)
        let local = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        let glyph = layout.glyphIndex(for: local, in: container)
        guard glyph < layout.numberOfGlyphs,
              layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
                .insetBy(dx: -2, dy: -2).contains(local) else { return }
        onInspect?(layout.characterIndexForGlyph(at: glyph))
    }

    @objc func reviewSelection(_ sender: Any?) -> Bool {
        guard canReview, !hasMarkedText(), selectedRange().location < (string as NSString).length else { return false }
        onInspect?(selectedRange().location)
        return true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event)
        if canReview {
            if let existing = menu?.items.first(where: { $0.action == #selector(reviewSelection(_:)) }) {
                existing.title = L10n.text("review.action")
            } else {
                let action = NSMenuItem(title: L10n.text("review.action"), action: #selector(reviewSelection(_:)), keyEquivalent: "")
                action.target = self
                menu?.addItem(.separator())
                menu?.addItem(action)
            }
        }
        return menu
    }
    // AppKit still registers text-coalescing actions when allowsUndo is false. Keep those
    // away from the model's explicitly grouped history; the actions below route Undo/Redo.
    // allowsUndoがfalseでもAppKitは入力結合用の操作を登録するため、明示グループの
    // モデル履歴とは分離する。Undo/Redoは下のアクションでモデルへ渡す。
    override var undoManager: UndoManager? { nil }

    @objc func undo(_ sender: Any?) { documentUndoManager?.undo() }
    @objc func redo(_ sender: Any?) { documentUndoManager?.redo() }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(undo(_:)) { return documentUndoManager?.canUndo == true }
        if item.action == #selector(redo(_:)) { return documentUndoManager?.canRedo == true }
        if item.action == #selector(reviewSelection(_:)) { return canReview && !hasMarkedText() }
        return super.validateUserInterfaceItem(item)
    }
}
