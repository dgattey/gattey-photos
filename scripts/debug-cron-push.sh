#!/usr/bin/env bash
# One-shot local cron advance with device-push summary in the JSON response.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER="$ROOT/server"
BASE_URL="${GATTEY_SERVER_URL:-http://127.0.0.1:3000}"

if [[ -f "$SERVER/.env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$SERVER/.env.local"
  set +a
fi

if [[ -z "${CRON_SECRET:-}" ]]; then
  echo "CRON_SECRET is not set in $SERVER/.env.local" >&2
  exit 1
fi

if ! curl -sf --max-time 2 "$BASE_URL/api/health" >/dev/null; then
  echo "Sync API is not running at $BASE_URL (try ./scripts/start-server.sh)" >&2
  exit 1
fi

echo "POST $BASE_URL/api/cron/advance-current"
curl -sf --max-time 120 \
  -H "Authorization: Bearer ${CRON_SECRET}" \
  "${BASE_URL}/api/cron/advance-current" | python3 -m json.tool
