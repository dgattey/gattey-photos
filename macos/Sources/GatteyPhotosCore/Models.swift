import Foundation

public typealias PhotoID = String

public struct PhotoEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: PhotoID
    public var filename: String
    public var blobPath: String
    public var sizeBytes: Int
    public var updatedAt: String
    public var deletedAt: String?
    public var downloadUrl: String?

    public var isDeleted: Bool { deletedAt != nil }
}

public struct GalleryState: Codable, Equatable, Sendable {
    public var version: Int
    public var order: [PhotoID]
    public var photos: [PhotoID: PhotoEntry]

    public static var empty: GalleryState {
        GalleryState(version: 0, order: [], photos: [:])
    }

    public func activePhotos() -> [PhotoEntry] {
        order.compactMap { id in
            guard let p = photos[id], !p.isDeleted else { return nil }
            return p
        }
    }
}

public struct GalleryResponse: Codable, Sendable {
    public var state: GalleryState
    public var photos: [PhotoEntry]
}

public struct AppSettings: Codable, Sendable {
    public var deviceIP: String
    public var serverBaseURL: String
    public var syncPassword: String
    public var galleryName: String

    public static var defaults: AppSettings {
        AppSettings(
            deviceIP: "192.168.1.100",
            serverBaseURL: "http://127.0.0.1:3000",
            syncPassword: "",
            galleryName: "default"
        )
    }
}
