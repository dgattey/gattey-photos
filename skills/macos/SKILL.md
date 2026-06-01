---
name: macos
description: Change the Gattey Photos macOS SwiftUI app. Use for UI, SyncClient, Application Support config, or shared GatteyPhotosUI behavior.
---

# Gattey Photos macOS

After **each** `macos/` edit session: from repo root run **`./scripts/launch.sh macos`** before considering the task done. See **`skills/dev-loop/SKILL.md`**. Do not skip relaunch; do not batch multiple UI changes without relaunch between them when the user is iterating; `swift build` alone does not refresh `dist/Gattey Photos.app`. If you also changed runtime `server/` code, restart the local server per dev-loop first, then relaunch.

The sync API is **not** bundled in the app. Run the server separately (`./scripts/start-server.sh` or `./scripts/dev.sh`). Sync server URL is `http://127.0.0.1:3000` in **Debug** mode and `https://photos.gattey.com` in production (read-only in Settings; toggle via **Debug → Toggle Debug Mode**).

## Targets (Package.swift)

- `GatteyPhotosCore` — networking and merge; no SwiftUI
- `GatteyPhotosUI` — shared SwiftUI (gallery, unlock, settings); used by macOS and iOS
- `GatteyPhotosApp` — `@main` macOS shell (`AppDelegate`, Debug menu)
Gallery pull while unlocked matches iOS: `AppSession` starts `GalleryStore.startPeriodicPullWhileUnlocked()` (15 min, same code path as refresh and ⌘R Sync). No LaunchAgent or bundled helper binary.

Open `macos/Package.swift` in Xcode for debugging UI.

iOS/iPad app (shared `GatteyPhotosUI` + `GatteyPhotosCore`): see **`skills/ios/SKILL.md`**.

## App icon

**What a fresh Xcode app target does:** add `AppIcon.icon` to the project; Xcode compiles it to `Assets.car` at build time (`CFBundleIconName` = `AppIcon`). Author in **Icon Composer** (layer fills, glass on/off), not hand-wavy JSON.

**This repo (SwiftPM, no `.xcodeproj`):** same bundle at `macos/AppIcon.icon/`; `./scripts/generate-app-icon.sh` runs `actool` → `macos/Assets.car`; packaging copies only `Assets.car`.

**Canvas gradient (root fill in `icon.json`):** vertical linear gradient only (two stops). Top RGB **94, 159, 125** → `srgb:0.368627,0.623529,0.490196,1.000000`. Bottom RGB **46, 92, 69** → `srgb:0.180392,0.360784,0.270588,1.000000`. Orientation `start` (0.5, 0) → `stop` (0.5, 1). Edit in Icon Composer: select **AppIcon** in the sidebar → Fill → Gradient.

**Letter G:** `Assets/Letter-G.svg` (Georgia “G” as paths, not live text). Icon Composer’s public `icon.json` schema uses `image-name` layers; Apple’s docs say to convert text to outlines in SVG. Tweak glass/position in Icon Composer on that image layer, or regenerate paths: `GATTEY_REGENERATE_LETTER_G=1 ./scripts/generate-app-icon.sh` (`macos/scripts/ExportLetterG.swift`). Do not expect a separate “Text layer” type in Icon Composer for actool.

Single **G** group: `glass: true`, solid white layer fill, translucency/specular on the group. Rebuild: `./scripts/generate-app-icon.sh` then relaunch.

## State

- `GalleryStore` (`GalleryStore.swift`) — UI-facing `ObservableObject`
- `AppConfig` — `config.json` and `local-gallery.json` under Application Support

## UI layout

Full-width `GalleryGridView`: left `DeviceCurrentPreview` (on-device photo, black frame, drop to set current) + right thumbnail grid. Floating `ConnectionStatusView` (top-trailing). `currentPhotoId` on `GalleryState` syncs via `PUT /api/gallery/current`; Bloomin8 `show_now` targets that photo. Toolbar **Set as current** when one grid photo is selected. Double-click opens `PhotoLightboxView`. Multi-select shows `GallerySelectionBar`. Drag thumbnails to reorder.

**macOS toolbar (logged-in):** leading `ToolbarItemGroup(.navigation)` — `Toggle` + `.toggleStyle(.button)` + `.labelStyle(.iconOnly)` for device preview (no custom `Button`/`Image`/`buttonStyle`); title with `.sharedBackgroundVisibility(.hidden)` on 26+ only. Grid `ScrollView`: `.scrollEdgeEffectStyle(.soft, for: .top)` on macOS 26+. Trailing: photos-per-row group, `ToolbarSpacer(.fixed)`, action group. Transparent `.toolbarBackground(.hidden)`; not `.primaryAction` on macOS.

**Glass chrome:** `GlassChromeStyle.swift` — floating panel background; `WindowGlassBackground.swift` — full-window vibrancy.

## Settings popover

`UnlockView` / `AppSession` — name + family password only. `POST /api/auth/session` → `syncSessionToken` in `config.json`.

`SettingsPopover.swift` + `FramesSettingsSection.swift` — register frames on the server (paste Bloomin8 setup block; tokens encrypted in `devices/registry.json` on Blob). **Debug → Toggle Debug Mode** switches API URL; start local server with `./scripts/dev.sh` (not from the app).

**Frames:** `GET /api/devices`, `POST /api/devices`, `GET /api/devices/status`. Server pushes to einkshot after `currentPhotoId` changes. No client pull when locked or quit.

Activity log inspector (toolbar / ⌘B) only when debug mode is on.

## Sync flows

- `GalleryStore.pullFromServer` — one path for foreground refresh, ⌘R Sync, and the 15-minute timer while unlocked (`SyncEngine.syncFromServer` underneath)

Server Bloomin8: `server/lib/bloomin8/`, `server/lib/devices/`.
