import Testing
@testable import KotoFloatKit

struct SourceLineBreaksTests {
    @Test(arguments: [
        ("The first line of a PDF\ncontinues below.\n\nA new paragraph.",
         "The first line of a PDF continues below.\n\nA new paragraph."),
        ("This text is an example of\r\nPDF text copied with hard wraps,\r\n even between clauses.\r\n\r\nNext paragraph.",
         "This text is an example of PDF text copied with hard wraps, even between clauses.\r\n\r\nNext paragraph."),
        ("PDFから選択した文章の途中に\n改行が入っています。\n段落の区切りは残ります。",
         "PDFから選択した文章の途中に改行が入っています。\n段落の区切りは残ります。"),
        ("这是从PDF中复制的\n一段文字。\n下一段文字。", "这是从PDF中复制的一段文字。\n下一段文字。"),
        ("It's a multi-\npage docu\u{00AD}\nment.", "It's a multi-page document."),
        ("The copied passage\ncontinues here.\n1. First item\n2. Second item",
         "The copied passage continues here.\n1. First item\n2. Second item"),
        ("この箇所で文章の途中に\n改行が入ります\n（１）最初の項目\n（２）次の項目",
         "この箇所で文章の途中に改行が入ります\n（１）最初の項目\n（２）次の項目")
    ])
    func joinsWrappedLines(_ example: (original: String, expected: String)) {
        #expect(SourceLineBreaks.reflow(example.original) == example.expected)
        #expect(SourceLineBreaks.reflow(example.expected) == nil)
    }

    @Test(arguments: [
        "A single line.", "\n\n  \n", "Heading\nThis paragraph starts below the heading.",
        "He said, ‘That’s all.’\nThen he left.", "One paragraph\n\nanother paragraph",
        "One paragraph\u{2029}another paragraph", "Heading\n• First item\n• Second item",
        "概要\n本書には使い方を記載しています。", "研究背景\n以下是这个研究的背景。",
        "Line above a new paragraph\n  the indented paragraph starts here."
    ])
    func leavesIntentionalBreaksAlone(_ text: String) {
        #expect(SourceLineBreaks.reflow(text) == nil)
    }

    @MainActor @Test func fixingASelectionReplacesTheActiveRequestWithReflowedSource() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            let capture = CaptureModel()
            model.bind(to: capture)
            let environment = CaptureEnvironmentStub()
            let original = "The selected text\ncontinues below."
            environment.selection = .selected(original, nil)
            capture.start(using: SelectionCapture(environment: environment), completion: {})
            await waitFor { await service.count == 1 }
            #expect(model.canFixLineBreaks)
            #expect(await service.inputs.first?.text == original)

            model.fixLineBreaksAndTranslate()
            #expect(model.sourceText == "The selected text continues below.")
            #expect(model.sourceApplicationName == environment.source?.name)
            #expect(!model.canFixLineBreaks)
            model.fixLineBreaksAndTranslate()
            await waitFor { await service.count == 2 }
            #expect(await service.inputs.map(\.text) == [original, model.sourceText])
            await service.emit("Obsolete result", at: 0)
            await service.finish(at: 0)
            await service.emit("Current result", at: 1)
            await service.finish(at: 1)
            await waitFor { model.state == .completed }
            #expect(model.resultText == "Current result")
        }
    }

    @MainActor @Test func fixingLineBreaksRetranslatesAnEditedResultImmediately() async throws {
        try await withTranslationContext { preferences, credentials in
            let service = ControlledTranslator()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            let original = "An editable\ntranslation source."
            model.start(text: CapturedText(text: original, source: nil, bounds: nil, method: .manual))
            await waitFor { await service.count == 1 }
            await service.emit("Generated result", at: 0)
            await service.finish(at: 0)
            await waitFor { model.state == .completed }
            model.editTranslation("Edited result")

            model.fixLineBreaksAndTranslate()
            #expect(!model.canFixLineBreaks)
            #expect(model.sourceText == "An editable translation source.")
            #expect(model.state == .running)
            #expect(!model.hasEdits)
            await waitFor { await service.count == 2 }
            #expect(await service.inputs.last?.text == "An editable translation source.")
            await service.emit("Updated result", at: 1)
            await service.finish(at: 1)
            await waitFor { model.state == .completed }
        }
    }
}
