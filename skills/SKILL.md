---
name: gattey-photos-project
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
| `macos/Sources/GatteyPhotosApp/` | SwiftUI UI only (macOS) |
| `macos/Sources/GatteyPhotosIOS/` | iOS Simulator scaffold (placeholder UI) |
| `macos/Sources/GatteyPhotosSyncHelper/` | Background sync helper (15 min while unlocked) |
| `macos/Sources/GatteyPhotosCore/SyncHelperLauncher.swift` | LaunchAgent install on first app open |

## Invariants

1. **Auth:** API calls use `Authorization: Bearer` with `syncSessionToken` (or the sync password for session minting). Secret is `SYNC_PASSWORD` on the server only; unlock screen collects the password once per machine.
2. **Merge:** `GalleryMerge.merge` in Swift mirrors server truth — remote wins except local-only active photo ids.
3. **Device:** einkshot `POST /open-api/push` (Bearer Bloomin8 token; displays on next wake).
4. **Cache:** JPEG bytes live in `~/Library/Application Support/GatteyPhotos/cache/{id}.jpg`.

## Local verify

See **`skills/dev-loop/SKILL.md`** for rebuild, server restart, and `npm run typecheck`. Full stack: `./scripts/dev.sh` (or `npm run dev`).

## Common tasks

- **New API field:** Update `server/lib/types.ts`, `macos/.../Models.swift`, and `buildGalleryResponse` if exposed to clients.
- **UI toolbar:** `GalleryGridView.swift` — `GalleryMainToolbar` on the gallery window.
- **Deploy:** Vercel project rooted at `server/`; remove `GATTEY_LOCAL_STORAGE`.

Read `docs/ARCHITECTURE.md` before structural changes.
