#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MACOS="$ROOT/macos"
DIST="$ROOT/dist"
APP="$DIST/Gattey Photos.app"
CONTENTS="$APP/Contents"
MACOS_BIN="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

if [[ ! -f "$ROOT/macos/AppIcon.icns" ]]; then
  chmod +x "$ROOT/scripts/generate-app-icon.sh"
  "$ROOT/scripts/generate-app-icon.sh"
fi

cd "$MACOS"
swift build -c release --product GatteyPhotos --product GatteyPhotosSyncHelper

rm -rf "$APP"
mkdir -p "$MACOS_BIN" "$RESOURCES"

ENTITLEMENTS="$ROOT/macos/GatteyPhotos.entitlements"
cp ".build/release/GatteyPhotos" "$MACOS_BIN/GatteyPhotos"
cp ".build/release/GatteyPhotosSyncHelper" "$MACOS_BIN/GatteyPhotosSyncHelper"
if [[ -f "$ENTITLEMENTS" ]]; then
  codesign --force --sign - --entitlements "$ENTITLEMENTS" "$MACOS_BIN/GatteyPhotos" 2>/dev/null || true
fi
cp "$ROOT/macos/AppIcon.icns" "$RESOURCES/AppIcon.icns"
chmod +x "$MACOS_BIN/GatteyPhotos" "$MACOS_BIN/GatteyPhotosSyncHelper"

BUILD_NUMBER="$(date +%s)"
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>GatteyPhotos</string>
  <key>CFBundleIdentifier</key>
  <string>com.gattey.photos</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Gattey Photos</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
</dict>
</plist>
PLIST

echo "Packaged: $APP"
ditto "$APP" "/Applications/Gattey Photos.app"
echo "Installed: /Applications/Gattey Photos.app"
