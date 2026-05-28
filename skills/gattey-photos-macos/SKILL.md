---
name: gattey-photos-macos
description: Change the Gattey Photos macOS SwiftUI app or bundled sync helper. Use for UI, SyncClient, Bloomin8 uploads, LaunchAgent install, or Application Support config.
---

# Gattey Photos macOS

## Targets (Package.swift)

- `GatteyPhotosCore` — networking and merge; no SwiftUI
- `GatteyPhotosApp` — `@main` SwiftUI app
- `GatteyPhotosSyncHelper` — hourly sync binary bundled in `Gattey Photos.app/Contents/MacOS/`

`SyncHelperLauncher` writes `~/Library/LaunchAgents/com.gattey.photos.sync.plist` on first launch of the packaged app.

`EmbeddedSyncRunner` runs the same loop in-process when developing via `swift run` (no bundled helper).

Package release app: `make package-macos` → `dist/Gattey Photos.app`.

Open `macos/Package.swift` in Xcode for debugging UI.

## State

- `GalleryStore` (`GalleryStore.swift`) — UI-facing `ObservableObject`
- `AppConfig` — `config.json` and `local-gallery.json` under Application Support

## UI layout

`NavigationSplitView`: sidebar (`GallerySidebar`), grid (`GalleryGridView`), detail (`PhotoDetailPanel` when a photo is selected).

## Settings popover

`SettingsPopover.swift` — device IP, server URL, sync password, gallery name.

## Sync flows

- Refresh toolbar → `SyncEngine.pullAndMerge`
- Packaged helper / embedded runner → `SyncLoop` → `SyncEngine.fullSync`

When adding Bloomin8 behavior, extend `Bloomin8Client.swift` only.
