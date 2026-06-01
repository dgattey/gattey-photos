import XCTest
@testable import GatteyPhotosCore

final class SyncHTTPFailureTests: XCTestCase {
    func testSummarizeJSONErrorMessage() {
        let body = #"{"error":"Blob storage misconfigured"}"#
        XCTAssertEqual(
            SyncHTTPFailure.summarizeResponseBody(body),
            "Blob storage misconfigured"
        )
    }

    func testSummarizeNestedJSONMessage() {
        let body = #"{"error":{"message":"upload limit exceeded"}}"#
        XCTAssertEqual(
            SyncHTTPFailure.summarizeResponseBody(body),
            "upload limit exceeded"
        )
    }

    func testActivityLogDetailIncludesUploadContext() {
        let failure = SyncHTTPFailure(
            statusCode: 500,
            method: "POST",
            url: "https://photos.example.com/api/gallery/photos",
            responseBody: #"{"message":"Internal error"}"#,
            requestBodyBytes: 1_048_576,
            context: "upload: beach.jpg (JPEG 900000 bytes)"
        )
        let detail = failure.activityLogDetail
        XCTAssertTrue(detail.contains("HTTP 500"))
        XCTAssertTrue(detail.contains("POST https://photos.example.com/api/gallery/photos"))
        XCTAssertTrue(detail.contains("upload: beach.jpg"))
        XCTAssertTrue(detail.contains("Request size:"))
        XCTAssertTrue(detail.contains("Response: Internal error"))
    }

    func testRedactsBearerInResponseSnippet() {
        let body = "failed Bearer secret-token-abc123 for user"
        let summary = SyncHTTPFailure.summarizeResponseBody(body)
        XCTAssertFalse(summary.contains("secret-token"))
        XCTAssertTrue(summary.contains("[redacted]"))
    }
}
