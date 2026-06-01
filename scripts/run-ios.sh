#!/usr/bin/env bash
# Build GatteyPhotosIOS, boot a simulator, install, and launch.
# Default device: iPad Pro 13-inch (M5). Override with IOS_DEVICE_NAME or IOS_SIM_DEST.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/scripts/launch.sh" ipad
