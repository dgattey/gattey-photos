#!/usr/bin/env bash
# Dev: local sync API, then build and open build/Gattey Photos Dev.app in the background.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CONFIG_DIR="$HOME/Library/Application Support/GatteyPhotos Dev"
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
  cat >"$CONFIG_DIR/config.json" <<EOF
{
  "serverBaseURL": "http://127.0.0.1:3000",
  "syncSessionToken": ""
}
EOF
fi

# dev.sh sequences start -> relaunch, so the launcher must return even
# headless; the supervisor it spawns keeps running in the background.
GATTEY_FOREGROUND_HOLD=0 "$ROOT/scripts/start-server.sh"
"$ROOT/run" dev relaunch
