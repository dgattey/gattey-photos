---
name: gattey-photos-project
description: Work on the Gattey Photos monorepo — macOS SwiftUI app, sync server on Vercel, Bloomin8 device uploads, and gallery timestamp sync. Use when changing gallery sync, server API routes, or macOS UI.
---

# Gattey Photos

## Repo map

| Path | Owns |
|------|------|
| `server/lib/types.ts` | `GalleryState`, `PhotoEntry` canonical JSON shape |
| `server/lib/gallery.ts` | Manifest mutations (order, soft delete, current) |
| `server/lib/gallery-mutation.ts` | `applyGalleryMutation`, `respondGalleryMutation`, `baseUpdatedAt` |
| `server/lib/storage/` | `GATTEY_LOCAL_STORAGE=1` → `.data/`; else Vercel Blob |
| `macos/Sources/GatteyPhotosUI/GalleryStore.swift` | Gallery UI, pull/mutations, 409 retry, backoff |
| `macos/Sources/GatteyPhotosApp/` | SwiftUI UI only (macOS) |
| `macos/Sources/GatteyPhotosIOS/` | iOS Simulator scaffold (placeholder UI) |

## Invariants

1. **Auth:** Gallery/device API calls use `Authorization: Bearer` with `syncSessionToken` only. The family password is sent once to `POST /api/auth/session` to mint the token; `SYNC_PASSWORD` stays on the server.
2. **Sync:** Every mutation sends `baseUpdatedAt`; server returns 409 when manifest is newer. `GalleryStore` applies 409 body and retries. Pull replaces local state; failed periodic pulls back off in-store.
3. **Device:** Server pushes current JPEG via einkshot on manual set-current and cron advance (after `applyGalleryMutation`).
4. **Cache:** JPEG bytes live in `~/Library/Application Support/GatteyPhotos/cache/{id}.jpg`.

## Local verify

See **`skills/dev-loop/SKILL.md`** for rebuild, server restart, and `npm run typecheck`. Full stack: `./scripts/dev.sh` (or `npm run dev`).

## Common tasks

- **New API field:** Update `server/lib/types.ts`, `macos/.../Models.swift`, and `buildGalleryResponse` if exposed to clients.
- **UI toolbar:** `GalleryGridView.swift` — `GalleryMainToolbar` on the gallery window.
- **Deploy:** Vercel project rooted at `server/`; remove `GATTEY_LOCAL_STORAGE`.

Read `docs/ARCHITECTURE.md` before structural changes.
