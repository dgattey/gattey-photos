import Foundation
import Observation

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

    private static let queue = DispatchQueue(label: "com.gattey.photos.activity-log", qos: .utility)

    private static let fractionalISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    public struct FileSignature: Equatable, Sendable {
        public let modificationDate: Date
        public let size: Int
    }

    public static func currentSignature() -> FileSignature? {
        queue.sync {
            readCurrentSignatureOnQueue()
        }
    }

    private static func readCurrentSignatureOnQueue() -> FileSignature? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
            let mod = attrs[.modificationDate] as? Date,
            let size = attrs[.size] as? Int
        else { return nil }
        return FileSignature(modificationDate: mod, size: size)
    }

    public static func append(_ entry: LogEntry) {
        queue.sync {
            appendOnQueue(entry)
        }
    }

    public static func appendAsync(
        _ entry: LogEntry,
        echoToStderr: Bool = false,
        completion: (@Sendable (FileSignature?) -> Void)? = nil
    ) {
        queue.async {
            appendOnQueue(entry)
            if echoToStderr {
                fputs("[\(entry.category.rawValue)] \(entry.message)\n", stderr)
                if let detail = entry.detail, !detail.isEmpty {
                    fputs("\(detail)\n", stderr)
                }
            }
            let sig = readCurrentSignatureOnQueue()
            completion?(sig)
        }
    }

    private static func appendOnQueue(_ entry: LogEntry) {
        guard let line = encode(entry) else { return }
        let data = Data((line + "\n").utf8)
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

    public static func loadRecent(limit: Int = 2000) -> [LogEntry] {
        queue.sync {
            loadRecentOnQueue(limit: limit)
        }
    }

    private static func loadRecentOnQueue(limit: Int = 2000) -> [LogEntry] {
        guard let data = try? Data(contentsOf: url),
            let text = String(data: data, encoding: .utf8)
        else { return [] }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        return lines.suffix(limit).compactMap { decode(String($0)) }
    }

    public static func loadIfChangedAsync(
        lastSignature: FileSignature?,
        onlyIfChanged: Bool,
        limit: Int = 2000
    ) async -> (entries: [LogEntry]?, signature: FileSignature?) {
        await withCheckedContinuation { continuation in
            queue.async {
                let sig = readCurrentSignatureOnQueue()
                if onlyIfChanged, let sig, sig == lastSignature {
                    continuation.resume(returning: (nil, sig))
                    return
                }
                let loaded = loadRecentOnQueue(limit: limit)
                continuation.resume(returning: (loaded, sig))
            }
        }
    }

    public static func clear() {
        queue.sync {
            try? Data().write(to: url)
        }
    }

    public static func clearAsync(completion: (@Sendable (FileSignature?) -> Void)? = nil) {
        queue.async {
            try? Data().write(to: url)
            completion?(readCurrentSignatureOnQueue())
        }
    }

    public static func flush() {
        queue.sync {}
    }

    private static func encode(_ entry: LogEntry) -> String? {
        let payload: [String: String] = [
            "id": entry.id.uuidString,
            "t": fractionalISOFormatter.string(from: entry.timestamp),
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
        if let d = fractionalISOFormatter.date(from: t) { return d }
        return standardISOFormatter.date(from: t)
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
@Observable
public final class ActivityLogStore {
    public static let shared = ActivityLogStore()

    public private(set) var entries: [LogEntry] = []

    private static let maxInMemoryEntries = 1000
    private var liveReloadTask: Task<Void, Never>?
    private var reloadTask: Task<Void, Never>?
    private var lastMergedSignature: ActivityLogFile.FileSignature?
    private var mergeGeneration: UInt64 = 0

    public init(entries: [LogEntry] = []) {
        self.entries = entries
    }

    /// Polls `activity.log` so entries written from other processes appear in the UI.
    public func startLiveReload(intervalSeconds: TimeInterval = 4) {
        liveReloadTask?.cancel()
        bootstrapFromDiskIfNeeded()
        liveReloadTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await mergeFromDiskAsync(onlyIfChanged: true)
            }
        }
    }

    public func stopLiveReload() {
        liveReloadTask?.cancel()
        liveReloadTask = nil
        reloadTask?.cancel()
        reloadTask = nil
    }

    /// Schedules an asynchronous merge of recent disk log lines off the main thread.
    public func reload() {
        reloadTask?.cancel()
        reloadTask = Task { @MainActor in
            await mergeFromDiskAsync(onlyIfChanged: false)
        }
    }

    public func reloadAsync() async {
        await mergeFromDiskAsync(onlyIfChanged: false)
    }

    public func clear() {
        mergeGeneration &+= 1
        reloadTask?.cancel()
        entries = []
        let expectedGen = mergeGeneration
        ActivityLogFile.clearAsync { sig in
            Task { @MainActor in
                guard ActivityLogStore.shared.mergeGeneration == expectedGen else { return }
                ActivityLogStore.shared.lastMergedSignature = sig
            }
        }
    }

    private func bootstrapFromDiskIfNeeded() {
        guard entries.isEmpty else { return }
        reload()
    }

    private func mergeFromDiskAsync(onlyIfChanged: Bool) async {
        let startGeneration = mergeGeneration
        let result = await ActivityLogFile.loadIfChangedAsync(
            lastSignature: lastMergedSignature,
            onlyIfChanged: onlyIfChanged
        )
        guard !Task.isCancelled, mergeGeneration == startGeneration else { return }
        lastMergedSignature = result.signature
        guard let fromFile = result.entries else { return }
        var byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        var addedOrUpdated = false
        for entry in fromFile {
            if byID[entry.id] != entry {
                byID[entry.id] = entry
                addedOrUpdated = true
            }
        }
        guard addedOrUpdated || entries.count != byID.count else { return }
        let sorted = byID.values.sorted { $0.timestamp > $1.timestamp }
        entries =
            sorted.count > Self.maxInMemoryEntries
            ? Array(sorted.prefix(Self.maxInMemoryEntries))
            : sorted
    }

    public func log(
        _ category: LogCategory,
        level: LogLevel,
        _ message: String,
        detail: String? = nil
    ) {
        let entry = LogEntry(category: category, level: level, message: message, detail: detail)
        if entries.first?.id != entry.id {
            entries.insert(entry, at: 0)
            if entries.count > Self.maxInMemoryEntries {
                entries.removeLast(entries.count - Self.maxInMemoryEntries)
            }
        }
        let expectedGen = mergeGeneration
        ActivityLogFile.appendAsync(entry, echoToStderr: true) { sig in
            Task { @MainActor in
                guard ActivityLogStore.shared.mergeGeneration == expectedGen else { return }
                ActivityLogStore.shared.lastMergedSignature = sig
            }
        }
    }

    public func log(error: Error, category: LogCategory, context: String) {
        log(category, level: .error, context, detail: Self.describe(error))
    }

    public nonisolated static func describe(_ error: Error) -> String {
        if let sync = error as? SyncError, let detail = sync.activityLogDetail {
            return detail
        }
        var parts: [String] = []
        if let localized = error as? LocalizedError {
            if let d = localized.errorDescription { parts.append(d) }
            if let r = localized.recoverySuggestion { parts.append("Recovery: \(r)") }
        }
        let ns = error as NSError
        if ns.domain != NSCocoaErrorDomain || ns.code != 0 {
            parts.append("Domain: \(ns.domain) code=\(ns.code)")
        }
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
