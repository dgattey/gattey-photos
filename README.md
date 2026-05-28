# Gattey Photos

Family-shared photo gallery that syncs through a Vercel API and pushes JPEGs to a Bloomin8 e-ink display on your LAN.

## Quick start (local)

One command starts the sync API and opens the macOS app:

```bash
make dev
```

Or: `./scripts/dev.sh`

Configure **Settings** in the app: server `http://127.0.0.1:3000`, sync password from `server/.env.local`, and your Bloomin8 device IP.

## Package the macOS app

Builds `dist/Gattey Photos.app` with the main app and a bundled background sync helper.

```bash
make package-macos
cp -R "dist/Gattey Photos.app" /Applications/
open "/Applications/Gattey Photos.app"
```

On first launch the app installs a per-user LaunchAgent (`com.gattey.photos.sync`) that runs the helper inside the app bundle. It starts at login and keeps running. No separate daemon install.

When you run via `swift run` during development, the app uses an in-process hourly sync instead (stops when you quit the app).

## Repository layout

| Path | Purpose |
|------|---------|
| `server/` | Next.js sync API (Vercel project root) |
| `macos/` | SwiftUI app + bundled `GatteyPhotosSyncHelper` |
| `skills/` | Cursor agent skills |
| `scripts/` | `dev.sh`, `package-macos.sh` |

## Vercel deploy

See [DEPLOY.md](DEPLOY.md). Set the Vercel project **Root Directory** to `server`.

## Conflict policy

Per-photo merge: remote wins for order, updates, and deletes. Local-only uploads are kept.

## API

All routes require `Authorization: Bearer <password>`.

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/gallery` | Manifest + download URLs |
| POST | `/api/gallery/photos` | Upload JPEG |
| DELETE | `/api/gallery/photos/:id` | Soft-delete |
| PUT | `/api/gallery/order` | Reorder |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
