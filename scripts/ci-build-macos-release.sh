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
if ! openssl pkcs12 -in /tmp/codesign.p12 -noout -passin "pass:${GATTEY_CODESIGN_P12_PASSWORD}" 2>/dev/null; then
  echo "ci-build-macos-release: P12 failed openssl check — GATTEY_CODESIGN_P12_PASSWORD may not match the file." >&2
  exit 1
fi
echo "ci-build-macos-release: P12 size=$(wc -c </tmp/codesign.p12 | tr -d ' ') bytes" >&2
echo "$SPARKLE_ED_PRIVATE_KEY_BASE64" | base64 -d > /tmp/sparkle_ed.key
export SPARKLE_ED_KEY_FILE=/tmp/sparkle_ed.key

security delete-keychain build.keychain 2>/dev/null || true
security create-keychain -p "$GATTEY_CODESIGN_P12_PASSWORD" build.keychain
security set-keychain-settings -lut 21600 build.keychain
security default-keychain -s build.keychain
security unlock-keychain -p "$GATTEY_CODESIGN_P12_PASSWORD" build.keychain
security import /tmp/codesign.p12 -k build.keychain -f pkcs12 -P "$GATTEY_CODESIGN_P12_PASSWORD" -A \
  -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$GATTEY_CODESIGN_P12_PASSWORD" build.keychain
security list-keychains -d user -s build.keychain
rm -f /tmp/codesign.p12

echo "ci-build-macos-release: codesigning identities:" >&2
security find-identity -v -p codesigning 2>&1 >&2 || true
security find-identity -v 2>&1 >&2 || true

SIGN_ID="$(resolve_sign_identity)"
if [[ "$SIGN_ID" == "-" ]]; then
  echo "ci-build-macos-release: no self-signed identity in build.keychain after import." >&2
  smoke="$(mktemp)"
  cp /bin/echo "$smoke"
  if codesign --force --sign "$GATTEY_SELF_SIGNED_NAME" "$smoke" 2>/dev/null; then
    SIGN_ID="$GATTEY_SELF_SIGNED_NAME"
    echo "ci-build-macos-release: codesign smoke test OK (using name ${SIGN_ID})" >&2
  fi
  rm -f "$smoke"
fi
if [[ "$SIGN_ID" == "-" ]]; then
  echo "ci-build-macos-release: re-export with ./scripts/export-ci-secrets.sh" >&2
  exit 1
fi
echo "ci-build-macos-release: signing identity=${SIGN_ID}" >&2

cd "$ROOT/macos"
swift build -c release --product GatteyPhotos

VERSION="$("$ROOT/scripts/next-release-version.sh")"
echo "ci-build-macos-release: packaging v${VERSION}"
"$ROOT/scripts/package-release.sh" "$VERSION"

echo "version=${VERSION}" >> "${GITHUB_OUTPUT:?}"
