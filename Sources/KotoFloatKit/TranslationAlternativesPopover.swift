import AppKit

@MainActor final class TranslationAlternativesPopover: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private weak var review: TranslationReviewModel?
    private var presentation: Presentation?

    private struct Presentation: Equatable {
        let phase: TranslationReviewModel.Phase
        let word: String
        let alternatives: [String]
    }

    override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
    }

    func update(in view: NSTextView, review: TranslationReviewModel) {
        self.review = review
        guard review.showsAlternatives, review.isCurrent, let range = review.targetWordRange,
              Range(range, in: view.string) != nil, let window = view.window, window.isVisible,
              window.isKeyWindow || popover.isShown,
              let layout = view.layoutManager, let container = view.textContainer else { close(); return }
        let next = Presentation(phase: review.phase, word: review.selectedWord, alternatives: review.alternatives)
        if presentation != next {
            presentation = next
            let controller = NSViewController()
            controller.view = content(for: next)
            controller.view.layoutSubtreeIfNeeded()
            controller.preferredContentSize = controller.view.fittingSize
            popover.contentViewController = controller
            popover.contentSize = controller.preferredContentSize
        }
        let glyph = layout.glyphRange(forCharacterRange: NSRange(location: range.location, length: 1), actualCharacterRange: nil)
        let rect = layout.boundingRect(forGlyphRange: glyph, in: container)
            .offsetBy(dx: view.textContainerOrigin.x, dy: view.textContainerOrigin.y)
        if popover.isShown { popover.positioningRect = rect }
        else { popover.show(relativeTo: rect, of: view, preferredEdge: .maxY) }
    }

    private func content(for presentation: Presentation) -> NSView {
        let title = NSTextField(wrappingLabelWithString: presentation.word)
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.preferredMaxLayoutWidth = 256
        var views: [NSView] = [title]
        switch presentation.phase {
        case .loading, .rewriting:
            let indicator = NSProgressIndicator()
            indicator.style = .spinning
            indicator.controlSize = .small
            indicator.startAnimation(nil)
            let status = label(L10n.text(presentation.phase == .rewriting ? "review.rewriting" : "review.loading"))
            views.append(NSStackView(views: [indicator, status]))
        case .failed(let failure):
            views.append(label(L10n.text("review.failed") + " " + L10n.text("translation.error.\(failure.rawValue)")))
        case .unmatched:
            views.append(label(L10n.text("review.noMatch")))
        case .ready, .idle:
            if presentation.alternatives.isEmpty { views.append(label(L10n.text("review.noAlternatives"))) }
            for (index, alternative) in presentation.alternatives.enumerated() {
                let button = NSButton(title: alternative, target: self, action: #selector(choose(_:)))
                button.bezelStyle = .rounded
                button.alignment = .left
                button.font = .systemFont(ofSize: 14)
                button.lineBreakMode = .byTruncatingTail
                button.tag = index
                button.toolTip = alternative + " — " + L10n.text("review.applyHint")
                button.setAccessibilityHelp(L10n.text("review.applyHint"))
                views.append(button)
            }
        }
        let close = NSButton(title: L10n.text("review.close"), target: self, action: #selector(dismiss(_:)))
        close.bezelStyle = .rounded
        close.keyEquivalent = "\u{1b}"
        close.keyEquivalentModifierMask = []
        views.append(close)
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        stack.setHuggingPriority(.required, for: .vertical)
        stack.widthAnchor.constraint(equalToConstant: 280).isActive = true
        for view in views { view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true }
        return stack
    }

    private func label(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.preferredMaxLayoutWidth = 256
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    @objc private func choose(_ sender: NSButton) {
        guard let review, review.alternatives.indices.contains(sender.tag) else { return }
        review.choose(review.alternatives[sender.tag])
    }

    @objc private func dismiss(_ sender: Any?) { close() }
    func close() { if popover.isShown { popover.performClose(nil) } }
    func popoverDidClose(_ notification: Notification) {
        if review?.showsAlternatives == true { review?.dismissAlternatives() }
        popover.contentViewController = nil
        presentation = nil
    }
}
