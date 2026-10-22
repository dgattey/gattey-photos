#!/usr/bin/env bash
# Write the newest published appcast.xml to dist/previous-appcast.xml (or $1). Releases read the current
# version, the last build number, and the release-notes history from it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$ROOT/dist/previous-appcast.xml}"
REPO="${GITHUB_REPOSITORY:-dgattey/gattey-photos}"
LEGACY="server/public/appcast.xml"

mkdir -p "$(dirname "$DEST")"
rm -f "$DEST"

# The latest GitHub release is the source of truth. Releases up to 1.1.10 were committed to
# server/public/ instead, so before the first GitHub release, read the last committed appcast.
legacy_commit="$(git -C "$ROOT" log -1 --format=%H --diff-filter=AM -- "$LEGACY" 2>/dev/null || true)"
if gh release download --repo "$REPO" --pattern appcast.xml --output "$DEST" 2>/dev/null; then
  echo "fetch-previous-appcast: latest GitHub release of $REPO" >&2
elif [[ -n "$legacy_commit" ]] && git -C "$ROOT" show "$legacy_commit:$LEGACY" >"$DEST"; then
  echo "fetch-previous-appcast: $LEGACY at ${legacy_commit:0:7}" >&2
else
  rm -f "$DEST"
  echo "fetch-previous-appcast: no appcast in $REPO releases or in the history of $LEGACY." >&2
  echo "fetch-previous-appcast: for a first release, set GATTEY_CURRENT_VERSION instead." >&2
  exit 1
fi
