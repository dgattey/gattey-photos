import GatteyPhotosCore
import SwiftUI

struct ActivityLogListView: View {
    @EnvironmentObject private var logStore: ActivityLogStore
    @State private var expandedEntryIDs: Set<UUID> = []

    private static let collapsedDetailLimit = 160

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
                detailView(detail, entry: entry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func detailView(_ detail: String, entry: LogEntry) -> some View {
        let needsExpansion = detail.count > Self.collapsedDetailLimit || detail.contains("\n")
        if needsExpansion {
            DisclosureGroup(isExpanded: expansionBinding(for: entry.id)) {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text(collapsedDetailPreview(detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func expansionBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedEntryIDs.contains(id) },
            set: { expanded in
                if expanded {
                    expandedEntryIDs.insert(id)
                } else {
                    expandedEntryIDs.remove(id)
                }
            }
        )
    }

    private func collapsedDetailPreview(_ detail: String) -> String {
        let firstLine = detail.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? detail
        if firstLine.count <= Self.collapsedDetailLimit {
            return firstLine
        }
        return String(firstLine.prefix(Self.collapsedDetailLimit)) + "…"
    }
}
