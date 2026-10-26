import GatteyPhotosCore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct GalleryGridView: View {
    @Environment(AppChromeState.self) private var chrome
    @Environment(GallerySelectionStore.self) private var selection
    @Environment(GalleryStore.self) private var store
    @FocusState private var gridDeleteKeyFocus: Bool
    @State private var showSettings = false
    @State private var didApplyInitialView = false
    @State private var isFileDropTargeted = false
    @State private var dropInsertionIndex: Int?
    @State private var pickerItems: [PhotosPickerItem] = []

    #if os(macOS)
    private let fileDropTypes: [UTType] = [.jpeg, .image, .fileURL]
    #else
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        galleryShell
    }

    @ViewBuilder
    private var platformShell: some View {
        #if os(macOS)
        PreviewGallerySplit {
            thumbnailGridColumn
        }
        .navigationTitle("")
        .toolbar {
            // Unified toolbar: hide SwiftUI/.navigationTitle duplicate (see `.toolbar(removing: .title)`)
            // and `WindowChromeConfigurator` title visibility. Leading title via `.navigation` only;
            // gallery actions follow a flexible spacer — `.primaryAction` is leading on macOS.
            GalleryToolbarLeadingCluster(
                photoCount: store.activePhotos.count,
                isBootstrapping: store.isBootstrappingGallery
            )
            GalleryMacOSToolbarFlexSpacer()
            GalleryMainToolbar(
                showSettings: $showSettings,
                pickerItems: $pickerItems
            )
        }
        .modifier(GalleryMacOSToolbarTitleRemoval())
        .overlay(alignment: .top) {
            VariableBlurView(maxBlurRadius: 4, direction: .blurredTopClearBottom)
                .frame(height: 68)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
        // Fallback for chrome outside the grid; populated grids use AppKit targets (see thumbnailGridColumn).
        .onDrop(of: fileDropTypes, isTargeted: $isFileDropTargeted) { providers, _ in
            handleFileDrop(providers: providers)
        }
        #else
        thumbnailGridColumn
            .navigationTitle("Gattey Photos")
            .toolbar {
                GalleryMainToolbar(
                    showSettings: $showSettings,
                    pickerItems: $pickerItems
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(isPresented: $showSettings)
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                let batch = items
                pickerItems = []
                Task { await uploadPickedItems(batch) }
            }
        #endif
    }

    private var galleryShell: some View {
        platformShell
            .focusable()
            .focusEffectDisabled()
            .focused($gridDeleteKeyFocus)
            .galleryDeleteKeyboard(photoIDs: gridDeleteKeyPhotoIDs)
            .galleryOpenLightboxKeyboard(
                isEnabled: galleryGridKeyboardEnabled,
                photoOrder: store.activePhotoIDs
            )
            .galleryClearSelectionKeyboard(isEnabled: galleryGridKeyboardEnabled)
            .galleryArrowSelectionKeyboard(isEnabled: galleryGridKeyboardEnabled, columnCount: gridColumnCount)
            .onChange(of: gridDeleteKeyPhotoIDs) { _, _ in
                syncGridKeyboardFocus()
            }
            .onChange(of: selection.isLightboxOpen) { _, _ in
                syncGridKeyboardFocus()
            }
            .onChange(of: showSettings) { _, _ in
                syncGridKeyboardFocus()
            }
            .onChange(of: store.activePhotoIDs) { _, _ in
                applyInitialViewIfNeeded()
            }
            .onAppear {
                syncGridKeyboardFocus()
                applyInitialViewIfNeeded()
            }
    }

    private func applyInitialViewIfNeeded() {
        guard !didApplyInitialView, let initialView = chrome.initialView else { return }
        switch initialView {
        case .settings:
            didApplyInitialView = true
            // Presenting during the first appear pass drops the iOS sheet; wait for the next run loop.
            Task { @MainActor in
                showSettings = true
            }
        case .activity:
            didApplyInitialView = true
            chrome.showActivityInspector = true
        case .lightbox:
            guard let firstID = store.currentPhoto?.id ?? store.activePhotoIDs.first else { return }
            didApplyInitialView = true
            Task { @MainActor in
                selection.openLightbox(firstID)
            }
        case .select:
            let ids = Array(store.activePhotoIDs.prefix(2))
            guard !ids.isEmpty else { return }
            didApplyInitialView = true
            #if os(iOS)
            selection.beginSelecting()
            #endif
            for id in ids {
                selection.selectPhoto(id, append: true)
            }
        case .unlock, .unlockHelp:
            didApplyInitialView = true
        }
    }

    #if os(iOS)
    private var photoCountLabel: String {
        GalleryPhotoCount.label(
            store.activePhotos.count,
            isBootstrapping: store.isBootstrappingGallery
        )
    }
    #endif

    private var galleryGridKeyboardEnabled: Bool {
        !selection.isLightboxOpen && !showSettings
    }

    /// macOS insets the grid from the window edge and the toolbar; iOS runs edge to edge like Photos.
    private static var gridInsets: EdgeInsets {
        #if os(macOS)
        EdgeInsets(top: 8, leading: 8, bottom: 20, trailing: 20)
        #else
        EdgeInsets()
        #endif
    }

    private var gridLayoutWidth: CGFloat {
        max(gridViewportWidth - Self.gridInsets.leading - Self.gridInsets.trailing, 1)
    }

    /// iOS has no thumbnail-size control, so columns follow the width: ~100pt cells on iPhone, ~150pt on iPad.
    private var gridColumnCount: Int {
        #if os(iOS)
        let targetCellWidth: CGFloat = horizontalSizeClass == .regular ? 150 : 100
        guard gridViewportWidth > 0 else { return 4 }
        return max(3, Int((gridViewportWidth / targetCellWidth).rounded()))
        #else
        store.settings.galleryGridColumnCount
        #endif
    }

    /// macOS fills the viewport so empty space below the grid stays a click and drop target; iOS lets the
    /// Now Showing card and grid size to content so a short gallery doesn't scroll.
    private var gridContentMinHeight: CGFloat {
        #if os(macOS)
        max(gridViewportHeight > 0 ? gridViewportHeight : 600, 280)
        #else
        280
        #endif
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
                VStack(spacing: 0) {
                    #if os(iOS)
                    NowShowingCard()
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 16)
                    #endif
                    ZStack(alignment: .top) {
                        #if os(macOS)
                        GalleryFileDropTarget(
                            onDrop: handleFileURLDrop,
                            isTargeted: $isFileDropTargeted
                        )
                        .frame(maxWidth: .infinity, minHeight: gridContentMinHeight)
                        #endif

                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: gridContentMinHeight)
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
                                columnCount: gridColumnCount,
                                deviceScreenAspectRatio: store.deviceScreenAspectRatio,
                                dropInsertionIndex: $dropInsertionIndex,
                                onSelectPhoto: handleGridPhotoTap,
                                onOpenLightbox: { store.selection.openLightbox($0) },
                                onReorderDrop: handleReorderDrop,
                                onFileDrop: handleFileURLDrop,
                                onFileDropTargeted: { isFileDropTargeted = $0 }
                            )
                            .padding(Self.gridInsets)
                            #else
                            GalleryPhotoGrid(
                                gridContainerWidth: gridLayoutWidth,
                                columnCount: gridColumnCount,
                                deviceScreenAspectRatio: store.deviceScreenAspectRatio,
                                dropInsertionIndex: $dropInsertionIndex,
                                onSelectPhoto: handleGridPhotoTap,
                                onOpenLightbox: { store.selection.openLightbox($0) },
                                onReorderDrop: handleReorderDrop
                            )
                            #endif
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: gridContentMinHeight)
                    #if os(iOS)
                    if !store.activePhotos.isEmpty {
                        Text(photoCountLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)
                            .padding(.bottom, selection.isSelecting ? 96 : 28)
                    }
                    #endif
                }
            }
            #if os(macOS)
            .galleryMacOSGridScrollEdgeEffect()
            #else
            .refreshable { await store.syncAll() }
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
            photoOrder: store.activePhotoIDs
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
            let wrote = await Task.detached(priority: .userInitiated) {
                (try? data.write(to: url, options: .atomic)) != nil
            }.value
            guard wrote else { continue }
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
        let order = store.activePhotoIDs
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
        guard !selection.isLightboxOpen else { return false }
        #if os(iOS)
        return selection.isSelecting
        #else
        return !selection.selectedIDs.isEmpty
        #endif
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
    @Environment(GalleryStore.self) private var store
    let gridContainerWidth: CGFloat
    let columnCount: Int
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

    /// iOS: hairline gutter (Photos-style) so neighboring photos don't bleed into each other. macOS: roomier gutters
    /// to suit pointer-sized thumbnails in a window.
    #if os(macOS)
    static let spacing: CGFloat = 8
    #else
    static let spacing: CGFloat = 2
    #endif

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: columnCount)
    }

    private var layoutGridWidth: CGFloat {
        settledGridWidth > 0 ? settledGridWidth : gridContainerWidth
    }

    private var cellWidth: CGFloat {
        max(1, (layoutGridWidth - Self.spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount))
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
        LazyVGrid(columns: gridColumns, spacing: Self.spacing) {
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
        let showsInsertionBefore = dropInsertionIndex == index
        let showsInsertionAfter = dropInsertionIndex == index + 1
        #if os(macOS)
        PhotoGridItem(
            photo: photo,
            photoIndex: index,
            photoCount: store.activePhotos.count,
            thumbAspectRatio: thumbAspectRatio,
            thumbMaxPixelSize: thumbMaxPixelSize,
            showsInsertionLineBefore: showsInsertionBefore,
            showsInsertionLineAfter: showsInsertionAfter,
            onSelectPhoto: onSelectPhoto,
            onOpenLightbox: onOpenLightbox,
            onReorderDrop: onReorderDrop,
            onFileDrop: onFileDrop,
            onFileDropTargeted: onFileDropTargeted,
            onDropInsertionIndexChange: { gap in
                if dropInsertionIndex != gap {
                    dropInsertionIndex = gap
                }
            }
        )
        #else
        PhotoGridItem(
            photo: photo,
            photoIndex: index,
            photoCount: store.activePhotos.count,
            thumbAspectRatio: thumbAspectRatio,
            thumbMaxPixelSize: thumbMaxPixelSize,
            showsInsertionLineBefore: showsInsertionBefore,
            showsInsertionLineAfter: showsInsertionAfter,
            onSelectPhoto: onSelectPhoto,
            onOpenLightbox: onOpenLightbox,
            onReorderDrop: onReorderDrop,
            onDropInsertionIndexChange: { gap in
                if dropInsertionIndex != gap {
                    dropInsertionIndex = gap
                }
            }
        )
        #endif
    }
}

/// One grid cell: observes selection for this photo only.
private struct PhotoGridItem: View {
    @Environment(GallerySelectionStore.self) private var selection
    @Environment(GalleryStore.self) private var store
    let photo: PhotoEntry
    let photoIndex: Int
    let photoCount: Int
    let thumbAspectRatio: CGFloat
    let thumbMaxPixelSize: Int
    let showsInsertionLineBefore: Bool
    let showsInsertionLineAfter: Bool
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

    var body: some View {
        PhotoThumb(
            photo: photo,
            thumbAspectRatio: thumbAspectRatio,
            thumbMaxPixelSize: thumbMaxPixelSize,
            isSelected: isSelected,
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
        .onTapGesture {
            if selection.isSelecting {
                onSelectPhoto(photo.id, .selectModeToggle)
            } else {
                onOpenLightbox(photo.id)
            }
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

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext)
        -> NSDragOperation
    {
        .move
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        dragDownLocation = nil
        didBeginReorderDrag = false
        onReorderDragEnded?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if GalleryFilePasteboard.hasCandidateUploadItems(in: sender) {
            onFileDropTargeted?(true)
            return .copy
        }
        guard PhotoDragPasteboard.photoID(from: sender) != nil else { return [] }
        updateInsertionIndex(from: sender)
        return .move
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if GalleryFilePasteboard.hasCandidateUploadItems(in: sender) {
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
        GalleryFilePasteboard.hasCandidateUploadItems(in: sender)
            || PhotoDragPasteboard.photoID(from: sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let payload = GalleryFilePasteboard.extractDropPayload(from: sender),
            let onFileDrop
        {
            onFileDropTargeted?(false)
            Task { @MainActor in
                let fileURLs = await payload.materializeURLs()
                guard !fileURLs.isEmpty else { return }
                _ = onFileDrop(fileURLs)
            }
            return true
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

private enum GalleryPhotoCount {
    static func label(_ count: Int, isBootstrapping: Bool = false) -> String {
        if isBootstrapping, count == 0 {
            return String(localized: "Loading photos…")
        }
        let word =
            count == 1
            ? String(localized: "photo")
            : String(localized: "photos")
        return "\(count) \(word)"
    }
}

#if os(macOS)
/// Leading macOS toolbar title + photo count (unified toolbar `.navigation` placement).
private struct GalleryToolbarLeadingTitle: View {
    let photoCount: Int
    var isBootstrapping = false

    var body: some View {
        Text(GalleryPhotoCount.label(photoCount, isBootstrapping: isBootstrapping))
            .font(AppTypography.toolbarTitle)
    }
}

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
extension View {
    /// macOS 26+: soft Liquid Glass scroll edge as the grid scrolls under the unified toolbar.
    @ViewBuilder
    fileprivate func galleryMacOSGridScrollEdgeEffect() -> some View {
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
    @Environment(GalleryStore.self) private var store

    private static let iconFrame: CGFloat = 20
    private static let leadingPadding: CGFloat = 10
    private static let trailingPadding: CGFloat = 10

    var body: some View {
        HStack(spacing: 6) {
            stepButton(delta: 1, systemImage: "square.grid.3x3", help: "Smaller thumbnails")
            Slider(
                value: columnCountSliderBinding,
                in: Double(AppSettings.galleryGridColumnCountMin)...Double(AppSettings.galleryGridColumnCountMax),
                step: 1
            )
            .frame(width: 120)
            .help("Photos per row")
            .accessibilityLabel("Photos per row")
            .accessibilityValue("\(store.settings.galleryGridColumnCount) columns")
            stepButton(delta: -1, systemImage: "square.grid.2x2", help: "Larger thumbnails")
        }
        .padding(.leading, Self.leadingPadding)
        .padding(.trailing, Self.trailingPadding)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func stepButton(delta: Int, systemImage: String, help: String) -> some View {
        let current = store.settings.galleryGridColumnCount
        let nextCount = AppSettings.clampedGalleryGridColumnCount(current + delta)
        return Button {
            persistColumnCount(nextCount)
        } label: {
            Image(systemName: systemImage)
                .font(.caption.weight(.medium))
                .imageScale(.medium)
                .foregroundStyle(.secondary)
                .frame(width: Self.iconFrame, height: Self.iconFrame, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(nextCount == current)
        .help(help)
        .accessibilityLabel(help)
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
        AppConfig.saveSettingsAsync(store.settings)
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
    @Environment(GalleryStore.self) private var store
    #if os(iOS)
    @Environment(GallerySelectionStore.self) private var selection
    #endif
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
        if selection.isSelecting {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    withAnimation(AppAnimation.bouncy) { selection.endSelecting() }
                }
                .fontWeight(.semibold)
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Select") {
                    withAnimation(AppAnimation.bouncy) { selection.beginSelecting() }
                }
                .disabled(store.activePhotos.isEmpty)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .images) {
                    Label("Add Photos", systemImage: "plus")
                }
                .disabled(store.isBusy)
                if store.settings.debugMode {
                    activityToolbarButton
                }
                Button("Settings", systemImage: "gearshape") {
                    showSettings = true
                }
            }
        }
        #endif
    }

    #if os(macOS)
    private var syncToolbarButton: some View {
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
        .help(store.isSyncing ? "Syncing photos…" : "Sync photos")
        .accessibilityLabel("Sync photos")
    }
    #endif

    private var activityToolbarButton: some View {
        Button {
            chrome.showActivityInspector.toggle()
        } label: {
            Label("Activity", systemImage: AppChromeState.activityInspectorSymbolName)
        }
        .help(chrome.showActivityInspector ? "Hide activity log" : "Show activity log")
    }

    #if os(macOS)
    @ViewBuilder
    private var galleryMacOSActionToolbarItems: some View {
        Button("Add", systemImage: "plus") {
            Task { await store.uploadFromPanel() }
        }
        .modifier(GalleryMacOSToolbarActionButtonStyle())
        .disabled(store.isBusy)
        .help("Add photos")

        syncToolbarButton
            .modifier(GalleryMacOSToolbarActionButtonStyle())

        if store.settings.debugMode {
            activityToolbarButton
                .modifier(GalleryMacOSToolbarActionButtonStyle())
        }

        Button("Settings", systemImage: "gearshape") {
            showSettings.toggle()
        }
        .modifier(GalleryMacOSToolbarActionButtonStyle())
        .help("Settings")
        .popover(isPresented: $showSettings, arrowEdge: .top) {
            SettingsView()
                .frame(width: 380, height: 540)
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
    var cornerTag: String? = nil
    var showsInsertionLineBefore: Bool = false
    var showsInsertionLineAfter: Bool = false

    /// Bucketed server thumbnail width so small grid-size changes reuse one cached variant (no refetch
    /// churn). The cell still downsamples this to `thumbMaxPixelSize` for display.
    private var thumbnailDownloadWidth: Int {
        let bucket = 256
        let steps = max(1, Int((Double(thumbMaxPixelSize) / Double(bucket)).rounded(.up)))
        return min(steps * bucket, 1024)
    }

    var body: some View {
        thumbImage
            .overlay {
                if isSelected {
                    Self.cellShape
                        .strokeBorder(AppBrandColor.accentGreen, lineWidth: 3)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, AppBrandColor.accentGreen)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .padding(6)
                }
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
            .overlay(alignment: .bottomLeading) {
                if let cornerTag,
                    selection.presentedLightboxPhotoID != photo.id
                {
                    PhotoThumbBadge(tag: cornerTag)
                        .padding(5)
                }
            }
            .animation(nil, value: isSelected)
            .frame(maxWidth: .infinity)
    }

    /// Square-cornered on iOS to tile like Photos; softly rounded on macOS, where the grid has gutters.
    private static var cellShape: RoundedRectangle {
        #if os(macOS)
        RoundedRectangle(cornerRadius: 6, style: .continuous)
        #else
        RoundedRectangle(cornerRadius: 0)
        #endif
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
                    thumbnailWidth: thumbnailDownloadWidth
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(Self.cellShape)
    }
}

/// Schedule chip on a thumbnail: green "Today" for the photo on the frame, a quiet date for upcoming slots.
private struct PhotoThumbBadge: View {
    let tag: String

    private var isShowingToday: Bool { tag == PhotoFormatters.showingTodayTag }

    var body: some View {
        HStack(spacing: 3) {
            if isShowingToday {
                Image(systemName: "photo.artframe")
            }
            Text(isShowingToday ? "Today" : tag)
        }
        .font(AppTypography.thumbBadge)
        .foregroundStyle(isShowingToday ? AppBrandColor.accentGreen : .white)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(isShowingToday ? Color.white : AppBrandColor.accentGreen, in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        .accessibilityLabel(tag)
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
@MainActor
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
