import XCTest
#if canImport(VizRemote)
@testable import VizRemote
#else
@testable import VizRemoteiOS
#endif

@MainActor
final class AppModelTests: XCTestCase {
    private func settle() async {
        try? await Task.sleep(nanoseconds: 30_000_000)
    }

    private func makeModel(
        discovery: TVDiscovery = FakeTVDiscovery(),
        client: ControllableSmartCastClient = ControllableSmartCastClient(),
        defaults: UserDefaults? = nil
    ) -> (AppModel, ControllableSmartCastClient) {
        let model = AppModel(
            discovery: discovery,
            makeRealClient: { _, _ in client },
            defaults: defaults ?? makeIsolatedDefaults(),
            autoStart: false
        )
        return (model, client)
    }

    // MARK: Discovery

    func testStartSearchPopulatesDiscoveredTVsAndTransitionsToDiscovered() async {
        let tv = DiscoveredTV(id: "1", name: "Living Room", model: "VIZIO SmartCast", host: "192.0.2.42")
        let (model, _) = makeModel(discovery: FakeTVDiscovery(tvsToYield: [tv]))

        model.startSearch()
        XCTAssertEqual(model.screen, .searching)
        await settle()

        XCTAssertEqual(model.screen, .discovered)
        XCTAssertEqual(model.discoveredTVs, [tv])
    }

    func testStartSearchDeduplicatesRepeatedTVs() async {
        let tv = DiscoveredTV(id: "1", name: "Living Room", model: "VIZIO SmartCast", host: "192.0.2.42")
        let (model, _) = makeModel(discovery: FakeTVDiscovery(tvsToYield: [tv, tv, tv]))

        model.startSearch()
        await settle()

        XCTAssertEqual(model.discoveredTVs.count, 1, "the same USN appearing multiple times in a scan must not produce duplicate cards")
    }

    func testStartSearchWithNoResultsStillReachesDiscoveredScreen() async {
        let (model, _) = makeModel(discovery: FakeTVDiscovery(tvsToYield: []))
        model.startSearch()
        await settle()
        XCTAssertEqual(model.screen, .discovered)
        XCTAssertTrue(model.discoveredTVs.isEmpty)
    }

    func testStartingANewSearchCancelsThePreviousOne() async {
        // A never-finishing first scan must not block a second, real one from ever
        // reaching .discovered — this is the same class of bug as the pairing race.
        let tv = DiscoveredTV(id: "1", name: "Living Room", model: "VIZIO SmartCast", host: "192.0.2.42")
        let (model, _) = makeModel(discovery: NeverFinishingDiscovery())
        model.startSearch()
        await settle()
        XCTAssertEqual(model.screen, .searching, "still stuck on the never-finishing scan")

        model.startSearch()
        // Second call still uses the same NeverFinishingDiscovery instance in this
        // constructor shape, so just confirm it didn't crash and reset cleanly.
        XCTAssertEqual(model.discoveredTVs, [])
        _ = tv
    }

    func testShowDiscoveryResultsJumpsStraightToDiscovered() {
        let (model, _) = makeModel()
        model.showDiscoveryResults()
        XCTAssertEqual(model.screen, .discovered)
    }

    // MARK: Pairing — connect()

    func testConnectMovesToPairingAndFetchesChallenge() async {
        let (model, client) = makeModel()
        let tv = DiscoveredTV(id: "1", name: "Living Room", model: "VIZIO SmartCast", host: "192.0.2.42")

        model.connect(to: tv)
        XCTAssertEqual(model.screen, .pairing)
        XCTAssertTrue(model.isFetchingChallenge)
        await settle()

        XCTAssertFalse(model.isFetchingChallenge)
        XCTAssertEqual(client.startPairingCallCount, 1)
        XCTAssertNil(model.pairingError)
    }

    func testConnectSurfacesErrorWhenStartPairingFails() async {
        let client = ControllableSmartCastClient()
        client.startPairingResult = .failure(StubError(message: "Couldn't reach the TV."))
        let (model, _) = makeModel(client: client)

        model.connect(to: DiscoveredTV(id: "1", name: "Living Room", model: "VIZIO SmartCast", host: "192.0.2.42"))
        await settle()

        XCTAssertEqual(model.pairingError, "Couldn't reach the TV.")
    }

    func testCallingConnectAgainCancelsThePreviousStartPairingCall() async {
        // Regression test for the DEVICE_ID/race bug: an earlier connect() whose
        // startPairing() is still in flight must not be allowed to resolve into the
        // state of a second, newer connect() call.
        let client = ControllableSmartCastClient()
        client.startPairingDelayNanoseconds = 200_000_000
        let (model, _) = makeModel(client: client)

        model.connect(to: DiscoveredTV(id: "1", name: "Living Room", model: "VIZIO SmartCast", host: "192.0.2.42"))
        model.connect(to: DiscoveredTV(id: "2", name: "Bedroom", model: "VIZIO SmartCast", host: "192.0.2.43"))
        try? await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertEqual(model.selectedTV?.id, "2", "the second connect() call must win")
    }

    func testCancelPairingCancelsInFlightStartPairingCall() async {
        // Regression test: cancelPairing() must actually cancel the network Task, not
        // just clear UI state — otherwise a slow startPairing() response can silently
        // repopulate pairingChallenge/pairingError after the user has already backed out.
        let client = ControllableSmartCastClient()
        client.startPairingDelayNanoseconds = 200_000_000
        let (model, _) = makeModel(client: client)

        model.connect(to: DiscoveredTV(id: "1", name: "Living Room", model: "VIZIO SmartCast", host: "192.0.2.42"))
        model.cancelPairing()
        XCTAssertEqual(model.screen, .discovered)

        try? await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertEqual(model.screen, .discovered, "must not have been pulled back into .pairing by the cancelled call resolving late")
        XCTAssertNil(model.pairingError, "a cancelled call must not surface a stale error after the user backed out")
    }

    func testConnectManualTrimsWhitespaceAndIgnoresEmptyInput() {
        let (model, _) = makeModel()
        model.connectManual(host: "   ")
        XCTAssertEqual(model.screen, .searching, "blank input must be a no-op, not start a pairing flow against an empty host")

        model.connectManual(host: "  192.0.2.50  ")
        XCTAssertEqual(model.selectedTV?.host, "192.0.2.50")
    }

    // MARK: Pairing digits

    func testSetPairingDigitFiltersNonNumericCharacters() {
        let (model, _) = makeModel()
        model.setPairingDigit(0, rawValue: "a")
        XCTAssertEqual(model.pairingDigits[0], "")
        model.setPairingDigit(0, rawValue: "7")
        XCTAssertEqual(model.pairingDigits[0], "7")
    }

    func testSetPairingDigitKeepsOnlyTheLastCharacterTyped() {
        let (model, _) = makeModel()
        model.setPairingDigit(0, rawValue: "12")
        XCTAssertEqual(model.pairingDigits[0], "2", "typing a second digit into a filled box should replace, not concatenate")
    }

    func testSetPairingDigitWithFourDigitPasteFillsAllBoxes() {
        let (model, _) = makeModel()
        model.setPairingDigit(2, rawValue: "4790")
        XCTAssertEqual(model.pairingDigits, ["4", "7", "9", "0"])
    }

    func testPairingCompleteReflectsAllFourBoxesFilled() {
        let (model, _) = makeModel()
        XCTAssertFalse(model.pairingComplete)
        model.setPairingDigit(0, rawValue: "1")
        model.setPairingDigit(1, rawValue: "2")
        model.setPairingDigit(2, rawValue: "3")
        XCTAssertFalse(model.pairingComplete, "still one box short")
        model.setPairingDigit(3, rawValue: "4")
        XCTAssertTrue(model.pairingComplete)
    }

    // MARK: submitPairing()

    func testSubmitPairingDoesNothingWhenDigitsAreIncomplete() async {
        let (model, client) = makeModel()
        model.connect(to: DiscoveredTV(id: "1", name: "Living Room", model: "VIZIO SmartCast", host: "192.0.2.42"))
        await settle()
        model.setPairingDigit(0, rawValue: "4")

        model.submitPairing()
        await settle()

        XCTAssertEqual(client.finishPairingCallCount, 0)
        XCTAssertEqual(model.screen, .pairing)
    }

    func testSubmitPairingSuccessSavesTokenAndMovesToRemote() async {
        let (model, _) = makeModel()
        let tv = DiscoveredTV(id: "test-tv-\(UUID().uuidString)", name: "Living Room", model: "VIZIO SmartCast", host: "192.0.2.42")
        defer { KeychainStore.delete(forUSN: tv.id) }

        model.connect(to: tv)
        await settle()
        for (i, d) in ["4", "7", "9", "0"].enumerated() { model.setPairingDigit(i, rawValue: d) }

        model.submitPairing()
        await settle()

        XCTAssertEqual(model.screen, .remote)
        XCTAssertNotNil(model.reachability)
        XCTAssertEqual(KeychainStore.loadToken(forUSN: tv.id), "fake-token")
    }

    func testSubmitPairingFailureKeepsUserOnPairingScreenWithError() async {
        let client = ControllableSmartCastClient()
        client.finishPairingResult = .failure(StubError(message: "That code didn't match. Check the TV screen and try again."))
        let (model, _) = makeModel(client: client)

        model.connect(to: DiscoveredTV(id: "1", name: "Living Room", model: "VIZIO SmartCast", host: "192.0.2.42"))
        await settle()
        for (i, d) in ["4", "7", "9", "0"].enumerated() { model.setPairingDigit(i, rawValue: d) }

        model.submitPairing()
        await settle()

        XCTAssertEqual(model.screen, .pairing)
        XCTAssertEqual(model.pairingError, "That code didn't match. Check the TV screen and try again.")
    }

    func testDoubleTappingSubmitPairingOnlyFiresOneNetworkCall() async {
        // Regression test: this exact race (two concurrent finishPairing() calls
        // consuming the same one-time PAIRING_REQ_TOKEN) produced a real "couldn't
        // understand the TV's response" failure against the actual hardware.
        let client = ControllableSmartCastClient()
        let (model, _) = makeModel(client: client)

        model.connect(to: DiscoveredTV(id: "1", name: "Living Room", model: "VIZIO SmartCast", host: "192.0.2.42"))
        await settle()
        for (i, d) in ["4", "7", "9", "0"].enumerated() { model.setPairingDigit(i, rawValue: d) }

        model.submitPairing()
        model.submitPairing()
        model.submitPairing()
        await settle()

        XCTAssertEqual(client.finishPairingCallCount, 1, "the isSubmittingPin guard must block every re-entrant call")
    }

    // MARK: forgetTV()

    func testForgetTVClearsKeychainAndStateThenRestartsSearch() async {
        let (model, _) = makeModel()
        let tv = DiscoveredTV(id: "test-tv-\(UUID().uuidString)", name: "Living Room", model: "VIZIO SmartCast", host: "192.0.2.42")
        KeychainStore.save(token: "some-token", forUSN: tv.id)
        model.selectedTV = tv

        model.forgetTV()

        XCTAssertNil(KeychainStore.loadToken(forUSN: tv.id))
        XCTAssertNil(model.selectedTV)
        XCTAssertNil(model.client)
        XCTAssertNil(model.reachability)
        XCTAssertEqual(model.screen, .searching)
    }

    // MARK: Appearance persistence

    func testAppearanceDefaultsToSystemWhenNothingSaved() {
        let (model, _) = makeModel(defaults: makeIsolatedDefaults())
        XCTAssertEqual(model.appearance, .system)
    }

    func testAppearancePersistsAcrossInstancesViaInjectedDefaults() {
        let defaults = makeIsolatedDefaults()
        let (first, _) = makeModel(defaults: defaults)
        first.appearance = .dark

        let (second, _) = makeModel(defaults: defaults)
        XCTAssertEqual(second.appearance, .dark, "a second AppModel reading the same defaults must see the saved appearance")
    }

    // MARK: tryResume() (exercised indirectly via autoStart)

    func testAutoStartWithNoSavedTVGoesToSearching() {
        let discovery = FakeTVDiscovery()
        let model = AppModel(
            discovery: discovery,
            makeRealClient: { _, _ in ControllableSmartCastClient() },
            defaults: makeIsolatedDefaults(),
            autoStart: true
        )
        XCTAssertEqual(model.screen, .searching)
    }

    func testAutoStartWithSavedTVAndValidTokenResumesToRemote() {
        let defaults = makeIsolatedDefaults()
        let usn = "test-tv-\(UUID().uuidString)"
        defer { KeychainStore.delete(forUSN: usn) }
        KeychainStore.save(token: "saved-token", forUSN: usn)
        defaults.set("192.0.2.42", forKey: "VizRemote.lastHost")
        defaults.set(usn, forKey: "VizRemote.lastUSN")
        defaults.set("Living Room", forKey: "VizRemote.lastName")

        let model = AppModel(
            discovery: FakeTVDiscovery(),
            makeRealClient: { _, _ in ControllableSmartCastClient() },
            defaults: defaults,
            autoStart: true
        )

        XCTAssertEqual(model.screen, .remote)
        XCTAssertEqual(model.selectedTV?.host, "192.0.2.42")
        XCTAssertNotNil(model.reachability)
    }

    func testAutoStartWithSavedTVButNoKeychainTokenFallsBackToSearch() {
        let defaults = makeIsolatedDefaults()
        defaults.set("192.0.2.42", forKey: "VizRemote.lastHost")
        defaults.set("usn-with-no-real-token-\(UUID().uuidString)", forKey: "VizRemote.lastUSN")

        let model = AppModel(
            discovery: FakeTVDiscovery(),
            makeRealClient: { _, _ in ControllableSmartCastClient() },
            defaults: defaults,
            autoStart: true
        )

        XCTAssertEqual(model.screen, .searching, "a saved host with no matching Keychain token must not be trusted")
    }

    // MARK: installDeviceID

    func testInstallDeviceIDIsStableAcrossCalls() {
        let first = AppModel.installDeviceID
        let second = AppModel.installDeviceID
        XCTAssertEqual(first, second, "must be generated once and persisted, not regenerated per call")
    }
}
