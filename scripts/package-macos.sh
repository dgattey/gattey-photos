#!/usr/bin/env bash
# Build dist/Gattey Photos.app (Swift release binaries only).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$HOME/Library/Application Support/GatteyPhotos"
echo "$ROOT" >"$HOME/Library/Application Support/GatteyPhotos/repo-root.txt"
MACOS="$ROOT/macos"
DIST="$ROOT/dist"
APP="$DIST/Gattey Photos.app"
CONTENTS="$APP/Contents"
MACOS_BIN="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

chmod +x "$ROOT/scripts/generate-app-icon.sh"
"$ROOT/scripts/generate-app-icon.sh"

cd "$MACOS"
APP_BIN=".build/release/GatteyPhotos"
if [[ -f "$APP_BIN" ]]; then
  stale="$(find Sources/GatteyPhotosApp Sources/GatteyPhotosCore Sources/GatteyPhotosUI -name '*.swift' -newer "$APP_BIN" -print -quit 2>/dev/null || true)"
  if [[ -n "${stale:-}" ]]; then
    echo "package-macos: app sources newer than binary — forcing GatteyPhotos rebuild" >&2
    rm -f "$APP_BIN"
  fi
fi
swift build -c release --product GatteyPhotos
if [[ ! -f "$APP_BIN" ]]; then
  echo "package-macos: missing $APP_BIN after swift build" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$MACOS_BIN" "$RESOURCES"

ENTITLEMENTS="$ROOT/macos/GatteyPhotos.entitlements"
cp "$APP_BIN" "$MACOS_BIN/GatteyPhotos"
for bundle in GatteyPhotos_GatteyPhotosApp GatteyPhotos_GatteyPhotosUI; do
  src=".build/release/${bundle}.bundle"
  if [[ -d "$src" ]]; then
    rm -rf "$MACOS_BIN/${bundle}.bundle"
    cp -R "$src" "$MACOS_BIN/"
  fi
done
cp "$ROOT/macos/Assets.car" "$RESOURCES/Assets.car"
chmod +x "$MACOS_BIN/GatteyPhotos"

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
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
</dict>
</plist>
PLIST

# SPM flat resource bundles lack Info.plist; add one so codesign accepts the .app.
for nested in "$MACOS_BIN"/*.bundle; do
  [[ -d "$nested" ]] || continue
  [[ -f "$nested/Info.plist" || -f "$nested/Contents/Info.plist" ]] && continue
  name="$(basename "$nested" .bundle)"
  cat > "$nested/Info.plist" <<BNDL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.gattey.photos.${name}</string>
  <key>CFBundlePackageType</key>
  <string>BNDL</string>
  <key>CFBundleVersion</key>
  <string>1</string>
</dict>
</plist>
BNDL
done

for nested in "$MACOS_BIN"/*.bundle; do
  [[ -d "$nested" ]] || continue
  codesign --force --sign - "$nested"
done
# Ad-hoc dist builds: omit associated-domains (SIGKILL at launch). Production uses GatteyPhotos.entitlements + real cert.
LOCAL_ENT="$ROOT/macos/GatteyPhotos.local.entitlements"
codesign --force --sign - --entitlements "$LOCAL_ENT" "$APP"

APP_SIZE="$(du -sh "$APP" | cut -f1)"
echo "Packaged: $APP ($APP_SIZE)"
echo "  CFBundleVersion=${BUILD_NUMBER}  GatteyPhotos=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$MACOS_BIN/GatteyPhotos")"
echo "  Launch only this bundle (not /Applications): $APP"
open "$APP"
