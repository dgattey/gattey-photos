---
name: dev-loop
description: Rebuild, restart, and verify the Gattey Photos local stack after edits. Use when changing Sources/, server/, or before ending an agent task that touched either; covers ./run dev, the server supervisor, typecheck, and dev.sh.
---

# Gattey Photos dev loop

Canonical rebuild/restart steps for agents. Domain skills (`macos`, `server`) describe code layout; this skill owns **how to refresh running processes**.

Tools: **mise** (`mise.toml`) pins Node and SwiftLint. Run `mise install` once. If `npm` is missing, prepend shims:

```bash
export PATH="$HOME/.local/share/mise/shims:$PATH"
```

## Swift app

Building, launching, capturing and testing follow DylKit's **`apple-dev-loop`** skill. Everything runs from the repo root through `./run dev …`:

| Task | Command |
|------|---------|
| Build `build/Gattey Photos.app` | `./run dev build` |
| Rebuild and reopen in the background | `./run dev relaunch` |
| iPhone Simulator, headless, with a screenshot | `./run dev ios --run --capture` |
| iPad Simulator | `./run dev ios --run --capture --simulator "iPad Pro 13-inch (M5)"` |
| Lint tiers 1–3 | `./run dev checks` |
| What macOS CI runs | `./run dev verify` |

After each Swift edit session, rebuild and verify in the same turn; a successful `swift build` alone doesn't refresh `build/Gattey Photos.app`. Never ask the user to relaunch as the main verification step.

`build/Gattey Photos.app` is signed with the release bundle ID `com.gattey.photos`, so it shares the installed app's preferences, Sparkle state and activity log. On a Mac where Gattey Photos is installed (`mdfind "kMDItemCFBundleIdentifier == 'com.gattey.photos'"`), don't `relaunch` or `capture`: verify shared `GatteyPhotosUI` changes on the iOS Simulator and say which macOS-only behavior is unverified.

The icon comes from `AppIcon.icon/` through `scripts/link-app-icon.swift`; editing it only needs a rebuild.

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

Starts the server (`start-server.sh`), then `./run dev relaunch`. Not for a Mac with Gattey Photos installed.

## When both Swift and `server/` change

1. Restart server first (`stop-server.sh` then `start-server.sh`)
2. Rebuild and verify the app as above

## Before `git push`

Run the same gates as CI (`verify.yml` on macOS, `site.yml` on ubuntu):

```bash
./run dev verify
cd server && npm run typecheck && npm run test && npm run build
```

## Agent checklist

| Touched | Before task end (this turn) |
|---------|-----------------------------|
| Swift only | `./run dev build`, then the iOS Simulator or `./run dev relaunch` per the bundle ID rule above |
| `server/` only (runtime) | `stop-server.sh` + `start-server.sh`, then `cd server && npm run typecheck` |
| Both | Server restart, then rebuild and verify the app |
| Before push | `./run dev verify` and the server checks — required; do not claim deploy-safe without a green build |
