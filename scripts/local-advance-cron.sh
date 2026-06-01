#!/usr/bin/env bash
# Local stand-in for Vercel Cron: advance currentPhotoId on an interval.
# Production uses vercel.json (every 4h). Default here: 30 minutes (1800s).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER="$ROOT/server"
BASE_URL="${GATTEY_SERVER_URL:-http://127.0.0.1:3000}"
INTERVAL_SEC="${ADVANCE_CURRENT_INTERVAL_SECONDS:-1800}"

if [[ -f "$SERVER/.env.local" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "$SERVER/.env.local"
  set +a
elif [[ -f "$SERVER/.env.example" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$SERVER/.env.example"
  set +a
fi

if [[ -z "${CRON_SECRET:-}" ]]; then
  echo "CRON_SECRET is not set in $SERVER/.env.local" >&2
  exit 1
fi

echo "Advancing current photo every ${INTERVAL_SEC}s at ${BASE_URL}/api/cron/advance-current (Ctrl+C to stop)"

while true; do
  if curl -sf --max-time 30 \
    -H "Authorization: Bearer ${CRON_SECRET}" \
    "${BASE_URL}/api/cron/advance-current"; then
    echo
  else
    echo "advance-current request failed (is the sync API running?)" >&2
  fi
  sleep "$INTERVAL_SEC"
done
