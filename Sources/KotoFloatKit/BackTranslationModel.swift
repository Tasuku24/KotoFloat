import Foundation
import Observation

@MainActor @Observable final class BackTranslationModel {
    enum State: Equatable { case idle, running, completed, failed(TranslationFailure) }
    private(set) var state = State.idle
    private(set) var targetLanguage: TranslationLanguage?
    private var output = ""
    @ObservationIgnored private weak var document: TranslationModel?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()
    private var activeSnapshot: Snapshot?

    private struct Snapshot: Equatable {
        let documentID: UUID
        let revision: Int
        let settingsRevision: Int
        let glossaryRevision: Int
    }

    init(document: TranslationModel) { self.document = document }
    deinit { task?.cancel() }

    var isCurrent: Bool { activeSnapshot != nil && activeSnapshot == snapshot() }
    var resultText: String { isCurrent ? output : "" }
    var needsLanguage: Bool { isCurrent && targetLanguage == nil }

    private func snapshot() -> Snapshot? {
        guard let document, document.canReview else { return nil }
        return Snapshot(documentID: document.documentID, revision: document.revision,
            settingsRevision: document.preferences.revision, glossaryRevision: document.glossaries?.revision ?? 0)
    }

    func start(language: TranslationLanguage? = nil) {
        invalidate()
        guard let document, let snapshot = snapshot(), let input = document.input else { return }
        activeSnapshot = snapshot
        targetLanguage = language ?? (input.source == .automatic ? TranslationLanguage.detect(in: document.sourceText) : input.source)
        guard let targetLanguage else { return }
        guard targetLanguage != .automatic else { state = .failed(.requestRejected); return }
        // Only the displayed translation goes back to the server; the original must not bias the check.
        // 確認結果が原文に引きずられないよう、表示中の訳文だけをサーバーへ送信する。
        let request = TranslationInput(text: document.resultText, source: input.target, target: targetLanguage)
        let id = requestID
        do {
            let client = try document.reviewClient()
            state = .running
            task = Task { [weak self] in
                do {
                    try await client.translate(request) { [weak self] part in
                        await self?.receive(part, request: id, snapshot: snapshot)
                    }
                    guard let self, requestID == id, self.snapshot() == snapshot,
                          state == .running, !Task.isCancelled else { return }
                    state = output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .failed(.emptyResponse) : .completed
                    task = nil
                } catch {
                    guard let self, requestID == id, self.snapshot() == snapshot, state == .running else { return }
                    output = ""
                    state = .failed(error as? TranslationFailure ?? .network)
                    task = nil
                }
            }
        } catch { state = .failed(error as? TranslationFailure ?? .network) }
    }

    private func receive(_ part: String, request id: UUID, snapshot: Snapshot) {
        guard requestID == id, self.snapshot() == snapshot, state == .running else { return }
        guard output.utf8.count + part.utf8.count <= 131_072 else {
            output = ""
            state = .failed(.outputTooLarge)
            task?.cancel()
            task = nil
            return
        }
        output += part
    }

    func invalidate() {
        requestID = UUID()
        task?.cancel()
        task = nil
        activeSnapshot = nil
        targetLanguage = nil
        output = ""
        state = .idle
    }

}
