---
name: ios
description: Build and run the Gattey Photos iOS/iPad app. Use when changing GatteyPhotosApp, GatteyPhotosUI, or GatteyPhotosCore on iOS.
---

# Gattey Photos iOS / iPad

The iOS app shares **GatteyPhotosCore** (sync, manifest, auth) and **GatteyPhotosUI** (unlock, gallery, lightbox, settings) with macOS. Client pull is identical on all platforms (`GalleryStore`); there is no local Node server or macOS LaunchAgent helper.

## Package layout (`Package.swift`)

| Target | Platform | Role |
|--------|----------|------|
| `GatteyPhotosCore` | macOS + iOS | Models, `SyncClient`, `AppConfig`; macOS-only helpers behind `#if os(macOS)` |
| `GatteyPhotosUI` | macOS + iOS | Shared SwiftUI (`AppRootContainer`, `GalleryStore`, grid, lightbox) |
| `GatteyPhotosApp` | macOS + iOS | `@main` — injects the `@Observable` stores with `.environment`; macOS adds `AppDelegate` and menus |
Bundle ID: `com.gattey.photos`.

Production sync URL: `https://photos.gattey.com`. **Debug mode** (Settings toggle on iOS; Debug menu on macOS) switches to local dev URL only — it does **not** start `scripts/start-server.sh` on iOS.

While unlocked: `GalleryStore` runs the same 15-minute periodic pull as macOS (shared code path with `refresh` and manual sync). No sync when locked or quit.

Frames: same **Settings → Frames** UI as macOS — register Bloomin8 tokens on the server; server pushes to devices.

## Build and run (Simulator)

DylKit's `apple-dev-loop` owns this. From repo root:

```bash
swift run devkit ios --run --capture
swift run devkit ios --run --capture --simulator "iPad Pro 13-inch (M5)"
```

devkit builds the `GatteyPhotos` product for the iOS Simulator, wraps it into `build/Gattey Photos-iOS.app` with the `[ios]` settings from `DylApp.toml`, installs and launches it headlessly with `simctl`, and saves a screenshot under `build/captures/`. The default simulator is `[ios] simulator`.

## Design sync

iOS and macOS share `GatteyPhotosUI`, so an iOS redesign is an app redesign. Update photos.gattey.com (screenshots under `[site]` in `DylApp.toml`) and ask the `dg` project to update dylangattey.com in the same PR. See **Design sync** in `AGENTS.md`.

## macOS still needs its own check

iOS testing covers shared `GatteyPhotosUI` behavior but not macOS-only chrome. After changes that affect the macOS app, follow **`skills/dev-loop/SKILL.md`** and say which macOS behavior is unverified when the bundle ID rule blocks a launch.

## macOS-only (not on iOS)

- macOS glass window chrome (`NSWindow` vibrancy)
- Finder drop / `NSOpenPanel` upload (iOS uses **PhotosPicker**)
- No gallery pull when the app is locked or quit (same on all platforms)
