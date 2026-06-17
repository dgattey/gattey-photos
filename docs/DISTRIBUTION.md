# Distributing Gattey Photos (macOS auto-update)

The macOS app self-updates with [Sparkle 2](https://sparkle-project.org). This is set up for a small
family install (a handful of people), so it deliberately skips the Apple Developer Program.

- **No Apple Developer ID, no notarization.** The app is ad-hoc code-signed; updates are
  EdDSA-signed. Sparkle installs an update when *either* the EdDSA signature *or* the code signature
  matches, and the EdDSA one always does, so updates verify and install fine without an Apple account.
- **One-time cost:** the first time each person opens the downloaded app, macOS Gatekeeper blocks it
  (true for any non-notarized app). They approve it once (below). Sparkle updates after that install
  in place without prompting.
- **Feed + app are hosted on `photos.gattey.com`** (the Vercel server), as static files under
  `server/public/`. No GitHub Releases, no Blob tokens.

## How it works

- The app embeds `Sparkle.framework` and checks `https://photos.gattey.com/appcast.xml` daily.
- `Info.plist` (written by `scripts/package-macos.sh`) carries `SUFeedURL`, `SUPublicEDKey` (from
  `macos/sparkle-public-key.txt`, when present), `SUEnableAutomaticChecks`, and a daily interval.
- `AppUpdaterModel` starts the updater only when both `SUFeedURL` and `SUPublicEDKey` are present, so
  unkeyed dev builds run cleanly with **Check for Updates…** (under the app menu) just disabled.

## One-time setup

Create the EdDSA key that signs every update:

```bash
cd macos && swift build          # makes the Sparkle CLI tools available
./scripts/generate-sparkle-key.sh
```

The **private** key stays in your login keychain (never committed); the **public** key is written to
`macos/sparkle-public-key.txt`, which you commit. Back it up:
`macos/.build/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle_private.key`.

## Cutting a release

```bash
./scripts/package-release.sh 1.0.1
git add server/public && git commit -m "Release v1.0.1" && git push
```

That builds the app (ad-hoc signed), EdDSA-signs it, writes `server/public/Gattey-Photos-1.0.1.zip`
and `server/public/appcast.xml`, and keeps only the latest zip. Pushing triggers a Vercel deploy, so
`photos.gattey.com/appcast.xml` updates and everyone's app picks it up on the next check (or via
**Check for Updates…**).

## First install (each family member, once)

1. Download `https://photos.gattey.com/Gattey-Photos-<version>.zip`, unzip, drag to Applications.
2. First open is blocked by Gatekeeper. Either right-click the app and choose **Open**, or go to
   **System Settings → Privacy & Security** and click **Open Anyway**. This is needed once per person.

After that, updates are automatic.

## Notes

- Build numbers use the git commit count (monotonic across releases). Dev builds use a timestamp and
  are never distributed, so the two never collide for family members.
- Only the latest zip is kept in `server/public/`; the appcast describes that version, and Sparkle
  jumps any older install straight to it.
- **Optional upgrade path:** if you ever get an Apple Developer ID, set `GATTEY_SIGN_IDENTITY` (and
  `GATTEY_NOTARY_PROFILE` for notarization) before `package-release.sh`. That removes the one-time
  "Open Anyway" step. Nothing else changes; keep the same EdDSA key.
