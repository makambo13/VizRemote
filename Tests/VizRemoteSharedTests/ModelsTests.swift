import XCTest
#if canImport(VizRemote)
@testable import VizRemote
#else
@testable import VizRemoteiOS
#endif

final class ModelsTests: XCTestCase {
    /// Every RemoteKey must resolve to a real (codeset, code) pair sourced from pyvizio —
    /// pin these exact values so a future edit can't silently drift back to a guess.
    func testRemoteKeyCodesetsAndCodes() {
        let expected: [RemoteKey: (codeset: Int, code: Int)] = [
            .powerToggle: (11, 2),
            .volumeUp: (5, 1),
            .volumeDown: (5, 0),
            .muteOff: (5, 2),
            .muteOn: (5, 3),
            .muteToggle: (5, 4),
            .up: (3, 8),
            .down: (3, 0),
            .left: (3, 1),
            .right: (3, 7),
            .ok: (3, 2),
            .back: (4, 0),
            .home: (4, 15),
            .menu: (4, 8),
            .smartcast: (4, 3),
            .info: (4, 6),
            .inputNext: (7, 1),
        ]
        for (key, expectedPair) in expected {
            XCTAssertEqual(key.codeset, expectedPair.codeset, "\(key) codeset")
            XCTAssertEqual(key.code, expectedPair.code, "\(key) code")
        }
        XCTAssertEqual(expected.count, RemoteKey.allCases.count, "every RemoteKey case must be covered by this test")
    }

    func testAppearanceModeLabelsAndIDs() {
        XCTAssertEqual(AppearanceMode.system.label, "System")
        XCTAssertEqual(AppearanceMode.dark.label, "Dark")
        XCTAssertEqual(AppearanceMode.light.label, "Light")
        for mode in AppearanceMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }

    func testDiscoveredTVEquatableByAllFields() {
        let a = DiscoveredTV(id: "1", name: "Living Room", model: "M-Series", host: "192.0.2.42")
        let b = DiscoveredTV(id: "1", name: "Living Room", model: "M-Series", host: "192.0.2.42")
        let differentHost = DiscoveredTV(id: "1", name: "Living Room", model: "M-Series", host: "192.0.2.99")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, differentHost)
    }

    func testTVDetailGetsAUniqueIDPerInstance() {
        let a = TVDetail(label: "Model", value: "M65Q7-J01")
        let b = TVDetail(label: "Model", value: "M65Q7-J01")
        XCTAssertNotEqual(a.id, b.id, "TVDetail.id is a fresh UUID per instance, even with identical content")
    }

    func testAppShortcutCarriesRealLaunchConfig() {
        let netflix = AppShortcut(id: "netflix", name: "Netflix", initial: "N", appID: "1", nameSpace: 3)
        XCTAssertEqual(netflix.appID, "1")
        XCTAssertEqual(netflix.nameSpace, 3)
    }
}
