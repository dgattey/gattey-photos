import Foundation

/// Locates the GatteyPhotosUI SwiftPM resource bundle in dev, packaged macOS, and iOS app bundles.
///
/// Do not use `Bundle.module` in shipped apps: when the bundle path does not match what SwiftPM
/// expects at runtime, `Bundle.module` traps during static initialization.
enum GatteyPhotosUIResources {
    private static let resourceBundleName = "GatteyPhotos_GatteyPhotosUI"
    private static let markerResource = "unlock-welcome"
    private static let markerExtension = "png"

    static let bundle: Bundle = locateResourceBundle() ?? .main

    private static func locateResourceBundle() -> Bundle? {
        func containsMarker(_ bundle: Bundle?) -> Bundle? {
            guard let bundle,
                  bundle.url(forResource: markerResource, withExtension: markerExtension) != nil
            else { return nil }
            return bundle
        }

        if let executableURL = Bundle.main.executableURL {
            let bundleURL = executableURL
                .deletingLastPathComponent()
                .appendingPathComponent("\(resourceBundleName).bundle")
            if let bundle = containsMarker(Bundle(url: bundleURL)) {
                return bundle
            }
        }

        if let path = Bundle.main.path(forResource: resourceBundleName, ofType: "bundle"),
           let bundle = containsMarker(Bundle(path: path)) {
            return bundle
        }

        if let resourcesURL = Bundle.main.resourceURL {
            let bundleURL = resourcesURL.appendingPathComponent("\(resourceBundleName).bundle")
            if let bundle = containsMarker(Bundle(url: bundleURL)) {
                return bundle
            }
        }

        return containsMarker(.main)
    }
}
