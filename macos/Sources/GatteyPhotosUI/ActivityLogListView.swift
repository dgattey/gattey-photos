import GatteyPhotosCore
import SwiftUI

struct ActivityLogListView: View {
    @EnvironmentObject private var logStore: ActivityLogStore

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        Group {
            if logStore.entries.isEmpty {
                ContentUnavailableView {
                    Label("No activity yet", systemImage: "text.badge.clock")
                } description: {
                    Text("Sync, uploads, and server events appear here.")
                }
            } else {
                List {
                    ForEach(logStore.entries) { entry in
                        logRow(entry)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .textSelection(.enabled)
    }

    private func logRow(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.message)
                    .foregroundStyle(entry.level == .error ? .red : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(Self.timeFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let detail = entry.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
