import Foundation
import CoreGraphics

struct SourceApplication: Equatable, Sendable {
    let processIdentifier: Int32
    let bundleIdentifier: String?
    let name: String
}

struct CapturedText: Equatable, Sendable {
    enum Method: Sendable { case accessibility, copy, manual }
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
            text = selected
            bounds = rectangle
            method = .accessibility
        case .empty: throw CaptureFailure.noSelection
        case .protectedField: throw CaptureFailure.protectedField
        case .failed(let failure): throw failure
        case .unavailable:
            text = try await environment.copySelection(from: source)
            bounds = nil
            method = .copy
        }
        try Task.checkCancellation()
        guard environment.currentSource() == source else { throw CaptureFailure.sourceChanged }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CaptureFailure.noSelection
        }
        return CapturedText(text: text, source: source, bounds: bounds, method: method)
    }
}
