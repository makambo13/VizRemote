import SwiftUI
#if os(macOS)
import AppKit
#endif

@MainActor
final class AppModel: ObservableObject {
    enum Screen: Equatable {
        case searching
        case discovered
        case pairing
        case remote
        case settings
    }

    @Published var screen: Screen
    @Published var discoveredTVs: [DiscoveredTV] = []
    @Published var selectedTV: DiscoveredTV?
    @Published var pairingDigits: [String] = ["", "", "", ""]
    @Published var pairingError: String?
    @Published var isFetchingChallenge = false
    @Published var isSubmittingPin = false
    @Published var appearance: AppearanceMode {
        didSet { applyAppearance() }
    }
    @Published var client: SmartCastClient?
    @Published var reachability: ReachabilityMonitor?

    private let discovery: TVDiscovery
    private let makeRealClient: (String, String) -> SmartCastClient
    private let defaults: UserDefaults
    private var pairingChallenge: PairingChallenge?
    private var searchTask: Task<Void, Never>?
    private var startPairingTask: Task<Void, Never>?

    private static let lastHostKey = "VizRemote.lastHost"
    private static let lastUSNKey = "VizRemote.lastUSN"
    private static let lastNameKey = "VizRemote.lastName"
    private static let appearanceKey = "VizRemote.appearance"
    private nonisolated static let installDeviceIDKey = "VizRemote.installDeviceID"

    /// A stable identifier for *this app install*. The pairing DEVICE_ID must name the
    /// controller, not the TV: if the Mac and iPhone sent the same DEVICE_ID, the TV could
    /// confuse their pairing sessions.
    nonisolated static var installDeviceID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: installDeviceIDKey) {
            return existing
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: installDeviceIDKey)
        return generated
    }

    init(discovery: TVDiscovery = SubnetScanDiscovery(),
         makeRealClient: @escaping (String, String) -> SmartCastClient = { host, usn in
             RealSmartCastClient(host: host, deviceID: AppModel.installDeviceID, authToken: KeychainStore.loadToken(forUSN: usn))
         },
         defaults: UserDefaults = .standard,
         autoStart: Bool = true) {
        self.discovery = discovery
        self.makeRealClient = makeRealClient
        self.defaults = defaults
        self.screen = .searching
        if let saved = defaults.string(forKey: Self.appearanceKey), let mode = AppearanceMode(rawValue: saved) {
            self.appearance = mode
        } else {
            self.appearance = .system
        }
        applyAppearance()
        if autoStart { tryResume() }
    }

    /// MenuBarExtra's `.window`-style popover doesn't reliably honor SwiftUI's
    /// `.preferredColorScheme` for asset-catalog dynamic colors — those key off the
    /// hosting NSWindow's effective appearance, so it has to be set directly here.
    /// iOS has no equivalent problem (UIKit scenes honor `.preferredColorScheme`
    /// normally), so this is a no-op there.
    private func applyAppearance() {
        defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
        #if os(macOS)
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        #endif
    }

    private func tryResume() {
        guard let host = defaults.string(forKey: Self.lastHostKey),
              let usn = defaults.string(forKey: Self.lastUSNKey),
              KeychainStore.loadToken(forUSN: usn) != nil else {
            startSearch()
            return
        }
        let name = defaults.string(forKey: Self.lastNameKey) ?? "Living Room"
        selectedTV = DiscoveredTV(id: usn, name: name, model: "VIZIO SmartCast", host: host)
        connectRemote(client: makeRealClient(host, usn))
    }

    func startSearch() {
        screen = .searching
        discoveredTVs = []
        searchTask?.cancel()
        searchTask = Task {
            for await tv in discovery.search(timeout: 6) {
                if !discoveredTVs.contains(where: { $0.id == tv.id }) {
                    discoveredTVs.append(tv)
                }
            }
            if screen == .searching { screen = .discovered }
        }
    }

    func showDiscoveryResults() { screen = .discovered }

    func connect(to tv: DiscoveredTV) {
        selectedTV = tv
        pairingDigits = ["", "", "", ""]
        pairingError = nil
        pairingChallenge = nil
        let client = makeRealClient(tv.host, tv.id)
        self.client = client
        screen = .pairing
        isFetchingChallenge = true
        startPairingTask?.cancel()
        startPairingTask = Task {
            defer { isFetchingChallenge = false }
            do {
                let challenge = try await client.startPairing()
                guard !Task.isCancelled else { return }
                pairingChallenge = challenge
            } catch is CancellationError {
                // superseded by a newer connect() call — that one owns the error state
            } catch {
                pairingError = (error as? LocalizedError)?.errorDescription ?? "Couldn't reach the TV."
            }
        }
    }

    func connectManual(host: String) {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        connect(to: DiscoveredTV(id: "manual-\(trimmed)", name: "Living Room", model: "VIZIO SmartCast", host: trimmed))
    }

    var pairingComplete: Bool { pairingDigits.allSatisfy { !$0.isEmpty } }

    func setPairingDigit(_ index: Int, rawValue: String) {
        let digitsOnly = rawValue.filter(\.isNumber)
        if digitsOnly.count == 4 {
            pairingDigits = digitsOnly.map { String($0) }
            return
        }
        pairingDigits[index] = String(digitsOnly.suffix(1))
    }

    func submitPairing() {
        guard !isSubmittingPin, let client, let challenge = pairingChallenge, pairingComplete else { return }
        let pin = pairingDigits.joined()
        pairingError = nil
        isSubmittingPin = true
        Task {
            defer { isSubmittingPin = false }
            do {
                let token = try await client.finishPairing(pin: pin, challenge: challenge)
                if let tv = selectedTV {
                    KeychainStore.save(token: token, forUSN: tv.id)
                    defaults.set(tv.host, forKey: Self.lastHostKey)
                    defaults.set(tv.id, forKey: Self.lastUSNKey)
                    defaults.set(tv.name, forKey: Self.lastNameKey)
                }
                connectRemote(client: client)
            } catch {
                pairingError = (error as? LocalizedError)?.errorDescription ?? "Pairing failed."
            }
        }
    }

    func cancelPairing() {
        startPairingTask?.cancel()
        startPairingTask = nil
        pairingChallenge = nil
        pairingError = nil
        client = nil
        screen = .discovered
    }

    private func connectRemote(client: SmartCastClient) {
        self.client = client
        let monitor = ReachabilityMonitor(client: client)
        reachability = monitor
        monitor.start()
        screen = .remote
    }

    func forgetTV() {
        if let tv = selectedTV { KeychainStore.delete(forUSN: tv.id) }
        defaults.removeObject(forKey: Self.lastHostKey)
        defaults.removeObject(forKey: Self.lastUSNKey)
        defaults.removeObject(forKey: Self.lastNameKey)
        reachability?.stop()
        reachability = nil
        client = nil
        selectedTV = nil
        startSearch()
    }

    func openSettings() { screen = .settings }
    func closeSettings() { screen = reachability != nil ? .remote : .discovered }
}

extension AppModel {
    static func previewConnected() -> AppModel {
        let model = AppModel(autoStart: false)
        let client = FakeSmartCastClient()
        model.selectedTV = DiscoveredTV(id: "preview", name: "Living Room", model: "VIZIO M-Series · 65″", host: client.host)
        model.client = client
        let monitor = ReachabilityMonitor(client: client)
        model.reachability = monitor
        Task { await monitor.checkOnce() }
        model.screen = .remote
        return model
    }

    static func previewOff() -> AppModel {
        let model = AppModel(autoStart: false)
        let client = FakeSmartCastClient(reachable: false)
        model.selectedTV = DiscoveredTV(id: "preview", name: "Living Room", model: "VIZIO M-Series · 65″", host: client.host)
        model.client = client
        let monitor = ReachabilityMonitor(client: client)
        model.reachability = monitor
        Task { await monitor.checkOnce() }
        model.screen = .remote
        return model
    }

    static func previewSearching() -> AppModel {
        let model = AppModel(autoStart: false)
        model.screen = .searching
        return model
    }

    static func previewDiscovered() -> AppModel {
        let model = AppModel(autoStart: false)
        model.discoveredTVs = [
            DiscoveredTV(id: "1", name: "Living Room", model: "VIZIO M-Series · 65″", host: "living-room.local"),
            DiscoveredTV(id: "2", name: "Bedroom", model: "VIZIO V-Series · 50″", host: "bedroom.local"),
        ]
        model.screen = .discovered
        return model
    }

    static func previewPairing() -> AppModel {
        let model = AppModel(autoStart: false)
        model.selectedTV = DiscoveredTV(id: "1", name: "Living Room", model: "VIZIO M-Series · 65″", host: "living-room.local")
        model.client = FakeSmartCastClient()
        model.screen = .pairing
        return model
    }

    static func previewSettings() -> AppModel {
        let model = previewConnected()
        model.screen = .settings
        return model
    }
}
