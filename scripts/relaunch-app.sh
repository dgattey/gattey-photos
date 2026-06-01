#!/usr/bin/env bash
# Quit running app, rebuild dist/Gattey Photos.app, and open it (via package-macos.sh).
# App icon: package-macos always runs generate-app-icon.sh first (actool on
# macos/AppIcon.icon → macos/Assets.car, copied into the .app Resources).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/scripts/launch.sh" macos
