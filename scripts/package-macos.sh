#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$HOME/Library/Application Support/GatteyPhotos"
echo "$ROOT" >"$HOME/Library/Application Support/GatteyPhotos/repo-root.txt"
MACOS="$ROOT/macos"
DIST="${GATTEY_DIST_DIR:-$ROOT/dist}"
APP="$DIST/Gattey Photos.app"
CONTENTS="$APP/Contents"
MACOS_BIN="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"

BUILD_CONFIG="${GATTEY_BUILD_CONFIG:-debug}"
SHORT_VERSION="${GATTEY_APP_SHORT_VERSION:-1.0.0}"
BUILD_NUMBER="${GATTEY_BUILD_NUMBER:-$(date +%s)}"
SIGN_ID="${GATTEY_SIGN_IDENTITY:--}"
SIGN_ENTITLEMENTS="${GATTEY_SIGN_ENTITLEMENTS:-$ROOT/macos/GatteyPhotos.local.entitlements}"
OPEN_AFTER="${GATTEY_OPEN_AFTER:-1}"
OPEN_BACKGROUND="${GATTEY_OPEN_BACKGROUND:-1}"
FORCE_RESIGN="${GATTEY_FORCE_RESIGN:-0}"
if [[ "$BUILD_CONFIG" == "release" || "$SIGN_ID" != "-" ]]; then
  FORCE_RESIGN=1
fi

SU_FEED_URL="${GATTEY_SU_FEED_URL:-https://photos.gattey.com/appcast.xml}"
SU_PUBLIC_KEY=""
if [[ -f "$ROOT/macos/sparkle-public-key.txt" ]]; then
  SU_PUBLIC_KEY="$(tr -d '[:space:]' <"$ROOT/macos/sparkle-public-key.txt")"
fi

csign() {
  local extra_opts=()
  if [[ -n "${GATTEY_CODESIGN_EXTRA_OPTS:-}" ]]; then
    read -r -a extra_opts <<<"$GATTEY_CODESIGN_EXTRA_OPTS"
    codesign --force --sign "$SIGN_ID" "${extra_opts[@]}" "$@"
  else
    codesign --force --sign "$SIGN_ID" "$@"
  fi
}

strip_non_system_rpaths() {
  local bin="$1"
  while IFS= read -r rpath; do
    [[ -n "$rpath" ]] || continue
    case "$rpath" in
      @*|/usr/lib/swift|/usr/lib/swift/*) ;;
      *)
        install_name_tool -delete_rpath "$rpath" "$bin"
        ;;
    esac
  done < <(otool -l "$bin" | awk '
    $1 == "cmd" && $2 == "LC_RPATH" { in_rpath = 1; next }
    in_rpath && $1 == "path" {
      sub(/^[[:space:]]*path[[:space:]]+/, "")
      sub(/[[:space:]]+\(offset [0-9]+\)$/, "")
      print
      in_rpath = 0
    }
  ')
}

chmod +x "$ROOT/scripts/generate-app-icon.sh"
CAR_OUT="$MACOS/Assets.car"
if [[ "$FORCE_RESIGN" == "1" || ! -f "$CAR_OUT" ]] || [[ -n "$(find "$MACOS/AppIcon.icon" -newer "$CAR_OUT" -print -quit 2>/dev/null || true)" ]]; then
  "$ROOT/scripts/generate-app-icon.sh"
fi

cd "$MACOS"
swift build --build-system native -c "$BUILD_CONFIG" --product GatteyPhotos
BIN_DIR="$MACOS/.build/$BUILD_CONFIG"
if [[ ! -f "$BIN_DIR/GatteyPhotos" ]]; then
  BIN_DIR="$(swift build --build-system native -c "$BUILD_CONFIG" --show-bin-path)"
fi
APP_BIN="$BIN_DIR/GatteyPhotos"
if [[ ! -f "$APP_BIN" ]]; then
  echo "package-macos: missing $APP_BIN after swift build" >&2
  exit 1
fi

SPARKLE_SRC=""
for cand in \
  "$BIN_DIR/Sparkle.framework" \
  "$MACOS/.build/$BUILD_CONFIG/Sparkle.framework" \
  "$MACOS"/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-*/Sparkle.framework; do
  if [[ -d "$cand" ]]; then SPARKLE_SRC="$cand"; break; fi
done
if [[ -z "$SPARKLE_SRC" ]]; then
  echo "package-macos: Sparkle.framework not found under .build — run 'swift build' first" >&2
  exit 1
fi

if [[ "$FORCE_RESIGN" == "1" ]]; then
  rm -rf "$APP"
fi
mkdir -p "$MACOS_BIN" "$RESOURCES" "$FRAMEWORKS"

cp "$APP_BIN" "$MACOS_BIN/GatteyPhotos"
for bundle in GatteyPhotos_GatteyPhotosApp GatteyPhotos_GatteyPhotosUI; do
  src="$BIN_DIR/${bundle}.bundle"
  if [[ -d "$src" ]]; then
    rm -rf "$MACOS_BIN/${bundle}.bundle"
    cp -R "$src" "$MACOS_BIN/"
  fi
done
cp "$CAR_OUT" "$RESOURCES/Assets.car"
UI_RESOURCE_BUNDLE="$BIN_DIR/GatteyPhotos_GatteyPhotosUI.bundle"
if [[ -f "$UI_RESOURCE_BUNDLE/unlock-welcome.png" ]]; then
  cp "$UI_RESOURCE_BUNDLE/unlock-welcome.png" "$RESOURCES/unlock-welcome.png"
fi
chmod +x "$MACOS_BIN/GatteyPhotos"
strip_non_system_rpaths "$MACOS_BIN/GatteyPhotos"

# Embed Sparkle.framework. ditto preserves the framework symlinks codesign needs.
FW="$FRAMEWORKS/Sparkle.framework"
SPARKLE_CHANGED=0
if [[ "$FORCE_RESIGN" == "1" || ! -d "$FW" ]]; then
  rm -rf "$FW"
  ditto "$SPARKLE_SRC" "$FW"
  SPARKLE_CHANGED=1
fi

SU_PUBLIC_KEY_PLIST=""
if [[ -n "$SU_PUBLIC_KEY" ]]; then
  SU_PUBLIC_KEY_PLIST="  <key>SUPublicEDKey</key>
  <string>${SU_PUBLIC_KEY}</string>"
fi

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
  <string>${SHORT_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>SUFeedURL</key>
  <string>${SU_FEED_URL}</string>
${SU_PUBLIC_KEY_PLIST}
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUScheduledCheckInterval</key>
  <integer>86400</integer>
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
  csign "$nested"
done

# Sign Sparkle inside-out (XPC services, helper, Updater.app, then the framework). Never --deep:
# it corrupts the XPC signatures. Order matters so the outer signature seals valid inner ones.
if [[ "$SPARKLE_CHANGED" == "1" ]]; then
  FWV="$FW/Versions/B"
  [[ -e "$FWV/XPCServices/Installer.xpc" ]] && csign "$FWV/XPCServices/Installer.xpc"
  if [[ -e "$FWV/XPCServices/Downloader.xpc" ]]; then
    # Downloader.xpc ships sandbox/network entitlements that must survive re-signing.
    csign --preserve-metadata=entitlements "$FWV/XPCServices/Downloader.xpc"
  fi
  [[ -e "$FWV/Autoupdate" ]] && csign "$FWV/Autoupdate"
  [[ -e "$FWV/Updater.app" ]] && csign "$FWV/Updater.app"
  csign "$FW"
fi

# When ad-hoc signing ('-'), pin the outer app's designated requirement to its bundle identifier
# rather than the default cdhash so Sparkle's SUCodeSigningVerifier matches old and new builds.
if [[ "$SIGN_ID" == "-" ]]; then
  csign --entitlements "$SIGN_ENTITLEMENTS" -r='designated => identifier "com.gattey.photos"' "$APP"
else
  csign --entitlements "$SIGN_ENTITLEMENTS" "$APP"
fi

APP_SIZE="$(du -sh "$APP" | cut -f1)"
echo "Packaged: $APP ($APP_SIZE)"
echo "  CFBundleShortVersionString=${SHORT_VERSION}  CFBundleVersion=${BUILD_NUMBER}  config=${BUILD_CONFIG}  identity=${SIGN_ID}"
echo "  Sparkle: feed=${SU_FEED_URL} publicKey=$([[ -n "$SU_PUBLIC_KEY" ]] && echo present || echo MISSING)"
echo "  Launch only this bundle (not /Applications): $APP"
if [[ "$OPEN_AFTER" == "1" ]]; then
  if [[ "$OPEN_BACKGROUND" == "1" ]]; then
    open -g -j "$APP"
  else
    open "$APP"
  fi
fi
