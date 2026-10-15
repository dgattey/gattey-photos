#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPCAST="$ROOT/server/public/appcast.xml"
VERSION_FILE="$ROOT/macos/VERSION"
BASE="${GATTEY_RELEASE_BASE_URL:-https://photos.gattey.com}"

current="${GATTEY_CURRENT_VERSION:-}"
release_type="${GATTEY_RELEASE_TYPE:-}"
has_pr_body=0
if [[ -n "${GATTEY_PR_BODY+x}" ]]; then
  pr_body="$GATTEY_PR_BODY"
  has_pr_body=1
fi

fail() {
  echo "next-release-version: $1" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --current | --release-type | --pr-body)
      [[ $# -ge 2 ]] || fail "usage: next-release-version.sh [--current <version>] [--release-type major|minor|patch] [--pr-body <text>]"
      case "$1" in
        --current) current="$2" ;;
        --release-type) release_type="$2" ;;
        --pr-body) pr_body="$2"; has_pr_body=1 ;;
      esac
      shift 2
      ;;
    *) fail "unknown option $1" ;;
  esac
done

release_type="$(printf '%s' "$release_type" | tr '[:upper:]' '[:lower:]')"
case "$release_type" in
  "" | major | minor | patch) ;;
  *) fail "release type must be major, minor, or patch, not '$release_type'" ;;
esac

appcast_version() {
  sed -n 's/.*<sparkle:shortVersionString>\([^<]*\)<\/sparkle:shortVersionString>.*/\1/p' | head -1
}

if [[ -z "$current" && -f "$APPCAST" ]]; then
  current="$(appcast_version <"$APPCAST")"
fi
if [[ -z "$current" ]]; then
  current="$(curl -fsS "$BASE/appcast.xml" 2>/dev/null | appcast_version || true)"
fi
if [[ -z "$current" && -f "$VERSION_FILE" ]]; then
  current="$(tr -d '[:space:]' <"$VERSION_FILE")"
fi
current="${current:-1.0.0}"

base="${current%%-*}"
semver_re='^[0-9]+(\.[0-9]+){0,2}$'
[[ "$base" =~ $semver_re ]] || fail "current version must look like 1.2.3, not '$current'"
IFS=. read -r major minor patch <<<"$base"
major=$((10#$major))
minor=$((10#${minor:-0}))
patch=$((10#${patch:-0}))

parse_release_type() {
  awk '
    { sub(/\r$/, ""); line = tolower($0) }
    line ~ /^#+[ \t]+release info[ \t]*$/ { in_section = 1; next }
    /^#+[ \t]/ || index($0, "<!-- CURSOR_AGENT_PR_BODY_END -->") { in_section = 0 }
    in_section && line ~ /^[ \t]*[-*][ \t]+\[x\][ \t]+major[ \t]*$/ { has_major = 1 }
    in_section && line ~ /^[ \t]*[-*][ \t]+\[x\][ \t]+minor[ \t]*$/ { has_minor = 1 }
    END { print (has_major ? "major" : (has_minor ? "minor" : "patch")) }
  '
}

fetch_merged_pr_body() {
  [[ -n "${GITHUB_REPOSITORY:-}" && -n "${GITHUB_SHA:-}" ]] || return 0
  local token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  local pulls
  if ! pulls="$(curl -fsS -H "Accept: application/vnd.github+json" ${token:+-H "Authorization: Bearer $token"} \
    "${GITHUB_API_URL:-https://api.github.com}/repos/$GITHUB_REPOSITORY/commits/$GITHUB_SHA/pulls")"; then
    echo "next-release-version: could not list pull requests for $GITHUB_SHA" >&2
    return 0
  fi
  jq -r --arg sha "$GITHUB_SHA" '
    if type == "array" then
      map(select(.merged_at != null))
      | ((map(select(.merge_commit_sha == $sha)) | first) // max_by(.number))
      | .body // empty
    else empty end' <<<"$pulls" 2>/dev/null || true
}

commit_message() {
  if [[ -n "${GATTEY_COMMIT_MESSAGE+x}" ]]; then
    printf '%s' "$GATTEY_COMMIT_MESSAGE"
  else
    git -C "$ROOT" log -1 --format=%B "${GITHUB_SHA:-HEAD}" 2>/dev/null || true
  fi
}

if [[ -n "$release_type" ]]; then
  decided_by="override"
elif [[ "$has_pr_body" -eq 1 ]]; then
  release_type="$(parse_release_type <<<"$pr_body")"
  decided_by="pr_body"
else
  body="$(fetch_merged_pr_body)"
  if [[ -n "$body" ]]; then
    decided_by="merged_pr"
  else
    body="$(commit_message)"
    if [[ -n "$body" ]]; then
      decided_by="commit"
    else
      decided_by="default"
    fi
  fi
  release_type="$(parse_release_type <<<"$body")"
fi

case "$release_type" in
  major) next="$((major + 1)).0.0" ;;
  minor) next="$major.$((minor + 1)).0" ;;
  patch) next="$major.$minor.$((patch + 1))" ;;
esac

echo "next-release-version: $current to $next ($release_type from $decided_by)" >&2
printf '%s\n' "$next"
