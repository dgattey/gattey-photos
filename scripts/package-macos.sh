#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MACOS="$ROOT/macos"
DIST="$ROOT/dist"
APP="$DIST/Gattey Photos.app"
CONTENTS="$APP/Contents"
MACOS_BIN="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

cd "$MACOS"
swift build -c release --product GatteyPhotos --product GatteyPhotosSyncHelper

rm -rf "$APP"
mkdir -p "$MACOS_BIN" "$RESOURCES"

cp ".build/release/GatteyPhotos" "$MACOS_BIN/GatteyPhotos"
cp ".build/release/GatteyPhotosSyncHelper" "$MACOS_BIN/GatteyPhotosSyncHelper"
chmod +x "$MACOS_BIN/GatteyPhotos" "$MACOS_BIN/GatteyPhotosSyncHelper"

cat > "$CONTENTS/Info.plist" <<'PLIST'
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
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "Packaged: $APP"
echo "Install: cp -R \"$APP\" /Applications/ && open \"/Applications/Gattey Photos.app\""
