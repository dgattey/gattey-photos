#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib/signing.sh
source "$ROOT/scripts/lib/signing.sh"
MACOS="$ROOT/macos"
PUBLIC_DIR="$ROOT/server/public"

VERSION="${1:-$("$ROOT/scripts/next-release-version.sh")}"

if [[ ! -f "$MACOS/sparkle-public-key.txt" ]]; then
  echo "package-release: macos/sparkle-public-key.txt missing — run scripts/generate-sparkle-key.sh first." >&2
  exit 1
fi

if [[ -n "${GATTEY_SIGN_IDENTITY:-}" && "${GATTEY_SIGN_IDENTITY}" != "-" ]]; then
  SIGN_ID="$GATTEY_SIGN_IDENTITY"
else
  SIGN_ID="$(resolve_sign_identity)"
fi
if [[ "$SIGN_ID" == "-" ]]; then
  echo "package-release: no self-signed identity — run scripts/setup-self-signed-cert.sh first." >&2
  exit 1
fi

WORK="$ROOT/dist/release"
STAGE="$WORK/stage"
rm -rf "$WORK"
mkdir -p "$STAGE" "$PUBLIC_DIR"

BUILD_NUMBER="${GATTEY_BUILD_NUMBER:-$(git -C "$ROOT" rev-list --count HEAD)}"
if [[ -z "${GATTEY_BUILD_NUMBER:-}" && -f "$PUBLIC_DIR/appcast.xml" ]]; then
  last_build="$(sed -n 's/.*<sparkle:version>\([^<]*\)<\/sparkle:version>.*/\1/p' "$PUBLIC_DIR/appcast.xml" | head -1)"
  if [[ -n "$last_build" && "$BUILD_NUMBER" -le "$last_build" ]]; then
    BUILD_NUMBER=$((last_build + 1))
  fi
fi

GATTEY_DIST_DIR="$STAGE" \
GATTEY_BUILD_CONFIG=release \
GATTEY_FORCE_RESIGN=1 \
GATTEY_APP_SHORT_VERSION="$VERSION" \
GATTEY_BUILD_NUMBER="$BUILD_NUMBER" \
GATTEY_SIGN_IDENTITY="$SIGN_ID" \
GATTEY_SIGN_ENTITLEMENTS="$ROOT/macos/GatteyPhotos.local.entitlements" \
GATTEY_OPEN_AFTER=0 \
  "$ROOT/scripts/package-macos.sh"

APP="$STAGE/Gattey Photos.app"
[[ -d "$APP" ]] || { echo "package-release: missing $APP" >&2; exit 1; }
codesign --verify --deep --strict "$APP"

ZIP="$WORK/Gattey-Photos-${VERSION}.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
rm -rf "$STAGE"

GA="$MACOS/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
[[ -x "$GA" ]] || { echo "package-release: generate_appcast not found — run 'cd macos && swift build'." >&2; exit 1; }
GA_ARGS=(--download-url-prefix "https://photos.gattey.com/" --link "https://photos.gattey.com")
[[ -n "${SPARKLE_ED_KEY_FILE:-}" ]] && GA_ARGS+=(--ed-key-file "$SPARKLE_ED_KEY_FILE")
"$GA" "${GA_ARGS[@]}" "$WORK"

rm -f "$PUBLIC_DIR"/Gattey-Photos-*.zip
cp "$ZIP" "$PUBLIC_DIR/"
cp "$WORK/appcast.xml" "$PUBLIC_DIR/appcast.xml"

echo "package-release: v${VERSION} (build ${BUILD_NUMBER}), identity=${SIGN_ID}"
echo "  server/public/$(basename "$ZIP")"
echo "  server/public/appcast.xml"
