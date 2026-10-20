import GatteyPhotosCore
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@MainActor
@Observable
final class PhotoImageModel {
    private(set) var image: PlatformThumbnailImage?
    private(set) var isLoading = false
    private(set) var loadFailed = false
    private var loadTask: Task<Void, Never>?
    private var loadedPhotoID: PhotoID?
    private var loadedMaxPixelSize: Int?

    func load(
        photoID: PhotoID,
        maxPixelSize: Int,
        thumbnailWidth: Int? = nil,
        ensureCached: (@MainActor () async -> Void)? = nil
    ) {
        if loadedPhotoID == photoID, loadedMaxPixelSize == maxPixelSize,
            image != nil || loadTask != nil
        {
            return
        }
        let photoChanged = loadedPhotoID != photoID
        loadedPhotoID = photoID
        loadedMaxPixelSize = maxPixelSize
        loadTask?.cancel()
        let url =
            thumbnailWidth.map { AppConfig.thumbnailCacheURL(for: photoID, width: $0) }
            ?? AppConfig.cacheURL(for: photoID)
        if let memoryHit = ImageDownsampler.cachedThumbnail(from: url, maxPixelSize: maxPixelSize) {
            image = memoryHit
            isLoading = false
            loadFailed = false
            loadTask = nil
            return
        }
        if photoChanged {
            image = nil
            loadFailed = false
        }
        isLoading = image == nil
        let requestedID = photoID
        let requestedSize = maxPixelSize
        loadTask = Task {
            var loaded = await Self.readThumbnail(from: url, maxPixelSize: maxPixelSize)
            if loaded == nil, let ensureCached {
                await ensureCached()
                loaded = await Self.readThumbnail(from: url, maxPixelSize: maxPixelSize)
            }
            guard !Task.isCancelled,
                self.loadedPhotoID == requestedID,
                self.loadedMaxPixelSize == requestedSize
            else { return }
            self.image = loaded
            self.isLoading = false
            if loaded == nil {
                self.loadFailed = true
                let path = url.path
                let exists = await Task.detached(priority: .utility) {
                    FileManager.default.fileExists(atPath: path)
                }.value
                ActivityLogStore.shared.log(
                    .gallery,
                    level: .warning,
                    "Could not load cached image",
                    detail: "\(requestedID) maxPx=\(requestedSize) fileExists=\(exists)"
                )
            } else {
                self.loadFailed = false
            }
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        loadedPhotoID = nil
        loadedMaxPixelSize = nil
        isLoading = false
        loadFailed = false
    }

    private static func readThumbnail(from url: URL, maxPixelSize: Int) async -> PlatformThumbnailImage? {
        await Task.detached(priority: .userInitiated) {
            ImageDownsampler.loadThumbnail(from: url, maxPixelSize: maxPixelSize)
        }.value
    }
}

struct CachedPhotoImage: View {
    let photoID: PhotoID
    let maxPixelSize: Int
    var contentMode: ContentMode = .fill
    /// When true, shows a centered spinner while the cache read is in flight.
    var showsLoadingSpinner = false
    /// When set, loads a server-resized thumbnail of this width (grid) instead of the full image.
    var thumbnailWidth: Int? = nil

    @Environment(GalleryStore.self) private var store
    @State private var model = PhotoImageModel()

    private func ensureCached(_ id: PhotoID) async {
        if let thumbnailWidth {
            await store.ensureThumbnailCached(photoID: id, width: thumbnailWidth)
        } else {
            await store.ensurePhotoCached(photoID: id)
        }
    }

    var body: some View {
        Group {
            if let image = model.image {
                platformImage(image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if model.isLoading, showsLoadingSpinner {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.loadFailed {
                ContentUnavailableView {
                    Label("Image not in cache", systemImage: "photo")
                } description: {
                    Text("Sync or download this photo, then reopen.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            model.load(
                photoID: photoID,
                maxPixelSize: maxPixelSize,
                thumbnailWidth: thumbnailWidth,
                ensureCached: { await ensureCached(photoID) }
            )
        }
        .onChange(of: photoID) { _, newID in
            model.load(
                photoID: newID,
                maxPixelSize: maxPixelSize,
                thumbnailWidth: thumbnailWidth,
                ensureCached: { await ensureCached(newID) }
            )
        }
        .onChange(of: maxPixelSize) { _, newSize in
            model.load(
                photoID: photoID,
                maxPixelSize: newSize,
                thumbnailWidth: thumbnailWidth,
                ensureCached: { await ensureCached(photoID) }
            )
        }
    }

    private func platformImage(_ image: PlatformThumbnailImage) -> Image {
        #if os(macOS)
        Image(nsImage: image)
        #elseif os(iOS)
        Image(uiImage: image)
        #endif
    }
}
