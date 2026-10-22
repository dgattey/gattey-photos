#!/usr/bin/env bash
# Build "Gattey Photos.app" for the iOS Simulator with swiftc (no Xcode project or xcodebuild).
# Prints the .app path on stdout.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MACOS="$ROOT/macos"
OUT="$MACOS/.build/ios-sim"
MODULES="$OUT/modules"
APP="$OUT/Gattey Photos.app"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"

SWIFTC=(
  xcrun --sdk iphonesimulator swiftc
  -target "$(uname -m)-apple-ios17.0-simulator"
  -sdk "$SDK"
  -swift-version 5
  -package-name GatteyPhotos
  -I "$MODULES"
  -Onone
)

# Modules compile in dependency order, so once one rebuilds every later one must too.
rebuilt=0
compile_module() {
  local mod="$1"
  local obj="$MODULES/$mod.o"
  if [[ "$rebuilt" == 0 && -f "$obj" && -z "$(find "Sources/$mod" -newer "$obj" -print -quit)" ]]; then
    return
  fi
  rebuilt=1
  "${SWIFTC[@]}" -parse-as-library -whole-module-optimization \
    -emit-module -emit-module-path "$MODULES/$mod.swiftmodule" \
    -emit-object -o "$obj" -module-name "$mod" "Sources/$mod"/*.swift
}

mkdir -p "$MODULES"
cd "$MACOS"
compile_module GatteyPhotosCore
compile_module GatteyPhotosUI

rm -rf "$APP"
mkdir -p "$APP/GatteyPhotos_GatteyPhotosUI.bundle"
"${SWIFTC[@]}" -parse-as-library -module-name GatteyPhotosIOS \
  Sources/GatteyPhotosIOS/*.swift "$MODULES/GatteyPhotosCore.o" "$MODULES/GatteyPhotosUI.o" \
  -o "$APP/GatteyPhotosIOS"
cp Sources/GatteyPhotosIOS/Info.plist "$APP/Info.plist"
cp Sources/GatteyPhotosUI/Resources/* "$APP/GatteyPhotos_GatteyPhotosUI.bundle/"
codesign --force --sign - "$APP" >/dev/null 2>&1

echo "$APP"
