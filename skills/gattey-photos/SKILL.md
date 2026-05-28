---
name: gattey-photos
description: Work on the Gattey Photos monorepo — macOS SwiftUI app, sync server on Vercel, Bloomin8 device uploads, and family gallery conflict merge. Use when changing gallery sync, the daemon, server API routes, or macOS UI.
---

# Gattey Photos

## Repo map

| Path | Owns |
|------|------|
| `server/lib/types.ts` | `GalleryState`, `PhotoEntry` canonical JSON shape |
| `server/lib/gallery.ts` | Manifest mutations (order, soft delete, version bump) |
| `server/lib/storage/` | `GATTEY_LOCAL_STORAGE=1` → `.data/`; else Vercel Blob |
| `macos/Sources/GatteyPhotosCore/` | Swift client, merge, Bloomin8 HTTP upload |
| `macos/Sources/GatteyPhotosApp/` | SwiftUI UI only |
| `macos/Sources/GatteyPhotosSyncHelper/` | Hourly sync binary bundled in the app |
| `macos/Sources/GatteyPhotosCore/SyncHelperLauncher.swift` | LaunchAgent install on first app open |

## Invariants

1. **Auth:** Every API call uses `Authorization: Bearer` matching `SYNC_PASSWORD` (never ship the password in the app binary; Settings stores it per machine).
2. **Merge:** `GalleryMerge.merge` in Swift mirrors server truth — remote wins except local-only active photo ids.
3. **Device:** Bloomin8 `POST http://{deviceIP}/upload` with query `filename`, `gallery`, `show_now` and multipart field `image` (JPEG).
4. **Cache:** JPEG bytes live in `~/Library/Application Support/GatteyPhotos/cache/{id}.jpg`.

## Local verify

```bash
make dev
```

Node comes from **mise** (`mise.toml`), not Homebrew.

## Common tasks

- **New API field:** Update `server/lib/types.ts`, `macos/.../Models.swift`, and `buildGalleryResponse` if exposed to clients.
- **UI toolbar:** `RootView.swift` — trailing `ToolbarItemGroup(placement: .primaryAction)`.
- **Deploy:** Vercel project rooted at `server/`; remove `GATTEY_LOCAL_STORAGE`.

Read `docs/ARCHITECTURE.md` before structural changes.
