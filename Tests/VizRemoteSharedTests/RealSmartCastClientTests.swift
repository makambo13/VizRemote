import XCTest
#if canImport(VizRemote)
@testable import VizRemote
#else
@testable import VizRemoteiOS
#endif

final class RealSmartCastClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    private func makeClient(authToken: String? = "existing-token") -> RealSmartCastClient {
        RealSmartCastClient(host: "192.0.2.42", deviceID: "test-device", authToken: authToken, session: MockURLProtocol.makeSession())
    }

    // MARK: Pairing

    func testStartPairingSendsPUTWithDeviceIdentityAndParsesChallenge() async throws {
        MockURLProtocol.responseQueue = [.json(["ITEM": ["PAIRING_REQ_TOKEN": 123456, "CHALLENGE_TYPE": 1]])]
        let client = makeClient(authToken: nil)

        let challenge = try await client.startPairing()

        XCTAssertEqual(challenge.token, 123456)
        XCTAssertEqual(challenge.challengeType, 1)
        let sent = MockURLProtocol.recordedRequests[0]
        XCTAssertEqual(sent.method, "PUT", "this firmware 404s on POST — must always be PUT")
        XCTAssertEqual(sent.path, "/pairing/start")
        XCTAssertEqual(sent.bodyJSON?["DEVICE_ID"] as? String, "test-device")
    }

    func testFinishPairingSuccessParsesAuthToken() async throws {
        MockURLProtocol.responseQueue = [.json(["ITEM": ["AUTH_TOKEN": "brand-new-token"]])]
        let client = makeClient(authToken: nil)

        let token = try await client.finishPairing(pin: "4790", challenge: PairingChallenge(token: 1, challengeType: 1))

        XCTAssertEqual(token, "brand-new-token")
        let sent = MockURLProtocol.recordedRequests[0]
        XCTAssertEqual(sent.method, "PUT")
        XCTAssertEqual(sent.path, "/pairing/pair")
        XCTAssertEqual(sent.bodyJSON?["RESPONSE_VALUE"] as? String, "4790")
    }

    func testFinishPairingWithMissingTokenThrowsPairingRejected() async {
        // A wrong PIN doesn't come back as an HTTP error — it comes back 200 OK without
        // an AUTH_TOKEN. Must be pairingRejected (friendly), not decode (generic).
        MockURLProtocol.responseQueue = [.json(["STATUS": ["RESULT": "CHALLENGE_INCORRECT"]])]
        let client = makeClient(authToken: nil)

        await XCTAssertThrowsErrorAsync(try await client.finishPairing(pin: "0000", challenge: PairingChallenge(token: 1, challengeType: 1))) { error in
            guard case SmartCastError.pairingRejected = error else {
                return XCTFail("expected .pairingRejected, got \(error)")
            }
        }
    }

    // MARK: Mute — regression test for today's real bug

    func testSetMutedTrueSendsMuteOnKeyCommandNotASettingsWrite() async throws {
        MockURLProtocol.responseQueue = [.json(["STATUS": ["RESULT": "SUCCESS"]])]
        let client = makeClient()

        try await client.setMuted(true)

        let sent = MockURLProtocol.recordedRequests[0]
        XCTAssertEqual(sent.path, "/key_command", "mute must be a key press, not /menu_native/.../audio/mute — that endpoint never worked")
        XCTAssertEqual(sent.method, "PUT")
        let keylist = sent.bodyJSON?["KEYLIST"] as? [[String: Any]]
        XCTAssertEqual(keylist?.first?["CODESET"] as? Int, 5)
        XCTAssertEqual(keylist?.first?["CODE"] as? Int, 3, "MUTE_ON is codeset 5 code 3")
    }

    func testSetMutedFalseSendsMuteOffKeyCommand() async throws {
        MockURLProtocol.responseQueue = [.json(["STATUS": ["RESULT": "SUCCESS"]])]
        let client = makeClient()

        try await client.setMuted(false)

        let keylist = MockURLProtocol.recordedRequests[0].bodyJSON?["KEYLIST"] as? [[String: Any]]
        XCTAssertEqual(keylist?.first?["CODE"] as? Int, 2, "MUTE_OFF is codeset 5 code 2")
    }

    // MARK: Key presses

    func testSendKeyPressPUTsCorrectCodesetAndCode() async throws {
        MockURLProtocol.responseQueue = [.json(["STATUS": ["RESULT": "SUCCESS"]])]
        let client = makeClient()

        try await client.send(.powerToggle)

        let sent = MockURLProtocol.recordedRequests[0]
        XCTAssertEqual(sent.path, "/key_command")
        let keylist = sent.bodyJSON?["KEYLIST"] as? [[String: Any]]
        XCTAssertEqual(keylist?.first?["CODESET"] as? Int, 11)
        XCTAssertEqual(keylist?.first?["CODE"] as? Int, 2)
        XCTAssertEqual(keylist?.first?["ACTION"] as? String, "KEYPRESS")
    }

    func testSendKeyWithoutAuthTokenThrowsNotPaired() async {
        let client = makeClient(authToken: nil)
        await XCTAssertThrowsErrorAsync(try await client.send(.powerToggle)) { error in
            guard case SmartCastError.notPaired = error else {
                return XCTFail("expected .notPaired, got \(error)")
            }
        }
        XCTAssertTrue(MockURLProtocol.recordedRequests.isEmpty, "must not make a network call at all without a token")
    }

    // MARK: Power state

    func testPowerStateTrueWhenValueIsOne() async throws {
        MockURLProtocol.responseQueue = [.json(["ITEMS": [["VALUE": 1]]])]
        let client = makeClient()
        let isOn = try await client.powerState()
        XCTAssertTrue(isOn)
    }

    func testPowerStateFalseWhenUnreachable() async throws {
        MockURLProtocol.responseQueue = [] // no stub queued → MockURLProtocol fails the request
        let client = makeClient()
        let isOn = try await client.powerState()
        XCTAssertFalse(isOn, "a network failure must be treated as 'off', not thrown as an error")
    }

    // MARK: Volume — read-then-write

    func testSetVolumeReadsHashThenWritesWithSameHash() async throws {
        MockURLProtocol.responseQueue = [
            .json(["ITEMS": [["VALUE": 28, "HASHVAL": 555]]]),
            .json(["STATUS": ["RESULT": "SUCCESS"]]),
        ]
        let client = makeClient()

        try await client.setVolume(40)

        XCTAssertEqual(MockURLProtocol.recordedRequests[0].method, "GET")
        let writeRequest = MockURLProtocol.recordedRequests[1]
        XCTAssertEqual(writeRequest.method, "PUT")
        XCTAssertEqual(writeRequest.bodyJSON?["VALUE"] as? Int, 40)
        XCTAssertEqual(writeRequest.bodyJSON?["HASHVAL"] as? Int, 555, "must reuse the HASHVAL from the read, not a stale or made-up one")
        XCTAssertEqual(writeRequest.bodyJSON?["REQUEST"] as? String, "MODIFY")
    }

    // MARK: App launch

    func testLaunchAppSendsCorrectValueShape() async throws {
        MockURLProtocol.responseQueue = [.json(["STATUS": ["RESULT": "SUCCESS"]])]
        let client = makeClient()

        try await client.launchApp(appID: "1", nameSpace: 3)

        let sent = MockURLProtocol.recordedRequests[0]
        XCTAssertEqual(sent.method, "PUT")
        XCTAssertEqual(sent.path, "/app/launch")
        let value = sent.bodyJSON?["VALUE"] as? [String: Any]
        XCTAssertEqual(value?["APP_ID"] as? String, "1")
        XCTAssertEqual(value?["NAME_SPACE"] as? Int, 3)
    }

    // MARK: Error handling

    func testNonTwoHundredStatusThrowsHTTPError() async {
        MockURLProtocol.responseQueue = [.raw(500, Data("Internal Server Error".utf8))]
        let client = makeClient()

        await XCTAssertThrowsErrorAsync(try await client.send(.powerToggle)) { error in
            guard case SmartCastError.http(let code, _) = error else {
                return XCTFail("expected .http, got \(error)")
            }
            XCTAssertEqual(code, 500)
        }
    }

    func testMalformedJSONThrowsDecodeError() async {
        MockURLProtocol.responseQueue = [.raw(200, Data("not json at all".utf8))]
        let client = makeClient()

        await XCTAssertThrowsErrorAsync(try await client.send(.powerToggle)) { error in
            guard case SmartCastError.decode = error else {
                return XCTFail("expected .decode, got \(error)")
            }
        }
    }
}

/// XCTAssertThrowsError has no async overload in this SDK version — this bridges it.
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("expected an error to be thrown", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
