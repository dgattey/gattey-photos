# Gattey Photos architecture

## Data shape

`GalleryState` is the single source of truth on the sync server.

```ts
type PhotoId = string; // UUID

interface PhotoEntry {
  id: PhotoId;
  filename: string;
  blobPath: string;       // e.g. photos/{id}.jpg
  sizeBytes: number;
  updatedAt: string;    // ISO-8601
  deletedAt: string | null;
  uploadedBy: string;     // family member display name; legacy entries backfill to "Dylan" on read
}

interface GalleryState {
  version: number;        // monotonic, bumped on every write
  order: PhotoId[];       // display order, excludes soft-deleted unless tombstone needed
  photos: Record<PhotoId, PhotoEntry>;
  currentPhotoId?: PhotoId | null;  // Bloomin8 display; Bloomin8 upload uses show_now on this id
}
```

Clients cache JPEG bytes under `~/Library/Application Support/GatteyPhotos/cache/{id}.jpg`.

## Conflict merge (per photo)

After fetching remote `R` and comparing to local `L`:

1. Start from a copy of `R` (remote wins for order, metadata, and deletes).
2. For each photo id in `L` that is active locally (`deletedAt == null`) and absent from `R.photos`, append to `order` and copy the entry (local-only addition).
3. Do not apply local deletes when remote still has the photo active.

## Runtime components

| Component | Role |
|-----------|------|
| `server/` | Next.js on Vercel. Blob + Edge Config in prod; filesystem under `.data/` when `GATTEY_LOCAL_STORAGE=1`. |
| `macos/` SwiftUI app | Gallery UI, upload/delete/reorder, manual refresh, unlock gate, settings (Bloomin8 token, server URL; debug mode for local dev). |
| `GatteyPhotosSyncHelper` (inside `.app`) | LaunchAgent while unlocked; polls every 15 minutes; merges; pushes to Bloomin8. |

## Bloomin8 device

The macOS app uses the **Bloomin8 Open API** (einkshot) with a device Bearer token in `config.json` as `bloomin8ApiToken` (parsed from pasted setup text via `Bloomin8TokenParser`). There is no LAN discovery or subnet scan.

`GET {einkshot}/open-api/device/status` — screen `width`/`height`, `remote_image_on`, wake interval. Preview defaults to 13.3" Eink Canvas (1200×1600) until status is fetched.

**Push (app default):** `POST {einkshot}/open-api/push` with Bearer token (multipart `image`). Display on the next scheduled wake (`estimated_push_time`); last-wins queue. Requires `remote_image_on` on the device.

**Device display:** Open API `POST /open-api/push` (queued for next wake). No LAN upload path in the app.

## Auth

`Authorization: Bearer` accepts either the family sync password or a signed session token minted by `POST /api/auth/session` (password only on that route). New session tokens do not expire; they remain valid until `SYNC_PASSWORD` changes on the server (HMAC secret rotation). Legacy tokens that included an `exp` field still honor that expiry. Server secret is `SYNC_PASSWORD` (env locally; Vercel env or Edge Config `syncPassword` in production). The macOS app stores `syncSessionToken` and `displayName` in `config.json` after unlock; the password is not persisted in the app bundle or settings UI. Uploads send `displayName` as manifest `uploadedBy`.

**Background sync:** After unlock, the app installs `~/Library/LaunchAgents/com.gattey.photos.sync.plist` (`GatteyPhotosSyncHelper`, every **15 minutes**). Locking clears `syncSessionToken` and **stops** the LaunchAgent so nothing syncs while logged out. Dev `swift run` uses `EmbeddedSyncRunner` when no bundled helper exists (same interval, same auth gate).

**Server state:** The Next.js API is stateless (no in-memory gallery). Canonical state is one JSON manifest plus JPEG blobs in storage:

| Artifact | Location (production) | Contents |
|----------|------------------------|----------|
| `gallery/manifest.json` | Vercel Blob | Full `GalleryState`: `version`, `order`, `photos`, **`currentPhotoId`** |
| `photos/{id}.jpg` | Vercel Blob | Image bytes |

Local dev (`GATTEY_LOCAL_STORAGE=1`) mirrors the same layout under `server/.data/`. `currentPhotoId` is a field inside the manifest JSON, not a separate blob or server session.

**Scheduled advance (production):** Vercel Cron hits `GET /api/cron/advance-current` once daily at **11:00 UTC** (`server/vercel.json`, `0 11 * * *`; Hobby allows at most one run per day; schedules are UTC-only). Chosen so the advance runs overnight US time and completes before a typical ~7 AM wake on both coasts (≈ 6 AM EST / 7 AM EDT / 3 AM PST / 4 AM PDT). Authenticated with `CRON_SECRET` (`Authorization: Bearer`). The handler advances `currentPhotoId` along manifest `order` among active photos (wrap at end). Local dev: `./scripts/local-advance-cron.sh` (default 30 minutes / 1800s; override `ADVANCE_CURRENT_INTERVAL_SECONDS`) or a manual `curl` to the same route.

**Cron → device (not direct):** Cron only writes the manifest. The Mac (or sync helper) must pull, then `POST /open-api/push` to einkshot; the frame shows the image on its next scheduled wake. Background `SyncLoop` uses `fullSync` every 15 minutes while unlocked. The UI `refresh()` path also queues a device push when `currentPhotoId` changed on pull. Manual **Sync** (`syncAll`) always pushes the current photo after pull.

## Local development

```bash
./scripts/dev.sh
```

Starts the sync API on port 3000 (supervisor + `GATTEY_LOCAL_STORAGE=1`), packages the app, and opens `dist/Gattey Photos.app`. API only: `./scripts/start-server.sh`. Point the macOS app at `http://127.0.0.1:3000`.
