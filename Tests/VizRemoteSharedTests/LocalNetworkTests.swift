import XCTest
#if canImport(VizRemote)
@testable import VizRemote
#else
@testable import VizRemoteiOS
#endif

final class LocalNetworkTests: XCTestCase {
    func testSlash24YieldsExactly254HostsExcludingNetworkAndBroadcast() {
        let hosts = LocalNetwork.hostAddresses(base: "192.0.2.5", prefixLength: 24)
        XCTAssertEqual(hosts.count, 254)
        XCTAssertFalse(hosts.contains("192.0.2.0"), "network address must be excluded")
        XCTAssertFalse(hosts.contains("192.0.2.255"), "broadcast address must be excluded")
        XCTAssertTrue(hosts.contains("192.0.2.1"))
        XCTAssertTrue(hosts.contains("192.0.2.254"))
    }

    func testSlash30YieldsExactlyTwoUsableHosts() {
        let hosts = LocalNetwork.hostAddresses(base: "203.0.113.5", prefixLength: 30)
        XCTAssertEqual(Set(hosts), Set(["203.0.113.5", "203.0.113.6"]))
    }

    func testSlash31OrSlash32YieldsNoUsableHosts() {
        XCTAssertEqual(LocalNetwork.hostAddresses(base: "203.0.113.1", prefixLength: 31), [])
        XCTAssertEqual(LocalNetwork.hostAddresses(base: "203.0.113.1", prefixLength: 32), [])
    }

    func testOversizedNetworkIsCappedNotHungOrCrashed() {
        // A /16 has 65534 usable hosts — must be capped, not scanned in full.
        let hosts = LocalNetwork.hostAddresses(base: "172.16.5.9", prefixLength: 16, limit: 512)
        XCTAssertEqual(hosts.count, 512, "must respect the explicit cap rather than enumerating the whole /16")
    }

    func testInvalidPrefixLengthReturnsEmptyRatherThanCrashing() {
        XCTAssertEqual(LocalNetwork.hostAddresses(base: "192.0.2.5", prefixLength: 0), [])
        XCTAssertEqual(LocalNetwork.hostAddresses(base: "192.0.2.5", prefixLength: 33), [])
        XCTAssertEqual(LocalNetwork.hostAddresses(base: "192.0.2.5", prefixLength: -1), [])
    }

    func testMalformedBaseAddressReturnsEmptyRatherThanCrashing() {
        XCTAssertEqual(LocalNetwork.hostAddresses(base: "not-an-ip", prefixLength: 24), [])
        XCTAssertEqual(LocalNetwork.hostAddresses(base: "", prefixLength: 24), [])
    }

    func testAllGeneratedAddressesAreDistinct() {
        let hosts = LocalNetwork.hostAddresses(base: "198.51.100.1", prefixLength: 24)
        XCTAssertEqual(hosts.count, Set(hosts).count, "no duplicate addresses in the scan list")
    }
}
