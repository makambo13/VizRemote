import Foundation

struct DiscoveredTV: Identifiable, Equatable, Codable {
    let id: String // USN
    var name: String
    var model: String
    var host: String
}

struct InputSource: Identifiable, Equatable, Codable {
    let id: String
    let label: String
}

/// APP_ID/NAME_SPACE sourced from pyvizio's published apps.json (its community-maintained
/// launch-config table), not guessed — same anti-hallucination approach as RemoteKey.
struct AppShortcut: Identifiable, Equatable {
    let id: String
    let name: String
    let initial: String
    let appID: String
    let nameSpace: Int
}

enum PowerState: Equatable {
    case connected
    case unreachable
}

/// CODESET/CODE pairs sourced from pyvizio's published const.py — the open-source
/// reference for VIZIO's undocumented local key-command API. Verified against this
/// TV only for pairing so far; individual buttons should be spot-checked.
enum RemoteKey: String, CaseIterable {
    case powerToggle, volumeUp, volumeDown, muteToggle, muteOn, muteOff
    case up, down, left, right, ok
    case back, home, menu, smartcast, info
    case inputNext

    var codeset: Int {
        switch self {
        case .powerToggle: return 11
        case .volumeUp, .volumeDown, .muteToggle, .muteOn, .muteOff: return 5
        case .up, .down, .left, .right, .ok: return 3
        case .back, .home, .menu, .smartcast, .info: return 4
        case .inputNext: return 7
        }
    }

    var code: Int {
        switch self {
        case .powerToggle: return 2
        case .volumeDown: return 0
        case .volumeUp: return 1
        case .muteOff: return 2
        case .muteOn: return 3
        case .muteToggle: return 4
        case .down: return 0
        case .left: return 1
        case .ok: return 2
        case .back: return 0
        case .smartcast: return 3
        case .info: return 6
        case .right: return 7
        case .up: return 8
        case .menu: return 8
        case .home: return 15
        case .inputNext: return 1
        }
    }
}

struct TVDetail: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, dark, light
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }
}
