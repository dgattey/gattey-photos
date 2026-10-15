#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> macOS: swift test"
(cd macos && swift test --build-system native)

echo "==> server: typecheck"
# shellcheck source=scripts/lib/node-env.sh
source "$ROOT/scripts/lib/node-env.sh"
(cd server && npm run typecheck)

echo "==> server: unit tests"
(cd server && npm run test)

echo "==> server: production build"
(cd server && npm run build)

echo "verify: all checks passed"
