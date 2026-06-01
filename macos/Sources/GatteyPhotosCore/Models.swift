import Foundation

public typealias PhotoID = String

public enum CurrentPhotoUpdatedBy: String, Codable, Sendable {
    case cron
    case manual
}

public enum GalleryDeleteBlockReason: Equatable, Sendable {
    case includesCurrentPhoto
    case wouldRemoveAllPhotos
}

public struct PhotoEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: PhotoID
    public var filename: String
    public var blobPath: String
    public var sizeBytes: Int
    public var updatedAt: String
    public var deletedAt: String?
    /// Family member who uploaded this photo (from server manifest).
    public var uploadedBy: String?
    public var downloadUrl: String?

    public var isDeleted: Bool { deletedAt != nil }
}

public struct GalleryState: Codable, Equatable, Sendable {
    public var version: Int
    public var order: [PhotoID]
    public var photos: [PhotoID: PhotoEntry]
    /// Photo the Bloomin8 frame is showing (synced across clients).
    public var currentPhotoId: PhotoID?
    /// How `currentPhotoId` last changed on the server (`cron` advance vs manual set).
    public var currentPhotoUpdatedBy: CurrentPhotoUpdatedBy?

    public static var empty: GalleryState {
        GalleryState(version: 0, order: [], photos: [:], currentPhotoId: nil)
    }

    public func activePhotos() -> [PhotoEntry] {
        order.compactMap { id in
            guard let p = photos[id], !p.isDeleted else { return nil }
            return p
        }
    }

    public func currentPhoto() -> PhotoEntry? {
        guard let id = currentPhotoId, let p = photos[id], !p.isDeleted else { return nil }
        return p
    }

    /// Why a delete request must be rejected, if any.
    public func deleteBlockReason(for ids: Set<PhotoID>) -> GalleryDeleteBlockReason? {
        let activeIDs = Set(activePhotos().map(\.id))
        let deleting = ids.filter { activeIDs.contains($0) }
        guard !deleting.isEmpty else { return nil }
        if let current = currentPhotoId, deleting.contains(current) {
            return .includesCurrentPhoto
        }
        if activeIDs.count <= deleting.count {
            return .wouldRemoveAllPhotos
        }
        return nil
    }

    /// Active photo ids slated for delete must not include the current photo or remove every active photo.
    public func canDeletePhotos(ids: Set<PhotoID>) -> Bool {
        deleteBlockReason(for: ids) == nil
    }

    /// Whether `photoID` is an active photo that is not already the device current.
    public func canSetAsCurrent(photoID: PhotoID) -> Bool {
        guard activePhotos().contains(where: { $0.id == photoID }) else { return false }
        return currentPhotoId != photoID
    }

    /// Local cache repair; server normalizes `currentPhotoId` on read/write (same rules).
    public func withResolvedCurrentPhoto() -> GalleryState {
        let active = activePhotos()
        guard !active.isEmpty else {
            var next = self
            next.currentPhotoId = nil
            return next
        }
        if let id = currentPhotoId, active.contains(where: { $0.id == id }) {
            return self
        }
        var next = self
        next.currentPhotoId = active[0].id
        return next
    }
}

public struct GalleryResponse: Codable, Sendable {
    public var state: GalleryState
    public var photos: [PhotoEntry]
}

public struct AppSettings: Codable, Sendable {
    /// Production sync API (Vercel). Used when `debugMode` is off and user toggles debug off.
    public static let productionServerBaseURL = SyncServerURLs.productionBaseURL

    /// Sync API base URL implied by `debugMode` (local dev vs production).
    public static func syncServerBaseURL(debugMode: Bool) -> String {
        debugMode ? SyncServerURLs.localDevBaseURL : productionServerBaseURL
    }

    public var serverBaseURL: String
    /// When true, `serverBaseURL` points at local dev (`http://127.0.0.1:3000`). Start API via `./scripts/dev.sh`.
    public var debugMode: Bool
    /// Opaque server-issued session token (persisted). Never the sync password.
    public var syncSessionToken: String
    public var galleryName: String
    /// Shown on unlock; sent as `uploadedBy` on gallery uploads and frame registration.
    public var displayName: String
    /// iPad split: left pane width as a fraction of the gallery split (0.28…0.72). macOS uses intrinsic width from device aspect + height.
    public var previewPaneSplitFraction: Double
    /// Photos per row in the gallery thumbnail grid (fixed column count).
    public var galleryGridColumnCount: Int

    public static let previewPaneSplitFractionDefault: Double = 0.48
    public static let previewPaneSplitFractionMin: Double = 0.28
    public static let previewPaneSplitFractionMax: Double = 0.72

    public static let galleryGridColumnCountDefault: Int = 5
    public static let galleryGridColumnCountMin: Int = 2
    public static let galleryGridColumnCountMax: Int = 8
    /// Reference width when migrating legacy `galleryThumbnailColumnMin` (points).
    private static let galleryGridColumnCountMigrationReferenceWidth: Double = 720
    private static let legacyGalleryThumbnailColumnMinDefault: Double = 140

    public static let defaultDisplayName = "Dylan"

    public static var defaults: AppSettings {
        AppSettings(
            serverBaseURL: productionServerBaseURL,
            debugMode: false,
            syncSessionToken: "",
            galleryName: "default",
            displayName: defaultDisplayName
        )
    }

    enum CodingKeys: String, CodingKey {
        case serverBaseURL, debugMode, syncSessionToken, galleryName, displayName
        // Legacy; never written. Dropped on load.
        case deviceIP
        case bloomin8ApiToken, bloomin8OpenApiBaseURL // legacy; dropped on load, never written
        case previewPaneSplitFraction
        case galleryGridColumnCount
        /// Legacy adaptive minimum width; migrated to `galleryGridColumnCount` on load.
        case galleryThumbnailColumnMin
        // Legacy; never written. Dropped on load.
        case syncPassword
    }

    public init(
        serverBaseURL: String,
        debugMode: Bool = false,
        syncSessionToken: String,
        galleryName: String,
        displayName: String = AppSettings.defaultDisplayName,
        previewPaneSplitFraction: Double = AppSettings.previewPaneSplitFractionDefault,
        galleryGridColumnCount: Int = AppSettings.galleryGridColumnCountDefault
    ) {
        self.serverBaseURL = serverBaseURL
        self.debugMode = debugMode
        self.syncSessionToken = syncSessionToken
        self.galleryName = galleryName
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Self.defaultDisplayName
            : displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.previewPaneSplitFraction = Self.clampedPreviewPaneSplitFraction(previewPaneSplitFraction)
        self.galleryGridColumnCount = Self.clampedGalleryGridColumnCount(galleryGridColumnCount)
    }

    public static func clampedPreviewPaneSplitFraction(_ value: Double) -> Double {
        min(max(value, previewPaneSplitFractionMin), previewPaneSplitFractionMax)
    }

    public static func clampedGalleryGridColumnCount(_ value: Int) -> Int {
        min(max(value, galleryGridColumnCountMin), galleryGridColumnCountMax)
    }

    /// Maps legacy adaptive minimum width to a fixed column count (~720pt grid).
    public static func galleryGridColumnCount(migratingLegacyColumnMin columnMin: Double) -> Int {
        let reference = galleryGridColumnCountMigrationReferenceWidth
        let estimate = reference / max(columnMin, 1)
        return clampedGalleryGridColumnCount(Int(estimate.rounded()))
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.defaults
        serverBaseURL = try c.decodeIfPresent(String.self, forKey: .serverBaseURL) ?? d.serverBaseURL
        debugMode = try c.decodeIfPresent(Bool.self, forKey: .debugMode) ?? d.debugMode
        _ = try c.decodeIfPresent(String.self, forKey: .deviceIP)
        syncSessionToken = try c.decodeIfPresent(String.self, forKey: .syncSessionToken) ?? d.syncSessionToken
        galleryName = try c.decodeIfPresent(String.self, forKey: .galleryName) ?? d.galleryName
        let nameRaw = try c.decodeIfPresent(String.self, forKey: .displayName) ?? Self.defaultDisplayName
        displayName = nameRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Self.defaultDisplayName
            : nameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try c.decodeIfPresent(String.self, forKey: .bloomin8ApiToken)
        _ = try c.decodeIfPresent(String.self, forKey: .bloomin8OpenApiBaseURL)
        let splitRaw = try c.decodeIfPresent(Double.self, forKey: .previewPaneSplitFraction)
            ?? Self.previewPaneSplitFractionDefault
        previewPaneSplitFraction = Self.clampedPreviewPaneSplitFraction(splitRaw)
        if let countRaw = try c.decodeIfPresent(Int.self, forKey: .galleryGridColumnCount) {
            galleryGridColumnCount = Self.clampedGalleryGridColumnCount(countRaw)
        } else {
            let legacyMin = try c.decodeIfPresent(Double.self, forKey: .galleryThumbnailColumnMin)
                ?? Self.legacyGalleryThumbnailColumnMinDefault
            galleryGridColumnCount = Self.galleryGridColumnCount(migratingLegacyColumnMin: legacyMin)
        }
        // Ignore legacy syncPassword — never persisted again.
        _ = try c.decodeIfPresent(String.self, forKey: .syncPassword)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(serverBaseURL, forKey: .serverBaseURL)
        try c.encode(debugMode, forKey: .debugMode)
        try c.encode(syncSessionToken, forKey: .syncSessionToken)
        try c.encode(galleryName, forKey: .galleryName)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(previewPaneSplitFraction, forKey: .previewPaneSplitFraction)
        try c.encode(galleryGridColumnCount, forKey: .galleryGridColumnCount)
    }

    /// Bearer value for sync API calls when a session exists.
    public var syncBearer: String? {
        let t = syncSessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
