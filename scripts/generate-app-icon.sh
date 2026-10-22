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

# Web icon URL contract shared with dyl-kit and dylangattey.com:
#   /icon.png             1024×1024 (server/public/icon.png)
#   /apple-touch-icon.png  180×180  (server/public/apple-touch-icon.png, same bytes as server/app/apple-icon.png)
#   /favicon.ico           16 + 32  (server/app/favicon.ico)
SERVER_APP_DIR="$ROOT/server/app"
SERVER_PUBLIC_DIR="$ROOT/server/public"
if [[ -d "$SERVER_APP_DIR" ]]; then
  if [[ ! -f "$OUT_DIR/AppIcon.icns" ]]; then
    echo "generate-app-icon: actool did not produce AppIcon.icns, so the web icons cannot be refreshed" >&2
    exit 1
  fi
  ICONSET_DIR="$OUT_DIR/AppIcon.iconset"
  IOS_OUT_DIR="$OUT_DIR/ios"
  rm -rf "$ICONSET_DIR" "$IOS_OUT_DIR"
  mkdir -p "$IOS_OUT_DIR"

  iconutil --convert iconset "$OUT_DIR/AppIcon.icns" -o "$ICONSET_DIR"

  # AppIcon.icns tops out at 512px, so Icon Composer's ictool renders the 1024px macOS icon.
  ICTOOL="${ICTOOL:-$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool}"
  if [[ ! -x "$ICTOOL" ]]; then
    echo "generate-app-icon: ictool not found at $ICTOOL (install Xcode 26+)" >&2
    exit 1
  fi
  if ! "$ICTOOL" "$ICON_BUNDLE" --export-image --output-file "$SERVER_PUBLIC_DIR/icon.png" \
    --platform macOS --rendition Default --width 1024 --height 1024 --scale 1; then
    "$ICTOOL" --help >&2 || true
    echo "generate-app-icon: ictool could not export the 1024px icon" >&2
    exit 1
  fi
  # ictool writes 16-bit RGBA (~1.4 MB); lossless 8-bit is ~320 KB.
  if [[ ! -d "$ROOT/server/node_modules/sharp" ]]; then
    echo "generate-app-icon: run npm ci in server/ first (sharp re-encodes icon.png)" >&2
    exit 1
  fi
  (cd "$ROOT/server" && node -e '
    const sharp = require("sharp");
    const file = process.argv[1];
    sharp(file).toColourspace("srgb").png({ compressionLevel: 9, adaptiveFiltering: true }).toBuffer()
      .then((png) => require("fs").writeFileSync(file, png));
  ' "$SERVER_PUBLIC_DIR/icon.png")

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

  if [[ ! -f "$IOS_OUT_DIR/AppIcon60x60@3x.png" ]]; then
    echo "generate-app-icon: actool did not produce the 180px iOS icon (AppIcon60x60@3x.png)" >&2
    exit 1
  fi
  cp "$IOS_OUT_DIR/AppIcon60x60@3x.png" "$SERVER_APP_DIR/apple-icon.png"
  cp "$IOS_OUT_DIR/AppIcon60x60@3x.png" "$SERVER_PUBLIC_DIR/apple-touch-icon.png"
  (cd "$ICON_BUNDLE" && export LC_ALL=C && cat icon.json Assets/*) | shasum -a 256 | cut -d' ' -f1 \
    >"$ROOT/server/lib/app-icon-source.sha256"
  echo "Web icons: server/public/{icon.png,apple-touch-icon.png}, server/app/{favicon.ico,apple-icon.png}"
  echo "App icon changed: update photos.gattey.com (server/app/page.tsx) and ask the dg project to update dylangattey.com."
fi
