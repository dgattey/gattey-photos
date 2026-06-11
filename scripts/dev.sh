#!/usr/bin/env bash
# Dev: local sync API + Swift .app + open dist/Gattey Photos.app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CONFIG_DIR="$HOME/Library/Application Support/GatteyPhotos"
mkdir -p "$CONFIG_DIR"
echo "$ROOT" >"$CONFIG_DIR/repo-root.txt"
if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
  cat >"$CONFIG_DIR/config.json" <<EOF
{
  "serverBaseURL": "http://127.0.0.1:3000",
  "syncSessionToken": ""
}
EOF
fi

chmod +x "$ROOT/scripts/start-server.sh" "$ROOT/scripts/package-macos.sh"
# dev.sh sequences start -> package -> open, so the launcher must return even
# headless; the supervisor it spawns keeps running in the background.
GATTEY_FOREGROUND_HOLD=0 "$ROOT/scripts/start-server.sh"
"$ROOT/scripts/package-macos.sh"
