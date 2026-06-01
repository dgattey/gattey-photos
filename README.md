# Gattey Photos

Family-shared photo gallery: Vercel sync API, macOS app, Bloomin8 display uploads.

## Quick start

Uses **mise** for Node (`mise.toml`). Do not use Homebrew `node`.

```bash
./scripts/dev.sh
```

Starts the local sync API (`http://127.0.0.1:3000`), builds `dist/Gattey Photos.app`, and opens the app. On first run it seeds `~/Library/Application Support/GatteyPhotos/config.json` with the local server URL (empty session token). Unlock with the family password from `server/.env.local` (`SYNC_PASSWORD`; default in `.env.example` is `change-me-family-only` until you change it).

Rebuild the app only:

```bash
./scripts/package-macos.sh
```

Run the sync API alone (two-terminal flow):

```bash
./scripts/start-server.sh   # or: cd server && GATTEY_LOCAL_STORAGE=1 npm run dev
./scripts/package-macos.sh  # rebuilds and opens dist/Gattey Photos.app
```

After macOS UI changes, rebuild and relaunch:

```bash
./scripts/relaunch-app.sh
```

Stop the dev supervisor:

```bash
./scripts/stop-server.sh
```

## Layout

| Path | Purpose |
|------|---------|
| `server/` | Next.js sync API |
| `macos/` | SwiftUI app |
| `scripts/` | `dev.sh` (full stack), `package-macos.sh`, `relaunch-app.sh`, `start-server.sh`, `stop-server.sh`, `local-advance-cron.sh`, `generate-app-icon.sh` (via package) |

## Deploy

[DEPLOY.md](DEPLOY.md) — Vercel root directory `server`.

## API

`Authorization: Bearer` with the sync password or an opaque session token from `POST /api/auth/session`. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
