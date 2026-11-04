import Foundation
import CoreGraphics

struct SourceApplication: Equatable, Sendable {
    let processIdentifier: Int32
    let bundleIdentifier: String?
    let name: String
}

struct CapturedText: Equatable, Sendable {
    enum Method: Sendable { case accessibility, verifiedCopy, copy, clipboard, manual }
    let text: String
    let source: SourceApplication?
    let bounds: CGRect?
    let method: Method
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
    case appUnavailable, copyFailed, clipboardChanged, clipboardUnavailable, inputChanged, timedOut
}

@MainActor
protocol CaptureEnvironment: AnyObject {
    var isTrusted: Bool { get }
    func currentSource() -> SourceApplication?
    func readSelection(from source: SourceApplication) -> SelectionRead
    func copySelection(from source: SourceApplication) async throws -> String
    func readClipboardText() throws -> String?
}

@MainActor
struct SelectionCapture {
    let environment: any CaptureEnvironment

    func capture() async throws -> CapturedText {
        try Task.checkCancellation()
        guard environment.isTrusted else { throw CaptureFailure.permissionRequired }
        guard let source = environment.currentSource() else { throw CaptureFailure.noSource }
        let selection = environment.readSelection(from: source)
        guard environment.currentSource() == source else { throw CaptureFailure.sourceChanged }
        let text: String
        let bounds: CGRect?
        let method: CapturedText.Method
        switch selection {
        case .selected(let selected, let rectangle):
            guard !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return try clipboardFallback(from: source)
            }
            let formatted = try await formattedSelection(selected, from: source)
            text = formatted.text
            bounds = formatted.method == .copy ? nil : rectangle
            method = formatted.method
        case .empty: return try clipboardFallback(from: source)
        case .protectedField: throw CaptureFailure.protectedField
        case .failed(let failure): throw failure
        case .unavailable:
            do { text = try await environment.copySelection(from: source) }
            catch CaptureFailure.timedOut { return try clipboardFallback(from: source) }
            bounds = nil
            method = .copy
        }
        try Task.checkCancellation()
        guard environment.currentSource() == source else { throw CaptureFailure.sourceChanged }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return try clipboardFallback(from: source)
        }
        return CapturedText(text: text, source: source, bounds: bounds, method: method)
    }

    private func formattedSelection(_ selected: String, from source: SourceApplication) async throws
        -> (text: String, method: CapturedText.Method) {
        // Accessibility can concatenate rich-text paragraphs. Native copy preserves their separators.
        // Only whitespace-equivalent copies may bypass the existing copy confirmation.
        // アクセシビリティが連結してしまう段落の区切りを、標準コピーで保持する。
        // 空白以外が一致する場合だけ、既存のコピー確認を省略できる。
        do {
            let copied = try await environment.copySelection(from: source)
            guard !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return (selected, .accessibility)
            }
            if copied == selected { return (selected, .accessibility) }
            let sameContent = copied.filter { !$0.isWhitespace } == selected.filter { !$0.isWhitespace }
            return (copied, sameContent ? .verifiedCopy : .copy)
        } catch let failure as CaptureFailure where
            failure == .timedOut || failure == .copyFailed || failure == .clipboardUnavailable {
            return (selected, .accessibility)
        }
    }

    private func clipboardFallback(from source: SourceApplication) throws -> CapturedText {
        try Task.checkCancellation()
        guard environment.currentSource() == source else { throw CaptureFailure.sourceChanged }
        let text = try environment.readClipboardText()
        try Task.checkCancellation()
        guard environment.currentSource() == source else { throw CaptureFailure.sourceChanged }
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CaptureFailure.noSelection
        }
        // Existing clipboard text has no reliable source application or selection bounds.
        // 既存のクリップボードには、確実な取得元アプリや選択範囲の情報がない。
        return CapturedText(text: text, source: nil, bounds: nil, method: .clipboard)
    }
}
