import SwiftUI

enum LinkStatus {
    case up
    case down
    case checking

    var symbol: String {
        switch self {
        case .up: return "checkmark.circle.fill"
        case .down: return "xmark.circle.fill"
        case .checking: return "ellipsis.circle.fill"
        }
    }

    /// User-facing connection summary (no endpoints).
    var connectionLabel: String {
        switch self {
        case .up: return "Connected"
        case .down: return "Disconnected"
        case .checking: return "Connecting"
        }
    }

    /// Badge label color, dark enough to read on `badgeFill` in light mode and bright on it in dark mode.
    func badgeForeground(for colorScheme: ColorScheme) -> Color {
        switch (self, colorScheme) {
        case (.up, .dark): return Color(red: 0.62, green: 0.88, blue: 0.70)
        case (.up, _): return AppBrandColor.accentGreen
        case (.checking, .dark): return Color(red: 1.0, green: 0.78, blue: 0.48)
        case (.checking, _): return Color(red: 0.70, green: 0.40, blue: 0.05)
        case (.down, .dark): return Color(red: 1.0, green: 0.62, blue: 0.60)
        case (.down, _): return Color(red: 0.78, green: 0.16, blue: 0.14)
        }
    }

    func badgeFill(for colorScheme: ColorScheme) -> Color {
        switch (self, colorScheme) {
        case (.up, .dark): return Color(red: 0.12, green: 0.30, blue: 0.18)
        case (.up, _): return Color(red: 0.85, green: 0.94, blue: 0.88)
        case (.checking, .dark): return Color(red: 0.34, green: 0.22, blue: 0.08)
        case (.checking, _): return Color(red: 1.0, green: 0.93, blue: 0.84)
        case (.down, .dark): return Color(red: 0.36, green: 0.13, blue: 0.13)
        case (.down, _): return Color(red: 1.0, green: 0.89, blue: 0.89)
        }
    }
}

/// Settings row for one link: title, optional detail, and a tinted status badge.
struct LinkStatusRow: View {
    let title: String
    var subtitle: String? = nil
    let status: LinkStatus

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            LinkStatusBadge(status: status)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LinkStatusBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let status: LinkStatus

    var body: some View {
        HStack(spacing: 5) {
            if status == .checking {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: status.symbol)
            }
            Text(status.connectionLabel)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(status.badgeForeground(for: colorScheme))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(status.badgeFill(for: colorScheme), in: Capsule())
    }
}
