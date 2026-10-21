import SwiftUI

/// Shared motion curves for user-facing UI transitions (not NavigationStack push/pop).
enum AppAnimation {
    /// Default interactive motion — slightly bouncy, not cartoonish (~0.38s feel).
    static let bouncy = Animation.spring(response: 0.38, dampingFraction: 0.72)

    /// Settled motion for subtle fades and dismissals.
    static let smooth = Animation.spring(response: 0.35, dampingFraction: 0.88)
}
