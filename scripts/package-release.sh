#!/usr/bin/env bash
# Build a self-distributable macOS release and update the Sparkle feed on photos.gattey.com.
#
# No Apple Developer account needed. The app is ad-hoc code-signed and updates are EdDSA-signed,
# which is all Sparkle requires to verify and install an update (it accepts an update when EITHER
# the EdDSA signature or the code signature matches; the EdDSA one always does here). On first
# install each person does a one-time macOS "Open Anyway" (Gatekeeper blocks any non-notarized
# app); Sparkle updates after that install in place without prompting.
#
# Output is written into server/public/ so the Vercel server hosts both the feed and the app:
#   https://photos.gattey.com/appcast.xml            (SUFeedURL)
#   https://photos.gattey.com/Gattey-Photos-<v>.zip  (the download)
# After running, commit server/public/ and push. Vercel deploys the new release.
#
# Usage: scripts/package-release.sh <version>      e.g. 1.0.1
#
# Optional (only if you later get a Developer ID and want to drop the "Open Anyway" step):
#   GATTEY_SIGN_IDENTITY   "Developer ID Application: Your Name (TEAMID)"
#   GATTEY_NOTARY_PROFILE  notarytool keychain profile (xcrun notarytool store-credentials)
#   SPARKLE_ED_KEY_FILE    private EdDSA key file for generate_appcast (default: login keychain)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MACOS="$ROOT/macos"
PUBLIC_DIR="$ROOT/server/public"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $(basename "$0") <version>   e.g. 1.0.1" >&2
  exit 1
fi

if [[ ! -f "$MACOS/sparkle-public-key.txt" ]]; then
  echo "package-release: macos/sparkle-public-key.txt missing — run scripts/generate-sparkle-key.sh first." >&2
  exit 1
fi

WORK="$ROOT/dist/release"
STAGE="$WORK/stage"
rm -rf "$WORK"
mkdir -p "$STAGE" "$PUBLIC_DIR"

# Monotonic build number (Sparkle compares CFBundleVersion across releases).
BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD)"

# Default: ad-hoc signing (no Apple account). A real Developer ID enables hardened runtime + notarization.
SIGN_ID="${GATTEY_SIGN_IDENTITY:--}"
EXTRA_OPTS=""
ENTITLEMENTS="$ROOT/macos/GatteyPhotos.local.entitlements"
if [[ "$SIGN_ID" != "-" ]]; then
  EXTRA_OPTS="--options runtime --timestamp"
  ENTITLEMENTS="${GATTEY_SIGN_ENTITLEMENTS:-$ROOT/macos/GatteyPhotos.entitlements}"
fi

GATTEY_DIST_DIR="$STAGE" \
GATTEY_APP_SHORT_VERSION="$VERSION" \
GATTEY_BUILD_NUMBER="$BUILD_NUMBER" \
GATTEY_SIGN_IDENTITY="$SIGN_ID" \
GATTEY_SIGN_ENTITLEMENTS="$ENTITLEMENTS" \
GATTEY_CODESIGN_EXTRA_OPTS="$EXTRA_OPTS" \
GATTEY_OPEN_AFTER=0 \
  "$ROOT/scripts/package-macos.sh"

APP="$STAGE/Gattey Photos.app"
[[ -d "$APP" ]] || { echo "package-release: missing $APP" >&2; exit 1; }

# Optional notarization, only when a real Developer ID + notary profile are configured.
if [[ -n "${GATTEY_NOTARY_PROFILE:-}" && "$SIGN_ID" != "-" ]]; then
  NZ="$STAGE/notarize.zip"
  ditto -c -k --keepParent "$APP" "$NZ"
  echo "package-release: notarizing (a few minutes)..."
  xcrun notarytool submit "$NZ" --keychain-profile "$GATTEY_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$NZ"
fi

ZIP="$WORK/Gattey-Photos-${VERSION}.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
rm -rf "$STAGE"

# EdDSA-sign + build the appcast. Enclosure URLs resolve to the server's static files.
GA="$MACOS/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
[[ -x "$GA" ]] || { echo "package-release: generate_appcast not found — run 'cd macos && swift build'." >&2; exit 1; }
GA_ARGS=(--download-url-prefix "https://photos.gattey.com/" --link "https://photos.gattey.com")
[[ -n "${SPARKLE_ED_KEY_FILE:-}" ]] && GA_ARGS+=(--ed-key-file "$SPARKLE_ED_KEY_FILE")
"$GA" "${GA_ARGS[@]}" "$WORK"

# Publish into the server's static dir. Keep only the latest zip so old binaries do not pile up.
rm -f "$PUBLIC_DIR"/Gattey-Photos-*.zip
cp "$ZIP" "$PUBLIC_DIR/"
cp "$WORK/appcast.xml" "$PUBLIC_DIR/appcast.xml"

echo
echo "package-release: built v${VERSION} (build ${BUILD_NUMBER}), identity=${SIGN_ID}"
echo "  -> server/public/$(basename "$ZIP")"
echo "  -> server/public/appcast.xml"
echo "Next: git add server/public && git commit -m \"Release v${VERSION}\" && git push   (Vercel serves the feed)"
