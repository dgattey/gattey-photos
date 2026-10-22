#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> macOS: swift-format lint"
if command -v swift-format >/dev/null 2>&1; then
  swift-format lint --strict --recursive --parallel --configuration "$ROOT/.swift-format" macos/Sources macos/Tests macos/Package.swift
else
  xcrun swift-format lint --strict --recursive --parallel --configuration "$ROOT/.swift-format" macos/Sources macos/Tests macos/Package.swift
fi

echo "==> macOS: swift test"
(cd macos && swift test --build-system native)

echo "==> iOS: simulator build"
"$ROOT/scripts/build-ios.sh" >/dev/null

echo "==> server: typecheck"
# shellcheck source=scripts/lib/node-env.sh
source "$ROOT/scripts/lib/node-env.sh"
(cd server && npm run typecheck)

echo "==> server: unit tests"
(cd server && npm run test)

echo "==> server: production build"
(cd server && npm run build)

echo "verify: all checks passed"
