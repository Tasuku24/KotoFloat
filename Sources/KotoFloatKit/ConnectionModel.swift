import Foundation
import Observation

@MainActor @Observable final class ConnectionModel {
    enum Status: Equatable { case idle, saved, checking, connected(Int), trialRunning, trialComplete, cancelled, failed(TranslationFailure) }
    let preferences: TranslationPreferences
    var endpoint: String { didSet { edited() } }
    var modelName: String { didSet { edited() } }
    var allowHTTP: Bool { didSet { edited() } }
    var tokenInput = "" { didSet { edited() } }
    var removeSavedToken = false { didSet { edited() } }
    private(set) var status = Status.idle
    private(set) var availableModels: [String] = []
    private(set) var trialOutput = ""
    @ObservationIgnored private let credentials: any CredentialStore
    @ObservationIgnored private let clientFactory: @MainActor (ServerConfiguration, String?) -> any TranslationServing
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()
    var isBusy: Bool { status == .checking || status == .trialRunning }
    init(preferences: TranslationPreferences, credentials: any CredentialStore,
         clientFactory: @escaping @MainActor (ServerConfiguration, String?) -> any TranslationServing = { OpenAITranslationClient(server: $0, token: $1) }) {
        self.preferences = preferences
        self.credentials = credentials
        self.clientFactory = clientFactory
        endpoint = preferences.server?.baseURL.absoluteString ?? ""
        modelName = preferences.server?.model ?? ""
        allowHTTP = preferences.server?.allowHTTP ?? false
    }

    deinit { task?.cancel() }

    func save() {
        invalidate()
        do {
            let server = try configuration()
            let update: TokenUpdate = removeSavedToken ? .remove : tokenInput.isEmpty ? .keep : .replace(tokenInput)
            try preferences.save(server, tokenUpdate: update, credentials: credentials)
            tokenInput = ""
            removeSavedToken = false
            status = .saved
        } catch { status = .failed(error as? TranslationFailure ?? .credentialsUnavailable) }
    }

    func checkConnection() {
        guard !isBusy else { return }
        invalidate()
        availableModels = []
        trialOutput = ""
        let client: any TranslationServing
        do { client = try currentClient() }
        catch { status = .failed(error as? TranslationFailure ?? .network); return }
        status = .checking
        let id = requestID
        task = Task { [weak self] in
            do {
                let models = try await client.models()
                guard let self, requestID == id, !Task.isCancelled else { return }
                availableModels = models
                status = .connected(models.count)
                task = nil
            } catch { self?.failed(error, request: id) }
        }
    }

    func tryTranslation() {
        guard !isBusy else { return }
        invalidate()
        trialOutput = ""
        let client: any TranslationServing
        do { client = try currentClient() }
        catch { status = .failed(error as? TranslationFailure ?? .network); return }
        status = .trialRunning
        let id = requestID
        let input = TranslationInput(text: "This is a translation connection test.", source: .english, target: preferences.targetLanguage)
        task = Task { [weak self] in
            do {
                try await client.translate(input) { [weak self] part in await self?.receive(part, request: id) }
                guard let self, requestID == id, !Task.isCancelled else { return }
                status = trialOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .failed(.emptyResponse) : .trialComplete
                task = nil
            } catch { self?.failed(error, request: id) }
        }
    }

    func cancel() {
        guard isBusy else { return }
        invalidate()
        status = .cancelled
    }

    private func configuration() throws -> ServerConfiguration {
        try ServerConfiguration(endpoint: endpoint, model: modelName, allowHTTP: allowHTTP)
    }
    private func currentClient() throws -> any TranslationServing {
        let server = try configuration()
        let token = removeSavedToken ? nil : tokenInput.isEmpty ? try credentials.token(for: server.baseURL.absoluteString) : tokenInput
        return clientFactory(server, token)
    }
    private func invalidate() {
        requestID = UUID()
        task?.cancel()
        task = nil
    }
    private func edited() {
        invalidate()
        status = .idle
        availableModels = []
        trialOutput = ""
    }
    private func receive(_ text: String, request id: UUID) {
        guard requestID == id, status == .trialRunning else { return }
        trialOutput += text
    }
    private func failed(_ error: Error, request id: UUID) {
        guard requestID == id, !Task.isCancelled else { return }
        status = .failed(error as? TranslationFailure ?? .network)
        task = nil
    }
}
