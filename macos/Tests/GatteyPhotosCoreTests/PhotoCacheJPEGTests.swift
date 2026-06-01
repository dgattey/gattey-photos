import XCTest
@testable import GatteyPhotosCore

final class PhotoCacheJPEGTests: XCTestCase {
    func testIsJPEGRecognizesJFIFHeader() {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        XCTAssertTrue(PhotoCacheJPEG.isJPEG(jpeg))
    }

    func testIsJPEGRejectsHEICMagic() {
        let heicPrefix = Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70])
        XCTAssertFalse(PhotoCacheJPEG.isJPEG(heicPrefix))
    }
}
