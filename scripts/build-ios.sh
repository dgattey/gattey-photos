#!/usr/bin/env bash
# Build GatteyPhotosIOS for the iOS Simulator (SwiftPM + xcodebuild).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MACOS="$ROOT/macos"
SCHEME="${IOS_SCHEME:-GatteyPhotosIOS}"
CONFIG="${IOS_CONFIG:-Debug}"
# Override with IOS_SIM_DEST if your Xcode has a different default simulator name.
DEST="${IOS_SIM_DEST:-platform=iOS Simulator,name=iPhone 17}"

cd "$MACOS"
echo "build-ios: scheme=$SCHEME destination='$DEST' config=$CONFIG" >&2

xcodebuild \
  -scheme "$SCHEME" \
  -destination "$DEST" \
  -sdk iphonesimulator \
  -configuration "$CONFIG" \
  CODE_SIGNING_ALLOWED=YES \
  build

echo "build-ios: done. Install and launch: ./scripts/run-ios.sh (see skills/ios/SKILL.md)." >&2
