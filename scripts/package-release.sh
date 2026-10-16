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

cleanup_files=()
cleanup() {
  for f in "${cleanup_files[@]:-}"; do
    [[ -n "$f" && -f "$f" ]] && rm -f "$f"
  done
}
trap cleanup EXIT

decode_secret_b64() {
  printf '%s' "$1" | tr -d '[:space:]' | base64 -D 2>/dev/null || printf '%s' "$1" | tr -d '[:space:]' | base64 -d
}

# Resolve Sparkle EdDSA private key (CI secret -> explicit file -> repo-local .cert/sparkle_ed.key)
if [[ -z "${SPARKLE_ED_KEY_FILE:-}" && -n "${SPARKLE_ED_PRIVATE_KEY_BASE64:-}" ]]; then
  KEY_FILE="$(mktemp /tmp/gattey-photos-sparkle-ed.XXXXXX.key)"
  cleanup_files+=("$KEY_FILE")
  decode_secret_b64 "$SPARKLE_ED_PRIVATE_KEY_BASE64" >"$KEY_FILE"
  export SPARKLE_ED_KEY_FILE="$KEY_FILE"
elif [[ -z "${SPARKLE_ED_KEY_FILE:-}" && -f "$ROOT/.cert/sparkle_ed.key" ]]; then
  export SPARKLE_ED_KEY_FILE="$ROOT/.cert/sparkle_ed.key"
fi

SIGN_ID="${GATTEY_SIGN_IDENTITY:-$(resolve_sign_identity)}"

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

INFO_PLIST="$APP/Contents/Info.plist"
PUB_KEY=""
if [[ -f "$INFO_PLIST" && -x /usr/libexec/PlistBuddy ]]; then
  PUB_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$INFO_PLIST" 2>/dev/null | tr -d '[:space:]' || true)"
fi
if [[ -z "$PUB_KEY" && -f "$MACOS/sparkle-public-key.txt" ]]; then
  PUB_KEY="$(tr -d '[:space:]' <"$MACOS/sparkle-public-key.txt")"
fi

ZIP="$WORK/Gattey-Photos-${VERSION}.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
rm -rf "$STAGE"

"$ROOT/scripts/release-notes.sh" --version "$VERSION" >"$WORK/Gattey-Photos-${VERSION}.html"

GA="$MACOS/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
[[ -x "$GA" ]] || { echo "package-release: generate_appcast not found — run 'cd macos && swift build'." >&2; exit 1; }
GA_ARGS=(--download-url-prefix "https://photos.gattey.com/" --link "https://photos.gattey.com" --embed-release-notes)
if [[ -n "${SPARKLE_ED_KEY_FILE:-}" && -f "${SPARKLE_ED_KEY_FILE}" ]]; then
  GA_ARGS+=(--ed-key-file "$SPARKLE_ED_KEY_FILE")
fi
"$GA" "${GA_ARGS[@]}" "$WORK"

ED_SIG="$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' "$WORK/appcast.xml" | head -1)"
if [[ "${REQUIRE_SPARKLE_SIGNATURE:-1}" == "1" && -z "$ED_SIG" ]]; then
  echo "package-release: failed to generate sparkle:edSignature for $ZIP (ensure SPARKLE_ED_PRIVATE_KEY_BASE64, SPARKLE_ED_KEY_FILE, or Keychain key is configured)" >&2
  exit 1
fi

# Verify the generated Ed25519 signature against SUPublicEDKey in Info.plist when OpenSSL 3+ is available
if [[ -n "$ED_SIG" && -n "$PUB_KEY" ]] && openssl version 2>/dev/null | grep -q '^OpenSSL'; then
  TMP_PUB="$(mktemp /tmp/gattey-photos-sparkle-pub.XXXXXX.pem)"
  TMP_SIG="$(mktemp /tmp/gattey-photos-sparkle-sig.XXXXXX.bin)"
  cleanup_files+=("$TMP_PUB" "$TMP_SIG")
  {
    echo "-----BEGIN PUBLIC KEY-----"
    printf '302a300506032b6570032100%s' "$(decode_secret_b64 "$PUB_KEY" | xxd -p -c 64)" | xxd -r -p | base64
    echo "-----END PUBLIC KEY-----"
  } >"$TMP_PUB"
  decode_secret_b64 "$ED_SIG" >"$TMP_SIG"
  if ! openssl pkeyutl -verify -pubin -inkey "$TMP_PUB" -rawin -in "$ZIP" -sigfile "$TMP_SIG" >/dev/null 2>&1; then
    echo "package-release: Ed25519 signature does not verify against SUPublicEDKey ($PUB_KEY) — private/public key mismatch" >&2
    exit 1
  fi
fi

rm -f "$PUBLIC_DIR"/Gattey-Photos-*.zip
cp "$ZIP" "$PUBLIC_DIR/"
cp "$WORK/appcast.xml" "$PUBLIC_DIR/appcast.xml"

echo "package-release: v${VERSION} (build ${BUILD_NUMBER}), identity=${SIGN_ID}"
echo "  server/public/$(basename "$ZIP")"
echo "  server/public/appcast.xml"
