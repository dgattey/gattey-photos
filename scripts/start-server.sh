#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/lib/node-env.sh"
SERVER="$ROOT/server"
PID_FILE="$ROOT/.dev-server-supervisor.pid"
LOG_FILE="$ROOT/.dev-server.log"

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  if curl -sf --max-time 1 http://127.0.0.1:3000/api/health >/dev/null; then
    echo "Sync server already running (supervisor pid $(cat "$PID_FILE"))"
    exit 0
  fi
  kill "$(cat "$PID_FILE")" 2>/dev/null || true
  rm -f "$PID_FILE"
fi

if [[ ! -f "$SERVER/.env.local" ]]; then
  cp "$SERVER/.env.example" "$SERVER/.env.local"
fi
cd "$SERVER"
[[ -d node_modules ]] || npm install

nohup "$ROOT/scripts/server-supervisor.sh" >>"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"

for i in $(seq 1 30); do
  if curl -sf --max-time 1 http://127.0.0.1:3000/api/health >/dev/null; then
    echo "Sync API ready at http://127.0.0.1:3000 (supervisor pid $(cat "$PID_FILE"))"
    exit 0
  fi
  sleep 0.5
done

echo "Sync server did not become ready. See $LOG_FILE" >&2
exit 1
