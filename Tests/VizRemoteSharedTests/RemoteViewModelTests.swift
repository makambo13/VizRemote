import XCTest
#if canImport(VizRemote)
@testable import VizRemote
#else
@testable import VizRemoteiOS
#endif

@MainActor
final class RemoteViewModelTests: XCTestCase {
    private func settle() async {
        // Lets the fire-and-forget Tasks inside RemoteViewModel's methods complete.
        try? await Task.sleep(nanoseconds: 20_000_000)
    }

    func testInitRefreshesVolumeInputsAndActiveInputFromClient() async {
        let client = FakeSmartCastClient(volume: 42, inputID: "hdmi2")
        let vm = RemoteViewModel(client: client)
        await settle()

        XCTAssertEqual(vm.volume, 42)
        XCTAssertFalse(vm.inputs.isEmpty)
        XCTAssertEqual(vm.activeInputID, "hdmi2")
        XCTAssertEqual(vm.activeInputLabel, "HDMI 2")
    }

    func testActiveInputLabelFallsBackToEmDashWhenUnmatched() {
        let client = FakeSmartCastClient()
        let vm = RemoteViewModel(client: client)
        vm.inputs = []
        vm.activeInputID = "nonexistent"
        XCTAssertEqual(vm.activeInputLabel, "—")
    }

    func testToggleMuteFlipsLocalStateOptimistically() {
        let client = FakeSmartCastClient()
        let vm = RemoteViewModel(client: client)
        XCTAssertFalse(vm.muted)
        vm.toggleMute()
        XCTAssertTrue(vm.muted)
        vm.toggleMute()
        XCTAssertFalse(vm.muted)
    }

    func testChangeVolumeClampsToZeroAndOneHundred() {
        let client = FakeSmartCastClient(volume: 2)
        let vm = RemoteViewModel(client: client)
        vm.volume = 2
        vm.changeVolume(by: -10)
        XCTAssertEqual(vm.volume, 0, "must clamp at 0, never go negative")

        vm.volume = 97
        vm.changeVolume(by: 10)
        XCTAssertEqual(vm.volume, 100, "must clamp at 100, never overflow")
    }

    func testSelectInputUpdatesActiveIDImmediately() {
        let client = FakeSmartCastClient()
        let vm = RemoteViewModel(client: client)
        let target = InputSource(id: "hdmi3", label: "HDMI 3")
        vm.selectInput(target)
        XCTAssertEqual(vm.activeInputID, "hdmi3")
    }

    func testToggleAppsFlipsAppsOpenState() {
        let vm = RemoteViewModel(client: FakeSmartCastClient())
        let initial = vm.appsOpen
        vm.toggleApps()
        XCTAssertEqual(vm.appsOpen, !initial)
    }

    func testLaunchGuardsAgainstOverlappingLaunches() async {
        let client = ControllableSmartCastClient()
        let vm = RemoteViewModel(client: client)
        let app = AppShortcut(id: "netflix", name: "Netflix", initial: "N", appID: "1", nameSpace: 3)

        vm.launch(app)
        XCTAssertEqual(vm.launchingAppID, "netflix", "launchingAppID must be set synchronously so the UI can disable other tiles immediately")
        vm.launch(app) // should be ignored — a launch is already in flight
        await settle()

        XCTAssertNil(vm.launchingAppID, "must clear back to nil once the launch completes")
    }

    func testLaunchSurfacesErrorMessageOnFailure() async {
        final class FailingClient: SmartCastClient {
            let host = "192.0.2.42"
            func startPairing() async throws -> PairingChallenge { fatalError("unused") }
            func finishPairing(pin: String, challenge: PairingChallenge) async throws -> String { fatalError("unused") }
            func send(_ key: RemoteKey) async throws {}
            func powerState() async throws -> Bool { true }
            func volume() async throws -> Int { 0 }
            func setVolume(_ value: Int) async throws {}
            func setMuted(_ muted: Bool) async throws {}
            func currentInput() async throws -> InputSource { InputSource(id: "x", label: "X") }
            func inputs() async throws -> [InputSource] { [] }
            func selectInput(_ input: InputSource) async throws {}
            func launchApp(appID: String, nameSpace: Int) async throws {
                throw StubError(message: "TV refused to launch the app")
            }
        }

        let vm = RemoteViewModel(client: FailingClient())
        let app = AppShortcut(id: "netflix", name: "Netflix", initial: "N", appID: "1", nameSpace: 3)
        vm.launch(app)
        await settle()

        XCTAssertEqual(vm.errorMessage, "TV refused to launch the app")
    }
}
