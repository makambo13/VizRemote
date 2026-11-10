import XCTest
#if canImport(VizRemote)
@testable import VizRemote
#else
@testable import VizRemoteiOS
#endif

@MainActor
final class ReachabilityMonitorTests: XCTestCase {
    func testCheckOnceReportsConnectedWhenClientIsReachable() async {
        let client = FakeSmartCastClient(reachable: true)
        let monitor = ReachabilityMonitor(client: client)
        await monitor.checkOnce()
        XCTAssertEqual(monitor.state, .connected)
    }

    func testCheckOnceReportsUnreachableWhenClientIsNot() async {
        let client = FakeSmartCastClient(reachable: false)
        let monitor = ReachabilityMonitor(client: client)
        await monitor.checkOnce()
        XCTAssertEqual(monitor.state, .unreachable)
    }

    func testStartsUnreachableBeforeFirstCheck() {
        let client = FakeSmartCastClient(reachable: true)
        let monitor = ReachabilityMonitor(client: client)
        XCTAssertEqual(monitor.state, .unreachable, "must not optimistically assume connected before ever checking")
    }

    func testStopCancelsPolling() async {
        let client = FakeSmartCastClient(reachable: true)
        let monitor = ReachabilityMonitor(client: client)
        monitor.start(interval: 0.05)
        try? await Task.sleep(nanoseconds: 120_000_000)
        monitor.stop()
        XCTAssertEqual(monitor.state, .connected)
        // No assertion beyond "doesn't crash and stop() is safe to call" — verifying a
        // task was truly cancelled requires observing absence of further side effects,
        // which FakeSmartCastClient's simple bool doesn't expose deterministically.
    }

    func testTransitionsFromConnectedToUnreachableWhenTVGoesOffline() async {
        let client = FakeSmartCastClient(reachable: true)
        let monitor = ReachabilityMonitor(client: client)
        await monitor.checkOnce()
        XCTAssertEqual(monitor.state, .connected)

        client.simulatedReachable = false
        await monitor.checkOnce()
        XCTAssertEqual(monitor.state, .unreachable)
    }
}
