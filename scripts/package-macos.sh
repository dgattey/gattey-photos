#!/usr/bin/env bash
# Build dist/Gattey Photos.app (Swift release binaries only).
#
# Dev defaults reproduce the old behavior (ad-hoc signature, timestamp build number, opens the app).
# scripts/package-release.sh reuses this by overriding the GATTEY_* env vars below.
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

SHORT_VERSION="${GATTEY_APP_SHORT_VERSION:-1.0.0}"
BUILD_NUMBER="${GATTEY_BUILD_NUMBER:-$(date +%s)}"
SIGN_ID="${GATTEY_SIGN_IDENTITY:--}"
SIGN_ENTITLEMENTS="${GATTEY_SIGN_ENTITLEMENTS:-$ROOT/macos/GatteyPhotos.local.entitlements}"
OPEN_AFTER="${GATTEY_OPEN_AFTER:-1}"

# Sparkle auto-update feed, hosted on the app's own server (server/public/appcast.xml on Vercel).
# The public EdDSA key is committed (it is public) once scripts/generate-sparkle-key.sh has been
# run; without it the app ships update-capable but inert (AppUpdaterModel does not start the
# updater, so there is no "improperly configured" alert).
SU_FEED_URL="${GATTEY_SU_FEED_URL:-https://photos.gattey.com/appcast.xml}"
SU_PUBLIC_KEY=""
if [[ -f "$ROOT/macos/sparkle-public-key.txt" ]]; then
  SU_PUBLIC_KEY="$(tr -d '[:space:]' <"$ROOT/macos/sparkle-public-key.txt")"
fi

# codesign with the configured identity, splitting any extra options (e.g. --options runtime).
csign() {
  if [[ -n "${GATTEY_CODESIGN_EXTRA_OPTS:-}" ]]; then
    # shellcheck disable=SC2086
    codesign --force --sign "$SIGN_ID" ${GATTEY_CODESIGN_EXTRA_OPTS} "$@"
  else
    codesign --force --sign "$SIGN_ID" "$@"
  fi
}

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

# Locate the Sparkle framework SwiftPM produced (copied next to the product, or in the artifact bundle).
SPARKLE_SRC=""
for cand in \
  "$MACOS/.build/release/Sparkle.framework" \
  "$MACOS"/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-*/Sparkle.framework; do
  if [[ -d "$cand" ]]; then SPARKLE_SRC="$cand"; break; fi
done
if [[ -z "$SPARKLE_SRC" ]]; then
  echo "package-macos: Sparkle.framework not found under .build — run 'swift build' first" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$MACOS_BIN" "$RESOURCES" "$FRAMEWORKS"

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

# Embed Sparkle.framework. ditto preserves the framework symlinks codesign needs.
rm -rf "$FRAMEWORKS/Sparkle.framework"
ditto "$SPARKLE_SRC" "$FRAMEWORKS/Sparkle.framework"

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
FW="$FRAMEWORKS/Sparkle.framework"
FWV="$FW/Versions/B"
[[ -e "$FWV/XPCServices/Installer.xpc" ]] && csign "$FWV/XPCServices/Installer.xpc"
if [[ -e "$FWV/XPCServices/Downloader.xpc" ]]; then
  # Downloader.xpc ships sandbox/network entitlements that must survive re-signing.
  if [[ -n "${GATTEY_CODESIGN_EXTRA_OPTS:-}" ]]; then
    # shellcheck disable=SC2086
    codesign --force --sign "$SIGN_ID" ${GATTEY_CODESIGN_EXTRA_OPTS} --preserve-metadata=entitlements "$FWV/XPCServices/Downloader.xpc"
  else
    codesign --force --sign "$SIGN_ID" --preserve-metadata=entitlements "$FWV/XPCServices/Downloader.xpc"
  fi
fi
[[ -e "$FWV/Autoupdate" ]] && csign "$FWV/Autoupdate"
[[ -e "$FWV/Updater.app" ]] && csign "$FWV/Updater.app"
csign "$FW"

# Ad-hoc dist builds: omit associated-domains (SIGKILL at launch). Production uses GatteyPhotos.entitlements + real cert.
csign --entitlements "$SIGN_ENTITLEMENTS" "$APP"

APP_SIZE="$(du -sh "$APP" | cut -f1)"
echo "Packaged: $APP ($APP_SIZE)"
echo "  CFBundleShortVersionString=${SHORT_VERSION}  CFBundleVersion=${BUILD_NUMBER}  identity=${SIGN_ID}"
echo "  Sparkle: feed=${SU_FEED_URL} publicKey=$([[ -n "$SU_PUBLIC_KEY" ]] && echo present || echo MISSING)"
echo "  Launch only this bundle (not /Applications): $APP"
if [[ "$OPEN_AFTER" == "1" ]]; then
  open "$APP"
fi
