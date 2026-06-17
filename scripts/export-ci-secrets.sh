#!/usr/bin/env bash
# Print GitHub Actions secret values for release-macos.yml (paste into repo Settings → Secrets).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib/signing.sh
source "$ROOT/scripts/lib/signing.sh"

CERT_DIR="$ROOT/.cert"
CRT="$CERT_DIR/gattey-photos.crt"
KEY="$CERT_DIR/key.pem"
P12="$CERT_DIR/gattey-photos.p12"
P12_PASS="${GATTEY_CODESIGN_P12_PASSWORD:-gattey-photos}"
NAME="$GATTEY_SELF_SIGNED_NAME"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

mkdir -p "$CERT_DIR"

write_p12_from_pem() {
  openssl pkcs12 -export -legacy -inkey "$KEY" -in "$CRT" -out "$P12" -passout "pass:${P12_PASS}"
}

export_p12_from_keychain() {
  if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "\"${NAME}\""; then
    echo "export-ci-secrets: no codesigning identity named \"${NAME}\" in the login keychain." >&2
    return 1
  fi
  local count
  count="$(security find-identity -v -p codesigning 2>/dev/null | awk '/valid identities found/ { print $1; exit }')"
  if [[ -z "$count" || "$count" -gt 1 ]]; then
    echo "export-ci-secrets: login keychain has ${count:-?} codesigning identities." >&2
    echo "  For CI we need only \"${NAME}\". Remove other release identities, or run:" >&2
    echo "  ./scripts/setup-self-signed-cert.sh" >&2
    return 1
  fi
  echo "export-ci-secrets: exporting \"${NAME}\" from login keychain to $P12" >&2
  security export -k "$KEYCHAIN" -t identities -f pkcs12 -o "$P12" -P "$P12_PASS"
}

if [[ ! -f "$P12" ]]; then
  if [[ -f "$KEY" && -f "$CRT" ]]; then
    echo "export-ci-secrets: building $P12 from .cert/*.pem" >&2
    write_p12_from_pem
  elif ! export_p12_from_keychain; then
    echo "export-ci-secrets: run ./scripts/setup-self-signed-cert.sh to create the identity." >&2
    exit 1
  fi
fi

SPARKLE_BIN="$ROOT/macos/.build/artifacts/sparkle/Sparkle/bin/generate_keys"
ED_KEY="/tmp/sparkle_ed.key"
if [[ -x "$SPARKLE_BIN" ]]; then
  "$SPARKLE_BIN" -x "$ED_KEY" 2>/dev/null || true
fi

echo "=== GitHub repository secrets ==="
echo
echo "GATTEY_CODESIGN_P12_PASSWORD"
echo "$P12_PASS"
echo
echo "GATTEY_CODESIGN_P12_BASE64 (one line):"
base64 <"$P12" | tr -d '\n'
echo
echo
if [[ -f "$ED_KEY" ]]; then
  echo "SPARKLE_ED_PRIVATE_KEY_BASE64 (one line):"
  base64 <"$ED_KEY" | tr -d '\n'
  echo
  rm -f "$ED_KEY"
else
  echo "SPARKLE_ED_PRIVATE_KEY_BASE64: run 'cd macos && swift build' then re-run this script,"
  echo "  or: .build/artifacts/sparkle/Sparkle/bin/generate_keys -x /tmp/sparkle_ed.key"
fi
echo
echo "Workflow: .github/workflows/release-macos.yml"
