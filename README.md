# Gattey Photos

Family-shared photo gallery: Vercel sync API, macOS app, Bloomin8 display uploads.

## Quick start

Uses **mise** for Node and SwiftLint (`mise.toml`; run `mise install` once). Do not use Homebrew `node`. Building, testing and releasing the app go through [DylKit](https://github.com/dgattey/dyl-kit) (`./run dev …`, `./run release …`); its [`apple-dev-loop`](https://github.com/dgattey/dyl-kit/blob/main/skills/apple-dev-loop/SKILL.md) and [`apple-release`](https://github.com/dgattey/dyl-kit/blob/main/skills/apple-release/SKILL.md) skills are the reference.

```bash
./scripts/dev.sh
```

Starts the local sync API (`http://127.0.0.1:3000`), builds `build/Gattey Photos Dev.app`, and opens it in the background. On first run it seeds `~/Library/Application Support/GatteyPhotos Dev/config.json` with the local server URL (empty session token). Unlock with the family password from `server/.env.local` (`SYNC_PASSWORD`; default in `.env.example` is `change-me-family-only` until you change it). The dev app has its own bundle ID (`com.gattey.photos.dev`) and support folder, so it runs alongside an installed Gattey Photos.

Rebuild the app only, or run it on the iOS Simulator:

```bash
./run dev build
./run dev ios --run --capture
```

Run the sync API alone (two-terminal flow):

```bash
./scripts/start-server.sh   # or: cd server && GATTEY_LOCAL_STORAGE=1 npm run dev
./run dev relaunch          # rebuilds and reopens build/Gattey Photos Dev.app
```

Stop the dev supervisor:

```bash
./scripts/stop-server.sh
```

## Layout

| Path | Purpose |
|------|---------|
| `server/` | Next.js sync API and download site |
| `Sources/`, `Tests/`, `Package.swift` | SwiftUI app for macOS and iOS |
| `DylApp.toml` | Bundle, signing, release and site settings for DylKit |
| `scripts/` | `dev.sh` (full stack), `start-server.sh`, `stop-server.sh`, `local-advance-cron.sh`, Sparkle key helpers |

## Deploy

[DEPLOY.md](DEPLOY.md) — Vercel root directory `server`.

## API

`Authorization: Bearer` with a session token from `POST /api/auth/session` (family password only on that route). See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
