import XCTest
#if canImport(VizRemote)
@testable import VizRemote
#else
@testable import VizRemoteiOS
#endif

final class KeychainStoreTests: XCTestCase {
    private func uniqueUSN() -> String { "test-usn-\(UUID().uuidString)" }

    override func tearDown() {
        super.tearDown()
    }

    func testSaveThenLoadRoundTrips() {
        let usn = uniqueUSN()
        defer { KeychainStore.delete(forUSN: usn) }

        KeychainStore.save(token: "abc123", forUSN: usn)
        XCTAssertEqual(KeychainStore.loadToken(forUSN: usn), "abc123")
    }

    func testLoadForUnknownUSNReturnsNil() {
        XCTAssertNil(KeychainStore.loadToken(forUSN: uniqueUSN()))
    }

    func testSaveTwiceOverwritesRatherThanFailing() {
        let usn = uniqueUSN()
        defer { KeychainStore.delete(forUSN: usn) }

        KeychainStore.save(token: "first-token", forUSN: usn)
        KeychainStore.save(token: "second-token", forUSN: usn)
        XCTAssertEqual(KeychainStore.loadToken(forUSN: usn), "second-token")
    }

    func testDeleteRemovesTheToken() {
        let usn = uniqueUSN()
        KeychainStore.save(token: "abc123", forUSN: usn)
        KeychainStore.delete(forUSN: usn)
        XCTAssertNil(KeychainStore.loadToken(forUSN: usn))
    }

    func testDeleteOnNeverSavedUSNDoesNotCrash() {
        KeychainStore.delete(forUSN: uniqueUSN())
    }

    func testTwoDifferentUSNsDoNotCollide() {
        let usnA = uniqueUSN()
        let usnB = uniqueUSN()
        defer {
            KeychainStore.delete(forUSN: usnA)
            KeychainStore.delete(forUSN: usnB)
        }

        KeychainStore.save(token: "token-a", forUSN: usnA)
        KeychainStore.save(token: "token-b", forUSN: usnB)
        XCTAssertEqual(KeychainStore.loadToken(forUSN: usnA), "token-a")
        XCTAssertEqual(KeychainStore.loadToken(forUSN: usnB), "token-b")
    }
}
