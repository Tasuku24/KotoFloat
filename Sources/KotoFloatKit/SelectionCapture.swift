import Foundation
import CoreGraphics

struct SourceApplication: Equatable, Sendable {
    let processIdentifier: Int32
    let bundleIdentifier: String?
    let name: String
}

struct CapturedText: Equatable, Sendable {
    enum Method: Sendable { case accessibility, copy, clipboard, manual }
    let text: String
    let source: SourceApplication?
    let bounds: CGRect?
    let method: Method
    let clipboardAge: TimeInterval?

    init(text: String, source: SourceApplication?, bounds: CGRect?, method: Method, clipboardAge: TimeInterval? = nil) {
        self.text = text
        self.source = source
        self.bounds = bounds
        self.method = method
        self.clipboardAge = clipboardAge
    }

    var requiresConfirmation: Bool {
        guard method == .clipboard else { return false }
        guard let clipboardAge else { return true }
        return !(0...300).contains(clipboardAge)
    }
}

enum SelectionRead: Equatable {
    case selected(String, CGRect?)
    case empty
    case protectedField
    case unavailable
    case failed(CaptureFailure)
}

enum CaptureFailure: String, Error, Equatable {
    case permissionRequired, noSource, noSelection, protectedField, sourceChanged
    case appUnavailable, copyFailed, clipboardChanged, clipboardUnavailable, clipboardReadNotAllowed, inputChanged, timedOut
}

@MainActor
protocol CaptureEnvironment: AnyObject {
    var isTrusted: Bool { get }
    func currentSource() -> SourceApplication?
    func readSelection(from source: SourceApplication) -> SelectionRead
    func copySelection(from source: SourceApplication) async throws -> String
    func readClipboardText() throws -> ClipboardText?
}

@MainActor
struct SelectionCapture {
    let environment: any CaptureEnvironment

    func capture() async throws -> CapturedText {
        try Task.checkCancellation()
        guard environment.isTrusted else { throw CaptureFailure.permissionRequired }
        guard let source = environment.currentSource() else { throw CaptureFailure.noSource }
        let selection = environment.readSelection(from: source)
        try Task.checkCancellation()
        guard environment.currentSource() == source else { throw CaptureFailure.sourceChanged }
        switch selection {
        case .selected(let selected, let rectangle):
            guard !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return try clipboardFallback(from: source)
            }
            return CapturedText(text: selected, source: source, bounds: rectangle, method: .accessibility)
        case .empty: return try clipboardFallback(from: source)
        case .protectedField: throw CaptureFailure.protectedField
        case .failed(let failure): throw failure
        case .unavailable:
            let text: String
            do { text = try await environment.copySelection(from: source) }
            catch CaptureFailure.timedOut { return try clipboardFallback(from: source) }
            try Task.checkCancellation()
            guard environment.currentSource() == source else { throw CaptureFailure.sourceChanged }
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return try clipboardFallback(from: source)
            }
            return CapturedText(text: text, source: source, bounds: nil, method: .copy)
        }
    }

    private func clipboardFallback(from source: SourceApplication) throws -> CapturedText {
        try Task.checkCancellation()
        guard environment.currentSource() == source else { throw CaptureFailure.sourceChanged }
        let clipboard = try environment.readClipboardText()
        try Task.checkCancellation()
        guard environment.currentSource() == source else { throw CaptureFailure.sourceChanged }
        guard let clipboard, !clipboard.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CaptureFailure.noSelection
        }
        // Existing clipboard text has no reliable source application or selection bounds.
        // 既存のクリップボードには、確実な取得元アプリや選択範囲の情報がない。
        return CapturedText(text: clipboard.text, source: nil, bounds: nil, method: .clipboard, clipboardAge: clipboard.age)
    }
}
