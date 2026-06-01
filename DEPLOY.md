# Deploying the sync server on Vercel

## Connect the GitHub repo

1. Push this repository to GitHub.
2. In Vercel: **Add New Project** → import `gattey-photos`.
3. Set **Root Directory** to `server` (required; the Next.js app lives there).
4. Framework preset should detect **Next.js** automatically.

Vercel only deploys `server/` when root directory is set. No monorepo rewrite is needed.

## Environment variables (Production)

| Variable | Purpose |
|----------|---------|
| `BLOB_READ_WRITE_TOKEN` | Vercel Blob (auto-added if Blob is linked) |
| `SYNC_PASSWORD` | Family sync password (not in the app binary) |
| `CRON_SECRET` | Protects `GET /api/cron/advance-current` (Vercel Cron sends `Authorization: Bearer …`) |
| `EDGE_CONFIG` | Optional; use Edge Config key `syncPassword` instead of env |

Do **not** set `GATTEY_LOCAL_STORAGE` in production.

## Scheduled current photo

`server/vercel.json` runs **`0 */4 * * *`** (every 4 hours) against `/api/cron/advance-current`, advancing `currentPhotoId` to the next active id in manifest `order` (wraps at end). Mac apps and Bloomin8 pick this up on their normal sync.

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

Seeds macOS settings (first run), builds and opens the app. Start the sync API with `./scripts/start-server.sh` (`GATTEY_LOCAL_STORAGE=1`, data in `server/.data/`). When `CRON_SECRET` is in `server/.env.local`, `start-server.sh` also starts `./scripts/local-advance-cron.sh` in the background (default **3600s** / 1 hour; override with `ADVANCE_CURRENT_INTERVAL_SECONDS`). `stop-server.sh` stops that loop too.

The Mac app only shows a new current photo after it syncs; the cron updates the manifest on the server.
