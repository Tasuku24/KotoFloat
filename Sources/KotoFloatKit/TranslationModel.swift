import Foundation
import Observation

@MainActor @Observable final class TranslationModel {
    enum State: Equatable { case idle, needsConfiguration, running, completed, cancelled, failed(TranslationFailure) }
    private(set) var state = State.idle
    private(set) var output = ""
    private(set) var input: TranslationInput?
    let preferences: TranslationPreferences
    @ObservationIgnored private let credentials: any CredentialStore
    @ObservationIgnored private let clientFactory: @MainActor (ServerConfiguration, String?) -> any TranslationServing
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var capturedText: CapturedText?
    @ObservationIgnored private var configuration: ServerConfiguration?
    @ObservationIgnored private var configurationRevision = 0

    init(preferences: TranslationPreferences, credentials: any CredentialStore,
         clientFactory: @escaping @MainActor (ServerConfiguration, String?) -> any TranslationServing = { OpenAITranslationClient(server: $0, token: $1) }) {
        self.preferences = preferences
        self.credentials = credentials
        self.clientFactory = clientFactory
    }

    func start(text: CapturedText, force: Bool = false) {
        let next = TranslationInput(text: text.text, source: preferences.sourceLanguage, target: preferences.targetLanguage)
        if !force, state == .running, input == next, configuration == preferences.server,
           configurationRevision == preferences.revision { return }
        cancel(clear: true)
        capturedText = text
        input = next
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
                try await client.translate(next) { [weak self] part in
                    await self?.receive(part, request: id)
                }
                guard let self, requestID == id, !Task.isCancelled else { return }
                state = output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .failed(.emptyResponse) : .completed
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
