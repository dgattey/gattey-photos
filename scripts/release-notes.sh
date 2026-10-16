#!/usr/bin/env bash
# Extract release notes from a PR body or commit message and format them as
# clean, scannable HTML suitable for Sparkle's WebKit update dialog (<description><![CDATA[...]]>).
#
# Prefers `# Release notes` -> `# Highlights` -> `# What changed?` -> `# Summary` -> `# How`,
# strips parenthetical repo file-path noise and standalone PR images, and renders
# Markdown bullets, `code`, **bold**, and links into styled HTML.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

version="${GATTEY_RELEASE_VERSION:-1.0.0}"
has_pr_body=0
pr_body=""
if [[ -n "${GATTEY_RELEASE_NOTES+x}" && -n "${GATTEY_RELEASE_NOTES}" ]]; then
  pr_body="$GATTEY_RELEASE_NOTES"
  has_pr_body=1
elif [[ -n "${GATTEY_PR_BODY+x}" ]]; then
  pr_body="$GATTEY_PR_BODY"
  has_pr_body=1
fi

fail() {
  echo "release-notes: $1" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version | --pr-body)
      [[ $# -ge 2 ]] || fail "usage: release-notes.sh [--version <version>] [--pr-body <text>]"
      case "$1" in
        --version) version="$2" ;;
        --pr-body) pr_body="$2"; has_pr_body=1 ;;
      esac
      shift 2
      ;;
    *) fail "unknown option $1" ;;
  esac
done

fetch_merged_pr_body() {
  [[ -n "${GITHUB_REPOSITORY:-}" && -n "${GITHUB_SHA:-}" ]] || return 0
  local token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  local pulls=""
  local attempt
  for attempt in 1 2 3; do
    if pulls="$(curl -fsS --connect-timeout 10 --max-time 20 -H "Accept: application/vnd.github+json" ${token:+-H "Authorization: Bearer $token"} \
      "${GITHUB_API_URL:-https://api.github.com}/repos/$GITHUB_REPOSITORY/commits/$GITHUB_SHA/pulls" 2>/dev/null)"; then
      break
    fi
    sleep 2
  done
  if [[ -z "$pulls" ]]; then
    echo "release-notes: could not list pull requests for $GITHUB_SHA" >&2
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

if [[ "$has_pr_body" -eq 1 ]]; then
  raw_body="$pr_body"
else
  raw_body="$(fetch_merged_pr_body)"
  if [[ -z "$raw_body" ]]; then
    raw_body="$(commit_message)"
  fi
fi

GATTEY_RAW_NOTES="$raw_body" python3 - "$version" <<'PY'
import html
import os
import re
import sys

version = sys.argv[1]
raw = os.environ.get("GATTEY_RAW_NOTES", "").replace("\r\n", "\n").replace("\r", "\n").strip()

# Truncate at CURSOR_AGENT_PR_BODY_END if present before stripping comments
end_marker = "<!-- CURSOR_AGENT_PR_BODY_END -->"
if end_marker in raw:
    raw = raw.split(end_marker, 1)[0]

# Strip HTML comments and agent footer divs
raw = re.sub(r"<!--[\s\S]*?-->", "", raw)
raw = re.sub(r"<div\b[^>]*>[\s\S]*?</div>", "", raw, flags=re.IGNORECASE).strip()


def extract_section(text: str, heading: str) -> str:
    lines = text.splitlines()
    in_section = False
    collected = []
    heading_re = re.compile(rf"^#+\s*{re.escape(heading)}\s*$", re.IGNORECASE)
    any_heading_re = re.compile(r"^#+\s+\S")
    hr_re = re.compile(r"^---+\s*$")
    for line in lines:
        if heading_re.match(line.strip()):
            in_section = True
            continue
        if in_section:
            if any_heading_re.match(line.strip()) or hr_re.match(line.strip()):
                break
            collected.append(line)
    cleaned = [l for l in collected if not re.match(r"^\s*[-*]\s*$", l)]
    return "\n".join(cleaned).strip()


def strip_non_note_sections(text: str) -> str:
    lines = text.splitlines()
    skip_section = False
    skip_heading_re = re.compile(r"^#+\s*(?:release info|testing|test plan|why)\s*$", re.IGNORECASE)
    any_heading_re = re.compile(r"^#+\s+\S")
    closes_re = re.compile(r"^(?:closes|fixes|resolves)\b.*$", re.IGNORECASE)
    collected = []
    for line in lines:
        stripped = line.strip()
        if skip_heading_re.match(stripped):
            skip_section = True
            continue
        if skip_section:
            if any_heading_re.match(stripped):
                skip_section = False
            else:
                continue
        if closes_re.match(stripped) or re.match(r"^\s*[-*]\s*$", line):
            continue
        collected.append(line)
    return "\n".join(collected).strip()


selected = ""
for section_name in ("Release notes", "Highlights", "What changed?", "Summary", "How"):
    extracted = extract_section(raw, section_name)
    if extracted:
        selected = extracted
        break

if not selected and not re.search(r"^#+\s+\S", raw, re.MULTILINE):
    selected = strip_non_note_sections(raw)

raw = selected

if re.search(r"<(ul|ol|li|p)\b", raw, re.IGNORECASE):
    print(raw)
    sys.exit(0)

PATH_EXT_RE = re.compile(
    r"^("
    r"[/\.]\S+|"
    r"(?:macos|scripts|server|docs|\.github)/\S*|"
    r"\S+\.(?:swift|ts|tsx|js|mjs|css|json|yml|yaml|sh|py|md|plist|entitlements|pbxproj|xcframework|png|jpg|jpeg|svg|ico|xml)|"
    r"(?:npm|swift)\s+test"
    r")$"
)


def is_noise_paren(inner: str) -> bool:
    cleaned = inner.strip()
    if not cleaned:
        return True
    parts = re.split(r"\s*(?:,|\band\b|\bor\b)\s*", cleaned)
    for part in parts:
        token = part.strip().strip("`").strip()
        if not token or not PATH_EXT_RE.match(token):
            return False
    return True


def strip_file_path_parens(text: str) -> str:
    def repl(match: re.Match) -> str:
        inner = match.group(1)
        if is_noise_paren(inner):
            return ""
        return match.group(0)

    out = re.sub(r"\s*\(([^()]+)\)", repl, text)
    out = re.sub(r"\s+([,.;:])", r"\1", out)
    out = re.sub(r"  +", " ", out)
    return out.strip()


def render_inline(text: str) -> str:
    text = strip_file_path_parens(text)
    escaped = html.escape(text, quote=False)
    escaped = re.sub(
        r"\[([^\]]+)\]\((https?://[^\s)]+)\)",
        r'<a href="\2">\1</a>',
        escaped,
    )
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", escaped)
    escaped = re.sub(r"`([^`]+)`", r"<code>\1</code>", escaped)
    return escaped


lines = raw.splitlines()
bullets = []
paragraphs = []
current_bullet = None

for line in lines:
    stripped = line.strip()
    if not stripped:
        if current_bullet is not None:
            bullets.append(current_bullet)
            current_bullet = None
        continue
    if re.match(r"^!\[[^\]]*\]\([^)]+\)$", stripped) or re.match(
        r"^<(?:img|video)\b", stripped, re.IGNORECASE
    ):
        continue
    if re.match(r"^#+\s+", stripped):
        continue
    bullet_match = re.match(r"^[-*]\s+(.+)$", stripped)
    if bullet_match:
        if current_bullet is not None:
            bullets.append(current_bullet)
        current_bullet = bullet_match.group(1).strip()
    elif current_bullet is not None:
        current_bullet = f"{current_bullet} {stripped}"
    else:
        paragraphs.append(stripped)

if current_bullet is not None:
    bullets.append(current_bullet)

out_parts = []
if paragraphs:
    for p in paragraphs:
        rendered_p = render_inline(p)
        if rendered_p:
            out_parts.append(
                f'<p style="margin: 0 0 8px 0; line-height: 1.45;">{rendered_p}</p>'
            )
if bullets:
    rendered_bullets = [render_inline(b) for b in bullets]
    rendered_bullets = [b for b in rendered_bullets if b]
    if rendered_bullets:
        out_parts.append("<ul>")
        for b in rendered_bullets:
            out_parts.append(f'  <li style="margin-bottom: 6px; line-height: 1.45;">{b}</li>')
        out_parts.append("</ul>")

if not out_parts:
    out_parts.append(f'<p style="margin: 0; line-height: 1.45;">Release v{html.escape(version)}</p>')

print("\n".join(out_parts))
PY
