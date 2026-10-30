import Foundation
import Observation

@MainActor @Observable
final class CaptureModel {
    enum State: Equatable {
        case idle, capturing
        case captured(CapturedText)
        case needsConfirmation(CapturedText)
        case failed(CaptureFailure)
        case manual
    }
    private(set) var state: State = .idle {
        didSet { onStateChange?(state) }
    }
    @ObservationIgnored var onStateChange: (@MainActor (State) -> Void)?
    var showsSample = true
    var manualText = ""
    var hasUnsentWork: Bool { !manualText.isEmpty }
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()

    func start(using capture: SelectionCapture, completion: @escaping @MainActor () -> Void) {
        cancel()
        let id = requestID
        showsSample = false
        state = .capturing
        task = Task { [weak self] in
            do {
                let text = try await capture.capture()
                guard let self, requestID == id, !Task.isCancelled else { return }
                state = text.method == .copy ? .needsConfirmation(text) : .captured(text)
            } catch {
                guard let self, requestID == id, !Task.isCancelled else { return }
                state = .failed(error as? CaptureFailure ?? .copyFailed)
            }
            completion()
        }
    }
    func cancel() {
        requestID = UUID()
        task?.cancel()
        task = nil
        if state == .capturing { state = .idle }
    }
    func beginManualEntry() {
        cancel()
        showsSample = false
        state = .manual
    }
    func acceptManualText() {
        guard !manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        cancel()
        state = .captured(CapturedText(text: manualText, source: nil, bounds: nil, method: .manual))
        manualText = ""
    }
    func confirmCopy() {
        if case .needsConfirmation(let text) = state { state = .captured(text) }
    }
}
