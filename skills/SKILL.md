---
name: gattey-photos-project
description: Work on the Gattey Photos monorepo — macOS SwiftUI app, sync server on Vercel, Bloomin8 device uploads, and gallery timestamp sync. Use when changing gallery sync, server API routes, or macOS UI.
---

# Gattey Photos

## Repo map

| Path | Owns |
|------|------|
| `server/lib/types.ts` | `GalleryState`, `PhotoEntry` canonical JSON shape |
| `server/lib/gallery.ts` | Manifest mutations (order, soft delete, current) |
| `server/lib/gallery-mutation.ts` | `applyGalleryMutation`, `respondGalleryMutation`, `baseUpdatedAt` |
| `server/lib/storage/` | `GATTEY_LOCAL_STORAGE=1` → `.data/`; else Vercel Blob |
| `Sources/GatteyPhotosUI/GalleryStore.swift` | Gallery UI, pull/mutations, 409 retry, backoff |
| `Sources/GatteyPhotosApp/` | `@main` app for macOS and iOS (macOS `AppDelegate`, menus) |
| `DylApp.toml` | Bundle, signing, release and download-site settings read by DylKit |

## Invariants

1. **Auth:** Gallery/device API calls use `Authorization: Bearer` with `syncSessionToken` only. The family password is sent once to `POST /api/auth/session` to mint the token; `SYNC_PASSWORD` stays on the server.
2. **Sync:** Every mutation sends `baseUpdatedAt`; server returns 409 when manifest is newer. `GalleryStore` applies 409 body and retries. Pull replaces local state; failed periodic pulls back off in-store.
3. **Device:** Server pushes current JPEG via einkshot on manual set-current and cron advance (after `applyGalleryMutation`).
4. **Cache:** JPEG bytes live in `~/Library/Application Support/GatteyPhotos/cache/{id}.jpg`.

## Local verify

See **`skills/dev-loop/SKILL.md`** for rebuild, server restart, and `pnpm typecheck`. Full stack: `./scripts/dev.sh`.

## Common tasks

- **New API field:** Update `server/lib/types.ts`, `Sources/GatteyPhotosCore/Models.swift`, and `buildGalleryResponse` if exposed to clients.
- **UI toolbar:** `GalleryGridView.swift` — `GalleryMainToolbar` on the gallery window.
- **Deploy:** Vercel project rooted at `server/`; remove `GATTEY_LOCAL_STORAGE`.

Read `docs/ARCHITECTURE.md` before structural changes.

## Working agreements

Hard-won from past sessions; they bind future agents in this repo.

- **Match means copy the baseline, not re-derive it.** When asked to make one surface match another, the baseline is the spec. Grep it for the exact mechanism (e.g. a SwiftUI modifier) and render both to compare, rather than guessing by eye. A "make X match Y" subtask counts even when it is buried inside a larger feature.
- **Do not override an explicit instruction with your own taste.** Proceed-without-asking autonomy covers decisions the user left open, not re-deciding something they specified (layout, alignment, copy). Verify against the instruction.
- **Delegate intent, not finished code.** A subagent prompt carries the goal, constraints, and success criteria. Pasting the solution turns the subagent into a transcriber, so a wrong interpretation ships unreviewed.
- **The smallest change must also be reversible.** Prefer the small diff, but binaries, generated artifacts, and secrets committed to git are append-only debt, removable only by a history rewrite. When the small option compounds, the larger-now option is the lazy one.
- **Security pass before shipping a delivery surface.** Code that signs, authenticates, or auto-updates the app reaches every user's machine. Threat-model it and settle key custody before shipping, do not wait to be asked.
- **Ship the web pages with the design.** A change to the app UI, brand colors, or `AppIcon.icon` also updates photos.gattey.com (`[site]` in `DylApp.toml`) and asks the `dg` project to update dylangattey.com (Contentful). Steps are under **Design sync** in `AGENTS.md`.
- **Never commit release artifacts or version numbers.** A PR only picks the bump under `# Release info` (`Major` / `Minor` / `Patch`). On merge, `dylkit.yml` runs DylKit's `release-kit`, which computes the version and build number and uploads the zip, appcast and site icons to the Blob store (see DylKit's `apple-release`).
