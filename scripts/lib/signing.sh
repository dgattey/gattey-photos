# Self-signed code signing for macOS releases (scripts/package-release.sh).
# Source from bash: source "$(dirname "$0")/lib/signing.sh"

GATTEY_SELF_SIGNED_NAME="${GATTEY_SELF_SIGNED_NAME:-Gattey Photos Self-Signed}"

# Prints the self-signed identity name, or ad-hoc (-) when missing (dev package-macos only).
resolve_sign_identity() {
  if security find-identity -v -p codesigning 2>/dev/null | grep -F "\"${GATTEY_SELF_SIGNED_NAME}\"" | head -1 | grep -q .; then
    printf '%s' "$GATTEY_SELF_SIGNED_NAME"
    return 0
  fi
  printf '%s' '-'
}

sign_identity_is_real() {
  [[ "$(resolve_sign_identity)" != "-" ]]
}
