#!/bin/bash
# Capture the live Gattey Photos gallery toolbar at rest and scrolled.
# Usage: ./capture-toolbar.sh <label>
# Produces <label>-at-rest.png and <label>-scrolled.png in this directory.
set -euo pipefail
label="${1:?usage: capture-toolbar.sh <label>}"
dir="$(cd "$(dirname "$0")" && pwd)"
helper="$dir/gptoolbar.swift"

grab() { # grab <outfile>
  local out="$1" winid tries=0
  while [ $tries -lt 8 ]; do
    read -r winid _ < <(swift "$helper" info)
    if [ -n "${winid:-}" ] && screencapture -x -o -l"$winid" "$out" 2>/dev/null; then
      return 0
    fi
    tries=$((tries+1)); sleep 0.5
  done
  echo "failed to grab $out" >&2; return 1
}

swift "$helper" scroll 0 >/dev/null
sleep 0.6
grab "$dir/$label-at-rest.png"

swift "$helper" scroll 0.72 >/dev/null
sleep 0.6
grab "$dir/$label-scrolled.png"

swift "$helper" scroll 0 >/dev/null
echo "wrote $label-at-rest.png and $label-scrolled.png"
