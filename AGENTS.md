# Agent guide

Use these skills when editing this repo (copy into `.cursor/skills/` or reference by path):

- `skills/SKILL.md` — whole project
- `skills/dev-loop/SKILL.md` — after each Swift edit: rebuild and verify per DylKit's `apple-dev-loop`; server restart + typecheck when runtime `server/` changes
- `skills/server/SKILL.md` — Next.js API and download site
- `skills/macos/SKILL.md` — Swift app
- `skills/ios/SKILL.md` — iOS/iPad build of the same app target; `./run dev ios --run --capture`

DylKit ([`dgattey/dyl-kit`](https://github.com/dgattey/dyl-kit)) owns building, launching, testing and releasing: its `apple-dev-loop` and `apple-release` skills are the reference, and `DylApp.toml` holds the bundle, signing, release and site settings. The skills ship in the DylKit Cursor plugin; if they aren't loaded, see that repo's README. Architecture: `docs/ARCHITECTURE.md`.

**Design sync (agents):** The app and its two web pages move together. When a change touches the app UI design, brand colors (`AppBrandColor.swift`), or app icon (`AppIcon.icon`), the same PR must:

1. Refresh the web icons after an icon change. Until DylKit v0.2.1's `site-icons` generates them, export them from Icon Composer by hand. dyl-kit and dylangattey.com read a fixed URL contract from every `<app>.gattey.com`: `/icon.png` at 1024×1024 (`server/public/icon.png`), `/apple-touch-icon.png` at 180×180 (`server/public/apple-touch-icon.png`, same bytes as `server/public/apple-icon.png`), and `/favicon.ico` with 16 and 32 px frames (`server/app/favicon.ico`). `server/next.config.ts` serves the first two cross-origin with an hour of caching.
2. Update photos.gattey.com. `@dylkit/web` renders it from `[site]` in `DylApp.toml` (tagline, accent colors, screenshots) and `server/public/app-icon.png`.
3. Ask the `dg` project (`dgattey/dg`, Contentful) to update the Gattey Photos entry on dylangattey.com, and tick both boxes under **Design sync** in the PR template.

`server/lib/site-assets.test.ts` (run by `npm test` and the `site` CI job) fails when the shared icons or their headers break that contract.

**Swift UI changes (agents):** Run `./run dev relaunch`, which opens `build/Gattey Photos Dev.app` (`com.gattey.photos.dev`) in the background, and check shared UI on the iOS Simulator (`./run dev ios --run --capture`). Never launch the staged release, which carries `com.gattey.photos`.

Before `git push`, run `./run dev verify` (checks, build, Swift tests) and `npm run typecheck && npm run test && npm run build` in `server/`.
