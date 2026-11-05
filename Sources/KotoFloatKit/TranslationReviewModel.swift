import Foundation
import Observation

@MainActor @Observable final class TranslationReviewModel {
    enum Phase: Equatable { case idle, loading, ready, unmatched, rewriting, failed(TranslationFailure) }
    private(set) var phase = Phase.idle
    private(set) var showsAlternatives = false
    private(set) var selectedWord = ""
    private(set) var selectedSide: TranslationSide?
    private(set) var alternatives: [String] = []
    @ObservationIgnored private weak var document: TranslationModel?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()
    private var activeSnapshot: Snapshot?
    private var context: TranslationReviewDocument?
    private var match: TranslationSentenceMatch?
    private var clickedSourceRange: NSRange?
    private var clickedTargetRange: NSRange?
    private var wordRange: NSRange?
    @ObservationIgnored private var cache: [TranslationReviewQuery: TranslationReviewReply] = [:]

    private struct Snapshot: Equatable {
        let documentID: UUID
        let revision: Int
        let settingsRevision: Int
        let glossaryRevision: Int
        let source: TranslationLanguage
        let target: TranslationLanguage
    }

    init(document: TranslationModel) { self.document = document }
    deinit { task?.cancel() }

    var isAvailable: Bool { document?.canReview == true }
    var isCurrent: Bool { activeSnapshot != nil && activeSnapshot == snapshot() }
    var isBusy: Bool { isCurrent && (phase == .loading || phase == .rewriting) }
    var sourceHighlight: NSRange? { isCurrent ? match?.sourceRange ?? clickedSourceRange : nil }
    var targetHighlight: NSRange? { isCurrent ? match?.targetRange ?? clickedTargetRange : nil }
    var targetWordRange: NSRange? { isCurrent ? wordRange : nil }
    var failure: TranslationFailure? {
        guard isCurrent, case .failed(let failure) = phase else { return nil }
        return failure
    }

    private func snapshot() -> Snapshot? {
        guard let document, document.canReview else { return nil }
        return Snapshot(documentID: document.documentID, revision: document.revision,
            settingsRevision: document.preferences.revision, glossaryRevision: document.glossaries?.revision ?? 0,
            source: document.preferences.sourceLanguage, target: document.preferences.targetLanguage)
    }

    func inspect(side: TranslationSide, at location: Int) {
        guard let document, let snapshot = snapshot() else { invalidate(); return }
        if activeSnapshot != snapshot {
            invalidate()
            activeSnapshot = snapshot
            context = TranslationReviewDocument(source: document.sourceText, target: document.resultText,
                sourceLanguage: document.preferences.sourceLanguage, targetLanguage: document.preferences.targetLanguage,
                glossary: document.input?.glossary ?? GlossaryContext())
        }
        guard let context, let query = context.query(side: side, at: location) else { dismissAlternatives(); return }
        stopRequest()
        selectedSide = side
        self.match = nil
        clickedSourceRange = side == .source ? context.sourceSentences[query.sentenceID].range : nil
        clickedTargetRange = side == .target ? context.targetSentences[query.sentenceID].range : nil
        wordRange = query.wordRange
        selectedWord = query.wordRange.flatMap { context.text(in: $0, side: .target) } ?? ""
        showsAlternatives = !selectedWord.isEmpty
        alternatives = []
        let request = TranslationReviewRequest(document: context, query: query)
        if let cached = cache[query] {
            accept(cached, for: request)
            return
        }
        // Reuse returned sentence IDs while another word's candidates load; semantic accuracy depends on the model.
        // 別の単語の候補を取得中は既存の対応IDを再利用する。意味の対応精度はモデルに依存する。
        if let cached = cache.first(where: { entry in
            query.side == .source ? entry.value.source_sentence_ids.contains(query.sentenceID)
                : entry.value.target_sentence_ids.contains(query.sentenceID)
        })?.value {
            match = try? cached.validated(for: request)
        }
        phase = .loading
        let id = requestID
        do {
            _ = try request.payload()
            let client = try document.reviewClient()
            task = Task { [weak self] in
                do {
                    let reply = try await client.review(request)
                    guard let self, requestID == id, activeSnapshot == snapshot, self.snapshot() == snapshot,
                          !Task.isCancelled else { return }
                    accept(reply, for: request)
                    if phase == .ready {
                        if cache.count >= 32 { cache.removeAll() }
                        cache[query] = reply
                    }
                    task = nil
                } catch { self?.fail(error, request: id, snapshot: snapshot) }
            }
        } catch { fail(error, request: id, snapshot: snapshot) }
    }

    private func accept(_ reply: TranslationReviewReply, for request: TranslationReviewRequest) {
        if reply.source_sentence_ids.isEmpty && reply.target_sentence_ids.isEmpty {
            match = nil
            alternatives = []
            phase = .unmatched
            return
        }
        do {
            let verified = try reply.validated(for: request)
            match = verified
            alternatives = verified.alternatives
            phase = reply.alternativesFailure.map(Phase.failed) ?? .ready
        } catch {
            match = nil
            alternatives = []
            phase = .failed(.malformedResponse)
        }
    }

    func choose(_ preferred: String) {
        guard let document, let snapshot = activeSnapshot, self.snapshot() == snapshot,
              phase == .ready, let context, let match, let wordRange, alternatives.contains(preferred), !selectedWord.isEmpty else { return }
        stopRequest()
        phase = .rewriting
        let id = requestID
        let request = TranslationRewriteRequest(document: context, match: match, originalWord: selectedWord, wordRange: wordRange, preferred: preferred)
        do {
            _ = try request.payload()
            let client = try document.reviewClient()
            task = Task { [weak self] in
                do {
                    let replacement = try request.validate(await client.rewrite(request))
                    guard let self, let document = self.document, requestID == id, self.snapshot() == snapshot,
                          !Task.isCancelled, let range = Range(match.targetRange, in: document.resultText) else { return }
                    let edited = document.resultText.replacingCharacters(in: range, with: replacement)
                    // Commit once after a complete validated reply; the existing edit path owns Undo.
                    // 応答全体の検証後に一度だけ反映し、既存の編集処理でUndoを管理する。
                    document.editTranslation(edited)
                    activeSnapshot = self.snapshot()
                    selectedSide = .target
                    self.context = TranslationReviewDocument(source: document.sourceText, target: edited,
                        sourceLanguage: document.preferences.sourceLanguage, targetLanguage: document.preferences.targetLanguage,
                        glossary: document.input?.glossary ?? GlossaryContext())
                    self.match = TranslationSentenceMatch(sourceRange: match.sourceRange,
                        targetRange: NSRange(location: match.targetRange.location, length: (replacement as NSString).length), alternatives: [])
                    phase = .ready
                    showsAlternatives = false
                    task = nil
                } catch { self?.fail(error, request: id, snapshot: snapshot) }
            }
        } catch { fail(error, request: id, snapshot: snapshot) }
    }

    func dismissAlternatives() {
        showsAlternatives = false
        if phase == .loading || phase == .rewriting { stopRequest(); phase = .idle }
    }

    func invalidate() {
        stopRequest()
        activeSnapshot = nil
        context = nil
        match = nil
        clickedSourceRange = nil
        clickedTargetRange = nil
        wordRange = nil
        selectedWord = ""
        selectedSide = nil
        alternatives = []
        showsAlternatives = false
        phase = .idle
        cache.removeAll()
    }

    private func stopRequest() {
        requestID = UUID()
        task?.cancel()
        task = nil
    }

    private func fail(_ error: Error, request id: UUID, snapshot: Snapshot) {
        guard requestID == id, self.snapshot() == snapshot else { return }
        phase = error is CancellationError ? .idle : .failed(error as? TranslationFailure ?? .network)
        task = nil
    }
}
