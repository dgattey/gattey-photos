import GatteyPhotosCore
import SwiftUI

// MARK: - Copy

enum GalleryDeleteCopy {
    static func confirmTitle(count: Int) -> String {
        count == 1 ? "Delete photo?" : "Delete \(count) photos?"
    }

    static func confirmMessage(count: Int) -> String {
        if count == 1 {
            return "This photo will be removed from the gallery."
        }
        return "These photos will be removed from the gallery."
    }

    static let blockedTitle = "Cannot delete"

    static func blockedMessage(reason: GalleryDeleteBlockReason) -> String {
        switch reason {
        case .includesCurrentPhoto:
            "Can't delete the current photo. Show another photo for today first."
        case .wouldRemoveAllPhotos:
            "At least one photo must remain in the gallery."
        }
    }
}

// MARK: - Alert state

enum GalleryDeleteAlert: Identifiable {
    case confirm(count: Int)
    case blocked(GalleryDeleteBlockReason)

    var id: String {
        switch self {
        case .confirm(let count): "confirm-\(count)"
        case .blocked(let reason): "blocked-\(reason)"
        }
    }
}

/// Shared entry for keyboard and toolbar/lightbox delete buttons.
enum GalleryDeleteRequest {
    @MainActor
    static func request(
        photoIDs: Set<PhotoID>,
        store: GalleryStore,
        alert: inout GalleryDeleteAlert?
    ) {
        guard !photoIDs.isEmpty, !store.isBusy else { return }
        if let reason = store.state.deleteBlockReason(for: photoIDs) {
            alert = .blocked(reason)
        } else {
            alert = .confirm(count: photoIDs.count)
        }
    }
}

// MARK: - Environment (buttons → same confirmation as keyboard)

private struct GalleryDeleteRequestKey: EnvironmentKey {
    static let defaultValue: ((Set<PhotoID>) -> Void)? = nil
}

extension EnvironmentValues {
    /// Presents the gallery delete confirmation (or blocked alert) for the given IDs.
    var galleryDeleteRequest: ((Set<PhotoID>) -> Void)? {
        get { self[GalleryDeleteRequestKey.self] }
        set { self[GalleryDeleteRequestKey.self] = newValue }
    }
}

// MARK: - Backspace / Delete key + shared confirmation

/// Handles Backspace (`.delete`) and forward-delete (`.deleteForward`) with a confirmation step.
struct GalleryDeleteHandling: ViewModifier {
    @EnvironmentObject private var store: GalleryStore
    @Environment(GallerySelectionStore.self) private var selection
    let photoIDs: Set<PhotoID>

    @State private var alert: GalleryDeleteAlert?
    /// IDs frozen when the confirmation opens so selection changes cannot widen the delete batch.
    @State private var pendingDeleteIDs: Set<PhotoID>?
    @State private var lastKeyboardDeleteRequest = Date.distantPast

    func body(content: Content) -> some View {
        content
            .environment(\.galleryDeleteRequest, requestDelete(photoIDs:))
            #if os(macOS)
        .onDeleteCommand {
            _ = triggerDeleteFromKeyboard()
        }
            #else
        .onKeyPress(.delete) { handleDeleteKey() }
        .onKeyPress(.deleteForward) { handleDeleteKey() }
            #endif
            .galleryDeleteAlertPresentation(
                photoIDs: photoIDs,
                alert: $alert,
                onConfirm: performConfirmedDelete,
                onCancel: cancelPendingDelete
            )
    }

    private func cancelPendingDelete() {
        alert = nil
        pendingDeleteIDs = nil
    }

    private func requestDelete(photoIDs ids: Set<PhotoID>) {
        guard !ids.isEmpty else { return }
        pendingDeleteIDs = ids
        GalleryDeleteRequest.request(photoIDs: ids, store: store, alert: &alert)
        if alert == nil {
            pendingDeleteIDs = nil
        }
    }

    private func handleDeleteKey() -> KeyPress.Result {
        guard triggerDeleteFromKeyboard() else { return .ignored }
        return .handled
    }

    /// Shared by `onKeyPress` (iOS) and macOS `onDeleteCommand` (Edit → Delete / keyboard Delete).
    @discardableResult
    private func triggerDeleteFromKeyboard() -> Bool {
        guard !photoIDs.isEmpty, !store.isBusy else { return false }
        let now = Date()
        guard now.timeIntervalSince(lastKeyboardDeleteRequest) >= 0.35 else { return false }
        lastKeyboardDeleteRequest = now
        if case .confirm = alert { return true }
        requestDelete(photoIDs: photoIDs)
        return true
    }

    private func performConfirmedDelete() {
        let ids = pendingDeleteIDs ?? photoIDs
        pendingDeleteIDs = nil
        alert = nil
        guard !ids.isEmpty, !store.isBusy else { return }
        dismissLightboxIfDeletingOpenPhoto(ids: ids)
        Task { await store.deletePhotos(ids: ids) }
    }

    private func dismissLightboxIfDeletingOpenPhoto(ids: Set<PhotoID>) {
        guard let open = selection.presentedLightboxPhotoID, ids.contains(open) else { return }
        selection.closeLightbox()
    }
}

extension View {
    fileprivate func galleryDeleteAlertPresentation(
        photoIDs: Set<PhotoID>,
        alert: Binding<GalleryDeleteAlert?>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        confirmationDialog(
            alertConfirmTitle(alert: alert.wrappedValue, fallbackCount: photoIDs.count),
            isPresented: confirmPresented(alert: alert, onCancel: onCancel),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onConfirm)
            Button("Cancel", role: .cancel, action: onCancel)
        } message: {
            Text(alertConfirmMessage(alert: alert.wrappedValue, fallbackCount: photoIDs.count))
        }
        .alert(GalleryDeleteCopy.blockedTitle, isPresented: blockedPresented(alert: alert, onCancel: onCancel)) {
            Button("OK", role: .cancel, action: onCancel)
        } message: {
            Text(blockedAlertMessage(alert: alert.wrappedValue))
        }
    }

    fileprivate func confirmPresented(alert: Binding<GalleryDeleteAlert?>, onCancel: @escaping () -> Void) -> Binding<
        Bool
    > {
        Binding(
            get: {
                if case .confirm = alert.wrappedValue { return true }
                return false
            },
            set: { if !$0, case .confirm = alert.wrappedValue { onCancel() } }
        )
    }

    fileprivate func blockedPresented(alert: Binding<GalleryDeleteAlert?>, onCancel: @escaping () -> Void) -> Binding<
        Bool
    > {
        Binding(
            get: {
                if case .blocked = alert.wrappedValue { return true }
                return false
            },
            set: { if !$0, case .blocked = alert.wrappedValue { onCancel() } }
        )
    }

    fileprivate func blockedAlertMessage(alert: GalleryDeleteAlert?) -> String {
        if case .blocked(let reason) = alert {
            return GalleryDeleteCopy.blockedMessage(reason: reason)
        }
        return GalleryDeleteCopy.blockedMessage(reason: .wouldRemoveAllPhotos)
    }

    fileprivate func alertConfirmTitle(alert: GalleryDeleteAlert?, fallbackCount: Int) -> String {
        if case .confirm(let count) = alert {
            return GalleryDeleteCopy.confirmTitle(count: count)
        }
        return GalleryDeleteCopy.confirmTitle(count: fallbackCount)
    }

    fileprivate func alertConfirmMessage(alert: GalleryDeleteAlert?, fallbackCount: Int) -> String {
        if case .confirm(let count) = alert {
            return GalleryDeleteCopy.confirmMessage(count: count)
        }
        return GalleryDeleteCopy.confirmMessage(count: fallbackCount)
    }
}

extension View {
    /// Backspace / Delete keys and `galleryDeleteRequest` use the same confirmation, then `GalleryStore.deletePhotos`.
    func galleryDeleteHandling(photoIDs: Set<PhotoID>) -> some View {
        modifier(GalleryDeleteHandling(photoIDs: photoIDs))
    }

    /// Backspace / Delete keys request confirmation, then call `GalleryStore.deletePhotos`.
    func galleryDeleteKeyboard(photoIDs: Set<PhotoID>) -> some View {
        galleryDeleteHandling(photoIDs: photoIDs)
    }
}

// MARK: - Return / Enter / Space opens lightbox

private struct GalleryOpenLightboxKeyboardHandling: ViewModifier {
    @Environment(GallerySelectionStore.self) private var selection
    let isEnabled: Bool
    let photoOrder: [PhotoID]

    func body(content: Content) -> some View {
        content
            .onKeyPress(.return) { handleOpenLightboxKey() }
            .onKeyPress(.space) { handleOpenLightboxKey() }
    }

    private func handleOpenLightboxKey() -> KeyPress.Result {
        guard isEnabled, !selection.selectedIDs.isEmpty else { return .ignored }
        selection.openLightboxFromSelection(photoOrder: photoOrder)
        return selection.isLightboxOpen ? .handled : .ignored
    }
}

extension View {
    /// Return / Enter / Space opens the lightbox for the current grid selection (same target as double-click).
    func galleryOpenLightboxKeyboard(isEnabled: Bool, photoOrder: [PhotoID]) -> some View {
        modifier(GalleryOpenLightboxKeyboardHandling(isEnabled: isEnabled, photoOrder: photoOrder))
    }
}

// MARK: - Escape clears grid selection

private struct GalleryClearSelectionKeyboardHandling: ViewModifier {
    @Environment(GallerySelectionStore.self) private var selection
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .onKeyPress(.escape) { handleEscapeKey() }
            #if os(macOS)
        .onExitCommand { handleEscapeCommand() }
            #endif
    }

    private func handleEscapeKey() -> KeyPress.Result {
        guard isEnabled, !selection.selectedIDs.isEmpty else { return .ignored }
        selection.clearSelection()
        return .handled
    }

    #if os(macOS)
    private func handleEscapeCommand() {
        guard isEnabled, !selection.selectedIDs.isEmpty else { return }
        selection.clearSelection()
    }
    #endif
}

extension View {
    /// Escape clears bulk selection when the grid is focused and the lightbox is closed.
    func galleryClearSelectionKeyboard(isEnabled: Bool) -> some View {
        modifier(GalleryClearSelectionKeyboardHandling(isEnabled: isEnabled))
    }
}

// MARK: - Grid arrow selection (lightbox closed)

private struct GalleryArrowSelectionKeyboardHandling: ViewModifier {
    @EnvironmentObject private var store: GalleryStore
    @Environment(GallerySelectionStore.self) private var selection
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .onKeyPress(.leftArrow) { handleArrow(horizontal: -1, vertical: 0) }
            .onKeyPress(.rightArrow) { handleArrow(horizontal: 1, vertical: 0) }
            .onKeyPress(.upArrow) { handleArrow(horizontal: 0, vertical: -1) }
            .onKeyPress(.downArrow) { handleArrow(horizontal: 0, vertical: 1) }
    }

    private func handleArrow(horizontal: Int, vertical: Int) -> KeyPress.Result {
        guard isEnabled else { return .ignored }
        let order = store.activePhotos.map(\.id)
        let columns = store.settings.galleryGridColumnCount
        guard
            selection.navigateGridSelection(
                horizontalDelta: horizontal,
                verticalDelta: vertical,
                photoOrder: order,
                columnCount: columns
            )
        else { return .ignored }
        return .handled
    }
}

extension View {
    /// Arrow keys move grid selection when the lightbox is closed (order matches `activePhotos` / grid rows).
    func galleryArrowSelectionKeyboard(isEnabled: Bool) -> some View {
        modifier(GalleryArrowSelectionKeyboardHandling(isEnabled: isEnabled))
    }
}

// MARK: - Lightbox left/right arrows

private struct GalleryLightboxArrowKeyboardHandling: ViewModifier {
    @EnvironmentObject private var store: GalleryStore
    @Environment(GallerySelectionStore.self) private var selection

    func body(content: Content) -> some View {
        content
            .onKeyPress(.leftArrow) { handleArrow(delta: -1) }
            .onKeyPress(.rightArrow) { handleArrow(delta: 1) }
    }

    private func handleArrow(delta: Int) -> KeyPress.Result {
        guard selection.isLightboxOpen else { return .ignored }
        let order = store.activePhotos.map(\.id)
        guard selection.navigateLightbox(by: delta, photoOrder: order) else { return .ignored }
        return .handled
    }
}

extension View {
    /// Left/right arrows move between photos in `activePhotos` order while the lightbox is open.
    func galleryLightboxArrowKeyboard() -> some View {
        modifier(GalleryLightboxArrowKeyboardHandling())
    }
}
