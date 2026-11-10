import Foundation

struct PairingChallenge {
    let token: Int
    let challengeType: Int
}

enum SmartCastError: Error, LocalizedError {
    case unreachable
    case notPaired
    case pairingRejected
    case http(Int, String)
    case decode

    var errorDescription: String? {
        switch self {
        case .unreachable: return "The TV isn't responding."
        case .notPaired: return "Not paired with this TV yet."
        case .pairingRejected: return "That code didn't match. Check the TV screen and try again."
        case .http(let code, _): return "TV returned an unexpected response (\(code))."
        case .decode: return "Couldn't understand the TV's response."
        }
    }
}

protocol SmartCastClient: AnyObject {
    var host: String { get }

    func startPairing() async throws -> PairingChallenge
    func finishPairing(pin: String, challenge: PairingChallenge) async throws -> String
    func send(_ key: RemoteKey) async throws

    func powerState() async throws -> Bool
    func volume() async throws -> Int
    func setVolume(_ value: Int) async throws
    func setMuted(_ muted: Bool) async throws
    func currentInput() async throws -> InputSource
    func inputs() async throws -> [InputSource]
    func selectInput(_ input: InputSource) async throws
    func launchApp(appID: String, nameSpace: Int) async throws
}

/// Deterministic in-memory stand-in for every SwiftUI #Preview and for UI development
/// before a real TV is on hand. Never makes a network call.
final class FakeSmartCastClient: SmartCastClient {
    let host: String
    var simulatedReachable: Bool
    private var volumeValue: Int
    private var muted: Bool
    private var inputID: String
    private let allInputs: [InputSource] = [
        InputSource(id: "smartcast", label: "SmartCast"),
        InputSource(id: "hdmi1", label: "HDMI 1"),
        InputSource(id: "hdmi2", label: "HDMI 2"),
        InputSource(id: "hdmi3", label: "HDMI 3"),
        InputSource(id: "comp", label: "Composite"),
    ]

    init(host: String = "192.0.2.42", reachable: Bool = true, volume: Int = 28, inputID: String = "hdmi1") {
        self.host = host
        self.simulatedReachable = reachable
        self.volumeValue = volume
        self.muted = false
        self.inputID = inputID
    }

    func startPairing() async throws -> PairingChallenge { PairingChallenge(token: 123456, challengeType: 1) }
    func finishPairing(pin: String, challenge: PairingChallenge) async throws -> String {
        guard pin != "0000" else { throw SmartCastError.pairingRejected }
        return "fake-auth-token"
    }
    func send(_ key: RemoteKey) async throws {
        guard simulatedReachable else { throw SmartCastError.unreachable }
        switch key {
        case .volumeUp: volumeValue = min(100, volumeValue + 1)
        case .volumeDown: volumeValue = max(0, volumeValue - 1)
        case .muteToggle: muted.toggle()
        default: break
        }
    }
    func powerState() async throws -> Bool { simulatedReachable }
    func volume() async throws -> Int { muted ? 0 : volumeValue }
    func setVolume(_ value: Int) async throws { volumeValue = value }
    func setMuted(_ isMuted: Bool) async throws { muted = isMuted }
    func currentInput() async throws -> InputSource { allInputs.first { $0.id == inputID } ?? allInputs[0] }
    func inputs() async throws -> [InputSource] { allInputs }
    func selectInput(_ input: InputSource) async throws { inputID = input.id }
    func launchApp(appID: String, nameSpace: Int) async throws { guard simulatedReachable else { throw SmartCastError.unreachable } }
}
