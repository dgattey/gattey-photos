#!/usr/bin/env bash
# Build server/public/gattey-photos-trust.mobileconfig from the self-signed signing cert.
# Family installs this once from photos.gattey.com (no repo scripts).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRT="${1:-$ROOT/.cert/gattey-photos.crt}"
OUT="${2:-$ROOT/server/public/gattey-photos-trust.mobileconfig}"

if [[ ! -f "$CRT" ]]; then
  echo "generate-trust-profile: missing $CRT — run scripts/setup-self-signed-cert.sh first." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
B64="$(openssl x509 -in "$CRT" -outform DER | base64 | tr -d '\n')"

# Fixed UUIDs so re-generated profiles replace the same logical payload.
CERT_PAYLOAD_UUID="a1b2c3d4-e5f6-4789-a012-3456789abcde"
PROFILE_PAYLOAD_UUID="b2c3d4e5-f6a7-4890-b123-456789abcdef0"

cat >"$OUT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadCertificateFileName</key>
      <string>gattey-photos-self-signed.cer</string>
      <key>PayloadContent</key>
      <data>
${B64}
      </data>
      <key>PayloadDescription</key>
      <string>Trust Gattey Photos on this Mac (self-signed app, not from the App Store).</string>
      <key>PayloadDisplayName</key>
      <string>Gattey Photos signing certificate</string>
      <key>PayloadIdentifier</key>
      <string>com.gattey.photos.signing-cert</string>
      <key>PayloadType</key>
      <string>com.apple.security.pem</string>
      <key>PayloadUUID</key>
      <string>${CERT_PAYLOAD_UUID}</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
    </dict>
  </array>
  <key>PayloadDescription</key>
  <string>One-time install so macOS allows Gattey Photos and future updates from photos.gattey.com.</string>
  <key>PayloadDisplayName</key>
  <string>Gattey Photos — macOS trust</string>
  <key>PayloadIdentifier</key>
  <string>com.gattey.photos.trust</string>
  <key>PayloadOrganization</key>
  <string>Gattey Photos</string>
  <key>PayloadRemovalDisallowed</key>
  <false/>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadUUID</key>
  <string>${PROFILE_PAYLOAD_UUID}</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
</dict>
</plist>
EOF

if plutil -lint "$OUT" >/dev/null 2>&1; then
  echo "generate-trust-profile: $OUT (valid plist)"
else
  echo "generate-trust-profile: wrote $OUT (plutil lint skipped or failed)"
fi
