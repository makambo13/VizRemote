import Foundation

@MainActor
final class ReachabilityMonitor: ObservableObject {
    @Published private(set) var state: PowerState = .unreachable

    private let client: SmartCastClient
    private var pollTask: Task<Void, Never>?

    init(client: SmartCastClient) {
        self.client = client
    }

    func start(interval: TimeInterval = 4) {
        stop()
        pollTask = Task {
            while !Task.isCancelled {
                await checkOnce()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func checkOnce() async {
        let reachable = (try? await client.powerState()) ?? false
        state = reachable ? .connected : .unreachable
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }
}
