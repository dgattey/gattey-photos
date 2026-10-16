import Foundation
import XCTest

@testable import GatteyPhotosCore

private final class CapturingURLProtocol: URLProtocol {
    nonisolated(unsafe) static var lastRequestURL: URL?
    nonisolated(unsafe) static var responseJSON: String = #"{"devices":[]}"#

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequestURL = request.url
        let data = Data(Self.responseJSON.utf8)
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://photos.gattey.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

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

    func testListDevicesAndFetchDevicesStatusEncodeOwnerQueryParameter() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CapturingURLProtocol.self]
        let session = URLSession(configuration: config)

        var settings = AppSettings.defaults
        settings.serverBaseURL = "https://photos.gattey.com"
        settings.syncSessionToken = "test-token"
        let client = try SyncClient(settings: settings, session: session)

        CapturingURLProtocol.responseJSON =
            #"{"devices":[{"id":"1","displayName":"Bedroom","registeredBy":"Dylan","registeredAt":"2026-06-02T03:18:40.054Z"}]}"#
        let devices = try await client.listDevices(owner: "  Dylan Gattey ")
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(
            CapturingURLProtocol.lastRequestURL?.absoluteString,
            "https://photos.gattey.com/api/devices?owner=Dylan%20Gattey"
        )

        _ = try await client.listDevices(owner: "   ")
        XCTAssertEqual(
            CapturingURLProtocol.lastRequestURL?.absoluteString,
            "https://photos.gattey.com/api/devices"
        )

        CapturingURLProtocol.responseJSON =
            #"{"devices":[{"id":"1","displayName":"Bedroom","registeredBy":"Dylan","reachable":true}]}"#
        let statuses = try await client.fetchDevicesStatus(owner: "Dylan")
        XCTAssertEqual(statuses.count, 1)
        XCTAssertEqual(statuses.first?.registeredBy, "Dylan")
        XCTAssertEqual(
            CapturingURLProtocol.lastRequestURL?.absoluteString,
            "https://photos.gattey.com/api/devices/status?owner=Dylan"
        )
    }
}
