#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT/.dev-server-supervisor.pid"
if [[ -f "$PID_FILE" ]]; then
  kill "$(cat "$PID_FILE")" 2>/dev/null || true
  rm -f "$PID_FILE"
fi
pkill -f "server-supervisor.sh" 2>/dev/null || true
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
echo "Sync server stopped"
