import Foundation

/// Shared client pull interval while the app is unlocked (macOS, iOS, iPadOS).
public enum GallerySyncSchedule {
    public static let periodicIntervalNanoseconds: UInt64 = 900_000_000_000
}
