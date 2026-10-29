import Foundation
import Testing
@testable import KotoFloatKit

@MainActor struct CopyRequestGateTests {
    @Test func successiveRequestsNeverOverlapClipboardTransactions() async throws {
        let gate = CopyRequestGate()
        var order: [String] = []
        var releaseFirst: CheckedContinuation<Void, Never>?
        let first = Task {
            try await gate.run {
                order.append("first start")
                await withCheckedContinuation { releaseFirst = $0 }
                order.append("first end")
            }
        }
        for _ in 0..<10 { await Task.yield() }
        let release = try #require(releaseFirst)
        let second = Task { try await gate.run { order.append("second") } }
        try await Task.sleep(for: .milliseconds(30))
        #expect(order == ["first start"])
        release.resume()
        try await first.value
        try await second.value
        #expect(order == ["first start", "first end", "second"])
    }
}
