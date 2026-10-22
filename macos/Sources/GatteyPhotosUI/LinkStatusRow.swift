import SwiftUI

enum LinkStatus {
    case up
    case down
    case checking

    var tint: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .checking: return .orange
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
}

/// Settings row for one link: title, optional detail, and a trailing status dot and label.
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
            if status == .checking {
                ProgressView()
                    .controlSize(.small)
            } else {
                Circle()
                    .fill(status.tint)
                    .frame(width: 8, height: 8)
            }
            Text(status.connectionLabel)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
