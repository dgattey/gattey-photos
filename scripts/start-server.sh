#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/lib/node-env.sh"
SERVER="$ROOT/server"
PID_FILE="$ROOT/.dev-server-supervisor.pid"
LOG_FILE="$ROOT/.dev-server.log"
ADVANCE_PID_FILE="$ROOT/.dev-advance-cron.pid"
ADVANCE_LOG="$ROOT/.dev-advance-cron.log"

advance_cron_running() {
  [[ -f "$ADVANCE_PID_FILE" ]] || return 1
  local pid
  pid="$(tr -d '[:space:]' <"$ADVANCE_PID_FILE")"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && ps -p "$pid" -o command= 2>/dev/null | grep -q "local-advance-cron.sh"
}

start_advance_cron() {
  if advance_cron_running; then
    echo "Advance cron already running (pid $(cat "$ADVANCE_PID_FILE"))"
    return 0
  fi
  rm -f "$ADVANCE_PID_FILE"
  if [[ -f "$SERVER/.env.local" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$SERVER/.env.local"
    set +a
  fi
  if [[ -z "${CRON_SECRET:-}" ]]; then
    echo "Advance cron not started (set CRON_SECRET in server/.env.local)" >&2
    return 0
  fi
  chmod +x "$ROOT/scripts/local-advance-cron.sh"
  nohup "$ROOT/scripts/local-advance-cron.sh" >>"$ADVANCE_LOG" 2>&1 &
  echo $! >"$ADVANCE_PID_FILE"
  echo "Advance cron every ${ADVANCE_CURRENT_INTERVAL_SECONDS:-1800}s (30 minutes; pid $(cat "$ADVANCE_PID_FILE"), log $ADVANCE_LOG)"
}

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  if curl -sf --max-time 1 http://127.0.0.1:3000/api/health >/dev/null; then
    echo "Sync server already running (supervisor pid $(cat "$PID_FILE"))"
    start_advance_cron
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
    start_advance_cron
    exit 0
  fi
  sleep 0.5
done

echo "Sync server did not become ready. See $LOG_FILE" >&2
exit 1
