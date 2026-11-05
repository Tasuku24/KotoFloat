import AppKit
import Testing
@testable import KotoFloatKit

@MainActor struct TranslationReviewModelTests {
    @Test func inspectionHighlightsBothPassagesAndCachesTheSameWord() async throws {
        try await withReview { model, service in
            let location = (model.resultText as NSString).range(of: "useful").location
            model.review.inspect(side: .target, at: location)
            await waitFor { await service.reviewCount == 1 }
            #expect(model.review.phase == .loading)
            #expect(model.review.sourceHighlight == nil)
            await service.answerReview(0)
            await waitFor { model.review.phase == .ready }
            let source = try #require(model.review.sourceHighlight)
            let target = try #require(model.review.targetHighlight)
            #expect((model.sourceText as NSString).substring(with: source) == "便利な道具です。")
            #expect((model.resultText as NSString).substring(with: target) == "This is a useful tool.")
            #expect(model.review.alternatives == ["helpful", "practical"])
            let before = model.resultText
            model.review.dismissAlternatives()
            model.review.inspect(side: .target, at: location)
            #expect(model.review.phase == .ready)
            #expect(await service.reviewCount == 1)
            #expect(model.resultText == before)
        }
    }

    @Test func choosingAnAlternativeRewritesOnlyTheMatchedSentenceAndUndoRestoresIt() async throws {
        try await withReview { model, service in
            let before = model.resultText
            model.review.inspect(side: .target, at: (before as NSString).range(of: "useful").location)
            await waitFor { await service.reviewCount == 1 }
            await service.answerReview(0)
            await waitFor { model.review.phase == .ready }
            model.review.choose("helpful")
            await waitFor { await service.rewriteCount == 1 }
            #expect(model.resultText == before)
            #expect(model.review.phase == .rewriting)
            await service.answerRewrite(0, text: "This tool is helpful.")
            await waitFor { model.resultText != before }
            #expect(model.resultText == "This tool is helpful.\n\nKeep this sentence.")
            #expect(model.hasEdits)
            #expect(!model.review.showsAlternatives)
            #expect(model.canUndo)
            let pasteboard = NSPasteboard(name: .init("KotoFloatReviewCopy.\(UUID())"))
            defer { pasteboard.releaseGlobally() }
            #expect(model.copyResult(to: pasteboard))
            #expect(pasteboard.string(forType: .string) == model.resultText)
            model.undoManager.undo()
            #expect(model.resultText == before)
            #expect(model.review.targetHighlight == nil)
            model.undoManager.redo()
            #expect(model.resultText == "This tool is helpful.\n\nKeep this sentence.")
            model.review.inspect(side: .target, at: 5)
            await waitFor { await service.reviewCount == 2 }
        }
    }

    @Test func lateInspectionCannotReplaceTheSelectionFromANewerClick() async throws {
        try await withReview { model, service in
            model.review.inspect(side: .target, at: 10)
            await waitFor { await service.reviewCount == 1 }
            model.review.inspect(side: .target, at: (model.resultText as NSString).range(of: "Keep").location)
            await waitFor { await service.reviewCount == 2 }
            await service.answerReview(1, source: [1], target: [1], alternatives: ["Retain"])
            await waitFor { model.review.phase == .ready }
            await service.answerReview(0)
            try await Task.sleep(for: .milliseconds(10))
            #expect(model.review.selectedWord == "Keep")
            #expect(model.review.alternatives == ["Retain"])
            let range = try #require(model.review.targetHighlight)
            #expect((model.resultText as NSString).substring(with: range) == "Keep this sentence.")
        }
    }

    @Test(arguments: ["edit", "language", "settings", "newDocument", "dismiss", "confirmation"])
    func pendingRewriteCannotOverwriteChangedOrDismissedWork(_ change: String) async throws {
        try await withReview { model, service in
            model.review.inspect(side: .target, at: 10)
            await waitFor { await service.reviewCount == 1 }
            await service.answerReview(0)
            await waitFor { model.review.phase == .ready }
            model.review.choose("helpful")
            await waitFor { await service.rewriteCount == 1 }
            switch change {
            case "edit": model.editTranslation("Keep my manual edit.")
            case "language": model.preferences.targetLanguage = .french
            case "settings":
                try model.preferences.save(try ServerConfiguration(endpoint: "https://other.fixture.invalid", model: "new-model"),
                    tokenUpdate: .keep, credentials: MemoryCredentials())
            case "newDocument": model.cancel(clear: true)
            case "confirmation": model.clearDocument()
            default: model.review.dismissAlternatives()
            }
            let before = model.resultText
            await service.answerRewrite(0, text: "A helpful tool.")
            try await Task.sleep(for: .milliseconds(10))
            #expect(model.resultText == before)
            #expect(!model.canUndo || change == "edit")
        }
    }

    @Test func invalidMappingAndFailedRewriteNeverChangeTheResult() async throws {
        try await withReview { model, service in
            let before = model.resultText
            model.review.inspect(side: .target, at: 10)
            await waitFor { await service.reviewCount == 1 }
            await service.answerReview(0, source: [99], target: [0])
            await waitFor { model.review.failure != nil }
            #expect(model.review.sourceHighlight == nil)
            #expect(model.resultText == before)
            model.review.inspect(side: .target, at: 10)
            await waitFor { await service.reviewCount == 2 }
            await service.answerReview(1)
            await waitFor { model.review.phase == .ready }
            model.review.choose("not a candidate")
            #expect(await service.rewriteCount == 0)
            model.review.choose("helpful")
            await waitFor { await service.rewriteCount == 1 }
            await service.answerRewrite(0, text: "Wrong output without the chosen word.")
            await waitFor { model.review.failure != nil }
            #expect(model.resultText == before)
            #expect(!model.canUndo)
        }
    }

    @Test func sourceClickAndUnmatchedResponseDoNotInventCounterparts() async throws {
        try await withReview { model, service in
            model.review.inspect(side: .source, at: 0)
            await waitFor { await service.reviewCount == 1 }
            #expect(!model.review.showsAlternatives)
            await service.answerReview(0, source: [], target: [], alternatives: [])
            await waitFor { model.review.phase == .unmatched }
            #expect(model.review.sourceHighlight != nil)
            #expect(model.review.targetHighlight == nil)
            #expect(!model.canUndo)
        }
    }

    @Test func reviewDoesNotSendForUntranslatedOrChangedSourceText() async throws {
        try await withReview { model, service in
            model.editSource("Changed source")
            model.review.inspect(side: .source, at: 0)
            #expect(!model.review.isAvailable)
            #expect(await service.reviewCount == 0)
            model.cancel(clear: true)
            model.review.inspect(side: .target, at: 0)
            #expect(await service.reviewCount == 0)
        }
    }

    private func withReview(_ body: (TranslationModel, ReviewService) async throws -> Void) async throws {
        try await withTranslationContext { preferences, credentials in
            preferences.targetLanguage = .english
            let service = ReviewService()
            let model = TranslationModel(preferences: preferences, credentials: credentials, clientFactory: { _, _ in service })
            model.start(text: CapturedText(text: "便利な道具です。\n\nこの文は変更しません。", source: nil, bounds: nil, method: .manual))
            await waitFor { model.state == .completed }
            do { try await body(model, service) }
            catch { model.cancel(); await service.finishAll(); throw error }
            model.cancel()
            await service.finishAll()
        }
    }
}

actor ReviewService: TranslationServing {
    private let translation: String
    init(translation: String = "This is a useful tool.\n\nKeep this sentence.") { self.translation = translation }
    private var reviews: [CheckedContinuation<TranslationReviewReply, any Error>?] = []
    private var rewrites: [CheckedContinuation<String, any Error>?] = []
    var reviewCount: Int { reviews.count }
    var rewriteCount: Int { rewrites.count }
    func models() async throws -> [String] { ["fixture-model"] }
    func translate(_ input: TranslationInput, onText: @escaping @Sendable (String) async -> Void) async throws {
        await onText(translation)
    }
    func review(_ input: TranslationReviewRequest) async throws -> TranslationReviewReply {
        try await withCheckedThrowingContinuation { reviews.append($0) }
    }
    func rewrite(_ input: TranslationRewriteRequest) async throws -> String {
        try await withCheckedThrowingContinuation { rewrites.append($0) }
    }
    func answerReview(_ index: Int, source: [Int] = [0], target: [Int] = [0], alternatives: [String] = ["helpful", "practical"]) {
        guard reviews.indices.contains(index), let continuation = reviews[index] else { return }
        reviews[index] = nil
        continuation.resume(returning: TranslationReviewReply(source_sentence_ids: source, target_sentence_ids: target, alternatives: alternatives))
    }
    func answerRewrite(_ index: Int, text: String) {
        guard rewrites.indices.contains(index), let continuation = rewrites[index] else { return }
        rewrites[index] = nil
        continuation.resume(returning: text)
    }
    func finishAll() {
        for index in reviews.indices {
            reviews[index]?.resume(throwing: CancellationError())
            reviews[index] = nil
        }
        for index in rewrites.indices {
            rewrites[index]?.resume(throwing: CancellationError())
            rewrites[index] = nil
        }
    }
}
