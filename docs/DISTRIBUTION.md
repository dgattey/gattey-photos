# Distributing Gattey Photos (macOS auto-update)

Small family install: **self-signed** code signing + Sparkle EdDSA. No Apple Developer Program.

- Stable self-signed cert in the keychain lets Sparkle replace the app in place. Ad-hoc (`-`) can show updates but **cannot install** them.
- EdDSA signs the zip in `appcast.xml` (`scripts/generate-sparkle-key.sh`).
- One-time per Mac: install **Gattey Photos — macOS trust** from [photos.gattey.com](https://photos.gattey.com) (configuration profile), or **Privacy & Security → Open Anyway** after a blocked launch; Sparkle updates after that.
- Feed + zip live in `server/public/` and deploy with the Next.js app on Vercel (normal Git integration).

## How it works

- App checks `https://photos.gattey.com/appcast.xml` (Sparkle 2, HTTPS only).
- `AppUpdaterModel` runs only when `SUFeedURL` and `SUPublicEDKey` are in the built app.
- Push to **`main`** with `macos/` (or packaging script) changes → `.github/workflows/release-macos.yml` builds, commits `server/public/`, pushes once.
- That release commit only touches `server/public/**`, so the workflow does **not** run again (no loop). Vercel’s usual Git deploy picks up the new zip (often a second Production deploy after your code push — that is fine).

PRs into `main` work the same way: merge → one code push (maybe + one `Release v…` commit). No release branch and no manual steps.

## One-time setup

### EdDSA key

```bash
cd macos && swift build
./scripts/generate-sparkle-key.sh
```

Commit `macos/sparkle-public-key.txt`. Back up the private key (1Password, etc.):

```bash
macos/.build/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle_private.key
```

### Self-signed certificate (local builds + CI export)

```bash
./scripts/setup-self-signed-cert.sh
```

Trust on Macs that build releases (once, admin):

```bash
sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain .cert/gattey-photos.crt
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k ~/Library/Keychains/login.keychain-db
```

### GitHub secrets

From the repo root (after `./scripts/setup-self-signed-cert.sh`):

```bash
gh auth login   # once
./scripts/export-ci-secrets.sh
```

That openssl-checks the P12 and pushes secrets with `gh secret set` on **this** repository. The script does not create temporary keychains (that caused "Keychain Not Found" dialogs). Do not paste base64 into the GitHub UI by hand.

| Secret | Purpose |
|--------|---------|
| `GATTEY_CODESIGN_P12_BASE64` | Self-signed `.p12` from `.cert/` (openssl-built, not `security export`) |
| `GATTEY_CODESIGN_P12_PASSWORD` | P12 password (default `gattey-photos`) |
| `SPARKLE_ED_PRIVATE_KEY_BASE64` | EdDSA private key |

Options: `--print-only`, `--dry-run`, `--skip-sparkle`, `--sparkle-key-file path`, `--repo owner/name`.

Leave Vercel **Production** Git deploys enabled (default). You do not need to change anything in the Vercel dashboard for this setup.

## First install (each family Mac, once)

1. On [photos.gattey.com](https://photos.gattey.com), click **Install macOS trust** and install the downloaded profile in System Settings (Mac login password once).
2. Click **Download for macOS**, unzip, drag **Gattey Photos** to Applications, and open it.

If Gatekeeper still blocks after the profile: open the app once, then **System Settings → Privacy & Security → Open Anyway**.

The release zip is correctly self-signed; macOS blocks unknown developers until you install trust or approve the app. That is not a broken build.

Maintainers regenerate the profile when the signing cert changes: `./scripts/generate-trust-profile.sh` (also runs from `package-release.sh`).

Anyone on an old **ad-hoc** build needs one install of the current self-signed zip; then Sparkle works.

## Notes

- Releases use `GatteyPhotos.local.entitlements` only (no `associated-domains`).
- `CFBundleVersion` is monotonic (`git rev-list --count` or last `appcast.xml` + 1).
- Only the latest zip is kept in `server/public/`.
