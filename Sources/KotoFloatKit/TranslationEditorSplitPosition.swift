import AppKit
import SwiftUI

struct TranslationEditorSplitPosition: NSViewRepresentable {
    func makeNSView(context: Context) -> EditorSplitPositionView { EditorSplitPositionView() }
    func updateNSView(_ view: EditorSplitPositionView, context: Context) {}
}

final class EditorSplitPositionView: NSView {
    private weak var positionedSplit: NSSplitView?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in self?.positionDivider() }
    }

    override func layout() {
        super.layout()
        positionDivider()
    }

    private func positionDivider() {
        var ancestor = superview
        while let view = ancestor {
            if let split = view as? NSSplitView {
                guard positionedSplit !== split, split.arrangedSubviews.count == 2, split.bounds.width > 0 else { return }
                positionedSplit = split
                // Set the initial balance once; AppKit owns subsequent dragging and resizing.
                // 初期の比率だけを設定し、その後のドラッグやリサイズはAppKitに任せる。
                DispatchQueue.main.async { [weak self, weak split] in
                    guard let self, let split, window != nil else { return }
                    split.setPosition(max(260, min(split.bounds.width * 0.36, split.bounds.width - 360)),
                        ofDividerAt: 0)
                }
                return
            }
            ancestor = view.superview
        }
    }
}
