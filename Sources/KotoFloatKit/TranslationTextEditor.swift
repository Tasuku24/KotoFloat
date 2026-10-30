import AppKit
import SwiftUI

struct TranslationTextEditor: NSViewRepresentable {
    let text: String
    let editable: Bool
    let label: String
    let documentID: UUID
    let undoManager: UndoManager
    let onChange: (String) -> Void

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
        view.font = .systemFont(ofSize: 17)
        view.textColor = .textColor
        view.backgroundColor = .textBackgroundColor
        view.textContainerInset = NSSize(width: 12, height: 14)
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
        view.documentUndoManager = undoManager
        view.isEditable = editable
        view.isSelectable = true
        view.setAccessibilityLabel(label)
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
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TranslationTextEditor
        var documentID: UUID?
        init(_ parent: TranslationTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.onChange(view.string)
        }
    }
}

private final class DocumentTextView: NSTextView {
    weak var documentUndoManager: UndoManager?
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
        return super.validateUserInterfaceItem(item)
    }
}
