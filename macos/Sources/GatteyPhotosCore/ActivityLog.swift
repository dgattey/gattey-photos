import Foundation

public enum LogCategory: String, Codable, Sendable, CaseIterable {
    case server
    case device
    case sync
    case gallery
    case system
}

public enum LogLevel: String, Codable, Sendable {
    case info
    case success
    case warning
    case error
}

/// Detected on pull when `currentPhotoId` changes vs pre-pull local state.
public struct CurrentPhotoPullDelta: Sendable, Equatable {
    public let previousId: PhotoID?
    public let newId: PhotoID?
    public let updatedBy: CurrentPhotoUpdatedBy?

    public init(previousId: PhotoID?, newId: PhotoID?, updatedBy: CurrentPhotoUpdatedBy?) {
        self.previousId = previousId
        self.newId = newId
        self.updatedBy = updatedBy
    }

    public var didChange: Bool {
        previousId != newId && newId != nil
    }

    public static func ifCurrentChanged(
        from previousId: PhotoID?,
        to state: GalleryState
    ) -> CurrentPhotoPullDelta? {
        guard previousId != state.currentPhotoId else { return nil }
        return CurrentPhotoPullDelta(
            previousId: previousId,
            newId: state.currentPhotoId,
            updatedBy: state.currentPhotoUpdatedBy
        )
    }
}

public enum GalleryCurrentPhotoActivity {
    /// Activity log lines when the server changes the gallery current photo (not local Set as current).
    public static func logEntry(
        delta: CurrentPhotoPullDelta,
        photo: PhotoEntry?
    ) -> (message: String, detail: String?)? {
        guard delta.didChange, let newId = delta.newId else { return nil }
        let label = photo?.filename ?? newId
        switch delta.updatedBy {
        case .cron:
            return (
                "Gallery advanced",
                "Scheduled advance · \(label)"
            )
        case .manual:
            return (
                "Current photo updated from server",
                label
            )
        case nil:
            return (
                "Server updated current photo",
                label
            )
        }
    }

}

public struct LogEntry: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let category: LogCategory
    public let level: LogLevel
    public let message: String
    public let detail: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: LogCategory,
        level: LogLevel,
        message: String,
        detail: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.level = level
        self.message = message
        self.detail = detail
    }
}

public enum ActivityLogFile {
    private static let maxFileBytes = 512_000

    public static var url: URL {
        AppConfig.supportFolder.appendingPathComponent("activity.log")
    }

    private static let queue = DispatchQueue(label: "com.gattey.photos.activity-log")

    public static func append(_ entry: LogEntry) {
        queue.sync {
            guard let line = encode(entry) else { return }
            let data = Data(line.utf8)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: data)
                return
            }
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            trimIfNeeded()
        }
    }

    public static func loadRecent(limit: Int = 2000) -> [LogEntry] {
        queue.sync {
            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8)
            else { return [] }
            let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
            return lines.suffix(limit).compactMap { decode(String($0)) }
        }
    }

    public static func clear() {
        queue.sync {
            try? Data().write(to: url)
        }
    }

    private static func encode(_ entry: LogEntry) -> String? {
        let payload: [String: String] = [
            "id": entry.id.uuidString,
            "t": ISO8601DateFormatter().string(from: entry.timestamp),
            "c": entry.category.rawValue,
            "l": entry.level.rawValue,
            "m": entry.message,
            "d": entry.detail ?? "",
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8)
        else { return nil }
        return json
    }

    private static func parseTimestamp(_ t: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: t) { return d }
        return ISO8601DateFormatter().date(from: t)
    }

    private static func decode(_ line: String) -> LogEntry? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let id = UUID(uuidString: obj["id"] ?? ""),
              let t = obj["t"],
              let ts = parseTimestamp(t),
              let c = obj["c"],
              let category = LogCategory(rawValue: c),
              let l = obj["l"],
              let level = LogLevel(rawValue: l),
              let message = obj["m"]
        else { return nil }
        let detail = obj["d"].flatMap { $0.isEmpty ? nil : $0 }
        return LogEntry(id: id, timestamp: ts, category: category, level: level, message: message, detail: detail)
    }

    private static func trimIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int,
              size > maxFileBytes
        else { return }
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8)
        else { return }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        let keep = lines.suffix(200).joined(separator: "\n") + "\n"
        try? keep.data(using: .utf8)?.write(to: url)
    }
}

@MainActor
public final class ActivityLogStore: ObservableObject {
    public static let shared = ActivityLogStore()

    @Published public private(set) var entries: [LogEntry] = []

    private var liveReloadTask: Task<Void, Never>?

    private init() {}

    /// Polls `activity.log` so entries written from other processes appear in the UI.
    public func startLiveReload(intervalSeconds: TimeInterval = 4) {
        liveReloadTask?.cancel()
        bootstrapFromDiskIfNeeded()
        liveReloadTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
                guard !Task.isCancelled else { break }
                mergeFromDisk()
            }
        }
    }

    public func stopLiveReload() {
        liveReloadTask?.cancel()
        liveReloadTask = nil
    }

    /// Merges new lines from disk without removing in-memory entries.
    public func reload() {
        mergeFromDisk()
    }

    public func clear() {
        ActivityLogFile.clear()
        entries = []
    }

    private func bootstrapFromDiskIfNeeded() {
        guard entries.isEmpty else { return }
        mergeFromDisk()
    }

    private func mergeFromDisk() {
        let fromFile = ActivityLogFile.loadRecent()
        var byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for entry in fromFile {
            byID[entry.id] = entry
        }
        entries = byID.values.sorted { $0.timestamp > $1.timestamp }
    }

    public func log(
        _ category: LogCategory,
        level: LogLevel,
        _ message: String,
        detail: String? = nil
    ) {
        let entry = LogEntry(category: category, level: level, message: message, detail: detail)
        ActivityLogFile.append(entry)
        if !entries.contains(where: { $0.id == entry.id }) {
            entries.insert(entry, at: 0)
        }
        fputs("[\(category.rawValue)] \(message)\n", stderr)
        if let detail, !detail.isEmpty {
            fputs("\(detail)\n", stderr)
        }
    }

    public func log(error: Error, category: LogCategory, context: String) {
        log(category, level: .error, context, detail: Self.describe(error))
    }

    public nonisolated static func describe(_ error: Error) -> String {
        var parts: [String] = []
        if let localized = error as? LocalizedError {
            if let d = localized.errorDescription { parts.append(d) }
            if let r = localized.recoverySuggestion { parts.append("Recovery: \(r)") }
        }
        let ns = error as NSError
        parts.append("Domain: \(ns.domain) code=\(ns.code)")
        if !ns.localizedDescription.isEmpty, !parts.contains(ns.localizedDescription) {
            parts.append(ns.localizedDescription)
        }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            parts.append("Underlying: \(describe(underlying))")
        }
        if parts.isEmpty {
            parts.append(String(describing: error))
        }
        return parts.joined(separator: "\n")
    }
}
