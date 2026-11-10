import XCTest
#if canImport(VizRemote)
@testable import VizRemote
#else
@testable import VizRemoteiOS
#endif

final class FakeSmartCastClientTests: XCTestCase {
    func testStartPairingReturnsAChallenge() async throws {
        let client = FakeSmartCastClient()
        let challenge = try await client.startPairing()
        XCTAssertEqual(challenge.token, 123456)
    }

    func testFinishPairingWithCorrectPinSucceeds() async throws {
        let client = FakeSmartCastClient()
        let token = try await client.finishPairing(pin: "4790", challenge: PairingChallenge(token: 1, challengeType: 1))
        XCTAssertEqual(token, "fake-auth-token")
    }

    func testFinishPairingWithMagicWrongPinFails() async {
        let client = FakeSmartCastClient()
        do {
            _ = try await client.finishPairing(pin: "0000", challenge: PairingChallenge(token: 1, challengeType: 1))
            XCTFail("pin '0000' is the fake client's documented rejection case")
        } catch SmartCastError.pairingRejected {
            // expected
        } catch {
            XCTFail("expected .pairingRejected, got \(error)")
        }
    }

    func testSendWhenUnreachableThrows() async {
        let client = FakeSmartCastClient(reachable: false)
        do {
            try await client.send(.powerToggle)
            XCTFail("must throw when simulatedReachable is false")
        } catch SmartCastError.unreachable {
            // expected
        } catch {
            XCTFail("expected .unreachable, got \(error)")
        }
    }

    func testSendVolumeUpAndDownAdjustVolumeWithClamping() async throws {
        let client = FakeSmartCastClient(volume: 99)
        try await client.send(.volumeUp)
        try await client.send(.volumeUp)
        let high = try await client.volume()
        XCTAssertEqual(high, 100, "must clamp at 100")

        let low = FakeSmartCastClient(volume: 1)
        try await low.send(.volumeDown)
        try await low.send(.volumeDown)
        let lowVolume = try await low.volume()
        XCTAssertEqual(lowVolume, 0, "must clamp at 0")
    }

    func testMuteToggleKeyMutesVolumeReading() async throws {
        let client = FakeSmartCastClient(volume: 50)
        try await client.send(.muteToggle)
        let volume = try await client.volume()
        XCTAssertEqual(volume, 0, "volume() reports 0 while muted")
    }

    func testPowerStateReflectsSimulatedReachable() async throws {
        let reachable = FakeSmartCastClient(reachable: true)
        let reachablePower = try await reachable.powerState()
        XCTAssertTrue(reachablePower)

        let unreachable = FakeSmartCastClient(reachable: false)
        let unreachablePower = try await unreachable.powerState()
        XCTAssertFalse(unreachablePower)
    }

    func testCurrentInputMatchesInitialInputID() async throws {
        let client = FakeSmartCastClient(inputID: "hdmi3")
        let current = try await client.currentInput()
        XCTAssertEqual(current.id, "hdmi3")
        XCTAssertEqual(current.label, "HDMI 3")
    }

    func testCurrentInputFallsBackToFirstWhenIDIsUnknown() async throws {
        let client = FakeSmartCastClient(inputID: "does-not-exist")
        let current = try await client.currentInput()
        XCTAssertEqual(current.id, "smartcast", "falls back to the first entry in the fixed input list")
    }

    func testInputsReturnsTheFullFixedList() async throws {
        let client = FakeSmartCastClient()
        let all = try await client.inputs()
        XCTAssertEqual(all.map(\.id), ["smartcast", "hdmi1", "hdmi2", "hdmi3", "comp"])
    }

    func testSelectInputUpdatesCurrentInput() async throws {
        let client = FakeSmartCastClient(inputID: "hdmi1")
        try await client.selectInput(InputSource(id: "hdmi2", label: "HDMI 2"))
        let current = try await client.currentInput()
        XCTAssertEqual(current.id, "hdmi2")
    }

    func testSetVolumeDirectlySetsValue() async throws {
        let client = FakeSmartCastClient()
        try await client.setVolume(77)
        let volume = try await client.volume()
        XCTAssertEqual(volume, 77)
    }

    func testSetMutedDirectlySetsState() async throws {
        let client = FakeSmartCastClient(volume: 30)
        try await client.setMuted(true)
        let mutedVolume = try await client.volume()
        XCTAssertEqual(mutedVolume, 0)
        try await client.setMuted(false)
        let unmutedVolume = try await client.volume()
        XCTAssertEqual(unmutedVolume, 30)
    }

    func testLaunchAppSucceedsWhenReachable() async {
        let client = FakeSmartCastClient(reachable: true)
        do {
            try await client.launchApp(appID: "1", nameSpace: 3)
        } catch {
            XCTFail("must not throw when reachable: \(error)")
        }
    }

    func testLaunchAppThrowsWhenUnreachable() async {
        let client = FakeSmartCastClient(reachable: false)
        await XCTAssertThrowsErrorAsync(try await client.launchApp(appID: "1", nameSpace: 3)) { error in
            guard case SmartCastError.unreachable = error else {
                return XCTFail("expected .unreachable, got \(error)")
            }
        }
    }
}
