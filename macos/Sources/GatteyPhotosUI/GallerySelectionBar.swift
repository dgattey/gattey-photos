import GatteyPhotosCore
import SwiftUI

struct GallerySelectionBar: View {
    @Environment(GalleryStore.self) private var store
    @Environment(GallerySelectionStore.self) private var selection
    @Environment(\.galleryDeleteRequest) private var galleryDeleteRequest

    private var count: Int { selection.selectedIDs.count }

    private var selectionLabel: String {
        switch count {
        case 0: return "Select Photos"
        case 1: return "1 photo selected"
        default: return "\(count) photos selected"
        }
    }

    private var singleSelectedID: PhotoID? {
        guard count == 1 else { return nil }
        return selection.selectedIDs.first
    }

    private func canSetAsCurrent(for id: PhotoID) -> Bool {
        store.canSetAsCurrent(photoID: id) && !store.isBusy
    }

    private var canDelete: Bool {
        count > 0 && !store.isBusy && store.canDeletePhotos(ids: selection.selectedIDs)
    }

    var body: some View {
        HStack(spacing: 12) {
            #if os(iOS)
            Button {
                Task { await store.downloadPhotos(ids: selection.selectedIDs) }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
            .galleryBorderedButtonStyle()
            .disabled(count == 0 || store.isBusy)
            #endif
            Text(selectionLabel)
                .font(AppTypography.sectionTitle)
                .contentTransition(.numericText())
            if let id = singleSelectedID {
                Button("Show for Today") {
                    Task { await store.setAsCurrent(photoID: id) }
                }
                .galleryPrimaryButtonStyle()
                .disabled(!canSetAsCurrent(for: id))
                .opacity(canSetAsCurrent(for: id) ? 1 : 0.45)
            }
            Button {
                galleryDeleteRequest?(selection.selectedIDs)
            } label: {
                #if os(iOS)
                Label("Delete", systemImage: "trash")
                    .labelStyle(.iconOnly)
                #else
                Text("Delete")
                #endif
            }
            .galleryDestructiveButtonStyle()
            .disabled(!canDelete)
            .galleryDestructiveChromeOpacity(isEnabled: canDelete)
        }
        .animation(AppAnimation.bouncy, value: count)
        .focusEffectDisabled()
        .floatingActionBarStyle()
    }
}
