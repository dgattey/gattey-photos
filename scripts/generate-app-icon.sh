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

SERVER_APP_DIR="$ROOT/server/app"
if [[ -d "$SERVER_APP_DIR" && -f "$OUT_DIR/AppIcon.icns" ]]; then
  ICONSET_DIR="$OUT_DIR/AppIcon.iconset"
  IOS_OUT_DIR="$OUT_DIR/ios"
  rm -rf "$ICONSET_DIR" "$IOS_OUT_DIR"
  mkdir -p "$IOS_OUT_DIR"

  iconutil --convert iconset "$OUT_DIR/AppIcon.icns" -o "$ICONSET_DIR"
  cp "$ICONSET_DIR/icon_128x128@2x.png" "$SERVER_APP_DIR/icon.png"

  python3 - "$ICONSET_DIR/icon_16x16.png" "$ICONSET_DIR/icon_16x16@2x.png" "$SERVER_APP_DIR/favicon.ico" <<'PY'
import struct
import sys

png16_path, png32_path, ico_path = sys.argv[1], sys.argv[2], sys.argv[3]
frames = [(16, 16, open(png16_path, "rb").read()), (32, 32, open(png32_path, "rb").read())]

header = struct.pack("<HHH", 0, 1, len(frames))
offset = 6 + 16 * len(frames)
entries = []
payloads = []

for width, height, data in frames:
    entries.append(
        struct.pack(
            "<BBBBHHII",
            width,
            height,
            0,
            0,
            1,
            32,
            len(data),
            offset,
        )
    )
    payloads.append(data)
    offset += len(data)

with open(ico_path, "wb") as out:
    out.write(header)
    for entry in entries:
        out.write(entry)
    for payload in payloads:
        out.write(payload)
PY

  "$ACTOOL" "$ICON_BUNDLE" --app-icon AppIcon \
    --compile "$IOS_OUT_DIR" \
    --output-partial-info-plist "$IOS_OUT_DIR/assetcatalog_generated_info.plist" \
    --minimum-deployment-target 10.0 --platform iphoneos --target-device iphone >/dev/null

  if [[ -f "$IOS_OUT_DIR/AppIcon60x60@3x.png" ]]; then
    cp "$IOS_OUT_DIR/AppIcon60x60@3x.png" "$SERVER_APP_DIR/apple-icon.png"
  fi
  echo "Web icons: $SERVER_APP_DIR/{favicon.ico,icon.png,apple-icon.png}"
fi
