import SwiftUI

enum LinkStatus {
    case up
    case down
    case checking
    /// iOS/iPad: e-ink frame is configured on Mac only.
    case notApplicable

    var tint: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .checking: return .orange
        case .notApplicable: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .up: return "checkmark.circle.fill"
        case .down: return "xmark.circle.fill"
        case .checking: return "ellipsis.circle.fill"
        case .notApplicable: return "minus.circle"
        }
    }

    func solidFill(for colorScheme: ColorScheme) -> Color {
        switch (self, colorScheme) {
        case (.up, .light):
            return Color(red: 0.86, green: 0.96, blue: 0.88)
        case (.up, .dark):
            return Color(red: 0.12, green: 0.28, blue: 0.16)
        case (.checking, .light):
            return Color(red: 1.0, green: 0.94, blue: 0.86)
        case (.checking, .dark):
            return Color(red: 0.32, green: 0.22, blue: 0.10)
        case (.down, .light):
            return Color(red: 1.0, green: 0.90, blue: 0.90)
        case (.down, .dark):
            return Color(red: 0.32, green: 0.14, blue: 0.14)
        case (.notApplicable, .light):
            return Color(red: 0.94, green: 0.94, blue: 0.95)
        case (.notApplicable, .dark):
            return Color(red: 0.22, green: 0.22, blue: 0.24)
        @unknown default:
            return Color(red: 0.86, green: 0.96, blue: 0.88)
        }
    }

    /// User-facing connection summary (no endpoints).
    var connectionLabel: String {
        switch self {
        case .up: return "Connected"
        case .down: return "Disconnected"
        case .checking: return "Connecting"
        case .notApplicable: return "N/A"
        }
    }
}

/// Per-link status row: tinted capsule, icon, title, optional detail, and connection label.
struct ConnectionPill: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var subtitle: String? = nil
    let status: LinkStatus

    private static let cornerRadius: CGFloat = 12

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.icon)
                .font(.body)
                .foregroundStyle(status.tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 4)
            Text(status.connectionLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(status.tint)
            if status == .checking {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            status.solidFill(for: colorScheme),
            in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        )
    }
}
