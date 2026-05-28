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
| `EDGE_CONFIG` | Optional; use Edge Config key `syncPassword` instead of env |

Do **not** set `GATTEY_LOCAL_STORAGE` in production.

## Local parity

```bash
make dev
```

Uses `GATTEY_LOCAL_STORAGE=1` and `server/.data/` instead of Blob.
