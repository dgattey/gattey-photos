#!/usr/bin/env bash
# CI-only: import signing cert, build, and package a macOS release in one shell (keychain state persists).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib/signing.sh
source "$ROOT/scripts/lib/signing.sh"

if [[ -z "${GATTEY_CODESIGN_P12_BASE64:-}" || -z "${GATTEY_CODESIGN_P12_PASSWORD:-}" ]]; then
  echo "ci-build-macos-release: GATTEY_CODESIGN_P12_BASE64 and GATTEY_CODESIGN_P12_PASSWORD are required." >&2
  exit 1
fi
if [[ -z "${SPARKLE_ED_PRIVATE_KEY_BASE64:-}" ]]; then
  echo "ci-build-macos-release: SPARKLE_ED_PRIVATE_KEY_BASE64 is required." >&2
  exit 1
fi

echo "$GATTEY_CODESIGN_P12_BASE64" | base64 -d > /tmp/codesign.p12
echo "$SPARKLE_ED_PRIVATE_KEY_BASE64" | base64 -d > /tmp/sparkle_ed.key
export SPARKLE_ED_KEY_FILE=/tmp/sparkle_ed.key

security delete-keychain build.keychain 2>/dev/null || true
security create-keychain -p "$GATTEY_CODESIGN_P12_PASSWORD" build.keychain
security set-keychain-settings -lut 21600 build.keychain
security default-keychain -s build.keychain
security unlock-keychain -p "$GATTEY_CODESIGN_P12_PASSWORD" build.keychain
security import /tmp/codesign.p12 -k build.keychain -P "$GATTEY_CODESIGN_P12_PASSWORD" -A \
  -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$GATTEY_CODESIGN_P12_PASSWORD" build.keychain
security list-keychains -d user -s build.keychain
rm -f /tmp/codesign.p12

echo "ci-build-macos-release: codesigning identities:"
security find-identity -v -p codesigning 2>&1 || true

SIGN_ID="$(resolve_sign_identity)"
if [[ "$SIGN_ID" == "-" ]]; then
  echo "ci-build-macos-release: no self-signed identity in build.keychain after import." >&2
  exit 1
fi
echo "ci-build-macos-release: signing identity=${SIGN_ID}"

cd "$ROOT/macos"
swift build -c release --product GatteyPhotos

VERSION="$("$ROOT/scripts/next-release-version.sh")"
echo "ci-build-macos-release: packaging v${VERSION}"
"$ROOT/scripts/package-release.sh" "$VERSION"

echo "version=${VERSION}"
