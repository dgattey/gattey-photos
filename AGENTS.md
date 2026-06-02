# Agent guide

Use these skills when editing this repo (copy into `.cursor/skills/` or reference by path):

- `skills/SKILL.md` — whole project
- `skills/dev-loop/SKILL.md` — after each `macos/` edit: agents run `./scripts/launch.sh macos` before ending the turn (required; no batching UI tweaks without relaunch); never end a macOS UI task without relaunching; never tell the user to relaunch manually as the main verification step; server restart + typecheck when runtime `server/` changes
- `skills/server/SKILL.md` — Next.js API only
- `skills/macos/SKILL.md` — Swift app and daemon
- `skills/ios/SKILL.md` — iOS/iPad app (`GatteyPhotosIOS` + shared `GatteyPhotosUI`); `./scripts/launch.sh (macos | ios | ipad)`

Architecture: `docs/ARCHITECTURE.md`.

**macOS UI (agents):** Run `./scripts/launch.sh macos` from repo root after every turn that changes `macos/`; do not finish without relaunching; do not ask the user to relaunch instead.

Before `git push`, run `./scripts/verify.sh` (Swift tests, server typecheck, unit tests, production build). Install the hook once: `./scripts/install-git-hooks.sh`.
