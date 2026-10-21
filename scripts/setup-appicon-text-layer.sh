#!/usr/bin/env bash
# Open AppIcon.icon in Icon Composer (gradient, glass, layer position). G stays Letter-G.svg paths.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON="$ROOT/AppIcon.icon"
IC_APP="${ICON_COMPOSER_APP:-/Applications/Xcode.app/Contents/Applications/Icon Composer.app}"

if [[ ! -d "$ICON" ]]; then
  echo "setup-appicon: missing $ICON" >&2
  exit 1
fi

echo "G is Assets/Letter-G.svg (outlined paths). Edit fill gradient on the canvas and glass on the G layer in Icon Composer."
echo "Then: ./run dev build"
echo ""
open -a "$IC_APP" "$ICON"
