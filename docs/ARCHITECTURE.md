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
}

interface GalleryState {
  version: number;        // monotonic, bumped on every write
  order: PhotoId[];       // display order, excludes soft-deleted unless tombstone needed
  photos: Record<PhotoId, PhotoEntry>;
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
| `macos/` SwiftUI app | Gallery UI, upload/delete/reorder, manual refresh, settings (device IP, server URL, sync password). |
| `GatteyPhotosSyncHelper` (inside `.app`) | LaunchAgent at login; polls hourly; merges; pushes to Bloomin8. |

## Bloomin8 device

`POST http://{deviceIP}/upload?filename=&gallery=default&show_now=0` with multipart field `image` (JPEG).

## Auth

`Authorization: Bearer <password>`. Server compares to `SYNC_PASSWORD` env (Edge Config in production). Password is not bundled in the app; each family member enters it in Settings.

## Local development

```bash
./scripts/dev-local.sh
```

Runs sync API on port 3000 with filesystem storage. Point the macOS app at `http://127.0.0.1:3000`.
