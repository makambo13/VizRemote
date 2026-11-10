import Foundation
// This file is compiled into both the macOS and iOS test bundles, each of which links
// only its own host app module — `canImport` picks the right one per target.
#if canImport(VizRemote)
@testable import VizRemote
#else
@testable import VizRemoteiOS
#endif

/// A scripted `TVDiscovery` for deterministic tests — no real sockets, no timing
/// flakiness. Yields the given TVs after `delayNanoseconds`, then finishes.
final class FakeTVDiscovery: TVDiscovery {
    let tvsToYield: [DiscoveredTV]
    let delayNanoseconds: UInt64

    init(tvsToYield: [DiscoveredTV] = [], delayNanoseconds: UInt64 = 0) {
        self.tvsToYield = tvsToYield
        self.delayNanoseconds = delayNanoseconds
    }

    func search(timeout: TimeInterval) -> AsyncStream<DiscoveredTV> {
        AsyncStream { continuation in
            Task {
                if delayNanoseconds > 0 {
                    try? await Task.sleep(nanoseconds: delayNanoseconds)
                }
                for tv in tvsToYield {
                    continuation.yield(tv)
                }
                continuation.finish()
            }
        }
    }
}

/// A `TVDiscovery` that never finishes on its own — for testing that a superseding
/// search cancels a stuck one, or that UI doesn't hang waiting for it.
final class NeverFinishingDiscovery: TVDiscovery {
    func search(timeout: TimeInterval) -> AsyncStream<DiscoveredTV> {
        AsyncStream { _ in /* never yields, never finishes */ }
    }
}

/// A `SmartCastClient` wrapper that counts calls and can delay/fail on demand — for
/// exercising re-entrancy guards (double-tap Connect/Pair) deterministically.
final class ControllableSmartCastClient: SmartCastClient {
    let host: String
    var startPairingCallCount = 0
    var finishPairingCallCount = 0
    var startPairingDelayNanoseconds: UInt64 = 0
    var startPairingResult: Result<PairingChallenge, Error> = .success(PairingChallenge(token: 1, challengeType: 1))
    var finishPairingResult: Result<String, Error> = .success("fake-token")
    private let inner: FakeSmartCastClient

    init(host: String = "192.0.2.42") {
        self.host = host
        self.inner = FakeSmartCastClient(host: host)
    }

    func startPairing() async throws -> PairingChallenge {
        startPairingCallCount += 1
        if startPairingDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: startPairingDelayNanoseconds)
        }
        return try startPairingResult.get()
    }

    func finishPairing(pin: String, challenge: PairingChallenge) async throws -> String {
        finishPairingCallCount += 1
        return try finishPairingResult.get()
    }

    func send(_ key: RemoteKey) async throws { try await inner.send(key) }
    func powerState() async throws -> Bool { try await inner.powerState() }
    func volume() async throws -> Int { try await inner.volume() }
    func setVolume(_ value: Int) async throws { try await inner.setVolume(value) }
    func setMuted(_ muted: Bool) async throws { try await inner.setMuted(muted) }
    func currentInput() async throws -> InputSource { try await inner.currentInput() }
    func inputs() async throws -> [InputSource] { try await inner.inputs() }
    func selectInput(_ input: InputSource) async throws { try await inner.selectInput(input) }
    func launchApp(appID: String, nameSpace: Int) async throws { try await inner.launchApp(appID: appID, nameSpace: nameSpace) }
}

struct StubError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Each test gets its own throwaway `UserDefaults` domain so tests never read/write the
/// real app's saved state, and never leak state between test runs.
func makeIsolatedDefaults(_ name: String = #function) -> UserDefaults {
    let suiteName = "VizRemoteTests.\(name).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
