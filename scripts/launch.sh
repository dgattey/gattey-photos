#!/usr/bin/env bash
# Unified launcher: macOS app + iOS/iPad simulators.
# Usage: ./scripts/launch.sh macos|ios|iphone|ipad|all [targets...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  cat <<EOF >&2
Usage: $(basename "$0") <target> [target...]

Targets:
  macos          Quit, rebuild dist/Gattey Photos.app, open
  ios, iphone    Build and run on iPhone simulator (default: iPhone 17)
  ipad           Build and run on iPad simulator (default: iPad Pro 13-inch (M5))
  all            macos + ios + ipad

Examples:
  $(basename "$0") macos
  $(basename "$0") ios ipad
  $(basename "$0") all

Overrides: IOS_DEVICE_NAME, IOS_SIM_DEST, IOS_SCHEME, IOS_CONFIG, IOS_DERIVED_DATA
EOF
}

launch_macos() {
  echo "launch: macos" >&2
  pkill -x GatteyPhotos 2>/dev/null || true
  for _ in $(seq 1 40); do
    pgrep -x GatteyPhotos >/dev/null || break
    sleep 0.25
  done
  if pgrep -x GatteyPhotos >/dev/null; then
    echo "launch: force-quitting GatteyPhotos" >&2
    pkill -9 -x GatteyPhotos 2>/dev/null || true
    sleep 0.5
  fi
  GATTEY_OPEN_BACKGROUND="${GATTEY_OPEN_BACKGROUND:-1}" "$ROOT/scripts/package-macos.sh"
}

launch_ios_simulator() {
  local default_device="$1"
  local MACOS="$ROOT/macos"
  local SCHEME="${IOS_SCHEME:-GatteyPhotosIOS}"
  local CONFIG="${IOS_CONFIG:-Debug}"
  local BUNDLE_ID="${IOS_BUNDLE_ID:-com.gattey.photos}"
  local DERIVED="${IOS_DERIVED_DATA:-$MACOS/.derivedData-ios}"
  local PRODUCTS="$DERIVED/Build/Products/${CONFIG}-iphonesimulator"
  local DEVICE_NAME="${IOS_DEVICE_NAME:-$default_device}"
  local DEST="${IOS_SIM_DEST:-platform=iOS Simulator,name=${DEVICE_NAME}}"

  cd "$MACOS"
  echo "launch: scheme=$SCHEME device='$DEVICE_NAME'" >&2

  xcodebuild \
    -scheme "$SCHEME" \
    -destination "$DEST" \
    -sdk iphonesimulator \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=YES \
    build

  local BINARY="$PRODUCTS/GatteyPhotosIOS"
  local UI_BUNDLE="$PRODUCTS/GatteyPhotos_GatteyPhotosUI.bundle"
  local INFO_PLIST="$MACOS/Sources/GatteyPhotosIOS/Info.plist"

  if [[ ! -x "$BINARY" ]]; then
    echo "launch: missing binary at $BINARY" >&2
    return 1
  fi

  local STAGE="$DERIVED/stage/Gattey Photos.app"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  cp "$BINARY" "$STAGE/GatteyPhotosIOS"
  cp "$INFO_PLIST" "$STAGE/Info.plist"
  if [[ -d "$UI_BUNDLE" ]]; then
    cp -R "$UI_BUNDLE" "$STAGE/"
  fi
  plutil -replace CFBundleExecutable -string GatteyPhotosIOS "$STAGE/Info.plist" 2>/dev/null || true
  plutil -replace MinimumOSVersion -string 17.0 "$STAGE/Info.plist" 2>/dev/null || true
  plutil -replace CFBundleSupportedPlatforms -json '["iPhoneSimulator"]' "$STAGE/Info.plist" 2>/dev/null || true

  export DEVICE_NAME
  local UDID
  UDID="$(xcrun simctl list devices available -j | python3 -c "
import json, os, sys
name = os.environ['DEVICE_NAME']
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'iOS' not in runtime and 'iphone' not in runtime.lower():
        continue
    for d in devices:
        if d.get('name') == name and d.get('isAvailable'):
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
" 2>/dev/null || true)"

  if [[ -z "${UDID:-}" ]]; then
    echo "launch: simulator '$DEVICE_NAME' not found; pick one with: xcrun simctl list devices available" >&2
    return 1
  fi

  # Boot and wait before UI open (reduces FBSOpenApplication preflight failures).
  xcrun simctl boot "$UDID" 2>/dev/null || true
  if ! xcrun simctl bootstatus "$UDID" -b >&2; then
    echo "launch: warning: bootstatus timed out for $UDID; continuing anyway" >&2
  fi

  echo "launch: opening Simulator (if no window: open -a Simulator)" >&2
  open -a Simulator --args -CurrentDeviceUDID "$UDID"
  sleep 2

  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl install "$UDID" "$STAGE"

  local launch_out=""
  local attempt
  for attempt in 1 2 3; do
    if launch_out="$(xcrun simctl launch "$UDID" "$BUNDLE_ID" 2>&1)"; then
      break
    fi
    echo "launch: simctl launch failed (attempt ${attempt}/3): ${launch_out}" >&2
    launch_out=""
    sleep 2
  done

  if [[ -z "$launch_out" ]]; then
    echo "launch: simctl launch failed after 3 attempts; console output:" >&2
    xcrun simctl launch --console "$UDID" "$BUNDLE_ID" 2>&1 || true
    return 1
  fi

  echo "$launch_out"
  echo "launch: installed and launched on $DEVICE_NAME ($UDID)" >&2
  echo "launch: app=$STAGE" >&2
}

dispatch_target() {
  case "$1" in
    macos) launch_macos ;;
    ios|iphone) launch_ios_simulator "iPhone 17" ;;
    ipad) launch_ios_simulator "iPad Pro 13-inch (M5)" ;;
    all)
      launch_macos
      launch_ios_simulator "iPhone 17"
      launch_ios_simulator "iPad Pro 13-inch (M5)"
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      echo "launch: unknown target '$1'" >&2
      usage
      return 1
      ;;
  esac
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

FAILED=0
for target in "$@"; do
  dispatch_target "$target" || FAILED=1
done
exit "$FAILED"
