#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER="$ROOT/server"
PID_FILE="$ROOT/.dev-server.pid"
LOG_FILE="$ROOT/.dev-server.log"

find_npm() {
  if command -v npm >/dev/null 2>&1; then
    command -v npm
    return
  fi
  for dir in /opt/homebrew/bin /usr/local/bin "$HOME/.fnm/current/bin" "$HOME/.local/share/mise/shims"; do
    if [[ -x "$dir/npm" ]]; then
      echo "$dir/npm"
      return
    fi
  done
  echo "npm not found. Install Node.js (brew install node) and re-run ./scripts/dev.sh" >&2
  exit 1
}

stop_server() {
  if [[ -f "$PID_FILE" ]]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
  fi
}

start_server() {
  NPM="$(find_npm)"
  if [[ ! -f "$SERVER/.env.local" ]]; then
    cp "$SERVER/.env.example" "$SERVER/.env.local"
    echo "Created server/.env.local"
  fi
  stop_server
  cd "$SERVER"
  if [[ ! -d node_modules ]]; then
    "$NPM" install
  fi
  export GATTEY_LOCAL_STORAGE=1
  "$NPM" run dev >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  echo "Sync API: http://127.0.0.1:3000 (log: $LOG_FILE)"
}

cleanup() {
  stop_server
}
trap cleanup EXIT INT TERM

start_server
sleep 2

cd "$ROOT/macos"
swift build --product GatteyPhotos 2>&1 | tail -3
echo "Launching Gattey Photos (embedded hourly sync while app runs)…"
swift run GatteyPhotos
