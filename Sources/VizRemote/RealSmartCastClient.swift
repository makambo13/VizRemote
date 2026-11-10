import Foundation

/// Trusts the TV's self-signed HTTPS certificate for exactly this one host — never
/// disables verification globally, since that would also blind the app to a real
/// man-in-the-middle on any other connection it might someday make.
final class PinnedHostTLSDelegate: NSObject, URLSessionDelegate {
    let pinnedHost: String
    init(pinnedHost: String) { self.pinnedHost = pinnedHost }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.host == pinnedHost,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

/// Local SmartCast control API. Reverse-engineered protocol (VIZIO doesn't publish it);
/// `pyvizio` is the reference implementation this was cross-checked against. Pairing
/// endpoints are confirmed working against a real TV; volume/input shapes below are
/// best-effort and should be treated as unverified until exercised against real hardware.
final class RealSmartCastClient: SmartCastClient {
    let host: String
    private let deviceID: String
    private let deviceName: String
    private var authToken: String?

    private let session: URLSession

    /// `session` is injectable so tests can substitute a `URLProtocol`-mocked session and
    /// verify the actual request shape (method, path, JSON body) without a real TV. That
    /// catches regressions such as sending POST where the TV requires PUT.
    init(host: String, deviceID: String, deviceName: String = "VizRemote-Mac", authToken: String? = nil, session: URLSession? = nil) {
        self.host = host
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.authToken = authToken
        self.session = session ?? URLSession(configuration: .ephemeral, delegate: PinnedHostTLSDelegate(pinnedHost: host), delegateQueue: nil)
    }

    func updateAuthToken(_ token: String?) { authToken = token }

    private func url(_ path: String) -> URL { URL(string: "https://\(host):7345\(path)")! }

    private func request(_ path: String, method: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        var req = URLRequest(url: url(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken { req.setValue(authToken, forHTTPHeaderField: "AUTH") }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw SmartCastError.unreachable
        }
        guard let http = response as? HTTPURLResponse else { throw SmartCastError.decode }
        guard (200..<300).contains(http.statusCode) else {
            throw SmartCastError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SmartCastError.decode
        }
        return json
    }

    // MARK: Pairing

    func startPairing() async throws -> PairingChallenge {
        let json = try await request("/pairing/start", method: "PUT", body: [
            "DEVICE_ID": deviceID, "DEVICE_NAME": deviceName,
        ])
        guard let item = json["ITEM"] as? [String: Any],
              let token = item["PAIRING_REQ_TOKEN"] as? Int,
              let challengeType = item["CHALLENGE_TYPE"] as? Int else {
            throw SmartCastError.decode
        }
        return PairingChallenge(token: token, challengeType: challengeType)
    }

    func finishPairing(pin: String, challenge: PairingChallenge) async throws -> String {
        let json = try await request("/pairing/pair", method: "PUT", body: [
            "DEVICE_ID": deviceID,
            "CHALLENGE_TYPE": challenge.challengeType,
            "RESPONSE_VALUE": pin,
            "PAIRING_REQ_TOKEN": challenge.token,
        ])
        guard let item = json["ITEM"] as? [String: Any], let token = item["AUTH_TOKEN"] as? String else {
            throw SmartCastError.pairingRejected
        }
        authToken = token
        return token
    }

    // MARK: Control

    func send(_ key: RemoteKey) async throws {
        guard authToken != nil else { throw SmartCastError.notPaired }
        _ = try await request("/key_command/", method: "PUT", body: [
            "KEYLIST": [["CODESET": key.codeset, "CODE": key.code, "ACTION": "KEYPRESS"]]
        ])
    }

    func powerState() async throws -> Bool {
        do {
            let json = try await request("/state/device/power_mode", method: "GET")
            let value = (json["ITEMS"] as? [[String: Any]])?.first?["VALUE"] as? Int
            return value == 1
        } catch SmartCastError.unreachable {
            return false
        }
    }

    private func readSetting(_ path: String) async throws -> (value: Int, hash: Int) {
        guard authToken != nil else { throw SmartCastError.notPaired }
        let json = try await request(path, method: "GET")
        guard let item = (json["ITEMS"] as? [[String: Any]])?.first,
              let value = item["VALUE"] as? Int, let hash = item["HASHVAL"] as? Int else {
            throw SmartCastError.decode
        }
        return (value, hash)
    }

    private func writeSetting(_ path: String, value: Int, hash: Int) async throws {
        guard authToken != nil else { throw SmartCastError.notPaired }
        _ = try await request(path, method: "PUT", body: [
            "REQUEST": "MODIFY", "VALUE": value, "HASHVAL": hash,
        ])
    }

    func volume() async throws -> Int {
        try await readSetting("/menu_native/dynamic/tv_settings/audio/volume").value
    }

    func setVolume(_ value: Int) async throws {
        let current = try await readSetting("/menu_native/dynamic/tv_settings/audio/volume")
        try await writeSetting("/menu_native/dynamic/tv_settings/audio/volume", value: value, hash: current.hash)
    }

    /// There is no audio/mute settings path on real VIZIO firmware (confirmed against
    /// pyvizio's reference implementation, which only exposes mute as MUTE_ON/MUTE_OFF
    /// remote-key presses) — the original settings-based guess here never worked.
    func setMuted(_ muted: Bool) async throws {
        try await send(muted ? .muteOn : .muteOff)
    }

    func currentInput() async throws -> InputSource {
        guard authToken != nil else { throw SmartCastError.notPaired }
        let json = try await request("/menu_native/dynamic/tv_settings/devices/current_input", method: "GET")
        guard let item = (json["ITEMS"] as? [[String: Any]])?.first, let name = item["VALUE"] as? String else {
            throw SmartCastError.decode
        }
        return InputSource(id: name, label: name)
    }

    func inputs() async throws -> [InputSource] {
        guard authToken != nil else { throw SmartCastError.notPaired }
        let json = try await request("/menu_native/dynamic/tv_settings/devices/name_input", method: "GET")
        guard let items = json["ITEMS"] as? [[String: Any]] else { throw SmartCastError.decode }
        return items.compactMap { item in
            guard let name = item["NAME"] as? String else { return nil }
            let label = (item["VALUE"] as? String) ?? name
            return InputSource(id: name, label: label)
        }
    }

    func selectInput(_ input: InputSource) async throws {
        let current = try await readSetting("/menu_native/dynamic/tv_settings/devices/current_input")
        _ = current // hash carried for parity with other writes; VIZIO's input-select payload
                    // shape (CNAME-keyed) differs slightly from the plain VALUE/HASHVAL pattern
                    // above and needs confirming against the real TV before this is trustworthy.
        _ = try await request("/menu_native/dynamic/tv_settings/devices/current_input", method: "PUT", body: [
            "REQUEST": "MODIFY", "VALUE": input.id, "HASHVAL": current.hash,
        ])
    }

    /// Confirmed against pyvizio's `LaunchAppConfigCommand`/`CommandBase`: PUT to
    /// /app/launch with a VALUE object wrapping APP_ID/NAME_SPACE/MESSAGE — no HASHVAL,
    /// this isn't a read-modify-write setting like volume/input.
    func launchApp(appID: String, nameSpace: Int) async throws {
        guard authToken != nil else { throw SmartCastError.notPaired }
        _ = try await request("/app/launch", method: "PUT", body: [
            "VALUE": ["APP_ID": appID, "NAME_SPACE": nameSpace, "MESSAGE": NSNull()],
        ])
    }
}
