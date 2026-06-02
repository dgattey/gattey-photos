import GatteyPhotosCore
import SwiftUI

struct GallerySelectionBar: View {
    @EnvironmentObject private var store: GalleryStore
    @Environment(GallerySelectionStore.self) private var selection
    @Environment(\.galleryDeleteRequest) private var galleryDeleteRequest

    private var count: Int { selection.selectedIDs.count }

    private var selectionLabel: String {
        if count == 1 {
            return "1 photo selected"
        }
        return "\(count) photos selected"
    }

    private var singleSelectedID: PhotoID? {
        guard count == 1 else { return nil }
        return selection.selectedIDs.first
    }

    private func canSetAsCurrent(for id: PhotoID) -> Bool {
        store.canSetAsCurrent(photoID: id) && !store.isBusy
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(selectionLabel)
                .font(AppTypography.sectionTitle)
            Spacer()
            if let id = singleSelectedID {
                Button("Show for today") {
                    Task { await store.setAsCurrent(photoID: id) }
                }
                .galleryPrimaryButtonStyle()
                .disabled(!canSetAsCurrent(for: id))
                .opacity(canSetAsCurrent(for: id) ? 1 : 0.45)
            }
            Button {
                galleryDeleteRequest?(selection.selectedIDs)
            } label: {
                Text("Delete")
            }
            .galleryDestructiveButtonStyle()
            .disabled(store.isBusy || !store.canDeletePhotos(ids: selection.selectedIDs))
            .galleryDestructiveChromeOpacity(
                isEnabled: !store.isBusy && store.canDeletePhotos(ids: selection.selectedIDs)
            )
        }
        .focusEffectDisabled()
        .floatingActionBarStyle()
    }
}
