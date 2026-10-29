import Foundation
import Observation

@MainActor @Observable final class TranslationModel {
    enum State: Equatable { case idle, needsConfiguration, running, completed, cancelled, failed(TranslationFailure) }
    private(set) var state = State.idle
    private(set) var output = ""
    private(set) var input: TranslationInput?
    private(set) var missingGlossaryTerms: [GlossaryEntry] = []
    let preferences: TranslationPreferences
    let glossaries: GlossaryStore?
    @ObservationIgnored private let credentials: any CredentialStore
    @ObservationIgnored private let clientFactory: @MainActor (ServerConfiguration, String?) -> any TranslationServing
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var capturedText: CapturedText?
    @ObservationIgnored private var configuration: ServerConfiguration?
    @ObservationIgnored private var configurationRevision = 0
    private var glossaryRevision = 0

    init(preferences: TranslationPreferences, credentials: any CredentialStore, glossaries: GlossaryStore? = nil,
         clientFactory: @escaping @MainActor (ServerConfiguration, String?) -> any TranslationServing = { OpenAITranslationClient(server: $0, token: $1) }) {
        self.preferences = preferences
        self.credentials = credentials
        self.glossaries = glossaries
        self.clientFactory = clientFactory
    }

    deinit { task?.cancel() }

    var glossaryChanged: Bool { input != nil && glossaryRevision != (glossaries?.revision ?? 0) }

    func start(text: CapturedText, force: Bool = false) {
        let next = TranslationInput(text: text.text, source: preferences.sourceLanguage, target: preferences.targetLanguage)
        if !force, state == .running, input?.text == next.text, input?.source == next.source, input?.target == next.target,
           configuration == preferences.server, configurationRevision == preferences.revision,
           glossaryRevision == (glossaries?.revision ?? 0) { return }
        cancel(clear: true)
        capturedText = text
        input = next
        glossaryRevision = glossaries?.revision ?? 0
        guard glossaries?.failure == nil else { state = .failed(.glossaryUnavailable); return }
        guard text.text.utf8.count <= 131_072 else { state = .failed(.requestRejected); return }
        let glossary = glossaries?.activeGlossary
        guard let server = preferences.server else { state = .needsConfiguration; return }
        configuration = server
        configurationRevision = preferences.revision
        let client: any TranslationServing
        do { client = clientFactory(server, try credentials.token(for: server.baseURL.absoluteString)) }
        catch { state = .failed(.credentialsUnavailable); return }
        state = .running
        let id = requestID
        task = Task { [weak self] in
            do {
                let matching = Task.detached(priority: .userInitiated) {
                    GlossaryMatcher.context(for: next.text, source: next.source, target: next.target, glossary: glossary)
                }
                let context = await withTaskCancellationHandler { await matching.value } onCancel: { matching.cancel() }
                guard let self, requestID == id, !Task.isCancelled else { return }
                let request = TranslationInput(text: next.text, source: next.source, target: next.target, glossary: context)
                input = request
                _ = try context.referenceData()
                try await client.translate(request) { [weak self] part in
                    await self?.receive(part, request: id)
                }
                guard requestID == id, !Task.isCancelled else { return }
                state = output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .failed(.emptyResponse) : .completed
                if state == .completed { missingGlossaryTerms = context.missingTerms(in: output) }
                task = nil
            } catch {
                guard let self, requestID == id, !Task.isCancelled else { return }
                state = error is CancellationError ? .cancelled : .failed(error as? TranslationFailure ?? .network)
                task = nil
            }
        }
    }

    func retranslate() {
        if let capturedText { start(text: capturedText, force: true) }
    }

    func cancel(clear: Bool = false) {
        requestID = UUID()
        task?.cancel()
        task = nil
        if clear {
            state = .idle
            output = ""
            input = nil
            missingGlossaryTerms = []
            capturedText = nil
        } else if state == .running { state = .cancelled }
    }

    func bind(to capture: CaptureModel) {
        capture.onStateChange = { [weak self] state in
            switch state {
            case .captured(let text): self?.start(text: text)
            case .capturing: break
            default: self?.cancel(clear: true)
            }
        }
    }

    private func receive(_ part: String, request id: UUID) {
        guard requestID == id, state == .running else { return }
        output += part
    }
}
