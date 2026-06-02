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
  uploadedBy: string;     // family member display name at upload; legacy entries backfill to "Dylan" on read; `PATCH /api/gallery/uploaders` rewrites matching names when a client saves a new display name in settings
}

interface GalleryState {
  updatedAt: string;      // ISO-8601; bumped on every manifest write (gallery revision)
  order: PhotoId[];       // display order, excludes soft-deleted unless tombstone needed
  photos: Record<PhotoId, PhotoEntry>;
  currentPhotoId?: PhotoId | null;  // Bloomin8 display; Bloomin8 upload uses show_now on this id
}
```

Clients cache JPEG bytes under `~/Library/Application Support/GatteyPhotos/cache/{id}.jpg` (macOS) or the app container on iOS.

## Sync (timestamp concurrency)

Every gallery mutation (upload, delete, reorder, set current, rename uploader) is a single atomic server write. The client sends `baseUpdatedAt` (the `updatedAt` it last saw). If the on-disk manifest is **newer** than `baseUpdatedAt`, the server responds **409** with the current gallery; the client applies that state and retries the same intent with the new timestamp (up to a few attempts).

Pulls (`GET /api/gallery`) replace local state entirely — no merge. Failed pulls use exponential backoff so periodic sync does not hammer an unreachable server.

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
