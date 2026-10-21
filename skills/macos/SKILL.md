---
name: macos
description: Change the Gattey Photos macOS SwiftUI app. Use for UI, SyncClient, Application Support config, or shared GatteyPhotosUI behavior.
---

# Gattey Photos macOS

After **each** Swift edit session, rebuild and verify per **`skills/dev-loop/SKILL.md`** before considering the task done; `swift build` alone does not refresh `build/Gattey Photos Dev.app`. If you also changed runtime `server/` code, restart the local server per dev-loop first.

The sync API is **not** bundled in the app. Run the server separately (`./scripts/start-server.sh` or `./scripts/dev.sh`). Sync server URL is `http://127.0.0.1:3000` in **Debug** mode and `https://photos.gattey.com` in production (read-only in Settings; toggle via **Debug → Toggle Debug Mode**).

## Targets (Package.swift)

- `GatteyPhotosCore` — networking and merge; no SwiftUI
- `GatteyPhotosUI` — shared SwiftUI (gallery, unlock, settings); used by macOS and iOS
- `GatteyPhotosApp` — `@main` for macOS and iOS (macOS `AppDelegate`, Debug menu); the one executable DylKit bundles
Gallery pull while unlocked matches iOS: `AppSession` starts `GalleryStore.startPeriodicPullWhileUnlocked()` (15 min, same code path as refresh and ⌘R Sync). No LaunchAgent or bundled helper binary.

iOS/iPad app (shared `GatteyPhotosUI` + `GatteyPhotosCore`): see **`skills/ios/SKILL.md`**.

## App icon

Author `AppIcon.icon/` in **Icon Composer** (layer fills, glass on/off), not hand-wavy JSON. There is no Xcode project: `scripts/link-app-icon.swift` (the `[build] icon-generator` in `DylApp.toml`) hands it to devkit, which runs `actool` into the bundle's `Assets.car`.

**Canvas gradient (root fill in `icon.json`):** vertical linear gradient only (two stops). Top RGB **94, 159, 125** → `srgb:0.368627,0.623529,0.490196,1.000000`. Bottom RGB **46, 92, 69** → `srgb:0.180392,0.360784,0.270588,1.000000`. Orientation `start` (0.5, 0) → `stop` (0.5, 1). Edit in Icon Composer: select **AppIcon** in the sidebar → Fill → Gradient.

**Letter G:** `Assets/Letter-G.svg` (Georgia “G” as paths, not live text). Icon Composer’s public `icon.json` schema uses `image-name` layers; Apple’s docs say to convert text to outlines in SVG. Tweak glass/position in Icon Composer on that image layer, or regenerate paths: `swift scripts/ExportLetterG.swift`. Do not expect a separate “Text layer” type in Icon Composer for actool.

Single **G** group: `glass: true`, solid white layer fill, translucency/specular on the group. Rebuild with `./run dev build`.

**Design sync.** An icon change also needs new web icons in `server/public/` (`icon.png` at 1024 px, `apple-touch-icon.png` and `apple-icon.png` at 180 px, `app-icon.png`) and `server/app/favicon.ico`. Export them from Icon Composer by hand until DylKit v0.2.1's `site-icons` generates them. Any icon, brand color, or UI redesign also updates photos.gattey.com and dylangattey.com (see **Design sync** in `AGENTS.md`). `server/lib/site-assets.test.ts` checks the shared icon URL contract in `npm test`.

## Auto-update (Sparkle)

The app self-updates through DylKit's `DylUpdates` (`AppUpdater.shared`, Sparkle 2 underneath). Family distribution uses **ad-hoc** signing (`-`) with `com.apple.security.cs.disable-library-validation` (`GatteyPhotos.local.entitlements`) plus EdDSA (`scripts/generate-sparkle-key.sh`). A push to **`main`** touching the `[release] inputs` in `DylApp.toml` runs `.github/workflows/release.yml`, which uses `release-kit` to commit `server/public/` once; Vercel Git deploys it. Each release bumps the version the merged PR checks under **Release info**. See DylKit's **`apple-release`** and **`docs/DISTRIBUTION.md`**.

## State

- `GalleryStore` (`GalleryStore.swift`) — UI-facing `@Observable` store, read with `@Environment(GalleryStore.self)`
- `AppConfig` — `config.json` and `local-gallery.json` under Application Support

## UI layout

Full-width `GalleryGridView`: left `DeviceCurrentPreview` (on-device photo, black frame, drop to set current) + right thumbnail grid. Floating `ConnectionStatusView` (top-trailing). `currentPhotoId` on `GalleryState` syncs via `PUT /api/gallery/current`; Bloomin8 `show_now` targets that photo. Toolbar **Set as current** when one grid photo is selected. Double-click opens `PhotoLightboxView`. Multi-select shows `GallerySelectionBar`. Drag thumbnails to reorder.

**macOS 26 toolbar Liquid Glass + soft scroll edge (verified recipe).** The scroll edge effect is automatic on macOS 26; you do not turn it on, you only avoid suppressing it. Three things must all hold, and any one wrong gives the failure shown:

1. `applyGatteyPhotosGalleryChrome` sets `titlebarAppearsTransparent = true`. With `false`, AppKit paints the standard opaque titlebar over the content and you get a solid gray toolbar slab at rest.
2. No forced toolbar background on 26. The `GalleryMacOSToolbarChrome` 26 branch is a no-op. A visible or opaque toolbar background (`.toolbarBackground(...)`, `.toolbarBackgroundVisibility(.visible)`) overrides Liquid Glass and suppresses the scroll edge (WWDC25 "Build a SwiftUI app with the new design"; HIG Toolbars best practices). Pre-26 keeps `.regularMaterial`.
3. A full-window content background fills under the toolbar so the glass samples app content, not the desktop. `RootView` uses `PushedDetailBackground` (`.withinWindow` vibrancy), which does not sample the desktop, so there is no wallpaper bleed. Do not use a `.behindWindow` background (`WindowGlassBackground`) for the gallery; it frosts the desktop and reads as bleed in the titlebar.

Grid `ScrollView` needs only `.scrollEdgeEffectStyle(.soft, for: .top)` (macOS 26+) for the soft fade. `.scrollClipDisabled()`, `.backgroundExtensionEffect()`, `.contentMargins(.top, 1)`, `.scrollContentBackground(.hidden)`, and a scroll edge on the gallery shell are not needed; content scrolls under the unified toolbar by default, and they were removed. Leading `ToolbarItemGroup(.navigation)` with `Toggle` + `.toggleStyle(.button)` + `.labelStyle(.iconOnly)` for device preview; title with `.sharedBackgroundVisibility(.hidden)` on 26+. `GatteyPhotosApp` sets `.windowToolbarStyle(.unified)`. Not `.primaryAction` on macOS.

Verify live with `.chrome-verify/capture-toolbar.sh <label>` (drives the running window over Accessibility across Spaces; writes `<label>-at-rest.png` and `<label>-scrolled.png`). A `-l` window capture shows within-window glass but not desktop bleed; for a bleed check use a composited full-screen capture over a bright backdrop.

**Glass chrome:** `GlassChromeStyle.swift` — floating panel background; `WindowGlassBackground.swift` — unlock/launch vibrancy; gallery uses `PushedDetailBackground`.

**Seamless titlebar (unlock + launch/checking).** Hide the titlebar *background* with `.toolbarBackground(.hidden, for: .windowToolbar)` over `UnlockGlassBackground()`, and keep the traffic lights. `WindowGlassBackground` (`.behindWindow`) leaves a darker titlebar strip, and hiding the `standardWindowButton`s is the wrong lever (it removes the traffic lights). When matching one screen's chrome to another, grep the baseline view (e.g. `UnlockView`) for the exact modifier and copy it, instead of guessing by eye or waiting for a screenshot.

## Settings popover

`UnlockView` / `AppSession` — name + family password only at unlock (`POST /api/auth/session` → `syncSessionToken`). All sync calls use session Bearer only.

`SettingsView.swift` + `FramesSettingsSection.swift` — register frames on the server (paste Bloomin8 setup block; tokens encrypted in `devices/registry.json` on Blob). **Debug → Toggle Debug Mode** switches API URL; start local server with `./scripts/dev.sh` (not from the app).

**Frames:** `GET /api/devices`, `POST /api/devices`, `GET /api/devices/status`. Server pushes to einkshot after `currentPhotoId` changes. No client pull when locked or quit.

Activity log inspector (toolbar / ⌘B) only when debug mode is on.

## Sync flows

- `GalleryStore.pullFromServer` — one path for foreground refresh, ⌘R Sync, and the 15-minute timer while unlocked

Server Bloomin8: `server/lib/bloomin8/`, `server/lib/devices/`.
