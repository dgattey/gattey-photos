#!/usr/bin/env bash
# Compile macos/AppIcon.icon (icon.json + Assets) to Assets.car via actool.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MACOS="$ROOT/macos"
ICON_BUNDLE="$MACOS/AppIcon.icon"
OUT_DIR="$MACOS/.icon-build/out"
CAR="$MACOS/Assets.car"
ACTOOL="${ACTOOL:-/Applications/Xcode.app/Contents/Developer/usr/bin/actool}"

if [[ ! -x "$ACTOOL" ]]; then
  echo "generate-app-icon: actool not found (install Xcode)" >&2
  exit 1
fi

if [[ ! -f "$ICON_BUNDLE/icon.json" ]]; then
  echo "generate-app-icon: missing $ICON_BUNDLE/icon.json" >&2
  exit 1
fi

mkdir -p "$ICON_BUNDLE/Assets"

if [[ ! -f "$ICON_BUNDLE/Assets/Letter-G.svg" ]] && grep -q '"image-name".*Letter-G' "$ICON_BUNDLE/icon.json" 2>/dev/null; then
  echo "generate-app-icon: icon.json references Letter-G.svg but Assets/Letter-G.svg is missing (run GATTEY_REGENERATE_LETTER_G=1 or restore the file)" >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
"$ACTOOL" "$ICON_BUNDLE" --app-icon AppIcon \
  --compile "$OUT_DIR" \
  --output-partial-info-plist "$OUT_DIR/assetcatalog_generated_info.plist" \
  --minimum-deployment-target 14.0 --platform macosx --target-device mac

if [[ ! -f "$OUT_DIR/Assets.car" ]]; then
  echo "generate-app-icon: actool did not produce Assets.car (check icon.json / layer assets)" >&2
  exit 1
fi

cp "$OUT_DIR/Assets.car" "$CAR"
echo "Icon: $CAR (CFBundleIconName AppIcon)"
