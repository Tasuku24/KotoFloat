import Foundation

@MainActor
final class CopyRequestGate {
    private var isBusy = false

    func run<T>(_ operation: () async throws -> T) async throws -> T {
        while isBusy { try await Task.sleep(for: .milliseconds(10)) }
        try Task.checkCancellation()
        isBusy = true
        defer { isBusy = false }
        return try await operation()
    }
}
