import AppKit
import Observation

@MainActor @Observable final class TranslationModel {
    enum State: Equatable { case idle, needsConfiguration, running, completed, cancelled, failed(TranslationFailure) }
    private(set) var state = State.idle
    private(set) var output = ""
    private(set) var input: TranslationInput?
    private(set) var sourceText = ""
    private(set) var editedOutput: String?
    private(set) var revision = 0
    private(set) var documentID = UUID()
    private(set) var pendingAction: PendingAction?
    @ObservationIgnored let undoManager = UndoManager()
    @ObservationIgnored private var pendingRevision = 0
    @ObservationIgnored private var pendingDirection: [TranslationLanguage] = []
    @ObservationIgnored private var pendingSettingsRevision = 0
    @ObservationIgnored private var pendingGlossaryRevision = 0

    enum PendingAction {
        case translate(CapturedText), clear, swap, restore(TranslationHistoryEntry)
        var messageKey: String {
            switch self {
            case .translate: "editor.confirm.replace"
            case .clear: "editor.confirm.clear"
            case .swap: "editor.confirm.swap"
            case .restore: "history.confirmRestore"
            }
        }
    }
    let preferences: TranslationPreferences
    let glossaries: GlossaryStore?
    let history: TranslationHistoryStore?
    @ObservationIgnored private var historyIdentity: (id: UUID, createdAt: Date)?
    @ObservationIgnored private var pendingContinuesHistory = false
    @ObservationIgnored private let credentials: any CredentialStore
    @ObservationIgnored private let clientFactory: @MainActor (ServerConfiguration, String?) -> any TranslationServing
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var automaticTranslationTask: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var capturedText: CapturedText?
    @ObservationIgnored private var configuration: ServerConfiguration?
    @ObservationIgnored private var configurationRevision = 0
    @ObservationIgnored lazy var review = TranslationReviewModel(document: self)
    private var glossaryRevision = 0

    init(preferences: TranslationPreferences, credentials: any CredentialStore, glossaries: GlossaryStore? = nil,
         history: TranslationHistoryStore? = nil,
         clientFactory: @escaping @MainActor (ServerConfiguration, String?) -> any TranslationServing = { OpenAITranslationClient(server: $0, token: $1) }) {
        self.preferences = preferences
        self.credentials = credentials
        self.glossaries = glossaries
        self.history = history
        self.clientFactory = clientFactory
        undoManager.groupsByEvent = false
        undoManager.levelsOfUndo = 100
    }

    deinit { task?.cancel(); automaticTranslationTask?.cancel() }

    var glossaryChanged: Bool { input != nil && glossaryRevision != (glossaries?.revision ?? 0) }

    var resultText: String { editedOutput ?? output }
    var sourceApplicationName: String? { capturedText?.source?.name }
    var hasEdits: Bool { editedOutput != nil }
    var sourceChanged: Bool { sourceText != (input?.text ?? "") }
    var directionChanged: Bool {
        guard let input else { return false }
        return input.source != preferences.sourceLanguage || input.target != preferences.targetLanguage
    }
    var hasUnsentWork: Bool {
        hasEdits || sourceChanged || (!sourceText.isEmpty && state != .completed && state != .running)
    }
    var canTranslate: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && sourceText.utf8.count <= 131_072
    }
    var canCopy: Bool { state == .completed && !resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var canSwapLanguages: Bool {
        canCopy && !sourceChanged && !directionChanged && preferences.sourceLanguage != .automatic &&
            preferences.sourceLanguage != preferences.targetLanguage
    }
    var missingGlossaryTerms: [GlossaryEntry] {
        state == .completed ? input?.glossary.missingTerms(in: resultText) ?? [] : []
    }
    var canUndo: Bool { _ = revision; return undoManager.canUndo }
    var canRedo: Bool { _ = revision; return undoManager.canRedo }

    var canReview: Bool {
        state == .completed && pendingAction == nil && !sourceChanged && !directionChanged && !glossaryChanged &&
            configuration == preferences.server && configurationRevision == preferences.revision &&
            !sourceText.isEmpty && !resultText.isEmpty && glossaries?.failure == nil
    }

    func reviewClient() throws -> any TranslationServing {
        guard canReview, let server = preferences.server else { throw TranslationFailure.requestRejected }
        do { return clientFactory(server, try credentials.token(for: server.baseURL.absoluteString)) }
        catch { throw TranslationFailure.credentialsUnavailable }
    }

    func editSource(_ text: String, isComposing: Bool = false) {
        cancelAutomaticTranslation()
        if text != sourceText {
            let previous = sourceText
            registerUndo { $0.editSource(previous) }
            cancel()
            sourceText = text
            didEdit()
        }
        guard !isComposing, canTranslate, !hasEdits, pendingAction == nil,
              sourceChanged || state != .completed else { return }
        let revision = revision
        let settingsRevision = preferences.revision
        let glossaryRevision = glossaries?.revision ?? 0
        let sourceLanguage = preferences.sourceLanguage
        let targetLanguage = preferences.targetLanguage
        automaticTranslationTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1)) }
            catch { return }
            guard let self, !Task.isCancelled, self.revision == revision,
                  preferences.revision == settingsRevision, (glossaries?.revision ?? 0) == glossaryRevision,
                  preferences.sourceLanguage == sourceLanguage, preferences.targetLanguage == targetLanguage,
                  pendingAction == nil, !hasEdits else { return }
            automaticTranslationTask = nil
            translateSource()
        }
    }

    private func cancelAutomaticTranslation() {
        automaticTranslationTask?.cancel()
        automaticTranslationTask = nil
    }

    func editTranslation(_ text: String) {
        guard state == .completed, text != resultText else { return }
        let previous = resultText
        registerUndo { $0.editTranslation(previous) }
        editedOutput = text == output ? nil : text
        didEdit()
        saveHistory()
    }

    private func registerUndo(_ action: @escaping @MainActor (TranslationModel) -> Void) {
        let grouping = !undoManager.isUndoing && !undoManager.isRedoing
        if grouping { undoManager.beginUndoGrouping() }
        undoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated { action(target) }
        }
        if grouping { undoManager.endUndoGrouping() }
    }

    private func didEdit() {
        cancelAutomaticTranslation()
        review.invalidate()
        revision += 1
        pendingAction = nil
    }

    @discardableResult func copyResult(to pasteboard: NSPasteboard) -> Bool {
        guard canCopy else { return false }
        pasteboard.clearContents()
        return pasteboard.setString(resultText, forType: .string)
    }

    func translateSource() {
        guard canTranslate else { return }
        let text = CapturedText(text: sourceText, source: capturedText?.source, bounds: nil, method: .manual)
        if hasEdits { requestConfirmation(.translate(text), continuingHistory: true) }
        else { beginTranslation(text: text, force: true, continuingHistory: true) }
    }

    // Explicit popup choices update and translate together; preference edits elsewhere do not send.
    // ポップアップの明示的な言語選択だけを再翻訳につなげ、他の設定変更では送信しない。
    func changePopupLanguages(source: TranslationLanguage? = nil, target: TranslationLanguage? = nil,
                              captureState: CaptureModel.State) {
        let previousSource = preferences.sourceLanguage
        let previousTarget = preferences.targetLanguage
        if let source { preferences.sourceLanguage = source }
        if let target { preferences.targetLanguage = target }
        guard previousSource != preferences.sourceLanguage || previousTarget != preferences.targetLanguage else { return }
        guard case .captured = captureState else { return }
        translateSource()
    }

    func start(text: CapturedText, force: Bool = false) {
        if hasUnsentWork { requestConfirmation(.translate(text)); return }
        beginTranslation(text: text, force: force)
    }

    func clearDocument() {
        guard !sourceText.isEmpty || !output.isEmpty else { return }
        requestConfirmation(.clear)
    }

    func swapLanguages() {
        guard canSwapLanguages else { return }
        requestConfirmation(.swap)
    }

    func keepEditing() { pendingAction = nil }

    private func requestConfirmation(_ action: PendingAction, continuingHistory: Bool = false) {
        cancelAutomaticTranslation()
        pendingAction = action
        pendingContinuesHistory = continuingHistory
        pendingRevision = revision
        pendingDirection = [preferences.sourceLanguage, preferences.targetLanguage]
        pendingSettingsRevision = preferences.revision
        pendingGlossaryRevision = glossaries?.revision ?? 0
    }

    func confirmPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        guard pendingRevision == revision,
              pendingDirection == [preferences.sourceLanguage, preferences.targetLanguage],
              pendingSettingsRevision == preferences.revision,
              pendingGlossaryRevision == (glossaries?.revision ?? 0) else { return }
        switch action {
        case .translate(let text): beginTranslation(text: text, force: true, continuingHistory: pendingContinuesHistory)
        case .clear: cancel(clear: true)
        case .swap:
            guard canSwapLanguages else { return }
            let text = resultText
            let oldSource = preferences.sourceLanguage
            preferences.sourceLanguage = preferences.targetLanguage
            preferences.targetLanguage = oldSource
            cancel(clear: true)
            sourceText = text
        case .restore(let entry): applyHistory(entry)
        }
    }

    private func beginTranslation(text: CapturedText, force: Bool, continuingHistory: Bool = false) {
        let next = TranslationInput(text: text.text, source: preferences.sourceLanguage, target: preferences.targetLanguage)
        if !force, state == .running, input?.text == next.text, input?.source == next.source, input?.target == next.target,
           configuration == preferences.server, configurationRevision == preferences.revision,
           glossaryRevision == (glossaries?.revision ?? 0) { return }
        let identity = continuingHistory ? historyIdentity : nil
        cancel(clear: true)
        historyIdentity = identity
        capturedText = text
        sourceText = text.text
        input = next
        glossaryRevision = glossaries?.revision ?? 0
        guard glossaries?.failure == nil else { state = .failed(.glossaryUnavailable); return }
        guard !text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.text.utf8.count <= 131_072 else { state = .failed(.requestRejected); return }
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
                task = nil
                saveHistory()
            } catch {
                guard let self, requestID == id, !Task.isCancelled else { return }
                state = error is CancellationError ? .cancelled : .failed(error as? TranslationFailure ?? .network)
                task = nil
            }
        }
    }

    func retranslate() {
        translateSource()
    }

    private func saveHistory() {
        guard state == .completed, let input, let history else { return }
        let now = Date()
        let create = historyIdentity == nil
        let identity = historyIdentity ?? (UUID(), now)
        historyIdentity = identity
        history.save(TranslationHistoryEntry(id: identity.id, source: input.text, translation: resultText,
            sourceLanguage: input.source, targetLanguage: input.target, createdAt: identity.createdAt,
            updatedAt: now), create: create)
    }

    func restoreHistory(_ entry: TranslationHistoryEntry) {
        guard (try? entry.validated()) != nil else { return }
        if hasUnsentWork || state == .running { requestConfirmation(.restore(entry)) }
        else { applyHistory(entry) }
    }

    private func applyHistory(_ entry: TranslationHistoryEntry) {
        cancel(clear: true)
        preferences.sourceLanguage = entry.sourceLanguage
        preferences.targetLanguage = entry.targetLanguage
        sourceText = entry.source
        output = entry.translation
        input = TranslationInput(text: entry.source, source: entry.sourceLanguage, target: entry.targetLanguage)
        configuration = preferences.server
        configurationRevision = preferences.revision
        glossaryRevision = glossaries?.revision ?? 0
        historyIdentity = (entry.id, entry.createdAt)
        state = .completed
    }

    func cancel(clear: Bool = false) {
        cancelAutomaticTranslation()
        review.invalidate()
        requestID = UUID()
        task?.cancel()
        task = nil
        if clear {
            state = .idle
            output = ""
            input = nil
            capturedText = nil
            sourceText = ""
            editedOutput = nil
            historyIdentity = nil
            pendingAction = nil
            documentID = UUID()
            revision += 1
            undoManager.removeAllActions()
        } else if state == .running { state = .cancelled }
    }

    func bind(to capture: CaptureModel) {
        capture.onStateChange = { [weak self] state in
            // Capture navigation/cancellation does not own the shared translation lifecycle.
            // 取得画面の移動やキャンセルでは共有翻訳のライフサイクルを変更しない。
            if case .captured(let text) = state { self?.start(text: text) }
        }
    }

    private func receive(_ part: String, request id: UUID) {
        guard requestID == id, state == .running else { return }
        output += part
    }
}
