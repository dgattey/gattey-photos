---
name: server
description: Change the Gattey Photos Next.js sync API on Vercel (gallery routes, Blob manifest, auth). Use for server-only work in gattey-photos/server.
---

# Gattey Photos server

## Entry points

- `app/page.tsx` — `GET /` download page from `@dylkit/web`, built from `[site]` in `../DylApp.toml` and the Blob store's `release.json` (revalidated every minute)
- `app/appcast.xml/route.ts`, `app/download/macos/route.ts` — installed apps' `SUFeedURL` and the download redirect, both read from the release Blob store (`[release] assets`)
- `app/icons/[name]/route.ts` — `/icons/*`, re-exported at `/icon.png`, `/apple-touch-icon.png` and `/favicon.ico`: the icons each release uploads, served cross-origin for dylangattey.com
- `next.config.ts` — traces `../DylApp.toml` and the screenshots into the functions, since `loadSite()` reads them at request time
- `app/api/gallery/route.ts` — GET manifest
- `app/api/gallery/photos/route.ts` — POST upload
- `app/api/gallery/photos/[id]/route.ts` — DELETE
- `app/api/gallery/order/route.ts` — PUT reorder
- `app/api/gallery/uploaders/route.ts` — PATCH rename an uploader in the `uploaders` map (settings display name change)
- `app/api/gallery/blob/[path]/route.ts` — GET bytes (local dev only)
- `app/api/gallery/current/route.ts` — PUT set current (`baseUpdatedAt`, then device push)
- `app/api/devices/route.ts` — GET list / POST register frame (encrypted token in registry)
- `app/api/devices/[id]/route.ts` — DELETE frame
- `app/api/devices/status/route.ts` — live reachability per frame

## Storage

`lib/storage/index.ts` picks backend via `GATTEY_LOCAL_STORAGE` (Vercel Blob in production). Blob `put`/`get` use `access: private` by default (`GATTEY_BLOB_ACCESS=public` only for a public store). Prod downloads: `/api/gallery/photos/[id]/image`, not direct Blob URLs.

- `gallery/manifest.json` — `GalleryState`
- `devices/registry.json` — frame tokens (AES-GCM with `SYNC_PASSWORD`)
- `photos/{id}.jpg` — JPEG blobs

`lib/gallery-mutation.ts` — `applyGalleryMutation`, `respondGalleryMutation` (shared 409 handling). Current/cron call `pushCurrentPhotoToAllDevices` after a successful mutation.

## Auth

`lib/auth.ts` — `assertSessionToken` on gallery/devices routes (Bearer = signed session only). `POST /api/auth/session` mints tokens (`assertPasswordOnly`, password Bearer). `GET /api/auth/verify` validates session Bearer.

`GET|POST /api/cron/advance-current` — `assertCronSecret` (`Authorization: Bearer` = `CRON_SECRET`). Vercel Cron schedule in `vercel.json` (`0 11 * * *` = 11:00 UTC daily; Hobby limit; ≈ 6 AM EST / 7 AM EDT / 3 AM PST / 4 AM PDT). Local loop: `./scripts/local-advance-cron.sh`.

## Local dev

```bash
cd server && cp .env.example .env.local && GATTEY_LOCAL_STORAGE=1 npm run dev
```

Do not write to local disk in production handlers except through the storage adapter.
