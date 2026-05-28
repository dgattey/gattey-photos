#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$ROOT/.dev-server.log"
cd "$ROOT/server"
export GATTEY_LOCAL_STORAGE=1

while true; do
  echo "--- sync server start $(date -u +%Y-%m-%dT%H:%M:%SZ) ---" >>"$LOG"
  npm run dev >>"$LOG" 2>&1 || echo "--- npm run dev exited $? $(date -u +%Y-%m-%dT%H:%M:%SZ) ---" >>"$LOG"
  echo "--- restarting in 3s ---" >>"$LOG"
  sleep 3
done
