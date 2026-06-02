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
  uploaderId: string;   // stable id for the family member who uploaded; display name via `uploaders`
}

interface GalleryState {
  updatedAt: string;      // ISO-8601; bumped on every manifest write (gallery revision)
  order: PhotoId[];       // display order, excludes soft-deleted unless tombstone needed
  photos: Record<PhotoId, PhotoEntry>;
  uploaders: Record<string, string>;  // uploader id → display name; `PATCH /api/gallery/uploaders` renames one map entry when settings change
  currentPhotoId?: PhotoId | null;  // Bloomin8 display; Bloomin8 upload uses show_now on this id
}
```

Legacy manifests may still store `uploadedBy` on photos without `uploaderId`; reads coalesce each distinct name to a deterministic id and fill `uploaders`. New uploads register the client’s `uploadedBy` form field via `ensureUploaderId` and persist `uploaderId` on the photo only.

Clients cache JPEG bytes under `~/Library/Application Support/GatteyPhotos/cache/{id}.jpg` (full) and `{id}_w{width}.jpg` (grid thumbnails) on macOS, or the app container on iOS.

## Storage layout (two blobs)

`GalleryState` is assembled at read time from two blobs so the frequently-rotated current photo never rewrites the catalog:

- `gallery/manifest.json` — the catalog: `updatedAt`, `order`, `photos`, `uploaders`. Written only by upload / delete / reorder / rename.
- `gallery/current.json` — `{ currentPhotoId, currentPhotoUpdatedBy, updatedAt }`. Written only by the cron rotate and manual "set current".

Both are read from origin (`useCache: false`) for read-after-write consistency, written with a 60s max cache. `storage.readManifest()` merges them and validates `currentPhotoId` against the active order.

## Sync (timestamp concurrency)

Catalog mutations (upload, delete, reorder, rename uploader) are single atomic catalog writes. The client sends `baseUpdatedAt` (the `updatedAt` it last saw). If the catalog is **newer**, the server responds **409** with the current gallery; the client applies that state and retries (up to a few attempts). Setting the current photo is last-write-wins against the cron and writes only `current.json`.

Pulls replace local state, no merge. Two cheap pull paths:

- `GET /api/gallery` is conditional: it returns an `ETag` of the catalog `updatedAt` and `304 Not Modified` when the client sends a matching `If-None-Match`, so an unchanged periodic pull transfers nothing.
- `GET /api/gallery/current` is a tiny payload the client polls to catch cron rotations without a full catalog pull.

The response carries only `state` (no duplicated photos array, no per-photo download URLs); clients build image URLs from the photo id. Failed pulls use exponential backoff.

## Images

`GET /api/gallery/photos/{id}/image` serves the original, or a resized JPEG when given `?w=<width>` (sharp, clamped 64–2048). The grid requests thumbnails at the cell width; the lightbox and device preview use the original.

## Runtime components

| Component | Role |
|-----------|------|
| `server/` | Next.js on Vercel. Blob + Edge Config in prod; filesystem under `.data/` when `GATTEY_LOCAL_STORAGE=1`. Owns gallery manifest, JPEG blobs, **device registry**, and **Bloomin8 push**. |
| `GatteyPhotosUI` + `GatteyPhotosCore` | Shared on macOS, iOS, iPadOS: gallery browser, upload, reorder, set current, frame registration. **Pull-only** sync; no client Bloomin8 push. |
| `GalleryStore` periodic pull | Same on macOS, iOS, iPadOS: `fetchGallery` + `commit` every 15 minutes **while unlocked** (foreground refresh, manual sync, and timer share one path; backoff on failure). |

## Bloomin8 frames (server-owned)

- Frame tokens live in `devices/registry.json` (Vercel Blob or local `.data/`), encrypted with `SYNC_PASSWORD`.
- Any signed-in family member can register or remove frames via `POST/GET/DELETE /api/devices`.
- `GET /api/devices/status` pings each frame for the connection pill and preview aspect ratio.
- On manifest commits that set `currentPhotoId` (`PUT /api/gallery/current`, cron advance), the server loads the current JPEG from blob storage and `POST`s to einkshot for **each** registered frame.
- Offline frames are logged; the manifest **always** saves. Push failures on individual frames do not roll back the gallery write.

Clients paste the Bloomin8 setup block in **Settings → Frames** (not at unlock). Use **Copy setup instructions** for the paste workflow.

## Auth

Gallery and device routes accept `Authorization: Bearer` with a signed session token from `POST /api/auth/session` only (password is not accepted on those routes). `GET /api/auth/verify` checks the stored session token. Session tokens do not expire until `SYNC_PASSWORD` rotates. The app stores `syncSessionToken` and `displayName` in `config.json` after unlock.

**Client sync:** Pull-only via `GalleryStore.pullFromServer` (foreground refresh, manual sync, 15-minute timer while unlocked). No sync when locked or quit; no separate macOS helper or LaunchAgent.

**Server state:**

| Artifact | Location (production) | Contents |
|----------|------------------------|----------|
| `gallery/manifest.json` | Vercel Blob | `GalleryState` |
| `photos/{id}.jpg` | Vercel Blob | Image bytes |
| `devices/registry.json` | Vercel Blob | Encrypted frame tokens + metadata |

**Scheduled advance (production):** Vercel Cron `GET|POST /api/cron/advance-current` once daily at **11:00 UTC** (`0 11 * * *`). Advances `currentPhotoId` and triggers server push to all frames.

## Local development

```bash
./scripts/dev.sh
```

Starts the sync API on port 3000 (`GATTEY_LOCAL_STORAGE=1`). Point the app at `http://127.0.0.1:3000` via Debug mode. Do not start the API from inside the app; use `dev.sh` or `start-server.sh`.
