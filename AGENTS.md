# Agent guide

Use these skills when editing this repo (copy into `.cursor/skills/` or reference by path):

- `skills/SKILL.md` — whole project
- `skills/dev-loop/SKILL.md` — after each `macos/` edit: `./scripts/launch.sh macos` (required; no batching UI tweaks without relaunch); server restart + typecheck when runtime `server/` changes
- `skills/server/SKILL.md` — Next.js API only
- `skills/macos/SKILL.md` — Swift app and daemon
- `skills/ios/SKILL.md` — iOS/iPad app (`GatteyPhotosIOS` + shared `GatteyPhotosUI`); `./scripts/launch.sh (macos | ios | ipad)`

Architecture: `docs/ARCHITECTURE.md`.

Before `git push`, run `./scripts/verify.sh` (Swift tests, server typecheck, unit tests, production build). Install the hook once: `./scripts/install-git-hooks.sh`.
