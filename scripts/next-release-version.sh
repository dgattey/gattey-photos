#!/usr/bin/env bash
# Print the next patch version (e.g. 1.0.3 → 1.0.4).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPCAST="$ROOT/server/public/appcast.xml"
VERSION_FILE="$ROOT/macos/VERSION"
BASE="${GATTEY_RELEASE_BASE_URL:-https://photos.gattey.com}"

current="1.0.0"
if [[ -f "$APPCAST" ]]; then
  parsed="$(sed -n 's/.*<sparkle:shortVersionString>\([^<]*\)<\/sparkle:shortVersionString>.*/\1/p' "$APPCAST" | head -1)"
  [[ -n "$parsed" ]] && current="$parsed"
elif tmp="$(mktemp)" && curl -fsS "$BASE/appcast.xml" -o "$tmp" 2>/dev/null; then
  parsed="$(sed -n 's/.*<sparkle:shortVersionString>\([^<]*\)<\/sparkle:shortVersionString>.*/\1/p' "$tmp" | head -1)"
  [[ -n "$parsed" ]] && current="$parsed"
  rm -f "$tmp"
elif [[ -f "$VERSION_FILE" ]]; then
  current="$(tr -d '[:space:]' <"$VERSION_FILE")"
fi

IFS='.' read -r major minor patch <<<"$current"
patch="${patch:-0}"
minor="${minor:-0}"
major="${major:-1}"
printf '%s.%s.%s\n' "$major" "$minor" "$((patch + 1))"
