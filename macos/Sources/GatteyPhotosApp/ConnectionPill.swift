import SwiftUI

enum LinkStatus {
    case up
    case down
    case checking

    var shortLabel: String {
        switch self {
        case .up: return "OK"
        case .down: return "Off"
        case .checking: return "…"
        }
    }

    var tint: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .checking: return .orange
        }
    }

    var icon: String {
        switch self {
        case .up: return "checkmark.circle.fill"
        case .down: return "xmark.circle.fill"
        case .checking: return "ellipsis.circle.fill"
        }
    }
}

struct ConnectionStatusPill: View {
    let serverStatus: LinkStatus
    let deviceStatus: LinkStatus

    var body: some View {
        HStack(spacing: 8) {
            statusChip(title: "Server", status: serverStatus)
            statusChip(title: "Device", status: deviceStatus)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private func statusChip(title: String, status: LinkStatus) -> some View {
        HStack(spacing: 5) {
            Image(systemName: status.icon)
                .font(.caption)
                .foregroundStyle(status.tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(status.shortLabel)
                .font(.caption.bold())
                .foregroundStyle(status.tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(status.tint.opacity(0.12), in: Capsule())
    }
}
