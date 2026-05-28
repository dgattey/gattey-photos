import AppKit
import GatteyPhotosCore
import SwiftUI

@MainActor
final class PhotoImageModel: ObservableObject {
    @Published private(set) var image: NSImage?
    private var loadTask: Task<Void, Never>?

    func load(photoID: PhotoID, maxPixelSize: Int) {
        loadTask?.cancel()
        image = nil
        let url = AppConfig.cacheURL(for: photoID)
        loadTask = Task {
            let loaded = await Task.detached(priority: .userInitiated) {
                ImageDownsampler.loadThumbnail(from: url, maxPixelSize: maxPixelSize)
            }.value
            guard !Task.isCancelled else { return }
            self.image = loaded
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }
}

struct CachedPhotoImage: View {
    let photoID: PhotoID
    let maxPixelSize: Int
    var contentMode: ContentMode = .fill

    @StateObject private var model = PhotoImageModel()

    var body: some View {
        Group {
            if let image = model.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .onAppear { model.load(photoID: photoID, maxPixelSize: maxPixelSize) }
        .onChange(of: photoID) { _, newID in
            model.load(photoID: newID, maxPixelSize: maxPixelSize)
        }
        .onDisappear { model.cancel() }
    }
}
