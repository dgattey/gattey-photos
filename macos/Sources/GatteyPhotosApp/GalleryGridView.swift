import AppKit
import GatteyPhotosCore
import SwiftUI

struct GalleryGridView: View {
    @EnvironmentObject private var store: GalleryStore

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.activePhotos) { photo in
                    PhotoThumb(photo: photo, isSelected: store.selectedID == photo.id)
                        .onTapGesture {
                            store.selectedID = photo.id
                        }
                        .onDrag {
                            NSItemProvider(object: photo.id as NSString)
                        }
                }
            }
            .padding()
        }
        .navigationTitle("Photos")
        .onDrop(of: [.plainText], isTargeted: nil) { providers, _ in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        let targetID = store.selectedID
        provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, _ in
            guard let data = item as? Data,
                  let draggedID = String(data: data, encoding: .utf8),
                  let targetID,
                  draggedID != targetID else { return }
            Task { @MainActor in
                await store.applyOrder(reorderIDs(draggedID: draggedID, before: targetID, in: store.activePhotos.map(\.id)))
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
            thumbImage
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

    @ViewBuilder
    private var thumbImage: some View {
        let url = AppConfig.cacheURL(for: photo.id)
        if let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else if let remote = photo.downloadUrl, let remoteURL = URL(string: remote) {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color.gray.opacity(0.2)
                }
            }
        } else {
            Color.gray.opacity(0.2)
        }
    }
}
