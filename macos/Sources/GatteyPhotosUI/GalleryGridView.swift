import GatteyPhotosCore
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

import PhotosUI

struct GalleryGridView: View {
    @Environment(AppChromeState.self) private var chrome
    @Environment(GallerySelectionStore.self) private var selection
    @EnvironmentObject private var store: GalleryStore
    @FocusState private var gridDeleteKeyFocus: Bool
    @State private var showSettings = false
    @State private var isFileDropTargeted = false
    @State private var dropInsertionIndex: Int?
    @State private var pickerItems: [PhotosPickerItem] = []

    #if os(macOS)
    private let fileDropTypes: [UTType] = [.jpeg, .image, .fileURL]
    #endif

    var body: some View {
        @Bindable var chrome = chrome
        galleryShell
            .inspector(isPresented: $chrome.showActivityInspector) {
                ActivityLogPaneView()
            }
    }

    private var galleryShell: some View {
        PreviewGallerySplit {
            thumbnailGridColumn
        }
        #if os(macOS)
        .navigationTitle("")
        #else
        .navigationTitle("Gattey Photos")
        #endif
        .toolbar {
            #if os(macOS)
            // Unified toolbar: hide SwiftUI/.navigationTitle duplicate (see `.toolbar(removing: .title)`)
            // and `WindowChromeConfigurator` title visibility. Leading title via `.navigation` only;
            // gallery actions follow a flexible spacer — `.primaryAction` is leading on macOS.
            GalleryToolbarLeadingCluster(
                photoCount: store.activePhotos.count,
                isBootstrapping: store.isBootstrappingGallery
            )
            GalleryMacOSToolbarFlexSpacer()
            #else
            ToolbarItem(placement: .principal) {
                Text(
                    GalleryToolbarLeadingTitle.photoCountLabel(
                        store.activePhotos.count,
                        isBootstrapping: store.isBootstrappingGallery
                    )
                )
                .font(AppTypography.toolbarTitle)
            }
            #endif
            GalleryMainToolbar(
                showSettings: $showSettings,
                pickerItems: $pickerItems
            )
        }
        #if os(macOS)
        .modifier(GalleryMacOSToolbarTitleRemoval())
        .overlay(alignment: .top) {
            VariableBlurView(maxBlurRadius: 4, direction: .blurredTopClearBottom)
                .frame(height: 68)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
        #endif
        #if os(macOS)
        // Fallback for chrome outside the grid; populated grids use AppKit targets (see thumbnailGridColumn).
        .onDrop(of: fileDropTypes, isTargeted: $isFileDropTargeted) { providers, _ in
            handleFileDrop(providers: providers)
        }
        #endif
        #if os(iOS)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            let batch = items
            pickerItems = []
            Task { await uploadPickedItems(batch) }
        }
        #endif
        .focusable()
        .focusEffectDisabled()
        .focused($gridDeleteKeyFocus)
        .galleryDeleteKeyboard(photoIDs: gridDeleteKeyPhotoIDs)
        .galleryOpenLightboxKeyboard(
            isEnabled: galleryGridKeyboardEnabled,
            photoOrder: store.activePhotos.map(\.id)
        )
        .galleryClearSelectionKeyboard(isEnabled: galleryGridKeyboardEnabled)
        .galleryArrowSelectionKeyboard(isEnabled: galleryGridKeyboardEnabled)
        .onChange(of: gridDeleteKeyPhotoIDs) { _, _ in
            syncGridKeyboardFocus()
        }
        .onChange(of: selection.isLightboxOpen) { _, _ in
            syncGridKeyboardFocus()
        }
        .onChange(of: showSettings) { _, _ in
            syncGridKeyboardFocus()
        }
        .onAppear {
            syncGridKeyboardFocus()
        }
    }

    private var galleryGridKeyboardEnabled: Bool {
        !selection.isLightboxOpen && !showSettings
    }

    private var gridLayoutWidth: CGFloat {
        max(gridViewportWidth, 1)
    }

    private var gridViewportMinHeight: CGFloat {
        max(gridViewportHeight > 0 ? gridViewportHeight : 600, 280)
    }

    private var gridDeleteKeyPhotoIDs: Set<PhotoID> {
        guard galleryGridKeyboardEnabled else { return [] }
        return selection.selectedIDs
    }

    @State private var gridViewportWidth: CGFloat = 0
    @State private var gridViewportHeight: CGFloat = 0

    @ViewBuilder
    private var thumbnailGridColumn: some View {
        ZStack {
            ScrollView {
                ZStack(alignment: .top) {
                    #if os(macOS)
                    GalleryFileDropTarget(
                        onDrop: handleFileURLDrop,
                        isTargeted: $isFileDropTargeted
                    )
                    .frame(maxWidth: .infinity, minHeight: gridViewportMinHeight)
                    #endif

                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: gridViewportMinHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { clearSelectionFromBackgroundTap() }

                    if store.isBootstrappingGallery {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Loading photos from server…")
                                .font(AppTypography.secondary)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 280)
                    } else if store.activePhotos.isEmpty {
                        ContentUnavailableView {
                            Label("Drop photos to upload", systemImage: "photo.badge.plus")
                        } description: {
                            Text("JPEG images from Finder, or use Add in the toolbar.")
                        }
                        .frame(maxWidth: .infinity, minHeight: 280)
                    } else {
                        #if os(macOS)
                        GalleryPhotoGrid(
                            gridContainerWidth: gridLayoutWidth,
                            currentPhotoID: store.state.currentPhotoId,
                            deviceScreenAspectRatio: store.deviceScreenAspectRatio,
                            dropInsertionIndex: $dropInsertionIndex,
                            onSelectPhoto: handleGridPhotoTap,
                            onOpenLightbox: { store.selection.openLightbox($0) },
                            onReorderDrop: handleReorderDrop,
                            onFileDrop: handleFileURLDrop,
                            onFileDropTargeted: { isFileDropTargeted = $0 }
                        )
                        #else
                        GalleryPhotoGrid(
                            gridContainerWidth: gridLayoutWidth,
                            currentPhotoID: store.state.currentPhotoId,
                            deviceScreenAspectRatio: store.deviceScreenAspectRatio,
                            dropInsertionIndex: $dropInsertionIndex,
                            onSelectPhoto: handleGridPhotoTap,
                            onOpenLightbox: { store.selection.openLightbox($0) },
                            onReorderDrop: handleReorderDrop
                        )
                        #endif
                    }
                }
                .frame(maxWidth: .infinity, minHeight: gridViewportMinHeight)
            }
            #if os(macOS)
            .galleryMacOSGridScrollEdgeEffect()
            #endif
            .background {
                GeometryReader { viewport in
                    Color.clear
                        .onAppear {
                            gridViewportWidth = viewport.size.width
                            gridViewportHeight = viewport.size.height
                        }
                        .onChange(of: viewport.size.width) { _, width in
                            gridViewportWidth = width
                        }
                        .onChange(of: viewport.size.height) { _, height in
                            gridViewportHeight = height
                        }
                }
            }

            #if os(macOS)
            if isFileDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundStyle(AppBrandColor.accentGreen)
                    .padding(8)
                    .allowsHitTesting(false)
            }
            #endif
        }
        .overlay(alignment: .bottom) {
            ThumbnailGridSelectionChrome()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Keeps keyboard shortcuts (delete, arrows, return, escape) on the gallery shell while the lightbox and settings are closed.
    private func syncGridKeyboardFocus() {
        let shouldFocus = galleryGridKeyboardEnabled && !store.activePhotos.isEmpty
        if shouldFocus {
            // Defer until after AppKit grid click handling so SwiftUI focus sticks.
            Task { @MainActor in
                gridDeleteKeyFocus = true
            }
        } else {
            gridDeleteKeyFocus = false
        }
    }

    private func handleGridPhotoTap(for id: PhotoID, modifiers: GridTapModifiers) {
        store.selection.selectPhoto(
            id,
            append: modifiers.append,
            rangeSelect: modifiers.rangeSelect,
            photoOrder: store.activePhotos.map(\.id)
        )
        if !store.selection.isLightboxOpen {
            syncGridKeyboardFocus()
        }
    }

    #if os(iOS)
    private func uploadPickedItems(_ items: [PhotosPickerItem]) async {
        var urls: [URL] = []
        for (index, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("upload-\(index)-\(UUID().uuidString).jpg")
            guard (try? data.write(to: url, options: .atomic)) != nil else { continue }
            urls.append(url)
        }
        guard !urls.isEmpty else { return }
        await store.uploadFiles(urls: urls)
    }
    #endif

    private func clearSelectionFromBackgroundTap() {
        guard !store.selection.isLightboxOpen else { return }
        store.selection.clearSelection()
    }

    #if os(macOS)
    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        Task { @MainActor in
            await store.uploadFromDrop(providers: providers)
        }
        return true
    }

    private func handleFileURLDrop(_ urls: [URL]) -> Bool {
        Task { @MainActor in
            await store.uploadFiles(urls: urls)
        }
        return true
    }
    #endif

    private func handleReorderDrop(draggedIDs: [String], insertionIndex: Int) -> Bool {
        guard let draggedID = draggedIDs.first else { return false }
        let order = store.activePhotos.map(\.id)
        let next = PhotoManifestReorder.applyingMove(
            draggedID: draggedID,
            insertionIndex: insertionIndex,
            in: order
        )
        guard next != order else { return false }
        dropInsertionIndex = nil
        Task { await store.applyOrder(next) }
        return true
    }
}

/// Bulk-selection bar anchored to the thumbnail grid column only.
private struct ThumbnailGridSelectionChrome: View {
    @Environment(GallerySelectionStore.self) private var selection

    private var showsSelectionBar: Bool {
        !selection.selectedIDs.isEmpty && !selection.isLightboxOpen
    }

    var body: some View {
        Group {
            if showsSelectionBar {
                BottomFloatingChrome {
                    GallerySelectionBar()
                }
                .transition(.opacity.combined(with: .offset(y: 20)))
            }
        }
        .animation(AppAnimation.bouncy, value: showsSelectionBar)
        .allowsHitTesting(showsSelectionBar)
    }
}

/// Grid layout and gallery list only — does not observe selection (per-cell views do).
private struct GalleryPhotoGrid: View {
    @EnvironmentObject private var store: GalleryStore
    let gridContainerWidth: CGFloat
    let currentPhotoID: PhotoID?
    let deviceScreenAspectRatio: CGFloat
    @Binding var dropInsertionIndex: Int?
    let onSelectPhoto: (PhotoID, GridTapModifiers) -> Void
    let onOpenLightbox: (PhotoID) -> Void
    let onReorderDrop: ([String], Int) -> Bool
    #if os(macOS)
    let onFileDrop: ([URL]) -> Bool
    let onFileDropTargeted: (Bool) -> Void
    #endif

    /// Width used for thumb downsample budget; lags live geometry during window resize.
    @State private var settledGridWidth: CGFloat = 0
    @State private var gridWidthDebounceTask: Task<Void, Never>?

    private var columnCount: Int {
        store.settings.galleryGridColumnCount
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: columnCount)
    }

    private var layoutGridWidth: CGFloat {
        settledGridWidth > 0 ? settledGridWidth : gridContainerWidth
    }

    private var cellWidth: CGFloat {
        max(1, layoutGridWidth / CGFloat(columnCount))
    }

    private var thumbMaxPixelSize: Int {
        GalleryThumbSizing.maxPixelSize(
            cellWidth: cellWidth,
            cellHeight: cellWidth / thumbAspectRatio
        )
    }

    /// Width ÷ height for SwiftUI `.aspectRatio` (portrait Bloomin8 panel).
    private var thumbAspectRatio: CGFloat {
        let r = deviceScreenAspectRatio
        return r > 0 ? min(r, 1) : Bloomin8Screen.defaultAspectRatio
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 0) {
            ForEach(Array(store.activePhotos.enumerated()), id: \.element.id) { index, photo in
                gridItem(index: index, photo: photo)
            }
        }
        .onAppear {
            settledGridWidth = gridContainerWidth
        }
        .onChange(of: gridContainerWidth) { _, width in
            scheduleGridWidthSettle(width)
        }
        .onChange(of: columnCount) { _, _ in
            gridWidthDebounceTask?.cancel()
            settledGridWidth = gridContainerWidth
        }
    }

    private func scheduleGridWidthSettle(_ width: CGFloat) {
        gridWidthDebounceTask?.cancel()
        gridWidthDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            settledGridWidth = width
        }
    }

    @ViewBuilder
    private func gridItem(index: Int, photo: PhotoEntry) -> some View {
        #if os(macOS)
        PhotoGridItem(
            photo: photo,
            photoIndex: index,
            photoCount: store.activePhotos.count,
            thumbAspectRatio: thumbAspectRatio,
            thumbMaxPixelSize: thumbMaxPixelSize,
            isCurrentOnDevice: currentPhotoID == photo.id,
            dropInsertionIndex: dropInsertionIndex,
            onSelectPhoto: onSelectPhoto,
            onOpenLightbox: onOpenLightbox,
            onReorderDrop: onReorderDrop,
            onFileDrop: onFileDrop,
            onFileDropTargeted: onFileDropTargeted,
            onDropInsertionIndexChange: { gap in
                dropInsertionIndex = gap
            }
        )
        #else
        PhotoGridItem(
            photo: photo,
            photoIndex: index,
            photoCount: store.activePhotos.count,
            thumbAspectRatio: thumbAspectRatio,
            thumbMaxPixelSize: thumbMaxPixelSize,
            isCurrentOnDevice: currentPhotoID == photo.id,
            dropInsertionIndex: dropInsertionIndex,
            onSelectPhoto: onSelectPhoto,
            onOpenLightbox: onOpenLightbox,
            onReorderDrop: onReorderDrop,
            onDropInsertionIndexChange: { gap in
                dropInsertionIndex = gap
            }
        )
        #endif
    }
}

/// One grid cell: observes selection for this photo only.
private struct PhotoGridItem: View {
    @Environment(GallerySelectionStore.self) private var selection
    @EnvironmentObject private var store: GalleryStore
    let photo: PhotoEntry
    let photoIndex: Int
    let photoCount: Int
    let thumbAspectRatio: CGFloat
    let thumbMaxPixelSize: Int
    var isCurrentOnDevice: Bool = false
    let dropInsertionIndex: Int?
    let onSelectPhoto: (PhotoID, GridTapModifiers) -> Void
    let onOpenLightbox: (PhotoID) -> Void
    let onReorderDrop: ([String], Int) -> Bool
    #if os(macOS)
    let onFileDrop: ([URL]) -> Bool
    let onFileDropTargeted: (Bool) -> Void
    #endif
    let onDropInsertionIndexChange: (Int?) -> Void

    private var isSelected: Bool {
        selection.isSelected(photo.id)
    }

    private var showsInsertionLineBefore: Bool {
        dropInsertionIndex == photoIndex
    }

    private var showsInsertionLineAfter: Bool {
        dropInsertionIndex == photoIndex + 1
    }

    var body: some View {
        PhotoThumb(
            photo: photo,
            thumbAspectRatio: thumbAspectRatio,
            thumbMaxPixelSize: thumbMaxPixelSize,
            isSelected: isSelected,
            isCurrentOnDevice: isCurrentOnDevice,
            cornerTag: store.showingTag(for: photo.id),
            showsInsertionLineBefore: showsInsertionLineBefore,
            showsInsertionLineAfter: showsInsertionLineAfter
        )
        .contentShape(Rectangle())
        .galleryPhotoContextMenu(photoID: photo.id)
        #if os(macOS)
        .overlay {
            PhotoGridClickTarget(
                photoID: photo.id,
                photoIndex: photoIndex,
                photoCount: photoCount,
                onSelect: { onSelectPhoto(photo.id, GridTapModifiers($0)) },
                onOpenLightbox: { onOpenLightbox(photo.id) },
                onReorderDrop: onReorderDrop,
                onFileDrop: onFileDrop,
                onFileDropTargeted: onFileDropTargeted,
                onDropInsertionIndexChange: onDropInsertionIndexChange,
                onReorderDragEnded: { onDropInsertionIndexChange(nil) }
            )
        }
        #else
        .onTapGesture(count: 2) {
            onOpenLightbox(photo.id)
        }
        .onTapGesture(count: 1) {
            onSelectPhoto(photo.id, GridTapModifiers.current)
        }
        .draggable(photo.id)
        .overlay {
            GalleryReorderDropHalves(
                photoIndex: photoIndex,
                photoCount: photoCount,
                onReorderDrop: onReorderDrop,
                onDropInsertionIndexChange: onDropInsertionIndexChange
            )
        }
        #endif
    }
}

#if os(iOS)
/// Leading/trailing drop halves so reorder uses gap insertion (SwiftUI `dropDestination`).
private struct GalleryReorderDropHalves: View {
    let photoIndex: Int
    let photoCount: Int
    let onReorderDrop: ([String], Int) -> Bool
    let onDropInsertionIndexChange: (Int?) -> Void

    var body: some View {
        HStack(spacing: 0) {
            reorderHalf(insertionIndex: photoIndex)
            reorderHalf(insertionIndex: photoIndex + 1)
        }
        .allowsHitTesting(true)
    }

    private func reorderHalf(insertionIndex: Int) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { items, _ in
                onReorderDrop(items, insertionIndex)
            } isTargeted: { targeted in
                if targeted {
                    onDropInsertionIndexChange(insertionIndex)
                } else {
                    onDropInsertionIndexChange(nil)
                }
            }
    }
}
#endif

#if os(macOS)
// MARK: - Grid cell click (mouseDown select; no SwiftUI tap/double-tap competition)

/// Finder-style: select on `mouseDown`; double-click opens lightbox without delaying the first click.
private struct PhotoGridClickTarget: NSViewRepresentable {
    let photoID: PhotoID
    let photoIndex: Int
    let photoCount: Int
    var onSelect: (NSEvent.ModifierFlags) -> Void
    var onOpenLightbox: () -> Void
    var onReorderDrop: ([String], Int) -> Bool
    var onFileDrop: ([URL]) -> Bool
    var onFileDropTargeted: (Bool) -> Void
    var onDropInsertionIndexChange: (Int?) -> Void
    var onReorderDragEnded: () -> Void

    func makeNSView(context: Context) -> PhotoGridClickNSView {
        let view = PhotoGridClickNSView()
        sync(into: view)
        return view
    }

    func updateNSView(_ nsView: PhotoGridClickNSView, context: Context) {
        sync(into: nsView)
    }

    private func sync(into view: PhotoGridClickNSView) {
        view.photoID = photoID
        view.photoIndex = photoIndex
        view.photoCount = photoCount
        view.onSelect = onSelect
        view.onOpenLightbox = onOpenLightbox
        view.onReorderDrop = onReorderDrop
        view.onFileDrop = onFileDrop
        view.onFileDropTargeted = onFileDropTargeted
        view.onDropInsertionIndexChange = onDropInsertionIndexChange
        view.onReorderDragEnded = onReorderDragEnded
    }
}

/// macOS: Finder-style clicks + AppKit drag/drop — SwiftUI `.draggable` / `.dropDestination` do not receive
/// `NSDraggingSession` pasteboard writes from this overlay. iOS uses SwiftUI halves + `dropDestination` instead.
private final class PhotoGridClickNSView: NSView, NSDraggingSource {
    var photoID: PhotoID?
    var photoIndex: Int = 0
    var photoCount: Int = 0
    var onSelect: ((NSEvent.ModifierFlags) -> Void)?
    var onOpenLightbox: (() -> Void)?
    var onReorderDrop: (([String], Int) -> Bool)?
    var onFileDrop: (([URL]) -> Bool)?
    var onFileDropTargeted: ((Bool) -> Void)?
    var onDropInsertionIndexChange: ((Int?) -> Void)?
    var onReorderDragEnded: (() -> Void)?

    private var dragDownLocation: NSPoint?
    private var didBeginReorderDrag = false
    private var pendingInsertionIndex: Int?

    private static let reorderDragThreshold: CGFloat = 4

    private static var draggedTypes: [NSPasteboard.PasteboardType] {
        PhotoDragPasteboard.draggedTypes + GalleryFilePasteboard.draggedTypes
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(Self.draggedTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(Self.draggedTypes)
    }

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var mouseDownCanMoveWindow: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard Self.receivesPrimaryMouse(for: NSApp.currentEvent) else { return nil }
        return super.hitTest(point)
    }

    /// Let SwiftUI `.contextMenu` on the thumb receive right-click and control-click.
    private static func receivesPrimaryMouse(for event: NSEvent?) -> Bool {
        guard let event else { return true }
        switch event.type {
        case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
            return false
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged:
            return !event.modifierFlags.contains(.control)
        default:
            return true
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragDownLocation = event.locationInWindow
        didBeginReorderDrag = false

        if event.clickCount == 2 {
            onOpenLightbox?()
            return
        }
        if event.clickCount == 1 {
            onSelect?(event.modifierFlags)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didBeginReorderDrag, let start = dragDownLocation else { return }
        let dx = event.locationInWindow.x - start.x
        let dy = event.locationInWindow.y - start.y
        guard hypot(dx, dy) >= Self.reorderDragThreshold else { return }
        beginReorderDragSession(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        dragDownLocation = nil
        didBeginReorderDrag = false
    }

    private func beginReorderDragSession(with event: NSEvent) {
        guard let photoID, !didBeginReorderDrag else { return }
        didBeginReorderDrag = true

        let item = NSPasteboardItem()
        PhotoDragPasteboard.write(photoID: photoID, to: item)

        let draggingItem = NSDraggingItem(pasteboardWriter: item)
        draggingItem.setDraggingFrame(bounds, contents: nil)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .move
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        dragDownLocation = nil
        didBeginReorderDrag = false
        onReorderDragEnded?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let fileURLs = GalleryFilePasteboard.uploadURLs(from: sender)
        if !fileURLs.isEmpty {
            onFileDropTargeted?(true)
            return .copy
        }
        guard PhotoDragPasteboard.photoID(from: sender) != nil else { return [] }
        updateInsertionIndex(from: sender)
        return .move
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let fileURLs = GalleryFilePasteboard.uploadURLs(from: sender)
        if !fileURLs.isEmpty {
            onFileDropTargeted?(true)
            return .copy
        }
        guard PhotoDragPasteboard.photoID(from: sender) != nil else { return [] }
        updateInsertionIndex(from: sender)
        return .move
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onFileDropTargeted?(false)
        pendingInsertionIndex = nil
        onDropInsertionIndexChange?(nil)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !GalleryFilePasteboard.uploadURLs(from: sender).isEmpty
            || PhotoDragPasteboard.photoID(from: sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let fileURLs = GalleryFilePasteboard.uploadURLs(from: sender)
        if !fileURLs.isEmpty {
            onFileDropTargeted?(false)
            return onFileDrop?(fileURLs) ?? false
        }
        guard let dragged = PhotoDragPasteboard.photoID(from: sender) else { return false }
        updateInsertionIndex(from: sender)
        let insertionIndex = pendingInsertionIndex ?? photoIndex
        pendingInsertionIndex = nil
        onDropInsertionIndexChange?(nil)
        return onReorderDrop?([dragged], insertionIndex) ?? false
    }

    private func updateInsertionIndex(from sender: NSDraggingInfo) {
        let local = convert(sender.draggingLocation, from: nil)
        let fraction = bounds.width > 0 ? local.x / bounds.width : 0.5
        let index = PhotoManifestReorder.insertionIndex(
            horizontalFraction: fraction,
            photoIndex: photoIndex,
            photoCount: photoCount
        )
        pendingInsertionIndex = index
        onDropInsertionIndexChange?(index)
    }
}
#endif

/// Leading macOS toolbar title + photo count (unified toolbar `.navigation` placement).
private struct GalleryToolbarLeadingTitle: View {
    let photoCount: Int
    var isBootstrapping = false

    var body: some View {
        Text(Self.photoCountLabel(photoCount, isBootstrapping: isBootstrapping))
            .font(AppTypography.toolbarTitle)
    }

    static func photoCountLabel(_ count: Int, isBootstrapping: Bool = false) -> String {
        if isBootstrapping, count == 0 {
            return String(localized: "Loading photos…")
        }
        let word = count == 1
            ? String(localized: "photo")
            : String(localized: "photos")
        return "\(count) \(word)"
    }
}

#if os(macOS)
/// Leading toolbar: system toggle + title in one navigation group (same treatment as trailing toolbar buttons).
private struct GalleryToolbarLeadingCluster: ToolbarContent {
    let photoCount: Int
    var isBootstrapping = false
    @Environment(AppChromeState.self) private var chrome

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            @Bindable var chrome = chrome
            Toggle(isOn: devicePreviewBinding) {
                Label("Device preview", systemImage: AppChromeState.devicePreviewToggleSymbolName)
            }
            .toggleStyle(.button)
            .labelStyle(.iconOnly)
            .help(chrome.showDevicePreview ? "Hide device preview" : "Show device preview")
            .accessibilityLabel("Device preview")
            .accessibilityValue(chrome.showDevicePreview ? "Shown" : "Hidden")
        }

        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .navigation) {
                GalleryToolbarLeadingTitle(
                    photoCount: photoCount,
                    isBootstrapping: isBootstrapping
                )
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigation) {
                GalleryToolbarLeadingTitle(
                    photoCount: photoCount,
                    isBootstrapping: isBootstrapping
                )
            }
        }
    }

    private var devicePreviewBinding: Binding<Bool> {
        Binding(
            get: { chrome.showDevicePreview },
            set: { newValue in
                withAnimation(AppAnimation.bouncy) {
                    chrome.showDevicePreview = newValue
                }
            }
        )
    }
}

/// Trailing action cluster: default toolbar buttons in one `ToolbarItemGroup` on 26+ (shared glass segment); `.bordered` pre-26.
private struct GalleryMacOSToolbarActionButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
        } else {
            content.buttonStyle(.bordered)
        }
    }
}
#endif

#if os(macOS)
private extension View {
    /// macOS 26+: soft Liquid Glass scroll edge as the grid scrolls under the unified toolbar.
    @ViewBuilder
    func galleryMacOSGridScrollEdgeEffect() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}

private struct GalleryMacOSToolbarTitleRemoval: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.toolbar(removing: .title)
        } else {
            content
        }
    }
}
#endif

#if os(macOS)
/// Thumbnail scale for the gallery grid (`AppSettings.galleryGridColumnCount`, photos per row).
private struct GalleryThumbnailSizeToolbarControl: View {
    @EnvironmentObject private var store: GalleryStore

    private static let iconFrame: CGFloat = 20
    private static let leadingPadding: CGFloat = 10
    private static let trailingPadding: CGFloat = 10

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.grid.3x3")
                .font(.caption.weight(.medium))
                .imageScale(.medium)
                .foregroundStyle(.secondary)
                .frame(width: Self.iconFrame, height: Self.iconFrame, alignment: .center)
                .accessibilityHidden(true)
            Slider(
                value: columnCountSliderBinding,
                in: Double(AppSettings.galleryGridColumnCountMin) ... Double(AppSettings.galleryGridColumnCountMax),
                step: 1
            )
            .frame(width: 120)
            Image(systemName: "square.grid.2x2")
                .font(.caption.weight(.medium))
                .imageScale(.medium)
                .foregroundStyle(.secondary)
                .frame(width: Self.iconFrame, height: Self.iconFrame, alignment: .center)
                .accessibilityHidden(true)
        }
        .padding(.leading, Self.leadingPadding)
        .padding(.trailing, Self.trailingPadding)
        .fixedSize(horizontal: true, vertical: false)
        .help("Photos per row")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Photos per row")
        .accessibilityValue("\(store.settings.galleryGridColumnCount) columns")
    }

    /// Slider left = denser grid (more columns); stored value is photos per row.
    private var columnCountSliderBinding: Binding<Double> {
        let min = AppSettings.galleryGridColumnCountMin
        let max = AppSettings.galleryGridColumnCountMax
        return Binding(
            get: {
                Double(min + max - store.settings.galleryGridColumnCount)
            },
            set: { persistColumnCount(min + max - Int($0.rounded())) }
        )
    }

    private func persistColumnCount(_ count: Int) {
        let clamped = AppSettings.clampedGalleryGridColumnCount(count)
        guard store.settings.galleryGridColumnCount != clamped else { return }
        store.settings.galleryGridColumnCount = clamped
        try? AppConfig.saveSettings(store.settings)
    }
}
#endif

#if os(macOS)
/// Pushes trailing toolbar items away from the leading title cluster (unified toolbar).
private struct GalleryMacOSToolbarFlexSpacer: ToolbarContent {
    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarSpacer(.flexible)
        } else {
            ToolbarItem(placement: .automatic) {
                Spacer()
            }
        }
    }
}

/// Visual break between thumbnail-size slider and action buttons (separate glass capsules on macOS 26+).
private struct GalleryMacOSToolbarSizeActionsSeparator: ToolbarContent {
    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarSpacer(.fixed)
        }
    }
}
#endif

/// Primary window toolbar scoped to the gallery (detail) column — not the activity inspector.
private struct GalleryMainToolbar: ToolbarContent {
    @Environment(AppChromeState.self) private var chrome
    @EnvironmentObject private var store: GalleryStore
    @Binding var showSettings: Bool
    @Binding var pickerItems: [PhotosPickerItem]

    var body: some ToolbarContent {
        #if os(macOS)
        // `.primaryAction` is leading on macOS; trailing items follow `GalleryMacOSToolbarFlexSpacer`.
        // macOS 26+: size cluster and action icons are separate unified-toolbar segments (group + fixed spacer + group).
        // Do not split actions into per-item `.glass` + `.sharedBackgroundVisibility(.hidden)` — that tints each orb from app `.tint`.
        if #available(macOS 26.0, *) {
            ToolbarItemGroup(placement: .automatic) {
                GalleryThumbnailSizeToolbarControl()
            }
            GalleryMacOSToolbarSizeActionsSeparator()
            ToolbarItemGroup(placement: .automatic) {
                galleryMacOSActionToolbarItems
            }
        } else {
            ToolbarItem(placement: .status) {
                GalleryThumbnailSizeToolbarControl()
            }
            ToolbarItemGroup(placement: .automatic) {
                galleryMacOSActionToolbarItems
            }
        }
        #else
        ToolbarItem(placement: .primaryAction) {
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .images) {
                Label("Add", systemImage: "plus")
            }
            .disabled(store.isBusy)
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await store.syncAll() }
            } label: {
                if store.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Sync", systemImage: "arrow.clockwise")
                }
            }
            .disabled(store.isBusy || store.isSyncing)
        }
        if store.settings.debugMode {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    chrome.showActivityInspector.toggle()
                } label: {
                    Label("Activity", systemImage: AppChromeState.activityInspectorSymbolName)
                }
                .help(chrome.showActivityInspector ? "Hide activity log" : "Show activity log")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Settings", systemImage: "gearshape") {
                showSettings.toggle()
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsPopover()
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showSettings = false }
                            }
                        }
                }
            }
        }
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private var galleryMacOSActionToolbarItems: some View {
        Button("Add", systemImage: "plus") {
            Task { await store.uploadFromPanel() }
        }
        .modifier(GalleryMacOSToolbarActionButtonStyle())
        .disabled(store.isBusy)

        Button {
            Task { await store.syncAll() }
        } label: {
            if store.isSyncing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Sync", systemImage: "arrow.clockwise")
            }
        }
        .modifier(GalleryMacOSToolbarActionButtonStyle())
        .disabled(store.isBusy || store.isSyncing)

        if store.settings.debugMode {
            Button {
                chrome.showActivityInspector.toggle()
            } label: {
                Label("Activity", systemImage: AppChromeState.activityInspectorSymbolName)
            }
            .modifier(GalleryMacOSToolbarActionButtonStyle())
            .help(chrome.showActivityInspector ? "Hide activity log" : "Show activity log")
        }

        Button("Settings", systemImage: "gearshape") {
            showSettings.toggle()
        }
        .modifier(GalleryMacOSToolbarActionButtonStyle())
        .popover(isPresented: $showSettings, arrowEdge: .top) {
            SettingsPopover()
                .frame(width: 340)
        }
    }
    #endif
}

struct PhotoThumb: View {
    @Environment(GallerySelectionStore.self) private var selection
    let photo: PhotoEntry
    let thumbAspectRatio: CGFloat
    let thumbMaxPixelSize: Int
    let isSelected: Bool
    var isCurrentOnDevice: Bool = false
    var cornerTag: String? = nil
    var showsInsertionLineBefore: Bool = false
    var showsInsertionLineAfter: Bool = false

    var body: some View {
        thumbImage
            .overlay {
                Rectangle()
                    .strokeBorder(
                        isSelected ? AppBrandColor.accentGreen : (isCurrentOnDevice ? Color.black : Color.clear),
                        lineWidth: isCurrentOnDevice ? 2 : 3
                    )
            }
            .overlay(alignment: .leading) {
                if showsInsertionLineBefore {
                    GalleryInsertionLine()
                }
            }
            .overlay(alignment: .trailing) {
                if showsInsertionLineAfter {
                    GalleryInsertionLine()
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let cornerTag,
                   selection.presentedLightboxPhotoID != photo.id {
                    Text(cornerTag)
                        .font(AppTypography.thumbBadge)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(cornerTag == PhotoFormatters.showingTodayTag ? Color.black : AppBrandColor.accentGreen)
                        .padding(6)
                }
            }
            .animation(nil, value: isSelected)
            .frame(maxWidth: .infinity)
    }

    /// Portrait cell (device aspect); image aspect-fills and center-crops inside.
    private var thumbImage: some View {
        Color.clear
            .aspectRatio(thumbAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                CachedPhotoImage(
                    photoID: photo.id,
                    maxPixelSize: thumbMaxPixelSize,
                    contentMode: .fill,
                    thumbnailWidth: thumbMaxPixelSize
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipped()
    }
}

/// Accent gap line shown between thumbnails during reorder drags.
private struct GalleryInsertionLine: View {
    var body: some View {
        Rectangle()
            .fill(AppBrandColor.accentGreen)
            .frame(width: 3)
            .frame(maxHeight: .infinity)
            .allowsHitTesting(false)
    }
}

/// Downsample budget for grid thumbnails from layout size and display scale.
private enum GalleryThumbSizing {
    private static let minPixelSize = 280
    private static let maxPixelSize = 4096

    static func maxPixelSize(cellWidth: CGFloat, cellHeight: CGFloat) -> Int {
        let scale = displayScale
        let longest = max(cellWidth, cellHeight) * scale * 1.05
        return min(maxPixelSize, max(minPixelSize, Int(ceil(longest))))
    }

    private static var displayScale: CGFloat {
        #if os(macOS)
        NSScreen.main?.backingScaleFactor ?? 2
        #elseif os(iOS)
        UIScreen.main.scale
        #endif
    }
}

