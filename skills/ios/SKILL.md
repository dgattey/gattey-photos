---
name: ios
description: Build and run the Gattey Photos iOS/iPad app. Use when changing GatteyPhotosIOS, GatteyPhotosUI, or GatteyPhotosCore on iOS.
---

# Gattey Photos iOS / iPad

The iOS app shares **GatteyPhotosCore** (sync, manifest, auth) and **GatteyPhotosUI** (unlock, gallery, lightbox, settings) with macOS. Client pull is identical on all platforms (`GalleryStore` + `SyncEngine`); there is no local Node server or macOS LaunchAgent helper.

## Package layout (`macos/Package.swift`)

| Target | Platform | Role |
|--------|----------|------|
| `GatteyPhotosCore` | macOS + iOS | Models, `SyncEngine`, `AppConfig`, merge; macOS-only helpers behind `#if os(macOS)` |
| `GatteyPhotosUI` | macOS + iOS | Shared SwiftUI (`AppRootContainer`, `GalleryStore`, grid, lightbox) |
| `GatteyPhotosIOS` | iOS | `@main` — wires environment objects |
| `GatteyPhotosApp` | macOS | `@main` + `AppDelegate` |
Bundle ID: `com.gattey.photos`.

Production sync URL: `https://photos.gattey.com`. **Debug mode** (Settings toggle on iOS; Debug menu on macOS) switches to local dev URL only — it does **not** start `scripts/start-server.sh` on iOS.

While unlocked: `GalleryStore` runs the same 15-minute periodic pull as macOS (shared code path with `refresh` and manual sync). No sync when locked or quit.

Frames: same **Settings → Frames** UI as macOS — register Bloomin8 tokens on the server; server pushes to devices.

## Build (Simulator)

From repo root:

```bash
./scripts/build-ios.sh
```

Defaults to iPhone 17 simulator. Override:

```bash
IOS_SIM_DEST='platform=iOS Simulator,name=iPad Pro 13-inch (M5)' ./scripts/build-ios.sh
```

## Build + install + launch (iPad or iPhone)

```bash
./scripts/launch.sh ipad
```

iPad (default):

```bash
IOS_DEVICE_NAME='iPad Pro 13-inch (M5)' ./scripts/launch.sh ipad
```

iPhone:

```bash
./scripts/launch.sh ios
```

Uses derived data under `macos/.derivedData-ios` and `simctl install` / `launch`.

In Simulator, choose **Device → iPad** (or iPhone) so the app is full-screen—not the tiny iPhone-compat window; use **⌘1** for the app switcher if the app is behind Simulator chrome.

## Run in Xcode

1. `open macos/Package.swift`
2. Scheme **GatteyPhotosIOS**
3. Destination: **iPad** or **iPhone** simulator
4. Run (⌘R)

## macOS dev loop unchanged

After `macos/` edits that affect the shipping macOS app (including shared `GatteyPhotosUI`), run **`./scripts/launch.sh macos`** per **`skills/dev-loop/SKILL.md`**. iOS-only testing does not replace relaunch when mac UI behavior may have changed.

## macOS-only (not on iOS)

- macOS glass window chrome (`NSWindow` vibrancy)
- Finder drop / `NSOpenPanel` upload (iOS uses **PhotosPicker**)
- No gallery pull when the app is locked or quit (same on all platforms)
