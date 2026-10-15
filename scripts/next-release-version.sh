#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPCAST="$ROOT/server/public/appcast.xml"
VERSION_FILE="$ROOT/macos/VERSION"
BASE="${GATTEY_RELEASE_BASE_URL:-https://photos.gattey.com}"

current_override="${GATTEY_CURRENT_VERSION:-}"
release_type_override="${GATTEY_RELEASE_TYPE:-}"
pr_body="${GATTEY_PR_BODY:-}"
event_path="${GITHUB_EVENT_PATH:-}"

fail() {
  echo "next-release-version: $1" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  [[ $# -ge 2 ]] || fail "usage: next-release-version.sh [--current <version>] [--release-type major|minor|patch] [--pr-body <text>] [--event-path <path>]"
  case "$1" in
    --current) current_override="$2" ;;
    --release-type) release_type_override="$2" ;;
    --pr-body) pr_body="$2" ;;
    --event-path) event_path="$2" ;;
    *) fail "unknown option $1" ;;
  esac
  shift 2
done

release_type_override="$(printf '%s' "$release_type_override" | tr '[:upper:]' '[:lower:]')"
case "$release_type_override" in
  "" | major | minor | patch) ;;
  *) fail "release type must be major, minor, or patch, not '$release_type_override'" ;;
esac

set_found_from_first_nonempty() {
  FOUND_SOURCE=""
  FOUND_TEXT=""
  local fn
  for fn in "$@"; do
    FOUND_TEXT="$("$fn")"
    if [[ -n "$FOUND_TEXT" ]]; then
      FOUND_SOURCE="$fn"
      return
    fi
  done
}

appcast_version() {
  sed -n 's/.*<sparkle:shortVersionString>\([^<]*\)<\/sparkle:shortVersionString>.*/\1/p' | head -1
}

current_from_override() { printf '%s' "$current_override"; }
current_from_committed_appcast() { if [[ -f "$APPCAST" ]]; then appcast_version <"$APPCAST"; fi; }
current_from_live_appcast() { curl -fsS "$BASE/appcast.xml" 2>/dev/null | appcast_version || true; }
current_from_version_file() { if [[ -f "$VERSION_FILE" ]]; then tr -d '[:space:]' <"$VERSION_FILE"; fi; }

fetch_pulls() {
  local token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  curl -fsS -H "Accept: application/vnd.github+json" ${token:+-H "Authorization: Bearer $token"} \
    "${GITHUB_API_URL:-https://api.github.com}/repos/$GITHUB_REPOSITORY/commits/$GITHUB_SHA/pulls" ||
    echo "next-release-version: could not list pull requests for $GITHUB_SHA" >&2
}

text_from_pr_body() { printf '%s' "$pr_body"; }
text_from_event() { if [[ -n "$event_path" ]]; then jq -r '.pull_request.body // empty' "$event_path"; fi; }
text_from_merged_pr() {
  local pulls=""
  if [[ -n "${GATTEY_PULLS_JSON+x}" ]]; then
    pulls="$GATTEY_PULLS_JSON"
  elif [[ -n "${GITHUB_REPOSITORY:-}" && -n "${GITHUB_SHA:-}" ]]; then
    pulls="$(fetch_pulls)"
  fi
  [[ -n "$pulls" ]] || return 0
  jq -r --arg sha "${GITHUB_SHA:-}" '
    map(select(.merged_at != null))
    | (map(select(.merge_commit_sha == $sha)) | first) // max_by(.number)
    | .body // empty' <<<"$pulls"
}
text_from_commit() {
  if [[ -n "${GATTEY_COMMIT_MESSAGE+x}" ]]; then
    printf '%s' "$GATTEY_COMMIT_MESSAGE"
  else
    git -C "$ROOT" log -1 --format=%B "${GITHUB_SHA:-HEAD}" 2>/dev/null || true
  fi
}

release_info_section_or_all() {
  tr -d '\r' | awk '
    tolower($0) ~ /^#+[ \t]+release info/ { found = 1; inside = 1; next }
    /^#+[ \t]/ || index($0, "<!-- CURSOR_AGENT_PR_BODY_END -->") { inside = 0 }
    { all = all $0 "\n" }
    inside { section = section $0 "\n" }
    END { printf "%s", (found ? section : all) }
  '
}

parse_release_type() {
  local info
  info="$(release_info_section_or_all)"
  if grep -qiF -e '- [x] major' <<<"$info"; then
    echo major
  elif grep -qiF -e '- [x] minor' <<<"$info"; then
    echo minor
  else
    echo patch
  fi
}

set_found_from_first_nonempty current_from_override current_from_committed_appcast current_from_live_appcast current_from_version_file
current="${FOUND_TEXT:-1.0.0}"
base="${current%%-*}"
semver_re='^[0-9]+(\.[0-9]+){0,2}$'
[[ "$base" =~ $semver_re ]] || fail "current version must look like 1.2.3, not '$current'"
IFS=. read -r major minor patch <<<"$base"
major=$((10#$major))
minor=$((10#${minor:-0}))
patch=$((10#${patch:-0}))

if [[ -n "$release_type_override" ]]; then
  release_type="$release_type_override"
  decided_by="override"
else
  set_found_from_first_nonempty text_from_pr_body text_from_event text_from_merged_pr text_from_commit
  release_type="$(parse_release_type <<<"$FOUND_TEXT")"
  decided_by="${FOUND_SOURCE#text_from_}"
fi

case "$release_type" in
  major) next="$((major + 1)).0.0" ;;
  minor) next="$major.$((minor + 1)).0" ;;
  patch) next="$major.$minor.$((patch + 1))" ;;
esac

echo "next-release-version: $current to $next ($release_type from ${decided_by:-default})" >&2
printf '%s\n' "$next"
