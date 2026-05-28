#!/usr/bin/env bash
# Build app, start sync API in background (keeps running), open Gattey Photos.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

chmod +x "$ROOT/scripts/"*.sh

echo "==> App icon"
"$ROOT/scripts/generate-app-icon.sh"

echo "==> macOS app"
"$ROOT/scripts/package-macos.sh"

echo "==> Sync server (background)"
"$ROOT/scripts/start-server.sh"
sleep 3

CONFIG_DIR="$HOME/Library/Application Support/GatteyPhotos"
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
  PASS="$(grep '^SYNC_PASSWORD=' "$ROOT/server/.env.local" | cut -d= -f2-)"
  cat >"$CONFIG_DIR/config.json" <<EOF
{
  "deviceIP": "192.168.1.100",
  "serverBaseURL": "http://127.0.0.1:3000",
  "syncPassword": "$PASS"
}
EOF
fi

echo "==> Launching Gattey Photos"
open "$ROOT/dist/Gattey Photos.app"
echo "Server stays up after this script exits. Stop it with: ./scripts/stop-server.sh"
