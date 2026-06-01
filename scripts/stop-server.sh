#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT/.dev-server-supervisor.pid"
ADVANCE_PID_FILE="$ROOT/.dev-advance-cron.pid"

advance_cron_cmd() {
  ps -p "$1" -o command= 2>/dev/null | grep -q "local-advance-cron.sh"
}

if [[ -f "$ADVANCE_PID_FILE" ]]; then
  pid="$(tr -d '[:space:]' <"$ADVANCE_PID_FILE")"
  if [[ -n "$pid" ]] && advance_cron_cmd "$pid"; then
    kill "$pid" 2>/dev/null || true
  fi
  rm -f "$ADVANCE_PID_FILE"
fi
pkill -f "$ROOT/scripts/local-advance-cron.sh" 2>/dev/null || true

supervisor_cmd() {
  ps -p "$1" -o command= 2>/dev/null | grep -q "server-supervisor.sh"
}

if [[ -f "$PID_FILE" ]]; then
  pid="$(tr -d '[:space:]' <"$PID_FILE")"
  if [[ -n "$pid" ]] && supervisor_cmd "$pid"; then
    kill "$pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
fi
pkill -f "$ROOT/scripts/server-supervisor.sh" 2>/dev/null || true

# Orphaned Next.js on :3000 only (avoid killing unrelated listeners).
while read -r pid; do
  [[ -n "$pid" ]] || continue
  cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  [[ "$cmd" == *node* || "$cmd" == *next* ]] || continue
  kill -9 "$pid" 2>/dev/null || true
done < <(lsof -ti:3000 2>/dev/null || true)

echo "Sync server stopped"
