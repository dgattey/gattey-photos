import GatteyPhotosCore
import Testing

struct Bloomin8ScreenDisplayAspectTests {
    @Test func portraitDisplayUsesNormalizedRatio() {
        let r = Bloomin8Screen.aspectRatio(width: 1200, height: 1600)
        #expect(Bloomin8Screen.displayAspectRatio(normalizedAspectRatio: r, isLandscape: false) == r)
        #expect(abs(r - 0.75) < 0.001)
    }

    @Test func landscapeDisplayUsesReciprocal() {
        let r = Bloomin8Screen.aspectRatio(width: 1600, height: 1200)
        let display = Bloomin8Screen.displayAspectRatio(normalizedAspectRatio: r, isLandscape: true)
        #expect(display > 1)
        #expect(abs(display * r - 1) < 0.001)
    }

    @Test func orientationLandscapeFlag() {
        #expect(Bloomin8Screen.isLandscapeDevice(orientation: "L", width: 1200, height: 1600))
        #expect(!Bloomin8Screen.isLandscapeDevice(orientation: "P", width: 1600, height: 1200))
        #expect(Bloomin8Screen.isLandscapeDevice(orientation: nil, width: 1600, height: 1200))
        #expect(!Bloomin8Screen.isLandscapeDevice(orientation: nil, width: 1200, height: 1600))
    }
}
