#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pkill -x GatteyPhotos 2>/dev/null || true
sleep 0.5

"$ROOT/scripts/package-macos.sh"

open -n "/Applications/Gattey Photos.app"
