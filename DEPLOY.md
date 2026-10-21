# Deploying the sync server on Vercel

## Connect the GitHub repo

1. Push this repository to GitHub.
2. In Vercel: **Add New Project** → import `gattey-photos`.
3. Set **Root Directory** to `server` (required; the Next.js app lives there).
4. Framework preset should detect **Next.js** automatically.

Vercel only deploys `server/` when root directory is set. No monorepo rewrite is needed.

macOS Sparkle files in `server/public/` are committed by `.github/workflows/release.yml` (DylKit's `release-kit`) when the app changes. `server/vercel.json`'s `ignoreCommand` also redeploys when `DylApp.toml` changes, since the download page reads it. Vercel’s normal Git Production deploy serves them; no extra Vercel settings required. See `docs/DISTRIBUTION.md`.

## Environment variables (Production)

| Variable | Purpose |
|----------|---------|
| `BLOB_READ_WRITE_TOKEN` | Vercel Blob (auto-added if Blob is linked) |
| `SYNC_PASSWORD` | Family sync password (not in the app binary) |
| `CRON_SECRET` | Protects `GET /api/cron/advance-current` (Vercel Cron sends `Authorization: Bearer …`) |
| `EDGE_CONFIG` | Optional; use Edge Config key `syncPassword` instead of env |

Do **not** set `GATTEY_LOCAL_STORAGE` in production.

Blob uploads use **`access: private`** by default (required when the linked Blob store is private). Optional `GATTEY_BLOB_ACCESS=public` only if the store is configured for public access. Gallery JPEGs are not served from raw Blob URLs in production; clients use authenticated `GET /api/gallery/photos/{id}/image` (`downloadUrl` in API responses). Re-upload photos if an old manifest still points at obsolete public Blob URLs.

## Scheduled current photo

`server/vercel.json` runs **`0 11 * * *`** (once daily at **11:00 UTC**; Hobby plan limit; Vercel crons are UTC-only) against `/api/cron/advance-current`, advancing `currentPhotoId` to the next active id in manifest `order` (wraps at end). Mac apps and Bloomin8 pick this up on their normal sync.

That time is overnight in the US and finishes before a typical ~7 AM wake on both coasts:

| Zone | Local time (11:00 UTC) |
|------|-------------------------|
| EST | 6:00 AM |
| EDT | 7:00 AM |
| PST | 3:00 AM |
| PDT | 4:00 AM |

Local verification (1-hour loop while the dev API is up):

```bash
chmod +x ./scripts/local-advance-cron.sh
./scripts/local-advance-cron.sh
```

One-shot (after `CRON_SECRET` is in `server/.env.local`):

```bash
curl -s -H "Authorization: Bearer $CRON_SECRET" http://127.0.0.1:3000/api/cron/advance-current
```

## Local parity

```bash
./scripts/dev.sh
```

Starts the sync API, then builds and opens the app with `./run dev relaunch`. Start the sync API with `./scripts/start-server.sh` (`GATTEY_LOCAL_STORAGE=1`, data in `server/.data/`). When `CRON_SECRET` is in `server/.env.local`, `start-server.sh` also starts `./scripts/local-advance-cron.sh` in the background (default **3600s** / 1 hour; override with `ADVANCE_CURRENT_INTERVAL_SECONDS`). `stop-server.sh` stops that loop too.

The Mac app only shows a new current photo after it syncs; the cron updates the manifest on the server.
