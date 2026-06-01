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

Clients cache JPEG bytes under `~/Library/Application Support/GatteyPhotos/cache/{id}.jpg` (macOS) or the app container on iOS.

## Conflict merge (per photo)

After fetching remote `R` and comparing to local `L`:

1. Start from a copy of `R` (remote wins for order, metadata, and deletes).
2. For each photo id in `L` that is active locally (`deletedAt == null`) and absent from `R.photos`, append to `order` and copy the entry (local-only addition).
3. Do not apply local deletes when remote still has the photo active.

## Runtime components

| Component | Role |
|-----------|------|
| `server/` | Next.js on Vercel. Blob + Edge Config in prod; filesystem under `.data/` when `GATTEY_LOCAL_STORAGE=1`. Owns gallery manifest, JPEG blobs, **device registry**, and **Bloomin8 push**. |
| `GatteyPhotosUI` + `GatteyPhotosCore` | Shared on macOS, iOS, iPadOS: gallery browser, upload, reorder, set current, frame registration. **Pull-only** sync; no client Bloomin8 push. |
| `GalleryStore` periodic pull | Same on macOS, iOS, iPadOS: `SyncEngine.pullAndMerge` every 15 minutes **while unlocked** (foreground refresh, ⌘R, and timer share one path). |

## Bloomin8 frames (server-owned)

- Frame tokens live in `devices/registry.json` (Vercel Blob or local `.data/`), encrypted with `SYNC_PASSWORD`.
- Any signed-in family member can register or remove frames via `POST/GET/DELETE /api/devices`.
- `GET /api/devices/status` pings each frame for the connection pill and preview aspect ratio.
- On manifest commits that set `currentPhotoId` (`PUT /api/gallery/current`, cron advance), the server loads the current JPEG from blob storage and `POST`s to einkshot for **each** registered frame.
- Offline frames are logged; the manifest **always** saves. Push failures on individual frames do not roll back the gallery write.

Clients paste the Bloomin8 setup block in **Settings → Frames** (not at unlock). Use **Copy setup instructions** for the paste workflow.

## Auth

`Authorization: Bearer` accepts either the family sync password or a signed session token minted by `POST /api/auth/session`. Session tokens do not expire until `SYNC_PASSWORD` rotates. The app stores `syncSessionToken` and `displayName` in `config.json` after unlock.

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
