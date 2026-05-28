---
name: gattey-photos-server
description: Change the Gattey Photos Next.js sync API on Vercel (gallery routes, Blob manifest, auth). Use for server-only work in gattey-photos/server.
---

# Gattey Photos server

## Entry points

- `app/api/gallery/route.ts` — GET manifest
- `app/api/gallery/photos/route.ts` — POST upload
- `app/api/gallery/photos/[id]/route.ts` — DELETE
- `app/api/gallery/order/route.ts` — PUT reorder
- `app/api/gallery/blob/[path]/route.ts` — GET bytes (local dev only)

## Storage

`lib/storage/index.ts` picks backend via `GATTEY_LOCAL_STORAGE`.

Manifest path is always `gallery/manifest.json` (`MANIFEST_PATH` in `lib/gallery.ts`).

## Auth

`lib/auth.ts` — `assertSyncPassword` on every mutating and read route.

## Local dev

```bash
cd server && cp .env.example .env.local && GATTEY_LOCAL_STORAGE=1 npm run dev
```

Do not write to local disk in production handlers except through the storage adapter.
