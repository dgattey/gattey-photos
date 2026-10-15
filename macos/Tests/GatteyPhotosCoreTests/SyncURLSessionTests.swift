import XCTest

@testable import GatteyPhotosCore

final class SyncURLSessionTests: XCTestCase {
    func testMakeConfigurationFailsFastWhenOffline() {
        let config = SyncURLSession.makeConfiguration()
        XCTAssertFalse(config.waitsForConnectivity)
        XCTAssertEqual(config.timeoutIntervalForRequest, SyncURLSession.requestTimeout)
        XCTAssertEqual(config.timeoutIntervalForResource, SyncURLSession.resourceTimeout)
    }
}
