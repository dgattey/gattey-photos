import AppKit
import GatteyPhotosCore
import SwiftUI
import UniformTypeIdentifiers

struct GalleryGridView: View {
    @EnvironmentObject private var store: GalleryStore
    @State private var isFileDropTargeted = false

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12),
    ]

    private let fileDropTypes: [UTType] = [.jpeg, .image, .fileURL]

    var body: some View {
        ZStack {
            ScrollView {
                if store.activePhotos.isEmpty {
                    ContentUnavailableView {
                        Label("Drop photos to upload", systemImage: "photo.badge.plus")
                    } description: {
                        Text("JPEG images from Finder, or use Add in the toolbar.")
                    }
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.activePhotos) { photo in
                            PhotoThumb(photo: photo, isSelected: store.selectedID == photo.id)
                                .onTapGesture {
                                    store.selectedID = photo.id
                                }
                                .onDrag {
                                    NSItemProvider(object: photo.id as NSString)
                                }
                                .onDrop(of: [.plainText], isTargeted: nil) { providers, _ in
                                    handleReorderDrop(providers: providers, onto: photo.id)
                                }
                        }
                    }
                    .padding()
                }
            }

            if isFileDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundStyle(Color.accentColor)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle("Gattey Photos")
        .onDrop(of: fileDropTypes, isTargeted: $isFileDropTargeted) { providers, _ in
            handleFileDrop(providers: providers)
        }
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        Task { @MainActor in
            await store.uploadFromDrop(providers: providers)
        }
        return true
    }

    private func handleReorderDrop(providers: [NSItemProvider], onto targetID: PhotoID) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
            let draggedID: String? = {
                if let data = item as? Data { return String(data: data, encoding: .utf8) }
                if let s = item as? String { return s }
                if let s = item as? NSString { return s as String }
                return nil
            }()
            guard let draggedID, draggedID != targetID else { return }
            Task { @MainActor in
                await store.applyOrder(
                    reorderIDs(draggedID: draggedID, before: targetID, in: store.activePhotos.map(\.id))
                )
            }
        }
        return true
    }

    private func reorderIDs(draggedID: PhotoID, before targetID: PhotoID, in order: [PhotoID]) -> [PhotoID] {
        var next = order
        guard let fromIndex = next.firstIndex(of: draggedID),
              let toIndex = next.firstIndex(of: targetID) else { return order }
        next.remove(at: fromIndex)
        next.insert(draggedID, at: toIndex)
        return next
    }
}

struct PhotoThumb: View {
    let photo: PhotoEntry
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedPhotoImage(photoID: photo.id, maxPixelSize: 280, contentMode: .fill)
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .clipped()
                .cornerRadius(8)
            Text(photo.filename)
                .font(.caption2)
                .lineLimit(1)
                .padding(6)
                .background(.black.opacity(0.45))
                .foregroundStyle(.white)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
        }
    }
}
