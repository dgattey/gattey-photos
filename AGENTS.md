# Agent guide

Use these skills when editing this repo (copy into `.cursor/skills/` or reference by path):

- `skills/SKILL.md` — whole project
- `skills/dev-loop/SKILL.md` — after each `macos/` edit: agents run `./scripts/launch.sh macos` before ending the turn (required; no batching UI tweaks without relaunch); never end a macOS UI task without relaunching; never tell the user to relaunch manually as the main verification step; server restart + typecheck when runtime `server/` changes
- `skills/server/SKILL.md` — Next.js API only
- `skills/macos/SKILL.md` — Swift app and daemon
- `skills/ios/SKILL.md` — iOS/iPad app (`GatteyPhotosIOS` + shared `GatteyPhotosUI`); `./scripts/launch.sh (macos | ios | ipad)`

Architecture: `docs/ARCHITECTURE.md`.

**Design sync (agents):** The app and its two web pages move together. When a change touches the app UI design, brand colors (`AppBrandColor.swift`), or app icon (`macos/AppIcon.icon`), the same PR must:

1. Run `./scripts/generate-app-icon.sh` on a Mac after an icon change, or commit the `web-icons` artifact from the `verify-web-icons` CI job. It rewrites the web icons and `server/lib/app-icon-source.sha256`. dyl-kit and dylangattey.com read a fixed URL contract from every `<app>.gattey.com`: `/icon.png` at 1024×1024 (`server/public/icon.png`), `/apple-touch-icon.png` at 180×180 (`server/public/apple-touch-icon.png`, same bytes as `server/app/apple-icon.png`), and `/favicon.ico` with 16 and 32 px frames (`server/app/favicon.ico`).
2. Update the photos.gattey.com landing page (`server/app/page.tsx`, `server/app/page.module.css`, `server/lib/brand.ts`, `server/lib/site-media.ts`) and refresh its showcase screenshots.
3. Ask the `dg` project (`dgattey/dg`, Contentful) to update the Gattey Photos entry on dylangattey.com, and tick both boxes under **Design sync** in the PR template.

`server/lib/site-assets.test.ts` (run by `npm test`, `./scripts/verify.sh`, and CI) fails when the web icons, brand colors, or landing images drift from the app. Example failure it catches: a PR recolors `AppBrandColor.accentGreen` and ships while the site keeps the old green. Do not silence the test by editing the hash or colors alone; update the page.

**macOS UI (agents):** Run `./scripts/launch.sh macos` from repo root after every turn that changes `macos/`; do not finish without relaunching; do not ask the user to relaunch instead.

Before `git push`, run `./scripts/verify.sh` (Swift tests, server typecheck, unit tests, production build). Install the hook once: `./scripts/install-git-hooks.sh`.
