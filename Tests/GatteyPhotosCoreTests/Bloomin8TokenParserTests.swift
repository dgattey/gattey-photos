import XCTest

@testable import GatteyPhotosCore

final class Bloomin8TokenParserTests: XCTestCase {
    private let sampleToken =
        "703A5D9FD4850827784AEED7AB800226.7be9909001aa2c0e9c51abdedb6e83746a12685392c70bbe105364031d8af474"

    private let sampleBlock = """
        🖼️ Bloomin8 Device Token
        Device: Bedroom | Interval: 6h
        Token: 703A5D9FD4850827784AEED7AB800226.7be9909001aa2c0e9c51abdedb6e83746a12685392c70bbe105364031d8af474
        """

    func testParseTokenFromFullBlock() {
        XCTAssertEqual(Bloomin8TokenParser.parseToken(from: sampleBlock), sampleToken)
    }

    func testParseTokenFromRawToken() {
        XCTAssertEqual(Bloomin8TokenParser.parseToken(from: sampleToken), sampleToken)
    }

    func testParseTokenFromTokenLineOnly() {
        XCTAssertEqual(
            Bloomin8TokenParser.parseToken(from: "Token: \(sampleToken)"),
            sampleToken
        )
    }

    func testParseDeviceName() {
        XCTAssertEqual(Bloomin8TokenParser.parseDeviceName(from: sampleBlock), "Bedroom")
    }

    func testParseTokenRejectsGarbage() {
        XCTAssertNil(Bloomin8TokenParser.parseToken(from: "not a token"))
    }

    func testLooksLikeToken() {
        XCTAssertTrue(Bloomin8TokenParser.looksLikeToken(sampleToken))
        XCTAssertFalse(Bloomin8TokenParser.looksLikeToken("abc"))
    }
}
