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
existing_appcast="${GATTEY_EXISTING_APPCAST:-}"
max_versions="${GATTEY_MAX_RELEASE_NOTES_VERSIONS:-10}"
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
    --version | --pr-body | --existing-appcast | --max-versions)
      [[ $# -ge 2 ]] || fail "usage: release-notes.sh [--version <version>] [--pr-body <text>] [--existing-appcast <path>] [--max-versions <count>]"
      case "$1" in
        --version) version="$2" ;;
        --pr-body) pr_body="$2"; has_pr_body=1 ;;
        --existing-appcast) existing_appcast="$2" ;;
        --max-versions) max_versions="$2" ;;
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

GATTEY_RAW_NOTES="$raw_body" \
GATTEY_EXISTING_APPCAST_PATH="$existing_appcast" \
GATTEY_MAX_VERSIONS="$max_versions" \
python3 - "$version" <<'PY'
import html
import os
import re
import subprocess
import sys

version = sys.argv[1].strip()
existing_appcast = os.environ.get("GATTEY_EXISTING_APPCAST_PATH", "").strip()
try:
    max_versions = max(1, int(os.environ.get("GATTEY_MAX_VERSIONS", "10")))
except ValueError:
    max_versions = 10
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


def render_current_body(raw_text: str) -> str:
    if re.search(r"<(ul|ol|li|p)\b", raw_text, re.IGNORECASE):
        h3_stripped = re.sub(r"^\s*<h3\b[^>]*>[\s\S]*?</h3>\s*", "", raw_text, count=1, flags=re.IGNORECASE)
        return h3_stripped.strip() or raw_text.strip()

    lines = raw_text.splitlines()
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

    return "\n".join(out_parts)


def extract_sections_from_appcast_xml(xml_text: str) -> list[tuple[str, str]]:
    sections: list[tuple[str, str]] = []
    item_blocks = re.findall(r"<item\b[^>]*>([\s\S]*?)</item>", xml_text, flags=re.IGNORECASE)
    if not item_blocks:
        item_blocks = [xml_text]

    for item in item_blocks:
        desc_match = re.search(r"<description\b[^>]*>([\s\S]*?)</description>", item, flags=re.IGNORECASE)
        if not desc_match:
            continue
        raw_desc = desc_match.group(1).strip()
        cdata_match = re.search(r"<!\[CDATA\[([\s\S]*?)\]\]>", raw_desc)
        if cdata_match:
            desc = cdata_match.group(1).strip()
        else:
            desc = html.unescape(raw_desc).strip()
        if not desc:
            continue

        h3_matches = list(re.finditer(r"<h3\b[^>]*>([\s\S]*?)</h3>", desc, flags=re.IGNORECASE))
        if h3_matches:
            for idx, match in enumerate(h3_matches):
                ver_text = html.unescape(re.sub(r"<[^>]+>", "", match.group(1))).strip()
                start = match.end()
                end = h3_matches[idx + 1].start() if idx + 1 < len(h3_matches) else len(desc)
                body_html = desc[start:end].strip()
                if ver_text and body_html:
                    sections.append((ver_text, body_html))
        else:
            ver_match = re.search(
                r"<sparkle:shortVersionString>\s*([^<\s]+)\s*</sparkle:shortVersionString>",
                item,
                flags=re.IGNORECASE,
            ) or re.search(r"<title>\s*([^<\s]+)\s*</title>", item, flags=re.IGNORECASE)
            if ver_match:
                ver_text = html.unescape(ver_match.group(1)).strip()
                if ver_text:
                    sections.append((ver_text, desc))

    return sections


def load_prior_sections(appcast_path: str) -> list[tuple[str, str]]:
    if not appcast_path:
        return []
    collected: list[tuple[str, str]] = []
    if os.path.isfile(appcast_path):
        try:
            with open(appcast_path, "r", encoding="utf-8") as f:
                collected.extend(extract_sections_from_appcast_xml(f.read()))
        except OSError:
            pass

    appcast_abs = os.path.abspath(appcast_path)
    appcast_dir = os.path.dirname(appcast_abs)
    appcast_name = os.path.basename(appcast_abs)
    if os.path.isdir(appcast_dir):
        rel_proc = subprocess.run(
            ["git", "-C", appcast_dir, "ls-files", "--full-name", "--error-unmatch", appcast_name],
            capture_output=True,
            text=True,
            check=False,
        )
        if rel_proc.returncode == 0:
            rel_path = rel_proc.stdout.strip()
            log_proc = subprocess.run(
                [
                    "git",
                    "-C",
                    appcast_dir,
                    "log",
                    f"-n{max_versions * 2}",
                    "--format=%H",
                    "--",
                    appcast_name,
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            if log_proc.returncode == 0:
                for sha in log_proc.stdout.splitlines():
                    sha = sha.strip()
                    if not sha:
                        continue
                    show_proc = subprocess.run(
                        ["git", "-C", appcast_dir, "show", f"{sha}:{rel_path}"],
                        capture_output=True,
                        text=True,
                        check=False,
                    )
                    if show_proc.returncode == 0 and show_proc.stdout:
                        collected.extend(extract_sections_from_appcast_xml(show_proc.stdout))

    return collected


def normalize_version_key(ver: str) -> str:
    return ver.strip().lstrip("vV")


all_sections: list[tuple[str, str]] = [(version, render_current_body(raw))]
all_sections.extend(load_prior_sections(existing_appcast))

deduped: list[tuple[str, str]] = []
seen_versions: set[str] = set()
for ver_label, body_html in all_sections:
    key = normalize_version_key(ver_label)
    if not key or key in seen_versions:
        continue
    seen_versions.add(key)
    deduped.append((key, body_html))
    if len(deduped) >= max_versions:
        break

rendered_sections: list[str] = []
for idx, (ver_label, body_html) in enumerate(deduped):
    escaped_ver = html.escape(ver_label)
    if idx == 0:
        heading = f'<h3 style="margin: 0 0 6px 0; font-size: 13px;">{escaped_ver}</h3>'
    else:
        heading = f'<h3 style="margin: 14px 0 6px 0; font-size: 13px; opacity: 0.75;">{escaped_ver}</h3>'
    rendered_sections.append(f"{heading}\n{body_html}")

print("\n".join(rendered_sections))
PY
