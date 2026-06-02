---
name: dev-loop
description: Rebuild, restart, and verify the Gattey Photos local stack after edits. Use when changing macos/, server/, or before ending an agent task that touched either; covers launch.sh, server supervisor, typecheck, and dev.sh.
---

# Gattey Photos dev loop

Canonical rebuild/restart steps for agents. Domain skills (`macos`, `server`) describe code layout; this skill owns **how to refresh running processes**.

Node: **mise** (`mise.toml`). If `npm` is missing, prepend shims:

```bash
export PATH="$HOME/.local/share/mise/shims:$PATH"
```

## macOS / frontend (Swift UI)

After **each** edit session that touches `macos/` (every agent turn with macOS code changes), from repo root:

```bash
./scripts/launch.sh macos
```

Do **not** treat the task as done until this has run for that session’s macOS edits. Agents must not skip relaunch.

- **One relaunch per macOS change batch** — if you edited `macos/` in this turn, relaunch before ending the turn.
- **Active UI iteration** — when the user is tuning SwiftUI or visual behavior, do **not** stack multiple macOS edits and relaunch once at the end. Relaunch after each logical UI change so they can verify in a fresh process.
- **`swift build` / compile success is not enough** — the running UI loads `dist/Gattey Photos.app` from `package-macos.sh`. A successful compile alone leaves a stale bundle in `dist/`.

Prefer `launch.sh macos` (quit + rebuild + open). Use `./scripts/package-macos.sh` only when no copy is running; `open` alone reuses the old process.

Both paths regenerate the dock icon every time (`generate-app-icon.sh` → `Assets.car` inside the bundle). After editing `macos/AppIcon.icon/`, relaunch is enough; no separate icon step.

- Entry point: `./scripts/dev.sh` or `npm run dev` (no separate Make wrapper); no install to `/Applications`
- `repo-root.txt` under Application Support is optional legacy from `dev.sh` / `package-macos.sh` (not used by the app)

### Changes not showing in the UI?

1. **Use `launch.sh macos`, not `package-macos.sh` alone** if the app is already running. `open dist/Gattey Photos.app` only focuses the existing process; Swift/UI code stays in memory until quit.
2. **Run only from `dist/Gattey Photos.app`**. An old copy in `/Applications` or a Dock alias to it will not pick up repo builds.
3. **Do not stop after `swift build`**. The running `.app` is assembled by `package-macos.sh` (copy into `dist/`). `.build/release/GatteyPhotos` alone is not what `open` uses.
4. Check the script prints a new `CFBundleVersion` and timestamp after package; if unsure, run `./scripts/launch.sh macos` again.

## Backend / server (Next.js under `server/`)

After **each** edit session under `server/` that affects runtime behavior (routes, `lib/`, env handling), restart the local sync API so the running process picks up changes:

```bash
./scripts/stop-server.sh
./scripts/start-server.sh
```

(`start-server.sh` is idempotent if the supervisor is already healthy.)

Or restart only the supervisor process if you know it is wedged.

Manual dev (no supervisor):

```bash
cd server && GATTEY_LOCAL_STORAGE=1 npm run dev
```

After server edits, run:

```bash
cd server && npm run typecheck
```

### Local `advance-current` cron and the Mac UI

`./scripts/start-server.sh` also starts `./scripts/local-advance-cron.sh` when `CRON_SECRET` is set in `server/.env.local` (default **30 minutes** / **1800s**; override with `ADVANCE_CURRENT_INTERVAL_SECONDS`). Pid/log: `.dev-advance-cron.pid`, `.dev-advance-cron.log`. `./scripts/stop-server.sh` stops both the supervisor and the cron loop.

Restart the server after adding `CRON_SECRET`, changing cron-related server code, or if advance requests fail while health is OK:

```bash
./scripts/stop-server.sh
./scripts/start-server.sh
```

Cron advances `currentPhotoId` and the **server** pushes to all registered frames. Clients **pull** via `GalleryStore` (`refresh`, `syncAll`, 15-minute timer while unlocked). No sync when locked or quit. Register frames in Settings (`POST /api/devices`).

Fast local check: one-shot advance, then sync in the app:

```bash
source server/.env.local
curl -s -H "Authorization: Bearer $CRON_SECRET" http://127.0.0.1:3000/api/cron/advance-current
```

Manual `cd server && npm run dev` does **not** start the advance cron; use `start-server.sh` or run `local-advance-cron.sh` separately.

## Full local stack

First-time or “run everything”:

```bash
./scripts/dev.sh
```

Starts the server (`start-server.sh`), packages the app, writes `repo-root.txt`, and opens `dist/Gattey Photos.app`.

## When both `macos/` and `server/` change

1. Restart server first (`stop-server.sh` then `start-server.sh`)
2. Relaunch app (`launch.sh macos` or `package-macos.sh`)

## Before `git push`

Run the full gate (same as GitHub Actions `verify` workflow):

```bash
./scripts/verify.sh
```

One-time hook install (blocks push when checks fail):

```bash
./scripts/install-git-hooks.sh
```

`verify.sh` runs: `swift test` (macos), `npm run typecheck`, `npm run test`, `npm run build` (server).

## Agent checklist

| Touched | Before task end (this turn) |
|---------|-----------------------------|
| `macos/` only | `./scripts/launch.sh macos` from repo root — required even if build succeeded |
| `server/` only (runtime) | `stop-server.sh` + `start-server.sh`, then `cd server && npm run typecheck` |
| Both | Server restart, then `./scripts/launch.sh macos` |
| Before push | `./scripts/verify.sh` — required; do not claim deploy-safe without a green build |

Never batch several macOS UI tweaks without a relaunch between them when the user is actively iterating.
