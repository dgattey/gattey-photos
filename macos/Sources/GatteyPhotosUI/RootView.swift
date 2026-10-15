import GatteyPhotosCore
import SwiftUI

#if os(macOS)
import AppKit
#endif

struct RootView: View {
    @EnvironmentObject private var store: GalleryStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var resignedActiveAt: Date?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            galleryRoot
                .navigationDestination(for: PhotoID.self) { photoID in
                    PhotoLightboxView(photoID: photoID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .galleryDeleteKeyboard(photoIDs: Set([photoID]))
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: store.selection.lightboxNavigationPhotoID) { _, photoID in
            syncNavigationPath(with: photoID)
        }
        .onChange(of: navigationPath.count) { oldCount, newCount in
            guard newCount < oldCount, store.selection.isLightboxOpen else { return }
            store.selection.closeLightbox()
        }
        #if os(iOS)
        .sheet(item: $store.photoShareItem) { item in
            PhotoActivityShareSheet(url: item.url) {
                store.clearPhotoShareItem()
            }
        }
        #endif
    }

    private func syncNavigationPath(with photoID: PhotoID?) {
        if let photoID {
            #if os(macOS)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if navigationPath.isEmpty {
                    navigationPath.append(photoID)
                } else {
                    navigationPath.removeLast()
                    navigationPath.append(photoID)
                }
            }
            #else
            var transaction = Transaction(animation: .easeInOut(duration: 0.32))
            withTransaction(transaction) {
                if navigationPath.isEmpty {
                    navigationPath.append(photoID)
                } else {
                    navigationPath.removeLast()
                    navigationPath.append(photoID)
                }
            }
            #endif
        } else if !navigationPath.isEmpty {
            #if os(macOS)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                navigationPath.removeLast()
            }
            #else
            var transaction = Transaction(animation: .easeInOut(duration: 0.32))
            withTransaction(transaction) {
                navigationPath.removeLast()
            }
            #endif
        }
    }

    private var galleryRoot: some View {
        GalleryGridView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Translucent brand glass; the top VariableBlurView strip fakes the scroll edge.
            .background(WindowGlassBackground())
        .task {
            if store.activePhotos.isEmpty {
                store.markAwaitingInitialGalleryPull()
            }
            async let gallery: Void = store.refresh()
            async let status: Void = store.updateConnectionStatus()
            _ = await (gallery, status)
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            resignedActiveAt = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshConnectionIfInactiveLongEnough()
            Task { await store.pullOnReactivation() }
        }
        #else
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                resignedActiveAt = Date()
            case .active:
                refreshConnectionIfInactiveLongEnough()
            @unknown default:
                break
            }
        }
        #endif
    }

    private func refreshConnectionIfInactiveLongEnough() {
        guard let resignedActiveAt,
              Date().timeIntervalSince(resignedActiveAt) >= 5
        else { return }
        self.resignedActiveAt = nil
        Task { await store.updateConnectionStatus() }
    }
}
