import XCTest

@testable import GatteyPhotosCore

final class SyncURLSessionTests: XCTestCase {
    func testMakeConfigurationFailsFastWhenOffline() {
        let config = SyncURLSession.makeConfiguration()
        XCTAssertFalse(config.waitsForConnectivity)
        XCTAssertEqual(config.timeoutIntervalForRequest, SyncURLSession.requestTimeout)
        XCTAssertEqual(config.timeoutIntervalForResource, SyncURLSession.resourceTimeout)
    }

    func testReachabilityAndAuthVerifierTimeoutConstants() {
        XCTAssertEqual(Reachability.probeTimeout, 2)
        XCTAssertEqual(AuthVerifier.verifyTimeout, 8)
        XCTAssertEqual(AuthVerifier.createSessionTimeout, 12)
    }
}
